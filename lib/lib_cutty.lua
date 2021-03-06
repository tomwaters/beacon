--
-- library to provide softcut functionality
--

er = require("er")
s = require("sequins")

local two_pi = math.pi * 2
local okResponse = "ok"
local delay_voice = 6
local delay_len = 1

cutty = {}
cutty.voices = {}
cutty.cmds = {}
cutty.lfos = {}
cutty.lfo_types = {"filter", "rate", "level", "pan"}

cutty.init = function()
  for i=1, softcut.VOICE_COUNT do
    cutty.voices[i] = {
      level = 1.0,
      pan = 0,
      start_sec = 0,
      end_sec = softcut.BUFFER_SIZE - delay_len,
      rate = {
        current = 1,
        min = 1.0
      },
      delay = 0
    }
    softcut.loop_start(i, cutty.voices[i].start_sec)
    softcut.loop_end(i, cutty.voices[i].end_sec)
  end
  
  math.randomseed(os.time())
  audio.level_adc_cut(1)
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

function get_help(cmd)
  return cutty.cmds[cmd]({"help"})
end

function supported_lfo(type)
  for _,t in pairs(cutty.lfo_types) do
    if t == type then 
      return true
    end
  end
  return false
end

-- helper to play a voice (one shot)
function play_voice(voice_num)
  if cutty.voices[voice_num].rate.seq ~= nil then
    cutty.voices[voice_num].rate.current = cutty.voices[voice_num].rate.seq()
  elseif cutty.voices[voice_num].rate.list ~= nil then
    cutty.voices[voice_num].rate.current = cutty.voices[voice_num].rate.list[cutty.voices[voice_num].rate.next]
    
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
    cutty.voices[voice_num].rate.current = cutty.voices[voice_num].rate.min + ((cutty.voices[voice_num].rate.max - cutty.voices[voice_num].rate.min) * math.random())
  else
    cutty.voices[voice_num].rate.current = cutty.voices[voice_num].rate.min
  end

  -- set current rate
  softcut.rate(voice_num, cutty.voices[voice_num].rate.current)

  -- handle negative rate to play backwards
  if cutty.voices[voice_num].rate.current < 0 then   
    softcut.position(voice_num, cutty.voices[voice_num].end_sec)
  else
    softcut.position(voice_num, cutty.voices[voice_num].start_sec)
  end
  
  softcut.loop(voice_num, 1)
  softcut.play(voice_num, 1)
  softcut.loop(voice_num, 0)
end

-- helper to trigger voice at regular interval
function every_handler(voice_num)
  while true do
    local every = cutty.voices[voice_num].every
    local rhy = cutty.voices[voice_num].rhy
    
    if every.unit == "b" then
      clock.sync(every.every)
    end

    if math.random() <= every.chance / 100 then
      local do_play = true
      if rhy ~= nil then
        if rhy.pos > #rhy.pattern then
          rhy.pos = 1
        end
        do_play = rhy.pattern[rhy.pos]
        rhy.pos = rhy.pos + 1
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

-- helper to run lfo
function lfo_handler(lfo_num)
  local lfo = cutty.lfos[lfo_num]
  
  while true do
    local n = math.sin((util.time() * two_pi) * lfo.freq)
    
    if lfo.param == "filter" then
      -- freq goes current value +- 5k
      n = ((n * 10000) - 5000)  * lfo.amount
      local freq = cutty.voices[lfo.voice].filter.freq
      softcut.post_filter_fc(lfo.voice, freq + n)
    elseif lfo.param == "rate" then
      -- rate goes current value +- 1.0
      n = ((n * 2) - 1) * lfo.amount
      local rate = cutty.voices[lfo.voice].rate.current
      softcut.rate(lfo.voice, rate + n)
    elseif lfo.param == "level" then
      -- level goes current value +- 1.0
      n = ((n * 2) - 1)  * lfo.amount
      local level = cutty.voices[lfo.voice].level
      softcut.level(lfo.voice, level + n)
    elseif lfo.param == "pan" then
      -- pan goes current value +- 1.0
      n = ((n * 2) - 1) * lfo.amount
      local pan = cutty.voices[lfo.voice].pan
      softcut.pan(lfo.voice, pan + n)
    end
    
    clock.sleep(0.01)
  end
  
end

function print_sequin(s)
  local o = "s{"
  for _, n in pairs(s.data) do
    if type(n) == "table" then
      o = o..print_sequin(n)
    else
      o = o..tostring(n)
    end
    
    if next(s.data, _) ~= nil then
      o = o..","
    end

  end
  o = o.."}"
  
  return o
end

function print_bool_table(t)
  local o = ""
  for _, n in pairs(t) do
    if n then
      o = o.."1"
    else
      o = o.."0"
    end
    
    if next(t, _) ~= nil then
      o = o..","
    end

  end

  return o
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
    return "bpm <bpm> (s)"
  else
    local new_tempo = tonumber(args[1])
    if new_tempo == nil then
      return get_help("bpm")
    end
    
    if cutty.bpm_clock ~= nil then
        clock.cancel(cutty.bpm_clock)
    end
    
    -- if change bpm over s seconds...
    if #args > 1 then
      local secs = tonumber(args[2])
      if secs == nil then
        return get_help("bpm")
      end

      cutty.bpm_dir = params:get("clock_tempo") < new_tempo and "up" or "down"
      cutty.bpm_end = util.time() + secs
      cutty.bpm_clock = clock.run(
        function()
          local done = false
          while not done do
            local cur_tempo = params:get("clock_tempo")
            local n = ((new_tempo - cur_tempo) / (cutty.bpm_end - util.time())) * 0.1
            params:set("clock_tempo", cur_tempo + n)
            
            -- stop if reached target
            if (cutty.bpm_dir == "up" and cur_tempo + n >= new_tempo) or (cutty.bpm_dir == "down" and cur_tempo + n <= new_tempo) then
              params:set("clock_tempo", new_tempo)
              done = true
            end
            
            clock.sleep(0.1)
          end
        end
      )
      
    else
      params:set("clock_tempo", new_tempo)
    end
    
    return okResponse
  end
end

cutty.cmds["load"] = function(args)
  if #args == 0 or args[1] == "help" then
    return "load <file> (b#) (s)"
  end

  local file = _path.dust..args[1]
  if #args == 1 then
    softcut.buffer_clear_channel(1)
    softcut.buffer_clear_channel(2)
    softcut.buffer_read_stereo(file, 0, 0, softcut.BUFFER_SIZE - delay_len)
  else
    local buf_num = tonumber(args[2])
    local start = 0
    
    if #args > 2 then
      start = tonumber(args[3])
    end
    
    if buf_num == nil or start == nil then
      return get_help("load")
    end
    
    softcut.buffer_clear_region_channel(buf_num, start, softcut.BUFFER_SIZE - start - delay_len, 0, 0)
    softcut.buffer_read_mono(file, 0, start, softcut.BUFFER_SIZE - start - delay_len, 1, buf_num)
  end
  
  return okResponse
end

cutty.cmds["rec"] = function(args)
  if #args == 0 or args[1] == "help" then
    return "rec <v#>"
  end

  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("rec")
  elseif cutty.delay ~= nil and voice_num == delay_voice then
    return "v "..delay_voice.." is being used for delay"
  end
  
  if cutty.voices[voice_num].rec_start == nil then
    cutty.voices[voice_num].rec_start = util.time()
    softcut.position(voice_num, cutty.voices[voice_num].start_sec)
    softcut.level_input_cut(1, voice_num, 1.0)
    softcut.level_input_cut(2, voice_num, 1.0)
    softcut.rec_level(voice_num, 1.0)
    softcut.pre_level(voice_num, 0.0)
    softcut.rec(voice_num, 1)
    return "recording"
  else
    softcut.rec(voice_num, 0)
    cutty.voices[voice_num].end_sec = cutty.voices[voice_num].start_sec + (util.time() - cutty.voices[voice_num].rec_start)
    cutty.voices[voice_num].rec_start = nil
    return "stopped"
  end

end

cutty.cmds["voice"] = function(args)
  if #args < 1 or args[1] == "help" then
    return "voice <v#> <b#>"
  end
  
  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("voice")
  elseif cutty.delay ~= nil and voice_num == delay_voice then
    return "v "..delay_voice.." is being used for delay"
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

cutty.cmds["pan"] = function(args)
  if #args < 1 or args[1] == "help" then
    return "pan <v#> <p>"
  end
  
  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("pan")
  end
  
  if #args == 1 then
    return "pan "..cutty.voices[voice_num].pan
  else
    local new_pan = tonumber(args[2])
    if new_pan == nil then
      return get_help("pan")
    end
    
    cutty.voices[voice_num].pan = new_pan
    softcut.pan(voice_num, new_pan)

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
  elseif cutty.delay ~= nil and voice_num == delay_voice then
    return "v "..delay_voice.." is being used for delay"
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
  elseif cutty.delay ~= nil and voice_num == delay_voice then
    return "v "..delay_voice.." is being used for delay"
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
  elseif cutty.delay ~= nil and voice_num == delay_voice then
    return "v "..delay_voice.." is being used for delay"
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
  elseif cutty.delay ~= nil and voice_num == delay_voice then
    return "v "..delay_voice.." is being used for delay"
  end
  
  if #args > 1 then
    if args[2] == "off" then
      softcut.loop(voice_num, 0)
    else
      return get_help("loop")
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
    if cutty.voices[voice_num].rate.seq ~= nil then
      return "rate "..print_sequin(cutty.voices[voice_num].rate.seq)
    elseif cutty.voices[voice_num].rate.list ~= nil then
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
    cutty.voices[voice_num].rate.seq = nil
    
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
    elseif args[2]:sub(1, 1) == 's' then
      local loaded_seq = load("return "..args[2])
      if loaded_seq then
        local ok, seq = pcall(loaded_seq)
        if ok then
          cutty.voices[voice_num].rate.seq = seq
        else
          return get_help("rate")
        end
      else
        return get_help("rate")
      end

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
  elseif cutty.delay ~= nil and voice_num == delay_voice then
    return "v "..delay_voice.." is being used for delay"
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
    return get_help("euc")
  elseif cutty.delay ~= nil and voice_num == delay_voice then
    return "v "..delay_voice.." is being used for delay"
  end
  
  local rhy_type = "euc"
  if #args == 1 then
    if cutty.voices[voice_num].rhy == nil or cutty.voices[voice_num].rhy.type ~= rhy_type then
      return "euc not set"
    else
      return "euc "..cutty.voices[voice_num].rhy.pulses.." "..cutty.voices[voice_num].rhy.steps.." "..cutty.voices[voice_num].rhy.offset
    end
  else
    local pulses = tonumber(args[2])
    local steps = tonumber(args[3])
    local offset = 0
    
    if #args >= 4 then
      offset = tonumber(args[4])
    end
    
    if pulses == nil or steps == nil or offset == nil or pulses > steps then
      return get_help("euc")
    end

    cutty.voices[voice_num].rhy = {
      type = rhy_type,
      pulses = pulses,
      steps = steps,
      offset = offset,
      pattern = er.gen(pulses, steps, offset),
      pos = 1
    }
    
    return okResponse
  end
end

cutty.cmds["rhy"] = function(args)
  if #args == 0 or args[1] == "help" then
    return "rhy <r>"
  end
  
  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("rhy")
  elseif cutty.delay ~= nil and voice_num == delay_voice then
    return "v "..delay_voice.." is being used for delay"
  end
  
  local rhy_type = "rhy"
  if #args == 1 then
    if cutty.voices[voice_num].rhy == nil or cutty.voices[voice_num].rhy.type ~= rhy_type then
      return "rhy not set"
    else
      return "rhy "..print_bool_table(cutty.voices[voice_num].rhy.pattern)
    end
  else
    local new_rhy = {}
    for v in string.gmatch(args[2], "[^,]+") do
      local v = tonumber(v)
      if v == nil or v < 0 or v > 1 then
        return get_help("rhy")
      end
      table.insert(new_rhy, v == 1)
    end

    cutty.voices[voice_num].rhy = {
      type = rhy_type,
      pattern = new_rhy,
      pos = 1
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
    return get_help("filter")
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
      return get_help("filter")
    end
    
    local rq = 2
    if #args > 3 then
      rq = tonumber(args[4])
      if rq == nil then
        return get_help("filter")
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

cutty.cmds["lfo"] = function(args)
  if #args == 0 or args[1] == "help" then
    return "lfo <l#> <v#/off> <p> <f> (a)"
  end

  local lfo_num = tonumber(args[1])
  if lfo_num == nil then
    return get_help("lfo")
  end

  if #args == 1 then
    if cutty.lfos[lfo_num] == nil then
      return "lfo not set"
    else
      return "lfo voice "..cutty.lfos[lfo_num].voice.." "..cutty.lfos[lfo_num].param.." "..cutty.lfos[lfo_num].freq.."hz "..cutty.lfos[lfo_num].amount
    end
  else
    local lfo = {
      voice = tonumber(args[2]),
      param = args[3],
      freq = tonumber(args[4]),
      amount = 1
    }
    
    if args[2] ~= "off" and lfo.voice == nil then
      return get_help("lfo")
    end
    
    -- if not stop do more checks
    if #args > 2 then
      
      if #args > 4 then
        lfo.amount = tonumber(args[5])
      end
      
      if not supported_lfo(lfo.param) or lfo.freq == nil or lfo.amount == nil then
        return get_help("lfo")
      end
      
      if lfo.param == "filter" and cutty.voices[lfo.voice].filter == nil then
        return "filter not set for voice "..lfo.voice
      end
    end
    
    -- cancel current lfo
    if cutty.lfos[lfo_num] ~= nil and cutty.lfos[lfo_num].clock ~= nil then
      clock.cancel(cutty.lfos[lfo_num].clock)
    end
    
    -- start a new lfo
    if #args > 2 then
      cutty.lfos[lfo_num] = lfo
      cutty.lfos[lfo_num].clock = clock.run(lfo_handler, lfo_num)
    else
      cutty.lfos[lfo_num] = nil
    end
  end

  return okResponse  
end

cutty.cmds["delay_voice"] = function(args)
  if #args == 0 or args[1] == "help" then
    return "delay_voice <v#> <a>"
  end
  
  if cutty.delay == nil then
    return "delay is disabled"
  end
  
  local voice_num = tonumber(args[1])
  if voice_num == nil then
    return get_help("delay_voice")
  elseif cutty.delay ~= nil and voice_num == delay_voice then
    return "v "..delay_voice.." is being used for delay"
  end
  
  if #args == 1 then
    return "delay_voice "..cutty.voices[voice_num].delay
  else
    local amount = tonumber(args[2])
    if amount == nil then
      return get_help("delay_voice")
    end

    cutty.voices[voice_num].delay = amount
    softcut.level_cut_cut(voice_num, delay_voice, amount)

    return okResponse
  end
end

cutty.cmds["delay"] = function(args)
  if #args > 0 and args[1] == "help" then
    return "delay off/<fb>"
  end

  if #args == 0 then
    if cutty.delay == nil then
      return "delay is off"
    else
      return "delay is on fb:"..cutty.delay.feedback
    end
  elseif args[1] == "off" then
    softcut.play(delay_voice, 0)
    cutty.delay = nil
  else
    local fb = tonumber(args[1])
    if fb == nil then
      return get_help("delay")
    end

    if cutty.voices[delay_voice].every_clock ~= nil then
      clock.cancel(cutty.voices[delay_voice].every_clock)
    end
    
    if cutty.delay == nil then
      cutty.delay = {}
      cutty.voices[delay_voice].rate.min = 1
      cutty.voices[delay_voice].level = 1
      
      softcut.level(delay_voice, 1)
      softcut.play(delay_voice, 1)
    	softcut.rate(delay_voice, 1)
      softcut.rate_slew_time(delay_voice, 0.25)
    	softcut.position(delay_voice, softcut.BUFFER_SIZE - delay_len)
    	softcut.loop_start(delay_voice, softcut.BUFFER_SIZE - delay_len)
    	softcut.loop_end(delay_voice, softcut.BUFFER_SIZE-0.5)
    	softcut.loop(delay_voice, 1)
    	softcut.fade_time(delay_voice, 0.1)
    	softcut.rec(delay_voice, 1)
    	softcut.rec_level(delay_voice, 1)
    	softcut.enable(delay_voice, 1)
    end

    cutty.delay.feedback = fb    
    softcut.pre_level(delay_voice, fb)
  end
  
  return okResponse  
end

return cutty