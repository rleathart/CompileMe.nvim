local class = require 'CompileMe.class'

-- Something like "echo" "Hi" is invalid in cmd.exe. We need echo "Hi" instead
local cmd_builtins = {
  "ASSOC", "BREAK", "CALL", "CD", "CHDIR", "CLS", "COLOR", "COPY", "DATE",
  "DEL", "DIR", "DPATH", "ECHO", "ENDLOCAL", "ERASE", "EXIT", "FOR", "FTYPE",
  "GOTO", "IF", "KEYS", "MD", "MKDIR", "MKLINK", "MOVE", "PATH", "PAUSE",
  "POPD", "PROMPT", "PUSHD", "REM", "REN", "RENAME", "RD", "RMDIR", "SET",
  "SETLOCAL", "SHIFT", "START", "TIME", "TITLE", "TYPE", "VER", "VERIFY", "VOL"
}

local Command = class(function (cmd, opts)
  opts = opts or {}
  cmd.args = opts.args or {}
  cmd.working_directory = opts.working_directory
  cmd.is_vim_command = opts.is_vim_command or false
  -- @@Implement fail_is_fatal. We might not care if some commands fail
  -- @@Implement silent. We might want to run some commands silently
end)

-- @param shell string|nil 'pwsh' or 'powershell' or nil
function Command:escape_args(shell)
  shell = shell or ""
  local escaped_args = {}
  for i, arg in pairs(self.args) do
    local needs_escape = true

    if arg:find('^-') then
      needs_escape = false
    end

    for _, builtin in ipairs(cmd_builtins) do
      if arg:upper() == builtin and i == 1 then
        needs_escape = false
      end
    end

    if needs_escape then -- Don't quote options
      escaped_args[i] = vim.fn.shellescape(arg)
      -- Need this so pwsh doesn't think we're passing options to a string literal
      if (shell:match('pwsh') or shell:match('powershell')) and i == 1 then
        escaped_args[1] = '&' .. escaped_args[1]
      end
    else
      escaped_args[i] = arg
    end
  end
  return escaped_args
end

return Command
