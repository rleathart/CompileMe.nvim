local M = {}

-- Should we send commands to terminal buffers that we can't currently see?
M.get_term_use_current_tab = function ()
  if vim.g.CompileMe_term_use_current_tab == nil then
    return true
  end
  return vim.g.CompileMe_term_use_current_tab
end

-- Should we spawn a new cmd.exe window on Windows?
M.get_term_use_cmd_window = function ()
  if vim.fn.has('win32') == 0 then
    return false
  end

  if vim.g.CompileMe_term_use_cmd_window == nil then
    return false
  end
  return vim.g.CompileMe_term_use_cmd_window
end

-- Should we pause at the end of a cmd.exe task? This stops the cmd.exe window
-- from instantly closing
M.get_term_use_cmd_window_pause = function ()
  if vim.g.CompileMe_term_use_cmd_window_pause == nil then
    return false
  end
  return vim.g.CompileMe_term_use_cmd_window_pause
end

-- @@Rework move this somewhere else
M.last_terminal = nil
M.last_regular_buffer_id = nil

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
