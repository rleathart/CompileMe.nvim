local Task = require 'CompileMe.task'
local Command = require 'CompileMe.command'
local upfind = require 'CompileMe.upfind'

local M = {}

M.cmakeWriteQuery = function(query)
  local cmakeListsPath = upfind('CMakeLists.txt')[1]
  local cmakeBuildDir = vim.b.CMakeBuildDir or 'build'
  local cmakeAPIDir = vim.fn.fnamemodify(
  cmakeListsPath, ':p:h') .. '/' .. cmakeBuildDir .. '/.cmake/api/v1'

  vim.fn.mkdir(cmakeAPIDir .. '/query/client-nvim', 'p')

  local file = io.open(cmakeAPIDir .. '/query/client-nvim/query.json', 'w')
  file:write(vim.fn.json_encode(query))
  file:close()
end

M.get_executables = function()
  M.cmakeWriteQuery{
    requests = {{
      kind = 'codemodel',
      version = 2
    }}
  }

  local cmakeListsPath = upfind('CMakeLists.txt')[1]
  local cmakeBuildDir = vim.b.CMakeBuildDir or 'build'

  local cmakeAPIDir = vim.fn.fnamemodify(
  cmakeListsPath, ':p:h') .. '/' .. cmakeBuildDir .. '/.cmake/api/v1'

  if not vim.fn.isdirectory(cmakeAPIDir .. '/reply') then -- Touch cmakelists
    vim.fn.writefile(vim.fn.readfile(cmakeListsPath), cmakeListsPath)
  end

  local exeList = {}
  local filesToParse = vim.fn.glob(cmakeAPIDir .. '/reply/target-*', 0, 1)
  local hasExecutables = false

  for _, file in pairs(filesToParse) do
    local fp = io.open(file, 'r')
    local jsonData = {}
    for line in fp:lines() do
      table.insert(jsonData, line)
    end
    local reply = vim.fn.json_decode(table.concat(jsonData, ""))

    for _, v in pairs(reply.backtraceGraph.commands) do
      if v == 'add_executable' then
        hasExecutables = true
        break
      end
    end

    if hasExecutables then
      for _, artifact in pairs(reply.artifacts or {}) do
        if vim.fn.has('win32') > 0 then
          if artifact.path:find('.exe$') then
            table.insert(exeList, artifact.path)
          end
        else
          table.insert(exeList, artifact.path)
        end
      end
    end
    fp:close()
  end

  if not hasExecutables then return nil end

  exeList = vim.fn.map(exeList, function(_, v) return cmakeBuildDir .. '/' .. v end)
  exeList = vim.fn.filter(exeList, function(_, v) return vim.fn.filereadable(v) end)

  return exeList
end

M.compile = function ()
  local buildDir = vim.b.CMakeBuildDir or 'build'
  local workingDirectory = vim.fn.fnamemodify(upfind('CMakeLists.txt')[1], ':h')
  local cmake = Command()
  cmake.args = {'cmake', '--build', buildDir}
  cmake.working_directory = workingDirectory

  local configure
  if vim.fn.isdirectory(workingDirectory .. '/' .. buildDir) ~= 1 then
    configure = Command{
      args = {'cmake', '-B', buildDir},
      working_directory = workingDirectory
    }
  end

  if configure then
    return Task{configure, cmake}
  else
    return Task{cmake}
  end
end

M.run = function ()
  local buildDir = vim.b.CMakeBuildDir or 'build'
  local lists = upfind('CMakeLists.txt')
  local workingDirectory = vim.fn.fnamemodify(lists[#lists], ':h')

  local executables = M.get_executables()

  local task = Task()

  if executables and #executables > 0 then
    for _, exe in pairs(executables) do
      local cmd = Command()
      cmd.args = {exe}
      cmd.working_directory = workingDirectory
      table.insert(task.commands, cmd)
    end
  else
    local cmd = Command()
    cmd.args = { 'cmake', '-B', buildDir }
    cmd.working_directory = workingDirectory
    task.commands = { cmd }
  end

  return task
end

M.compile_and_run = function ()
  return M.compile() + M.run()
end

return M
