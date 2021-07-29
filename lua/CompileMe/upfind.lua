---@param patterns string|table
---@param opts table
---opts:
---     dir: Start searching in this directory (default vim.fn.getcwd())
---     return_on_find: return once matches have been found (default false)
---     stop_at: Stop searching at this directory (default nil)
---@return table files_found
local upfind = function(patterns, opts)
  opts = opts or {}
  patterns = type(patterns) == "string" and {patterns} or patterns
  if opts.stop_at then
    opts.stop_at = vim.fn.glob(opts.stop_at)
  end

  local files_found = {}
  local current_dir = opts.dir or vim.fn.getcwd()
  local old_dir
  repeat
    for _, pattern in pairs(patterns) do
      for _, v in pairs(vim.fn.glob(current_dir .. '/' .. pattern, 0, 1)) do
        table.insert(files_found, v)
      end
    end

    if opts.return_on_find and #files_found > 0 then
      break
    end

    old_dir = current_dir
    current_dir = vim.fn.fnamemodify(current_dir, ':h')
  until current_dir == old_dir or current_dir == opts.stop_at

  return files_found
end

return upfind
