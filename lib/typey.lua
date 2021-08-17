typey = {}
typey.init = function(cmd_callback, redraw_callback)
  typey.cmd_callback = cmd_callback;
  typey.redraw_callback = redraw_callback;
  
  typey.cmd_input = ""
  typey.cmd_cursor_pos = 1

  typey.cmd_history_max = 10
  typey.cmd_history = {}
  typey.cmd_history_idx = 0

end

typey.add_command_history = function(command)
  if #typey.cmd_history >= typey.cmd_history_max then
    table.remove(typey.cmd_history, 1)
  end
  table.insert(typey.cmd_history, command)
  typey.cmd_history_idx = #typey.cmd_history + 1
end

typey.char = function(character)
  typey.cmd_input = typey.cmd_input:sub(1, typey.cmd_cursor_pos - 1) .. character .. typey.cmd_input:sub(typey.cmd_cursor_pos)
  typey.cmd_cursor_pos = typey.cmd_cursor_pos + 1
  typey.redraw_callback()
end

typey.code = function(code, value)
  if value == 1 or value == 2 then
    if code == "BACKSPACE" then
      typey.cmd_input = typey.cmd_input:sub(1, typey.cmd_cursor_pos - 2)..typey.cmd_input:sub(typey.cmd_cursor_pos)
      if #typey.cmd_input > 1 then
        typey.cmd_cursor_pos = typey.cmd_cursor_pos - 1
      end
    elseif code == "ENTER" then
      typey.add_command_history(typey.cmd_input)
      typey.cmd_callback(typey.cmd_input)
      typey.cmd_input = ""
      typey.cmd_cursor_pos = 1
    elseif code == "UP" and typey.cmd_history_idx > 1 then
      typey.cmd_history_idx = typey.cmd_history_idx - 1
      typey.cmd_input = typey.cmd_history[typey.cmd_history_idx]
      typey.cmd_cursor_pos = #typey.cmd_input + 1
    elseif code == "DOWN" and typey.cmd_history_idx <= #typey.cmd_history then
      typey.cmd_history_idx = typey.cmd_history_idx + 1
      if typey.cmd_history_idx <= #typey.cmd_history then
        typey.cmd_input = typey.cmd_history[typey.cmd_history_idx]
      else
        typey.cmd_input = ""
      end
      typey.cmd_cursor_pos = #typey.cmd_input + 1
    elseif code == "LEFT" and typey.cmd_cursor_pos > 1 then
      typey.cmd_cursor_pos = typey.cmd_cursor_pos - 1
    elseif code == "RIGHT" and typey.cmd_cursor_pos <= #typey.cmd_input then
      typey.cmd_cursor_pos = typey.cmd_cursor_pos + 1
    end
    typey.redraw_callback()
  end
end

function keyboard.char(character)
  typey.char(character)
end

function keyboard.code(code, value)
  typey.code(code, value)
end

typey.debugcmd = function(cmd)
  typey.add_command_history(typey.cmd_input)
  typey.cmd_callback(cmd)
  typey.cmd_input = ""
end


return typey