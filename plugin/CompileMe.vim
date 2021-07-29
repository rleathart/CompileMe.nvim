augroup CompileMe
  au!
  au BufEnter,TermOpen term://* lua require('CompileMe').last_terminal = {id = vim.b.terminal_job_id, pid = vim.b.terminal_job_pid, bufnr = vim.api.nvim_buf_get_number(0)}
  au TermClose * lua require('CompileMe').last_terminal = nil
  au VimEnter,BufWinEnter * lua require('CompileMe.project').init()
augroup END

function s:command_wrapper(dothis)
  if a:dothis == "run"
    lua require('CompileMe.project').get_current():run()
  endif
  if a:dothis == "compile_and_run"
    lua require('CompileMe.project').get_current():compile_and_run()
  endif

  lua require('CompileMe.project').get_current():compile()
endfunction

function s:command_completion(A, L, P)
  return ["compile", "run", "compile_and_run"]
endfunction

command! -complete=customlist,s:command_completion -nargs=? CompileMe call s:command_wrapper("<args>")
