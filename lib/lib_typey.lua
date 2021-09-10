--
-- library to handle keyboard input
--

typey = {}
typey.init = function(cmd_callback, redraw_callback)
  typey.cmd_callback = cmd_callback;
  typey.redraw_callback = redraw_callback;
  
  typey.cmd_input = ""
  typey.cmd_cursor_pos = 1

  typey.cmd_history_max = 10
  typey.cmd_history = {}
  typey.cmd_history_idx = 0

  typey.suggest_idx = 1
  typey.suggest_file = {}
  
  typey.macros = {}
  for i=1, 12 do
    typey.macros["F"..i] = ""
  end
  
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
  typey.suggest_reset()
  typey.redraw_callback()
end

typey.add_suggest_file = function(param, property)
  table.insert(typey.suggest_file, {
    param = param,
    property = property
  })
end

typey.suggest_reset = function() 
  typey.suggest_search = nil
  typey.suggest_idx = 1
end

-- tab suggest for file path
typey.suggest = function()
  -- check if we should suggest a file
  local i = string.find(typey.cmd_input, " ")
  if i == nil then
    i = 0
  end
  
  local param = string.sub(typey.cmd_input, 1, i - 1)
  local found = false
  for _, p in pairs(typey.suggest_file) do
    if p.param == param then
      local _, n = string.gsub(typey.cmd_input, " ", "")
      if p.property == n then
        found = true
        break
      end
    end
  end
  
  if not found then
    return
  end
  
  -- do the suggest
  if typey.suggest_search == nil then
    typey.suggest_search = string.match(typey.cmd_input, " ([^ ]+)$") or ""
  end

  local search_path = _path.dust
  local left_path = string.match(typey.suggest_search, "^(.+[//])")
  local left_length = 0
  if left_path ~= nil then
    search_path = search_path..left_path
    left_length = #left_path
  else
    left_path = ""
  end
  
  if util.file_exists(search_path) then
    local list = util.scandir(search_path)
    local search_term = string.sub(typey.suggest_search, left_length + 1)
    
    local matches = 0
    local back_to_start = true
    for _,f in ipairs(list) do
      if util.string_starts(f, search_term) then
        matches = matches + 1
        if matches == typey.suggest_idx then
          -- if f ends / then strip the / to tab through matching folders
          if string.sub(f, #f) == "/" then
            f = string.sub(f, 1, #f - 1)
          end
          
          local cmd_last_param = string.match(typey.cmd_input, " ([^ ]+)$")
          local clp_len = 0
          if cmd_last_param ~= nil then
            clp_len = #cmd_last_param
          end
          
          typey.cmd_input = string.sub(typey.cmd_input, 1, #typey.cmd_input - clp_len)..left_path..f
          typey.cmd_cursor_pos = #typey.cmd_input + 1
          
        elseif matches > typey.suggest_idx then
          back_to_start = false
        end
      end
    end
    
    -- if there were no more matches
    -- reset idx so we go back to the first match on next tab
    if back_to_start then
      typey.suggest_idx = 1
    else
      typey.suggest_idx = typey.suggest_idx + 1
    end
    
  end
end


typey.code = function(code, value)
  if value == 1 or value == 2 then
    if code == "BACKSPACE" then
      typey.suggest_reset()
      typey.cmd_input = typey.cmd_input:sub(1, typey.cmd_cursor_pos - 2)..typey.cmd_input:sub(typey.cmd_cursor_pos)
      if #typey.cmd_input > 0 then
        typey.cmd_cursor_pos = typey.cmd_cursor_pos - 1
      end
    elseif code == "ENTER" then
      typey.suggest_reset()
      typey.add_command_history(typey.cmd_input)
      typey.cmd_callback(typey.cmd_input)
      typey.cmd_input = ""
      typey.cmd_cursor_pos = 1
    elseif code == "UP" and typey.cmd_history_idx > 1 then
      typey.suggest_reset()      
      typey.cmd_history_idx = typey.cmd_history_idx - 1
      typey.cmd_input = typey.cmd_history[typey.cmd_history_idx]
      typey.cmd_cursor_pos = #typey.cmd_input + 1
    elseif code == "DOWN" and typey.cmd_history_idx <= #typey.cmd_history then
      typey.suggest_reset()      
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
    elseif code == "HOME" then
      typey.cmd_cursor_pos = 1
    elseif code == "END" then
      typey.cmd_cursor_pos = #typey.cmd_input + 1   
    elseif code == "ESC" then
      typey.suggest_reset()
      typey.cmd_cursor_pos = 1
      typey.cmd_input = ""
    elseif code == "TAB" then
      typey.suggest()
    elseif typey.macros[code] ~= nil then
      if typey.cmd_input ~= "" then
        typey.macros[code] = typey.cmd_input
      elseif typey.cmd_input == "" and typey.macros[code] ~= "" then
        typey.cmd_input = typey.macros[code]
        typey.cmd_cursor_pos = #typey.cmd_input + 1
      end
      
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

-- debug to allow me to run a command from maiden
typey.debugcmd = function(cmd)
  typey.add_command_history(typey.cmd_input)
  typey.cmd_callback(cmd)
  typey.cmd_input = ""
end

return typey