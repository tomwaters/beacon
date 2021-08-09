local typey = include('lib/typey')
local cutty = include('lib/cutty')

local output_lines = 8
output = {}


function init()
  typey.init(cmd_handler, redraw_handler)
  cutty.init()

  typey.debugcmd("load audio/tehn/whirl1.aif")
  typey.debugcmd("voice 1 1")
  --typey.debugcmd("play 1")
  
  redraw()

end

function cmd_handler(cmd)
  add_output("> "..cmd)
  
  local result = cutty.process(cmd)
  add_output(result)
  redraw()
end

function add_output(txt)
  if #output == output_lines then
    output[output_lines] = nil
  end
  table.insert(output, 1, txt)
end

function redraw_handler()
  redraw()
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.font_size(8)
  
  -- current command
  screen.move(0, 60)
  screen.text("> "..typey.cmd_input)
    
  -- command history
  for i=1, #output do
    screen.move(0, 60 - (i * 6))
    screen.text(output[i])
  end

  screen.update()
end

