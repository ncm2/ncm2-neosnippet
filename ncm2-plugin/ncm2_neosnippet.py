# -*- coding: utf-8 -*-

import sys
if __name__ == '__main__':
    sys.path.append('./pythonx')

def wrap():

    from ncm2_core import ncm2_core
    from ncm2 import getLogger
    import vim
    import ncm2_lsp_snippet.utils as lsp_utils
    from ncm2_lsp_snippet.parser import Parser
    import re
    import json

    # # escape $ inside place holder $1
    # #   $ -> \\$
    # #   } -> \}
    # # escape $ outside placeholder
    # #   $ -> \$
    # #   } -> }
    # snippet test
    # options head
    #   \${1:kjkj} ${1:escape \\${ \} value} foobar{}${0}
    # 
    # # place holder ${3:foo3} in nested placeholder $2
    # # - for $2 ${3:foo3\}
    # # - for $1 ${3:foo3\\\} or \${3:foo3\\\}
    # snippet test2
    # options head
    #   hi ${1:escape ${2:foo2 ${3:foo3\\\} \} foobar} ha
    # 
    # # leteral "${3:foo3}" in nested placeholder $2
    # # - for $2 \\${ ... \}
    # # - for $1 \\\\\${ ... \\\}
    # snippet test3
    # options head
    #   hi \`mode()\` ${1:escape \${2:foo2 \\\\\${3:\`mode()\`foo3\\\} \} foobar} ha
    def flatten_ast(ast, level=0):
        txt = ''
        for t, ele in ast:
            if t == 'text':
                yield (t, level, ele)
            elif t == 'tabstop':
                # txt += '${%s}' % ele
                yield ('${', level, '${%s' % ele)
                yield ('}', level, '}')
            elif t == 'placeholder':
                tab, subast = ele
                yield ('${', level, '${%s:' % tab)
                yield from flatten_ast(subast, level + 1)
                yield ('}', level, '}')
            elif t == 'choice':
                # neosnippet doesn't support choices, replace it with placeholder
                tab, opts = ele
                yield ('${', level, '${%s:' % tab)
                yield ('text', level + 1, opts[0])
                yield ('}', level, '}')

    def to_neosnippet(ast):
        eles = []
        for t, level, s in flatten_ast(ast):
            if t == '${':
                eles.append(s)
            elif t == '}':
                eles.append('\\' * (2 ** level - 1) + r'}')
            elif t == 'text':
                s = s.replace('\\', '\\' * (2 ** level))
                if level == 0:
                    s = s.replace('$', r'\$')
                    # s = s.replace('}', r'}')
                else:
                    if level == 1:
                        s = s.replace('$', r'\\$')
                        s = s.replace('}', r'\}')
                    else:
                        s = s.replace('$', '\\' * (2 ** (level-1) * 3 - 1) + '$')
                        s = s.replace('}', '\\' * (2 ** level - 1) + r'\}')
                s = s.replace('`', r'\`')
                eles.append(s)
        return ''.join(eles)

    logger = getLogger(__name__)

    vim.command('call ncm2_neosnippet#init()')

    old_formalize = ncm2_core.match_formalize
    old_decorate = ncm2_core.matches_decorate

    parser = Parser()

    # convert lsp snippet into neosnippet snippet
    def formalize(ctx, item):
        item = old_formalize(ctx, item)
        item = lsp_utils.match_formalize(ctx, item)
        ud = item['user_data']
        if not ud['is_snippet']:
            return item
        if ud['snippet'] == '':
            return item
        try:
            ast = parser.get_ast(ud['snippet'])
            neosnippet = to_neosnippet(ast)
            if neosnippet:
                if len(ast) == 1 and ast[0][0] == 'text':
                    neosnippet += '${0}'
                ud['neosnippet_snippet'] = neosnippet
                ud['is_snippet'] = 1
            else:
                ud['is_snippet'] = 0
        except:
            ud['is_snippet'] = 0
            logger.exception("ncm2_lsp_snippet failed parsing item %s", item)
        return item

    # add [+] mark for snippets
    def decorate(data, matches):
        matches = old_decorate(data, matches)

        has_snippet = False

        for m in matches:
            ud = m['user_data']
            if not ud.get('is_snippet', False):
                continue
            has_snippet = True

        if not has_snippet:
            return matches

        for m in matches:
            ud = m['user_data']
            if ud.get('is_snippet', False):
                # [+] sign indicates that this completion item is
                # expandable
                if ud.get('ncm2_neosnippet_auto', False):
                    m['menu'] = '(+) ' + m['menu']
                else:
                    m['menu'] = '[+] ' + m['menu']
            else:
                m['menu'] = '[ ] ' + m['menu']

        return matches

    ncm2_core.matches_decorate = decorate
    ncm2_core.match_formalize = formalize


wrap()

# parser = Parser()
# 
# snippets = ["""
# hello ${1:world}.
# ""","""
# hello ${1:world \${\}}.
# ""","""
# hello ${1:world ${2:\${foobar\}}}}.
# ""","""
# hello ${1:world ${2:\${`mode()`foobar\}}}}.
# """,
# ]
# 
# # results:
# # hello ${1:world}.
# # hello ${1:world \\${\}}.
# # hello ${1:world ${2:\\\\\${foobar\\\\}\}}}.
# # hello ${1:world ${2:\\\\\${\`mode()\`foobar\\\\}\}}}.
# 
# for snippet in snippets:
#     ast = parser.get_ast(snippet)
#     # print(snippet)
#     print(to_neosnippet(ast))
