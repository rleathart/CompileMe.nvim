# Summary

Ever wished that compiling/running your projects in Vim was as simple as
pressing a button? This plugin does that.

`:CompileMe` is the main command associated with this plugin. You can get
options supported for your project with tab completion. For example, `:CompileMe
compile` will build your project and `:CompileMe compile_and_run` will compile
your project, and then run it.

CompileMe will run commands in Vim's shell, or in a terminal buffer if one is
visible on the screen.

![CMake demo](../assets/demos/CMakeDemo.gif?raw=true)

Tested with
- Powershell Core
- Windows Powershell
- `cmd.exe`
- Bash

<!-- Have some demo vids here -->
<!-- Project goals: 
  Provide a robust way of executing taks.  (Task:run())
  Provide a small set of predefined detector/compiler combos (compilers/)
  Provide a user friendly interface for creating new detectors/compilers as well
  overriding or extending existing ones.
-->

# Requirements

- Neovim 0.5 or above
- [neovim-remote](https://github.com/mhinz/neovim-remote)

# Extending CompileMe

This plugin is designed to be extensible so you can add your own compilers and
detectors! You can even add functionality for things like running your project's
test suite. For example, let's say you want to add a new python project type:

```lua
-- Somewhere in your init.lua
-- Add Python to the Project.Type table
require('CompileMe.project').Type.Python = "Python"

-- Create a new detector function for our python project type
table.insert(require('CompileMe.project').detectors, function (bufnr)
  if #vim.fn.findfile('main.py', ';') > 0 then
    return require('CompileMe.project').Type.Python
  end
end)
```

Then, in `stdpath('config')/lua/CompileMe/compilers` you can have

```lua
-- stdpath('config')/lua/CompileMe/compilers/python.lua
-- Note: the compiler filename must be the same as
-- require('CompileMe.project').Type.Python except in all lowercase

local Task = require 'CompileMe.task'
local Command = require 'CompileMe.command'

local M = {}

M.compile = function()
  -- Python code doesn't need to be compiled
  return Task{}
end

M.run = function()
  -- This is a super simple run function that just upward searches for a file
  -- called main.py and executes it. These functions can be as complex as you like
  return Task{
    Command{
      args = {'python3', vim.fn.findfile('main.py', ';')}
    }
  }
end

M.compile_and_run = function ()
  -- You can combine tasks with the + operator
  return M.compile() + M.run()
end

return M
```
