local typey = include('lib/typey')
local cutty = include('lib/cutty')

local output_lines = 8
output = {}
redraw_metro = metro.init()


function init()
  typey.init(cmd_handler, redraw_handler)
  cutty.init()

  typey.debugcmd("load audio/tehn/whirl2.aif")
  --typey.debugcmd("voice 1 1")
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
  
  -- stop the screen going to sleep if typing
  screen.ping()
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
    
    -- figure out the cursor position
    local cursor_text = cur_line:sub(1, typey.cmd_cursor_pos + 1)
    local blink_x = screen.text_extents(cursor_text)
    
    -- trailing whitespace isn't included in text_extents
    if cursor_text:sub(-#" ") == " " then
      blink_x = blink_x + 4
    end
    
    screen.move(blink_x + 1, 61)
    screen.line(blink_x + 5, 61)
    screen.stroke()
  end
  
  -- command history
  for i=1, #output do
    screen.move(0, 60 - (i * 6))
    screen.text(output[i])
  end

  screen.update()
end

