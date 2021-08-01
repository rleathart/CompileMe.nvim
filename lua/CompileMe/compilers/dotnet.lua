local Task = require 'CompileMe.task'
local Command = require 'CompileMe.command'

local M = {}

M.compile = function ()
  return Task{
    Command{
      args = {'dotnet', 'build', '--nologo'}
    }
  }
end
M.run = function ()
  return Task{
    Command{
      args = {'dotnet', 'run', '--no-build'}
    }
  }
end
M.compile_and_run = function ()
  return Task{
    Command{
      args = {'dotnet', 'run'}
    }
  }
end

M.commands = {
  "run",
  "compile",
  "compile_and_run"
}

return M
