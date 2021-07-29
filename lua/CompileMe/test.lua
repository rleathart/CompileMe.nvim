local Task = require 'task'
local Command = require 'command'

Task{
  Command({'echo', 'Hi'}),
  Command({})
}:run()
