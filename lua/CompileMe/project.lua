local class = require 'CompileMe.class'
local upfind = require 'CompileMe.upfind'

local function dirname(x)
  return vim.fn.fnamemodify(x, ':h')
end

-- Since we can't store lua funcrefs in a vim b: variable, we keep a map of
-- bufnrs to project objects
local project_table = {}

local Project = class(function (proj, opts)
  opts = opts or {}
  proj.root = opts.root or proj.get_root()
  proj.type = opts.type or proj.get_type()
  proj.compiler = opts.compiler or require('CompileMe.compilers.' .. proj.type:lower())
end)

Project.get_current = function ()
  return project_table[vim.api.nvim_buf_get_number(0)]
end

Project.set_current = function (proj)
  project_table[vim.api.nvim_buf_get_number(0)] = proj
end

Project.Type = {
  None = "None",
  Makefile = "Makefile",
  CMake = "CMake",
  Dotnet = "Dotnet",
  Custom = "Custom", -- User specified commands from local vimrc
}

Project.root_markers = {
  '.git'
}

Project.init = function ()
  if not Project.get_current() then
    for _, v in ipairs(upfind({"nvimrc.lua", ".nvimrc.lua"}, {
      dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':h')
    })) do
      dofile(v)
    end
    if not Project.get_current() then
      Project.set_current(Project())
    end
  end
end

-- This is a table of functions that are called in order to determine the
-- project type. This can be extended by the caller with a simple
-- table.insert(). Functions should take a single argument, the buffer number
-- for which to detect the project type
Project.detectors = {
  function (bufnr)
    if upfind('Makefile', {dir = dirname(vim.api.nvim_buf_get_name(bufnr))})[1] then
      return Project.Type.Makefile
    end
  end,
  function (bufnr)
    if upfind('CMakeLists.txt', {dir = dirname(vim.api.nvim_buf_get_name(bufnr))})[1] then
      return Project.Type.CMake
    end
  end,
  function (bufnr)
    if upfind('*.[cf]sproj', {dir = dirname(vim.api.nvim_buf_get_name(bufnr))})[1] then
      return Project.Type.Dotnet
    end
  end,
}

-- @returns The first non nil return from all detectors
function Project.get_type()

  for _, detector in ipairs(Project.detectors) do
    local type = detector(vim.api.nvim_buf_get_number(0))
    if type then
      return type
    end
  end

  return Project.Type.None
end

function Project.get_root()
  local root = upfind(Project.root_markers, {return_on_find = true})[1]
  if root then
    root = vim.fn.fnamemodify(root, ':h')
  else
    root = vim.fn.getcwd()
  end

  return root
end

return Project
