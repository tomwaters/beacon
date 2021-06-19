cutty = {}
cutty.voices = {}
cutty.cmds = {}

cutty.init = function()
  for i=1, softcut.VOICE_COUNT do
    cutty.voices[i] = {
      start_sec = 0,
      end_sec = softcut.BUFFER_SIZE
    }
  end
end

local okResponse = "ok"

-- helper to get number from argument
-- if we can't call help of <cmd>
function getArgInt(arg, cmd)
  local argNum = tonumber(arg)
  if argNum == nil then
    return cutty.cmds[cmd]({"help"})
  end
  return argNum
end

-- process a command string
-- first word is the command, others are arguments
cutty.process = function(cmd)
  -- the command is up to the first space
  -- if there is no space then its the whole string
  local i = string.find(cmd, " ")
  if i == nil then
    i = 0
  end
  
  -- check we know the command
  local c = string.sub(cmd, 1, i - 1)
  if cutty.cmds[c] == nil then
    return "Unknown command "..c
  end
  
  -- if we found a space, arguments are everything after it
  -- split by space
  local args = {}
  if i > 0 then
    local arg_string = string.sub(cmd, i + 1)
    for w in string.gmatch(arg_string, "%S+") do
       table.insert(args, w)
    end
  end
  
  -- run the command with the arguments and return the result
  return cutty.cmds[c](args)
end

-- get a list of commands for help
cutty.cmds["help"] = function(args)
  local out = "CMDs: "
  for key in pairs(cutty.cmds) do
    if key ~= "help" then
      out = out..key..", "
    end
  end
  return out:sub(1, -3)
end


cutty.cmds["load"] = function(args)
  if #args == 0 or args[1] == "help" then
    return "load <file> (b#)"
  end

  local file = _path.dust..args[1]
  if #args == 1 then
    softcut.buffer_read_stereo(file, 0, 0, -1)
  else
    local buf_num = getArgInt(args[2], "load")
    softcut.buffer_read_mono(file, 0, 0, -1, 1, buf_num)
  end
  
  return okResponse
end

cutty.cmds["voice"] = function(args)
  if #args < 2 or args[1] == "help" then
    return "play <v#> <b#>"
  end
  
  local voice_num = getArgInt(args[1], "voice")
  local buf_num = getArgInt(args[2], "voice")

  softcut.enable(voice_num, 1)
  softcut.buffer(voice_num, buf_num)
  softcut.level(voice_num, 1.0)
  softcut.loop(voice_num, 0)
  softcut.loop_end(voice_num, softcut.BUFFER_SIZE)
  
  return okResponse  
end

cutty.cmds["range"] = function(args)
  if #args < 3 or args[1] == "help" then
    return "range <v#> <s> <e>"
  end

  local voice_num = getArgInt(args[1], "range")
  local start_sec = getArgInt(args[2], "range")
  local end_sec = getArgInt(args[3], "range")
  cutty.voices[voice_num].start_sec = start_sec
  cutty.voices[voice_num].end_sec = end_sec

  return okResponse  
end

cutty.cmds["play"] = function(args)
  if #args < 1 or args[1] == "help" then
    return "play <v#>"
  end
  
  local voice_num = getArgInt(args[1], "play")
  softcut.loop(voice_num, 1)
  softcut.position(voice_num, cutty.voices[voice_num].start_sec)
  softcut.loop_start(voice_num, cutty.voices[voice_num].start_sec)
  softcut.loop_end(voice_num, cutty.voices[voice_num].end_sec)
  softcut.play(voice_num, 1)
  softcut.loop(voice_num, 0)
    
  return okResponse  
end

cutty.cmds["loop"] = function(args)
  if #args < 1 or args[1] == "help" then
    return "loop <v#> (off)"
  end

  local voice_num = getArgInt(args[1], "loop")
  if #args > 1 then
    if args[2] == "off" then
      softcut.loop(voice_num, 0)
    else
      return cutty.cmds["loop"]({"help"})
    end
  else
    softcut.loop(voice_num, 1)
    softcut.position(voice_num, cutty.voices[voice_num].start_sec)
    softcut.loop_start(voice_num, cutty.voices[voice_num].start_sec)
    softcut.loop_end(voice_num, cutty.voices[voice_num].end_sec)
    softcut.play(voice_num, 1)
  end    
  
  return okResponse  
end

cutty.cmds["rate"] = function(args)
  if #args < 2 or args[1] == "help" then
    return "rate <v#> r"
  end

  local voice_num = getArgInt(args[1], "rate")
  local rate = getArgInt(args[2], "rate")
  softcut.rate(voice_num, rate)

  return okResponse  
end

return cutty