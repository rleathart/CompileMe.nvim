local Task = require 'CompileMe.task'
local Command = require 'CompileMe.command'
local upfind = require 'CompileMe.upfind'

local M = {}

local function dirname(x)
  return vim.fn.fnamemodify(x, ':h')
end

M.get_top_level_cmakelists = function ()
  local lists = upfind('CMakeLists.txt')
  return lists[#lists]
end

M.wait_for_api_reply = function ()
  local cmakelists_path = M.get_top_level_cmakelists()
  local cmake_build_dir = vim.b.CMakeBuildDir or 'build'
  local cmake_api_dir = vim.fn.fnamemodify(
  cmakelists_path, ':p:h') .. '/' .. cmake_build_dir .. '/.cmake/api/v1'

  while vim.fn.isdirectory(cmake_api_dir .. '/reply') ~= 1 do
    vim.cmd('sleep 100m')
  end
end

M.cmake_write_query = function(query)
  local cmakelists_path = M.get_top_level_cmakelists()
  local cmake_build_dir = vim.b.CMakeBuildDir or 'build'
  local cmake_api_dir = vim.fn.fnamemodify(
  cmakelists_path, ':p:h') .. '/' .. cmake_build_dir .. '/.cmake/api/v1'

  vim.fn.mkdir(cmake_api_dir .. '/query/client-nvim', 'p')

  local file = io.open(cmake_api_dir .. '/query/client-nvim/query.json', 'w')
  file:write(vim.fn.json_encode(query))
  file:close()
end

M.get_executables = function()
  M.cmake_write_query{
    requests = {{
      kind = 'codemodel',
      version = 2
    }}
  }

  local cmakelists_path = M.get_top_level_cmakelists()
  local cmake_build_dir = vim.b.CMakeBuildDir or 'build'

  local cmake_api_dir = vim.fn.fnamemodify(
  cmakelists_path, ':p:h') .. '/' .. cmake_build_dir .. '/.cmake/api/v1'

  if vim.fn.isdirectory(cmake_api_dir .. '/reply') ~= 1 then -- Touch cmakelists
    vim.fn.writefile(vim.fn.readfile(cmakelists_path), cmakelists_path)
  end

  local exe_list = {}
  local files_to_parse = vim.fn.glob(cmake_api_dir .. '/reply/target-*', 0, 1)
  local has_executables = false

  for _, file in pairs(files_to_parse) do
    local fp = io.open(file, 'r')
    local jsonData = {}
    for line in fp:lines() do
      table.insert(jsonData, line)
    end
    local reply = vim.fn.json_decode(table.concat(jsonData, ""))

    for _, v in pairs(reply.backtraceGraph.commands) do
      if v == 'add_executable' then
        has_executables = true
        break
      end
    end

    if has_executables then
      for _, artifact in pairs(reply.artifacts or {}) do
        if vim.fn.has('win32') > 0 then
          if artifact.path:find('.exe$') then
            table.insert(exe_list, artifact.path)
          end
        else
          table.insert(exe_list, artifact.path)
        end
      end
    end
    fp:close()
  end

  if not has_executables then return nil end

  exe_list = vim.fn.map(exe_list, function(_, v) return cmake_build_dir .. '/' .. v end)
  exe_list = vim.fn.filter(exe_list, function(_, v) return vim.fn.filereadable(v) end)

  local dir_sep = vim.fn.has('win32') ~= 1 and '/' or '\\'
  return vim.fn.map(exe_list, function(_, v) return v:gsub('/', dir_sep) end)
end

M.compile = function ()
  local cmakelists_path = M.get_top_level_cmakelists()
  local build_dir = vim.b.CMakeBuildDir or 'build'
  local working_directory = dirname(cmakelists_path)
  local cmake = Command()
  cmake.args = {'cmake', '--build', build_dir}
  cmake.working_directory = working_directory

  local configure
  if vim.fn.isdirectory(working_directory .. '/' .. build_dir) ~= 1 then
    configure = Command{
      args = {'cmake', '-B', build_dir},
      working_directory = working_directory
    }
  end

  if configure then
    return Task{configure, cmake}
  else
    return Task{cmake}
  end
end

M.run = function ()
  local working_directory = dirname(M.get_top_level_cmakelists())

  local executables = M.get_executables()

  local task = Task()

  if executables and #executables > 0 then
    for _, exe in pairs(executables) do
      local cmd = Command()
      cmd.args = {exe}
      cmd.working_directory = working_directory
      table.insert(task.commands, cmd)
    end
  else
    task.commands = {
      Command{
        is_vim_command = true,
        args = {'lua', 'require(\'CompileMe.project\').get_current().compiler.wait_for_api_reply()'}
      },
      Command{
        is_vim_command = true,
        args = {'CompileMe', 'run'}
      }
    }
  end

return task
end

M.compile_and_run = function ()
  return M.compile() + M.run()
end

local set_build_type = function(build_type)
  local build_dir = vim.b.CMakeBuildDir or 'build'
  return Task{
    Command {
      args = {'cmake', '-B', build_dir, '-DCMAKE_BUILD_TYPE=' .. build_type},
      working_directory = dirname(M.get_top_level_cmakelists())
    }
  }
end

M.release = function ()
  return set_build_type('Release')
end

M.debug = function ()
  return set_build_type('Debug')
end

M.rel_with_deb_info = function ()
  return set_build_type('RelWithDebInfo')
end

M.min_size_rel = function ()
  return set_build_type('MinSizeRel')
end

M.commands = {
  "run",
  "compile",
  "compile_and_run",
  "release",
  "debug",
  "rel_with_deb_info",
  "min_size_rel"
}

return M
