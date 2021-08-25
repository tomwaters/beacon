--
-- library to provide softcut functionality
--

er = require("er")

cutty = {}
cutty.voices = {}
cutty.cmds = {}

cutty.init = function()
  for i=1, softcut.VOICE_COUNT do
    cutty.voices[i] = {
      level = 1.0,
      start_sec = 0,
      end_sec = softcut.BUFFER_SIZE,
      rate = {
        min = 1.0
      }
    }
    softcut.loop_start(i, cutty.voices[i].start_sec)
    softcut.loop_end(i, cutty.voices[i].end_sec)
  end
  math.randomseed(os.time())
end

local okResponse = "ok"

function get_help(cmd)
  return cutty.cmds[cmd]({"help"})
end

-- helper to play a voice (one shot)
function play_voice(voice_num)
  if cutty.voices[voice_num].rate.list ~= nil then
    local rate = cutty.voices[voice_num].rate.list[cutty.voices[voice_num].rate.next]
    softcut.rate(voice_num, rate)
    
    -- calc next step
    if cutty.voices[voice_num].rate.direction == "rnd" then
      cutty.voices[voice_num].rate.next = math.random(#cutty.voices[voice_num].rate.list)
    elseif cutty.voices[voice_num].rate.direction == "up" then
      if cutty.voices[voice_num].rate.next == #cutty.voices[voice_num].rate.list then
        cutty.voices[voice_num].rate.next = 1
      else
        cutty.voices[voice_num].rate.next = cutty.voices[voice_num].rate.next + 1
      end
    elseif cutty.voices[voice_num].rate.direction == "dn" then
      if cutty.voices[voice_num].rate.next == 1 then
        cutty.voices[voice_num].rate.next = #cutty.voices[voice_num].rate.list
      else
        cutty.voices[voice_num].rate.next = cutty.voices[voice_num].rate.next - 1
      end
    end
  elseif cutty.voices[voice_num].rate.max ~= nil then
    local rnd_rate = cutty.voices[voice_num].rate.min + ((cutty.voices[voice_num].rate.max - cutty.voices[voice_num].rate.min) * math.random())
    softcut.rate(voice_num, rnd_rate)
  else
    softcut.rate(voice_num, cutty.voices[voice_num].rate.min)
  end
  
  softcut.loop(voice_num, 1)
  softcut.position(voice_num, cutty.voices[voice_num].start_sec)
  softcut.play(voice_num, 1)
  softcut.loop(voice_num, 0)
end

-- helper to trigger voice at regullar interval
function every_handler(voice_num)
  while true do
    local every = cutty.voices[voice_num].every
    local euc = cutty.voices[voice_num].euc
    
    if every.unit == "b" then
      clock.sync(every.every)
    end

    if math.random() <= every.chance / 100 then
      local do_play = true
      if euc ~= nil then
        if euc.pos > #euc.pattern then
          euc.pos = 1
        end
        do_play = euc.pattern[euc.pos]
        euc.pos = euc.pos + 1
      end
      
      if do_play then
        play_voice(voice_num)
      end
    end
    
    if every.unit == "s" then
      clock.sleep(every.every)
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
    local new_tempo = tonumber(args[1])
    if new_tempo == nil then
      return get_help("bpm")
    end
    
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
    softcut.buffer_clear_channel(1)
    softcut.buffer_clear_channel(2)
    softcut.buffer_read_stereo(file, 0, 0, -1)
  else
    local buf_num = tonumber(args[2])
    if buf_num == nil then
      return get_help("load")
    end
    
    softcut.buffer_clear_channel(buf_num)
    softcut.buffer_read_mono(file, 0, 0, -1, 1, buf_num)
  end
  
  return okResponse
end

cutty.cmds["voice"] = function(args)
  if #args < 1 or args[1] == "help" then
    return "voice <v#> <b#>"
  end
  
  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("voice")
  end
  
  if #args == 1 then
    if cutty.voices[voice_num].buffer == nil then
      return "not set"
    else
      return "voice "..voice_num.." buffer "..cutty.voices[voice_num].buffer
    end
  else
    local buf_num = tonumber(args[2])
    if buf_num == nil then
      return get_help("voice")
    end
    
    cutty.voices[voice_num].buffer = buf_num
    
    softcut.enable(voice_num, 1)
    softcut.buffer(voice_num, buf_num)
    softcut.level(voice_num, 1.0)
    softcut.loop(voice_num, 0)
    softcut.loop_end(voice_num, softcut.BUFFER_SIZE)
    
    return okResponse
  end
end

cutty.cmds["level"] = function(args)
  if #args < 1 or args[1] == "help" then
    return "level <v#> <l>"
  end
  
  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("level")
  end
  
  if #args == 1 then
    return "level "..cutty.voices[voice_num].level
  else
    local new_level = tonumber(args[2])
    if new_level == nil then
      return get_help("level")
    end
    
    cutty.voices[voice_num].level = new_level
    softcut.level(voice_num, new_level)

    return okResponse
  end
end

cutty.cmds["range"] = function(args)
  if #args == 0 or #args == 2 or args[1] == "help" then
    return "range <v#> <s> <e>"
  end

  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("range")
  end
  
  if #args == 1 then
    return "range "..cutty.voices[voice_num].start_sec.." "..cutty.voices[voice_num].end_sec
  else
    local start_sec = tonumber(args[2])
    local end_sec = tonumber(args[3])
    if start_sec == nil or end_sec == nil then
      return get_help("range")
    end
    
    cutty.voices[voice_num].start_sec = start_sec
    cutty.voices[voice_num].end_sec = end_sec
    softcut.loop_start(voice_num, cutty.voices[voice_num].start_sec)
    softcut.loop_end(voice_num, cutty.voices[voice_num].end_sec)
    
    return okResponse      
  end
end

cutty.cmds["play"] = function(args)
  if #args == 0 or args[1] == "help" then
    return "play <v#>"
  end
  
  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("play")
  end
  play_voice(voice_num)
    
  return okResponse  
end

cutty.cmds["stop"] = function(args)
  if #args < 1 or args[1] == "help" then
    return "stop <v#>"
  end
  
  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("stop")
  end
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

  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("loop")
  end
  
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
  if #args == 0 or args[1] == "help" then
    return "rate <v#> <r>"
  end

  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("rate")
  end
  
  if #args == 1 then
    if cutty.voices[voice_num].rate.list ~= nil then
      return "rate "..table.concat(cutty.voices[voice_num].rate.list, ",").." "..cutty.voices[voice_num].rate.direction
    else
      local val = "rate "..cutty.voices[voice_num].rate.min
      if cutty.voices[voice_num].rate.max ~= nil then
        val = val.." "..cutty.voices[voice_num].rate.max
      end
      return val
    end
  else
    cutty.voices[voice_num].rate.list = nil
    cutty.voices[voice_num].rate.direction = nil
    cutty.voices[voice_num].rate.min = nil
    cutty.voices[voice_num].rate.max = nil
    
    local a2 = tonumber(args[2])
    if a2 ~= nil then
      if #args > 2 then
        local a3 = tonumber(args[3])
        if a3 == nil then 
          return get_help("rate")
        end
        cutty.voices[voice_num].rate.max = a3
      end
      
      -- fixed rate or min rate / max random rate
      cutty.voices[voice_num].rate.min = a2
      softcut.rate(voice_num, a2)
      
    else
      -- list of rates
      cutty.voices[voice_num].rate.list = {}
      for v in string.gmatch(args[2], "[^,]+") do
        local rate = tonumber(v)
        if rate == nil then
          return get_help("rate")
        end
        table.insert(cutty.voices[voice_num].rate.list, rate)
      end
      
      -- pattern
      cutty.voices[voice_num].rate.direction = "up"
      if #args > 2 and (args[3] == "rnd" or args[3] == "dn") then
        cutty.voices[voice_num].rate.direction = args[3]
      end
      
      if cutty.voices[voice_num].rate.direction == "dn" then
        cutty.voices[voice_num].rate.next = #cutty.voices[voice_num].rate.list
      else
        cutty.voices[voice_num].rate.next = 1
      end
    end
    
  end
  
  return okResponse
end

cutty.cmds["rate_slew"] = function(args)
  if #args == 0 or args[1] == "help" then
    return "rate_slew <v#> <s>"
  end
  
  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("rate_slew")
  end
  
  if #args == 1 then
    if cutty.voices[voice_num].rate_slew == nil then
      return "rate_slew not set"
    else
      return "rate_slew "..cutty.voices[voice_num].rate_slew
    end
  else
    local secs = tonumber(args[2])
    if secs == nil then
      return get_help("rate_slew")
    end

    cutty.voices[voice_num].rate_slew = secs
    softcut.rate_slew_time(voice_num, secs)

    return okResponse
  end
end

cutty.cmds["every"] = function(args)
  if #args == 0 or #args == 2 or args[1] == "help" then
    return "every <v#> <x> <b/s> (n%)"
  end
  
  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("every")
  end
  
  if #args == 1 then
    if cutty.voices[voice_num].every == nil then
      return "every not set"
    else
      return "every "..cutty.voices[voice_num].every.every.." "..cutty.voices[voice_num].every.unit.." "..cutty.voices[voice_num].every.chance
    end
      
  else
    local every = tonumber(args[2])
    local unit = args[3]
    local chance = 100
    
    if #args == 4 then
      local rnd = string.gsub(args[4], "%%", "")
      chance = tonumber(rnd)
    end

    if every == nil or (unit ~= "b" and unit ~= "s") or chance == nil then
      return get_help("every")
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
    cutty.voices[voice_num].every_clock = clock.run(every_handler, voice_num)
    
    return okResponse
  end
end

cutty.cmds["euc"] = function(args)
  if #args == 0 or #args == 2 or args[1] == "help" then
    return "euc <v#> <p> <s> (o)"
  end
  
  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("every")
  end
  
  if #args == 1 then
    if cutty.voices[voice_num].euc == nil then
      return "euc not set"
    else
      return "euc "..cutty.voices[voice_num].euc.pulses.." "..cutty.voices[voice_num].euc.steps.." "..cutty.voices[voice_num].euc.offset
    end
  else
    local pulses = tonumber(args[2])
    local steps = tonumber(args[3])
    local offset = 0
    
    if #args >= 4 then
      offset = tonumber(args[4])
    end
    
    if pulses == nil or steps == nil or offset == nil then
      return get_help("every")
    end

    if pulses > steps then
      return cutty.cmds["euc"]({"help"})
    end

    local pos = 1
    if cutty.voices[voice_num].euc ~= nil then
      pos = cutty.voices[voice_num].euc.pos
    end
    
    cutty.voices[voice_num].euc = {
      pulses = pulses,
      steps = steps,
      offset = offset,
      pattern = er.gen(pulses, steps, offset),
      pos = pos
    }
    
    return okResponse
    
  end
end

cutty.cmds["filter"] = function(args)
  if #args == 0 or args[1] == "help" then
    return "filter <v#> <off/hp/lp/bp> <f> (q)"
  end
  
  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("every")
  end
  
  if #args == 1 then
    if cutty.voices[voice_num].filter == nil then
      return "filter not set"
    else
      return "filter "..cutty.voices[voice_num].filter.type.." "..cutty.voices[voice_num].filter.freq.." "..cutty.voices[voice_num].filter.rq
    end
  elseif args[2] == "off" then
    cutty.voices[voice_num].filter = nil
    softcut.post_filter_dry(voice_num, 1)
    softcut.post_filter_lp(voice_num, 0)
    softcut.post_filter_bp(voice_num, 0)
    softcut.post_filter_hp(voice_num, 0)
    softcut.post_filter_rq(voice_num, 2)
    softcut.post_filter_fc(voice_num, 12000)
  else
    local freq = tonumber(args[3])
    if (args[2] ~= "hp" and args[2] ~= "lp" and  args[2] ~= "bp") or freq == nil then
      return cutty.cmds["filter"]({"help"})
    end
    
    local rq = 2
    if #args > 3 then
      rq = tonumber(args[4])
      if rq == nil then
        return cutty.cmds["filter"]({"help"})
      end
    elseif cutty.voices[voice_num].filter ~= nil and cutty.voices[voice_num].filter.rq ~= nil then
      rq = cutty.voices[voice_num].filter.rq
    end
      
    cutty.voices[voice_num].filter = {
      type = args[2],
      freq = freq,
      rq = rq
    }
    
    softcut.post_filter_dry(voice_num, 0)
    softcut.post_filter_fc(voice_num, freq)
    softcut.post_filter_rq(voice_num, rq)
    
    if args[2] == "hp" then
      softcut.post_filter_hp(voice_num, 1)
      softcut.post_filter_lp(voice_num, 0)
      softcut.post_filter_bp(voice_num, 0)
    elseif args[2] == "lp" then
      softcut.post_filter_lp(voice_num, 1)
      softcut.post_filter_bp(voice_num, 0)
      softcut.post_filter_hp(voice_num, 0)
    elseif args[2] == "bp" then
      softcut.post_filter_bp(voice_num, 1)
      softcut.post_filter_lp(voice_num, 0)
      softcut.post_filter_hp(voice_num, 0)
    end
  end
  
  return okResponse
end


return cutty