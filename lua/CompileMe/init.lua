local M = {}

-- @@Rework move this somewhere else
M.last_terminal = nil

local commands = {
  "run",
  "compile",
  "compile_and_run"
}

M.command_wrapper = function (cmd)
  if not cmd then
    cmd = "compile"
  end

  local cmd_is_registered = false
  for _, command in ipairs(commands) do
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

M.get_commands = function ()
  return commands
end

M.add_command = function (cmd)
  table.insert(commands, cmd)
end

return M
