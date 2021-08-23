--
-- typey
-- a text based sample mangler
-- @tomw
-- 

local typey = include('lib/lib_typey')
local cutty = include('lib/lib_cutty')

local output_lines = 8
local doing_intro = false
output = {}
redraw_metro = metro.init()

intro_metro = metro.init()
local intro_line = nil
local intro_char = nil

function init()
  typey.init(cmd_handler, redraw_handler)
  cutty.init()
  
  redraw()
  redraw_metro.event = metro_redraw
  redraw_metro:start(1 / 30)

  intro_line = 1
  intro_char = 1
  intro_metro.event = intro
  intro_metro:start(0.125)
end

function intro()
  local intro_text = {"Welcome to typey", "use the 'help' command", "if you get lost"}

  if intro_char > #intro_text[intro_line] then
    typey.code("ENTER", 1)
    intro_line = intro_line + 1
    intro_char = 1
    if intro_line > #intro_text then
      intro_line = nil
      intro_metro:stop()
    end
  else
    typey.char(intro_text[intro_line]:sub(intro_char,intro_char))
    intro_char = intro_char + 1
  end
end

-- lib_typey gave us a command to run
function cmd_handler(cmd)
  add_output("> "..cmd)
  if intro_line == nil then
    local result = cutty.process(cmd)
    add_output(result)
    redraw()
  end
end

-- split output into lines
function add_output(txt)
  local len = screen.text_extents(txt)
  while len > 128 do
    -- get enough for a line
    for i=1, #txt do
      if screen.text_extents(txt:sub(1, i)) > 128 then
        add_output_line(txt:sub(1, i - 1))
        txt = txt:sub(i)
        break
      end
    end
    
    len = screen.text_extents(txt)
  end
  
  add_output_line(txt)
end

-- add a line of text to the output history
function add_output_line(txt)
  if #output == output_lines then
    output[output_lines] = nil
  end
  table.insert(output, 1, txt)
end

-- lib_typey asked for a redraw
function redraw_handler()
  redraw()
  
  -- stop the screen going to sleep if typing
  screen.ping()
end

-- metro scheduled redraw
function metro_redraw()
  redraw()
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.font_size(8)
  
  local cur_line = "> "..typey.cmd_input
  
  -- figure out the cursor position
  local cursor_text = cur_line:sub(1, typey.cmd_cursor_pos + 1)
  local cursor_x = screen.text_extents(cursor_text)
  
  -- trailing whitespace isn't included in text_extents
  if cursor_text:sub(-#" ") == " " then
    cursor_x = cursor_x + 4
  end
  
  local offset = 0
  if cursor_x > 128 then
    offset = math.floor(cursor_x / 128) * 128
  end
  
  -- current command
  screen.move(0 - offset, 63)
  screen.text(cur_line)

  -- cursor
  if util.round(util.time()) % 2 == 0 then
    screen.move(cursor_x - offset + 1, 64)
    screen.line(cursor_x - offset + 5, 64)
    screen.stroke()
  end
  
  -- command history
  for i=1, #output do
    screen.move(0, 63 - (i * 7))
    screen.text(output[i])
  end

  screen.update()
end