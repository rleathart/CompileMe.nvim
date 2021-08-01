augroup CompileMe
  au!
  au BufEnter,TermOpen term://* lua require('CompileMe').last_terminal = {id = vim.b.terminal_job_id, pid = vim.b.terminal_job_pid, bufnr = vim.api.nvim_buf_get_number(0)}
  au TermClose * lua require('CompileMe').last_terminal = nil
  au VimEnter,BufWinEnter * lua require('CompileMe.project').init()
augroup END

function s:command_completion(A, L, P)
  let commands = luaeval("require('CompileMe.project').get_current().compiler.commands")
  return filter(commands, {_, val -> match(val, "^".a:A) >= 0})
endfunction

command! -complete=customlist,s:command_completion -nargs=? CompileMe lua require('CompileMe').command_wrapper("<args>")
