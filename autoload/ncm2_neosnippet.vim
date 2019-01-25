if get(s:, 'loaded', 0)
    finish
endif
let s:loaded = 1

inoremap <silent> <Plug>(ncm2_neosnippet_expand_completed) <c-r>=ncm2_neosnippet#_do_expand_completed()<cr>

func! ncm2_neosnippet#expand_or(...)
    if !pumvisible()
        call call('feedkeys', a:000)
        return ''
    endif
    let s:or_key = a:000
    return "\<c-y>\<c-r>=ncm2_neosnippet#_do_expand_or()\<cr>"
endfunc

func! ncm2_neosnippet#_do_expand_or()
    if ncm2_neosnippet#completed_is_snippet()
        call feedkeys("\<Plug>(ncm2_neosnippet_expand_completed)", "im")
        return ''
    endif
    call call('feedkeys', s:or_key)
    return ''
endfunc

if !has("patch-8.0.1493")
    func! ncm2_neosnippet#_do_expand_or()
        call call('feedkeys', s:or_key)
        return ''
    endfunc
endif

func! ncm2_neosnippet#completed_is_snippet()
    if empty(v:completed_item)
        return 0
    endif
    let ud = {}
    silent! let ud = json_decode(v:completed_item.user_data)
    if empty(ud) || type(ud) != v:t_dict
        return 0
    endif
    return get(ud, 'is_snippet', 0)
endfunc

func! ncm2_neosnippet#_do_expand_completed()
    if !ncm2_neosnippet#completed_is_snippet()
        echom "v:completed_item is not a snippet"
        return ''
    endif
    let completed = deepcopy(v:completed_item)
    let ud = json_decode(completed.user_data)
    let completed.user_data = ud
    if ud.snippet == ''
        " neosnippet builtin snippet
        " FIXME use complete to empty the v:completed_item so that
        " neosnippet-s:get_completed_snippets will not mess with us. We don't
        " need neosnippet expanding v:completed_item directly anymore.
        call complete(1, [])
        call feedkeys("\<Plug>(neosnippet_expand_or_jump)", "im")
        return ''
    endif
    let &undolevels = &undolevels
    py3 from ncm2_lsp_snippet.utils import apply_additional_text_edits
    py3 import vim
    py3 apply_additional_text_edits(vim.eval('json_encode(l:completed)'))

    " remove trigger
    let trigger = ud.snippet_word
    let pos = getcurpos()
    let col = col('.')
    let line = getline('.')
    let begin = strpart(line, 0, col - 1 - len(trigger))
    let end = strpart(line, col - 1)
    call setline(line('.'), begin . end)
    let pos[2] = len(begin) + 1
    call setpos('.', pos)

    let snippet = ud.neosnippet_snippet
    return neosnippet#anonymous(snippet)
endfunc

" completion source

let g:ncm2_neosnippet#source = extend(get(g:, 'ncm2_neosnippet#source', {}), {
            \ 'name': 'neosnippet',
            \ 'priority': 7,
            \ 'mark': 'ns',
            \ 'word_pattern': '\S+',
            \ 'on_complete': 'ncm2_neosnippet#on_complete',
            \ }, 'keep')

func! ncm2_neosnippet#init()
    call ncm2#register_source(g:ncm2_neosnippet#source)
    if !has("patch-8.0.1493")
        " https://github.com/neovim/neovim/pull/8003
        echohl ErrorMsg
        echom 'ncm2-neosnippet requires has("patch-8.0.1493")'
            \  ' https://github.com/neovim/neovim/pull/8003'
        echohl None
    endif
    let g:neosnippet#enable_completed_snippet = 0
    let g:neosnippet#enable_complete_done = 0
endfunc

func! ncm2_neosnippet#on_complete(ctx)
	let snips = values(neosnippet#helpers#get_completion_snippets())
	let matches = map(l:snips, '{"word":v:val["word"], "dup":1, "icase":1, "menu": "Snip: " . v:val["menu_abbr"], "user_data": {"is_snippet": 1}}')
	call ncm2#complete(a:ctx, a:ctx.startccol, matches)
endfunc
