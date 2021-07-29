local Task = require 'CompileMe.task'
local Command = require 'CompileMe.command'
local upfind = require 'CompileMe.upfind'

local M = {}

M.compile = function ()
  local makefilePath = upfind('Makefile')[1]
  local makefileDir = vim.fn.fnamemodify(makefilePath, ':h')

  local make = Command()
  make.args = {'make'}
  make.working_directory = makefileDir
  make.is_vim_command = not require('CompileMe').last_terminal

  return Task{make}

end

M.run = function ()
  local makefilePath = upfind('Makefile')[1]
  local makefileDir = vim.fn.fnamemodify(makefilePath, ':h')

  local make = Command()
  make.args = {'make', 'run'}
  make.working_directory = makefileDir

  return Task{make}
end

M.compile_and_run = function ()
  return M.run()
end

return M
