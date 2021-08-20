local Task = require 'CompileMe.task'
local Command = require 'CompileMe.command'
local Project = require 'CompileMe.project'
local upfind = require 'CompileMe.upfind'
local class = require 'CompileMe.class'

local function dirname(x)
  return vim.fn.fnamemodify(x, ':h')
end

-- This is a wrapper class so we can use getters and setters
local CMakeCompiler = class(function ()
end)

-- Getters
function CMakeCompiler:__index(index)
  if index == "build_dir" then
    if not Project.get_current().build_dir then
      Project.get_current().build_dir = 'build'
    end

    return Project.get_current().build_dir
  end

  if index == "lists_path" then
    local lists = upfind('CMakeLists.txt')
    return lists[#lists]
  end

  if index == "api_dir" then
    return dirname(self.lists_path) .. '/' .. self.build_dir .. '/.cmake/api/v1'
  end

  return rawget(self, index)
end

-- Setters
function CMakeCompiler:__newindex(index, value)
  return rawset(self, index, value)
end

-- Project variables:
--  build_dir: Name of the CMake build directory. Default: 'build'
local cmake = CMakeCompiler()

cmake.wait_for_api_reply = function ()
  local timeout = 2 -- Wait this many seconds before timing out
  local start = os.time()
  while vim.fn.isdirectory(cmake.api_dir .. '/reply') ~= 1 do
    vim.cmd('sleep 100m')
    if os.time() >= start + timeout then
      error('Timeout waiting for cmake api reply')
      break
    end
  end
end

local write_query = function(query)
  vim.fn.mkdir(cmake.api_dir .. '/query/client-nvim', 'p')

  local file = io.open(cmake.api_dir .. '/query/client-nvim/query.json', 'w')
  file:write(vim.fn.json_encode(query))
  file:close()
end

local get_executables = function()
  write_query{
    requests = {{
      kind = 'codemodel',
      version = 2
    }}
  }

  if vim.fn.isdirectory(cmake.api_dir .. '/reply') ~= 1 then -- Touch cmakelists
    vim.fn.writefile(vim.fn.readfile(cmake.lists_path), cmake.lists_path)
  end

  local exe_list = {}
  local files_to_parse = vim.fn.glob(cmake.api_dir .. '/reply/target-*', 0, 1)
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

  exe_list = vim.fn.map(exe_list, function(_, v) return cmake.build_dir .. '/' .. v end)
  exe_list = vim.fn.filter(exe_list, function(_, v) return vim.fn.filereadable(v) end)

  local dir_sep = vim.fn.has('win32') ~= 1 and '/' or '\\'
  return vim.fn.map(exe_list, function(_, v) return v:gsub('/', dir_sep) end)
end

cmake.compile = function ()
  local build = Command {
    args = {'cmake', '--build', cmake.build_dir},
    working_directory = dirname(cmake.lists_path)
  }

  local configure = Command {
    args = {'cmake', '-B', cmake.build_dir},
    working_directory = dirname(cmake.lists_path)

  }

  if vim.fn.isdirectory(dirname(cmake.lists_path) .. '/' .. cmake.build_dir) ~= 1 then
    return Task{configure, build}
  else
    return Task{build}
  end
end

cmake.run = function ()
  local working_directory = dirname(cmake.lists_path)

  local executables = get_executables()

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

cmake.compile_and_run = function ()
  return cmake.compile() + cmake.run()
end

local set_build_type = function(build_type)
  return Task{
    Command {
      args = {'cmake', '-B', cmake.build_dir, '-DCMAKE_BUILD_TYPE=' .. build_type},
      working_directory = dirname(cmake.lists_path)
    }
  }
end

cmake.release = function ()
  return set_build_type('Release')
end

cmake.debug = function ()
  return set_build_type('Debug')
end

cmake.rel_with_deb_info = function ()
  return set_build_type('RelWithDebInfo')
end

cmake.min_size_rel = function ()
  return set_build_type('MinSizeRel')
end

return cmake
