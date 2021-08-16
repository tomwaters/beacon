local typey = include('lib/typey')
local cutty = include('lib/cutty')

local output_lines = 8
output = {}
redraw_metro = metro.init()


function init()
  typey.init(cmd_handler, redraw_handler)
  cutty.init()

  typey.debugcmd("load audio/tehn/whirl1.aif")
  typey.debugcmd("voice 1 1")
  --typey.debugcmd("play 1")
  
  redraw()
  
  redraw_metro.event = metro_redraw
  redraw_metro:start(1 / 30)
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

function metro_redraw()
  redraw()
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.font_size(8)
  
  -- current command
  local cur_line = "> "..typey.cmd_input
  screen.move(0, 60)
  screen.text(cur_line)
  
  -- cursor
  if util.round(util.time()) % 2 == 0 then
    local blink_x = screen.text_extents(string.gsub(cur_line, " ", "v"))
    screen.move(blink_x, 60)
    screen.line(blink_x + 4, 60)
    screen.stroke()
  end
  
  -- command history
  for i=1, #output do
    screen.move(0, 60 - (i * 6))
    screen.text(output[i])
  end

  screen.update()
end

