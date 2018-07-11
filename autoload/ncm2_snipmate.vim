if get(s:, 'loaded', 0)
    finish
endif
let s:loaded = 1

inoremap <Plug>(ncm2_snipmate_expand_completed) <c-r>=ncm2_snipmate#_do_expand_completed()<cr>

func! ncm2_snipmate#expand_or(...)
    if !pumvisible()
        call call('feedkeys', a:000)
        return ''
    endif
    let s:or_key = a:000
    return "\<c-y>\<c-r>=ncm2_snipmate#_do_expand_or()\<cr>"
endfunc

func! ncm2_snipmate#_do_expand_or()
    if ncm2_snipmate#completed_is_snippet()
        call feedkeys("\<Plug>(ncm2_snipmate_expand_completed)", "im")
        return ''
    endif
    call call('feedkeys', s:or_key)
    return ''
endfunc

if !has("patch-8.0.1493")
    func! ncm2_snipmate#_do_expand_or()
        call call('feedkeys', s:or_key)
        return ''
    endfunc
endif

func! ncm2_snipmate#completed_is_snippet()
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

func! ncm2_snipmate#_do_expand_completed()
    if !ncm2_snipmate#completed_is_snippet()
        echom "v:completed_item is not a snippet"
        return ''
    endif
    let ud = json_decode(v:completed_item.user_data)
    if ud.snippet == ''
        " snipmate builtin snippet
        call feedkeys("\<Plug>snipMateTrigger", "im")
        return ''
    endif
    let &undolevels = &undolevels
    let snippet = ud.snipmate_snippet
    let trigger = ud.snippet_word
    let col = col('.') - len(trigger)
    sil exe 's/\V'.escape(trigger, '/\.').'\%#//'
    return snipMate#expandSnip(snippet, 1, col)
endfunc

" completion source

let g:ncm2_snipmate#source = get(g:, 'ncm2_snipmate#source', {
            \ 'name': 'snipmate',
            \ 'priority': 7,
            \ 'mark': '',
            \ 'word_pattern': '\S+',
            \ 'on_complete': 'ncm2_snipmate#on_complete',
            \ })

let g:ncm2_snipmate#source = extend(g:ncm2_snipmate#source,
            \ get(g:, 'ncm2_snipmate#source_override', {}),
            \ 'force')

func! ncm2_snipmate#init()
    call ncm2#register_source(g:ncm2_snipmate#source)
    if !has("patch-8.0.1493")
        " https://github.com/neovim/neovim/pull/8003
        echohl ErrorMsg
        echom 'ncm2-snipmate requires has("patch-8.0.1493")'
            \  ' https://github.com/neovim/neovim/pull/8003'
        echohl None
    endif
endfunc

func! ncm2_snipmate#on_complete(ctx)
	let word    = snipMate#WordBelowCursor()
	let matches = map(snipMate#GetSnippetsForWordBelowCursorForComplete(''),'extend(v:val,{"dup":1, "user_data": {"is_snippet": 1, "snippet": ""}})')
    let ccol = a:ctx['ccol']
    let startccol = a:ctx['ccol'] - strchars(word)
	call ncm2#complete(a:ctx, startccol, matches)
endfunc

" FIXME snipmate somehow don't play well when LanguageClient-neovim is auto
" applying text edits in
"    autocmd CompleteDone * call LanguageClient#handleCompleteDone()
augroup languageClient
    autocmd! CompleteDone
augroup END
