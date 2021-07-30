local class = require 'CompileMe.class'
local CompileMe = require 'CompileMe'

local buffer_is_visible = function (bufnr)
  for _, winnr in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(winnr) == bufnr then
      return true
    end
  end
  return false
end

local Task = class(function (task, commands)
  task.commands = commands or {}
end)

function Task:__add(task)
  local commands = {}
  for _, cmd in ipairs(self.commands) do
    table.insert(commands, cmd)
  end
  for _, cmd in ipairs(task.commands) do
    table.insert(commands, cmd)
  end
  local rv = Task(commands)
  return rv
end

function Task:run()
  local cr = vim.fn.has('win32') == 1 and "\r" or "\n"

  -- We build the string for chansend here so that we can send the
  -- whole task as a single line
  local chansend_cmd_strs = {}
  local execute_in_term = false
  local terminal_process_name

  if CompileMe.last_terminal then
    local child_procs = vim.api.nvim_get_proc_children(CompileMe.last_terminal.pid)
    if #child_procs > 0 then
      -- We just check the first child here since this covers the case of the
      -- user starting a terminal with something like :term pwsh
      terminal_process_name = vim.api.nvim_get_proc(child_procs[1]).name
    else
      terminal_process_name = vim.api.nvim_get_proc(CompileMe.last_terminal.pid).name
    end

    execute_in_term = buffer_is_visible(CompileMe.last_terminal.bufnr)
  end

  local shell = vim.o.shell
  if execute_in_term then
    shell = terminal_process_name
  end

  local cmd_join_success = shell:match('powershell') and '; if ($?) { %s }' or ' && %s'
  local cmd_join_fail = shell:match('powershell') and '; if (!$?) { %s }' or ' || %s'
  local cmd_join_any = shell:match('cmd') and ' & %s' or '; %s'

  local function cmd_join(cmd1, cmd2, on_success)
    if #cmd1 == 0 then
      return cmd2
    end
    local fmt
    if not on_success then
      fmt = cmd_join_any
    else
      fmt = on_success and cmd_join_success or cmd_join_fail
    end

    return string.format("%s%s", cmd1, string.format(fmt, cmd2))
  end

  -- NOTE: strings passed to this should use single quotes for internal quoting
  local function wrap_vim_cmd_for_shell(cmd)
    return string.format('nvr -c %s', vim.fn.shellescape(cmd))
  end

  for _, cmd in ipairs(self.commands) do
    if #cmd.args == 0 then -- Skip commands with no args
      goto continue
    end
    local escaped_args = cmd:escape_args(shell)

    local cmd_string = ""

    local vim_cmd_strs = {
        string.format("silent! lcd %s", vim.fn.fnameescape(cmd.working_directory or ".")),
        table.concat(cmd.args, ' '),
        "silent! lcd -",
    }

    -- @@Rework add actual Command objects to chansend_cmd_strs and only use
    -- this part for adding and extra 'cd' command in front of each command.
    -- This means we can implement fail_is_fatal
    if execute_in_term then -- Going to use chansend
      if cmd.is_vim_command then
        for _, str in ipairs(vim_cmd_strs) do
          table.insert(chansend_cmd_strs, wrap_vim_cmd_for_shell(str))
        end
      else
        local cd_str = ""
        if cmd.working_directory then
          cd_str = string.format('cd %s', vim.fn.shellescape(cmd.working_directory))
        end
        cmd_string = cmd_join(cd_str, string.format("%s", table.concat(escaped_args, " ")), true)
        table.insert(chansend_cmd_strs, cmd_string)
      end
    else -- Going to use vim shell (:!)
      if cmd.is_vim_command then
        for _, str in ipairs(vim_cmd_strs) do
          vim.cmd(str)
        end
      else
        vim.cmd(string.format("silent! lcd %s", vim.fn.fnameescape(cmd.working_directory or ".")))
        -- Need to escape ! for vim shell
        vim.cmd('!'..table.concat(escaped_args, " "):gsub('!', '\\!'))
        vim.cmd("silent! lcd -")
        if vim.v.shell_error ~= 0 then
          break
        end
      end
    end
    ::continue::
  end

  if execute_in_term then
    local cmd_str = ""
    for _, cmd in ipairs(chansend_cmd_strs) do
      cmd_str = cmd_join(cmd_str, cmd, true)
    end
    vim.fn.chansend(CompileMe.last_terminal.id, cmd_str .. cr)
  end
end

return Task
