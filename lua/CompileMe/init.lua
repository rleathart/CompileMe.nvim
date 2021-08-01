local M = {}

-- @@Rework move this somewhere else
M.last_terminal = nil

M.command_wrapper = function (cmd)
  if cmd == "" then
    cmd = "compile"
  end

  local commands = require('CompileMe.project').get_current().compiler.commands

  local cmd_is_registered = false
  for _, command in pairs(commands) do
    if cmd == command then
      cmd_is_registered = true
      break
    end
  end

  if not cmd_is_registered then
    print(string.format("Command %s not implemented.", cmd))
    return
  end
  local str = string.format("require('CompileMe.project').get_current().compiler.%s():run()", cmd)
  loadstring(str)()
end

return M
