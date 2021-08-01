local Task = require 'CompileMe.task'
local Command = require 'CompileMe.command'
local upfind = require 'CompileMe.upfind'

local M = {}

M.compile = function()
  local exe_ext = vim.fn.has('win32') == 1 and '.exe' or ''
  local ft = vim.bo.ft
  local file_path = vim.fn.expand('%:p')
  local file_path_no_ext = vim.fn.fnamemodify(file_path, ':r')
  local exe_path = file_path_no_ext .. exe_ext

  local possible_commmands = {}
  if ft == 'c' then
    table.insert(possible_commmands, Command{
      args = {'cl.exe', '-nologo', file_path, '-Fe:', exe_path}
    })
    table.insert(possible_commmands, Command{
      args = {'clang', file_path, '-o', exe_path}
    })
    table.insert(possible_commmands, Command{
      args = {'gcc', file_path, '-o', exe_path}
    })
  elseif ft == 'cpp' then
    table.insert(possible_commmands, Command{
      args = {'cl.exe', '-nologo', '-EHsc', file_path, '-Fe:', exe_path}
    })
    table.insert(possible_commmands, Command{
      args = {'clang++', file_path, '-o', exe_path}
    })
    table.insert(possible_commmands, Command{
      args = {'g++', file_path, '-o', exe_path}
    })
  end

  local task = Task()
  for _, cmd in ipairs(possible_commmands) do
    if vim.fn.executable(cmd.args[1]) == 1 then
      task.commands = {cmd}
      break
    end
  end

  return task
end

M.run = function()
  local exe_ext = vim.fn.has('win32') == 1 and '.exe' or ''
  local ft = vim.bo.ft
  local file_path = vim.fn.expand('%:p')
  local file_path_no_ext = vim.fn.fnamemodify(file_path, ':r')
  local exe_path = file_path_no_ext .. exe_ext

  local task = Task()

  if vim.fn.has('unix') == 1 and vim.fn.getfperm(file_path):match('x') then
    task.commands = {Command{args = {file_path}}}
  end

  if ft == 'c' or ft == 'cpp' then
    task.commands = {Command{args = {exe_path}}}
  end

  if ft == 'python' then
    local main_py = upfind('main.py')[1]
    if main_py then
      task.commands = {Command{
        args = {'python3', main_py},
        workingDirectory = vim.fn.fnamemodify(main_py, ':h')
      }}
    end
  end

  return task
end

M.compile_and_run = function ()
  return M.compile() + M.run()
end

M.commands = {
  "run",
  "compile",
  "compile_and_run"
}

return M
