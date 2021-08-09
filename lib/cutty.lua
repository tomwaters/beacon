cutty = {}
cutty.voices = {}
cutty.cmds = {}

cutty.init = function()
  for i=1, softcut.VOICE_COUNT do
    cutty.voices[i] = {
      start_sec = 0,
      end_sec = softcut.BUFFER_SIZE,
      rate = 1.0
    }
    softcut.loop_start(i, cutty.voices[i].start_sec)
    softcut.loop_end(i, cutty.voices[i].end_sec)
  end
  math.randomseed(os.time())
end

local okResponse = "ok"

-- helper to get number from argument
-- if we can't call help of <cmd>
function getArgNum(arg, cmd)
  local argNum = tonumber(arg)
  if argNum == nil then
    return cutty.cmds[cmd]({"help"})
  end
  return argNum
end

-- helper to play a voice (one shot)
function play_voice(voice_num)
  softcut.loop(voice_num, 1)
  softcut.position(voice_num, cutty.voices[voice_num].start_sec)
  softcut.play(voice_num, 1)
  softcut.loop(voice_num, 0)
end

-- helper to trigger voice at regullar interval
function every_handler(voice_num, x, unit, chance)
  while true do
    if unit == "b" then
      clock.sync(x)
    end

    if math.random() <= chance  then    
      play_voice(voice_num)
    end
    
    if uint == "s" then
      clock.sleep(x)
    end
  end
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

cutty.cmds["bpm"] = function(args)
  if #args == 0 then
    return "bpm "..params:get("clock_tempo")
  elseif args[1] == "help" then
    return "bpm <bpm>"
  else
    local new_tempo = getArgNum(args[1], "bpm")
    params:set("clock_tempo", new_tempo)
    return okResponse
  end
end

cutty.cmds["load"] = function(args)
  if #args == 0 or args[1] == "help" then
    return "load <file> (b#)"
  end

  local file = _path.dust..args[1]
  if #args == 1 then
    softcut.buffer_read_stereo(file, 0, 0, -1)
  else
    local buf_num = getArgNum(args[2], "load")
    softcut.buffer_read_mono(file, 0, 0, -1, 1, buf_num)
  end
  
  return okResponse
end

cutty.cmds["voice"] = function(args)
  if #args < 1 or args[1] == "help" then
    return "voice <v#> <b#>"
  end
  
  local voice_num = getArgNum(args[1], "voice")
  if #args == 1 then
    if cutty.voices[voice_num].buffer == nil then
      return "not set"
    else
      return "voice "..voice_num.." buffer "..cutty.voices[voice_num].buffer
    end
  else
    local buf_num = getArgNum(args[2], "voice")
    cutty.voices[voice_num].buffer = buf_num
    
    softcut.enable(voice_num, 1)
    softcut.buffer(voice_num, buf_num)
    softcut.level(voice_num, 1.0)
    softcut.loop(voice_num, 0)
    softcut.loop_end(voice_num, softcut.BUFFER_SIZE)
    
    return okResponse
  end
end

cutty.cmds["range"] = function(args)
  if (#args ~= 1 and #args ~=3) or args[1] == "help" then
    return "range <v#> <s> <e>"
  end

  local voice_num = getArgNum(args[1], "range")
  if #args == 1 then
    return "range "..cutty.voices[voice_num].start_sec.." "..cutty.voices[voice_num].end_sec
  else
    local start_sec = getArgNum(args[2], "range")
    local end_sec = getArgNum(args[3], "range")
    cutty.voices[voice_num].start_sec = start_sec
    cutty.voices[voice_num].end_sec = end_sec
    softcut.loop_start(voice_num, cutty.voices[voice_num].start_sec)
    softcut.loop_end(voice_num, cutty.voices[voice_num].end_sec)
    
    return okResponse      
  end
end

cutty.cmds["play"] = function(args)
  if #args < 1 or args[1] == "help" then
    return "play <v#>"
  end
  
  local voice_num = getArgNum(args[1], "play")
  play_voice(voice_num)
    
  return okResponse  
end

cutty.cmds["stop"] = function(args)
  if #args < 1 or args[1] == "help" then
    return "stop <v#>"
  end
  
  local voice_num = getArgNum(args[1], "play")
  softcut.play(voice_num, 0)
  
  if cutty.voices[voice_num].every_clock ~= nil then
    clock.cancel(cutty.voices[voice_num].every_clock)
    cutty.voices[voice_num].every_clock = nil
    cutty.voices[voice_num].every = nil
  end
  
  return okResponse  
end

cutty.cmds["loop"] = function(args)
  if #args < 1 or args[1] == "help" then
    return "loop <v#>"
  end

  local voice_num = getArgNum(args[1], "loop")
  if #args > 1 then
    if args[2] == "off" then
      softcut.loop(voice_num, 0)
    else
      return cutty.cmds["loop"]({"help"})
    end
  else
    softcut.loop(voice_num, 1)
    softcut.position(voice_num, cutty.voices[voice_num].start_sec)
    softcut.play(voice_num, 1)
  end    
  
  return okResponse  
end

cutty.cmds["rate"] = function(args)
  if #args < 1 or args[1] == "help" then
    return "rate <v#> r"
  end

  local voice_num = getArgNum(args[1], "rate")
  if #args == 1 then
    return "rate "..cutty.voices[voice_num].rate
  else
    local rate = getArgNum(args[2], "rate")
    cutty.voices[voice_num].rate = rate
    softcut.rate(voice_num, rate)
  
    return okResponse
  end
end

cutty.cmds["every"] = function(args)
  if #args == 0 or #args == 2 or args[1] == "help" then
    return "every <v#> x b/s n%"
  end
  
  local voice_num = getArgNum(args[1], "every")
  if #args == 1 then
    if cutty.voices[voice_num].every == nil then
      return "every not set"
    else
      return "every "..cutty.voices[voice_num].every.every.." "..cutty.voices[voice_num].every.unit.." "..cutty.voices[voice_num].every.chance
    end
      
  else
    local every = getArgNum(args[2], "every")
    local unit = args[3]
    if unit ~= "b" and unit ~= "s" then
      return cutty.cmds["every"]({"help"})
    end
    
    local chance = 100
    if #args == 4 then
      local rnd = string.gsub(args[4], "%%", "")
      chance = getArgNum(rnd, "every")
    end
    
    -- cancel existing clock
    if cutty.voices[voice_num].every_clock ~= nil then
      clock.cancel(cutty.voices[voice_num].every_clock)
    end
    
    cutty.voices[voice_num].every = {
      every = every,
      unit = unit,
      chance = chance
    }
    cutty.voices[voice_num].every_clock = clock.run(every_handler, voice_num, every, unit, chance / 100)
    
    return okResponse
  end
end

return cutty