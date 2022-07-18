-- hnds
--
-- Lua lfo's for script
-- parameters.
-- ----------
--
-- v0.4 @justmat

local number_of_outputs = 4
local envelope = 0
local lamp_val = 0
local ramp_val = 0

local tau = math.pi * 2

local options = {
  lfotypes = {
    "sine",
    "square",
    "s+h",
    "l env follower",
    "r env follower"
  },

  polarity = {
    "+",
    "-"
  }
}

local lfo = {}
for i = 1, number_of_outputs do
  lfo[i] = {
    freq = 0.01,
    counter = 1,
    waveform = options.lfotypes[1],
    slope = 0,
    depth = 25,
    offset = 0,
    polarity = options.polarity[1],
    trig = false
  }
end

-- redefine in user script ---------
for i = 1, number_of_outputs do
  lfo[i].lfo_targets = {"none"}
end

function lfo.process()
end
------------------------------------


function lfo.scale(old_value, old_min, old_max, new_min, new_max)
  -- scale ranges
  local old_range = old_max - old_min

  if old_range == 0 then
    old_range = new_min
  end

  local new_range = new_max - new_min
  local new_value = (((old_value - old_min) * new_range) / old_range) + new_min

  return new_value
end


local function make_sine(n)
  local v = 1 * math.sin(((tau / 100) * (lfo[n].counter)) - (tau / (lfo[n].freq)))
  local pv = 1 * math.sin(((tau / 100) * (lfo[n].counter - 1)) - (tau / (lfo[n].freq)))
  if pv < 0 and v > 0 then
    lfo[n].trig = true
  else
    lfo[n].trig = false
  end
  return v
end


local function make_square(n)
  return make_sine(n) >= 0 and 1 or -1
end


local function make_sh(n)
  local polarity = make_square(n)
  if lfo[n].prev_polarity ~= polarity then
    lfo[n].prev_polarity = polarity
    return math.random() * (math.random(0, 1) == 0 and 1 or -1)
  else
    return lfo[n].prev
  end
  print(lfo[n].prev)
end


function lfo.init()
  params:add_separator("modulation")
  for i = 1, number_of_outputs do
    -- modulation destination
    params:add_group("lfo " .. i, 7)
    params:add_option(i .. "lfo_target", i .. " lfo target", lfo[i].lfo_targets, 1)
    -- lfo shape
    params:add_option(i .. "lfo_shape", i .. " lfo shape", options.lfotypes, 1)
    params:set_action(i .. "lfo_shape", 
      function(value)
        lfo[i].waveform = options.lfotypes[value]
        if lfo[i].waveform == "l env follower" or lfo[i].waveform == "r env follower" then
          params:show(i .. "env_pol")
          _menu.rebuild_params()
        else
          params:hide(i .. "env_pol")
          _menu.rebuild_params()
        end
      end)
    -- envelope polarity
    params:add_option(i .. "env_pol", i .. " polarity", options.polarity, 1)
    params:set_action(i .. "env_pol", function(value) lfo[i].polarity = options.polarity[value] end)
    --params:hide(i .. "env_pol")
    -- lfo depth
    params:add_number(i .. "lfo_depth", i .. " lfo depth", 0, 100, 25)
    params:set_action(i .. "lfo_depth", function(value) lfo[i].depth = value end)
    -- lfo offset
    params:add_control(i .."offset", i .. " offset", controlspec.new(-4.0, 3.0, "lin", 0.1, 0.0, ""))
    params:set_action(i .. "offset", function(value) lfo[i].offset = value end)
    -- lfo speed
    params:add_control(i .. "lfo_freq", i .. " lfo freq", controlspec.new(0.01, 10.0, "lin", 0.1, 0.01, ""))
    params:set_action(i .. "lfo_freq", function(value) lfo[i].freq = value end)
    -- lfo on/off
    params:add_option(i .. "lfo", i .. " lfo", {"off", "on"}, 1)
  end


  lenv = poll.set("amp_in_l")
  lenv.callback = function(x)
    x = x * 100
    if x < 1.0 then
      lamp_val = 0
    else
      lamp_val = lfo.scale(x, 0.0, 100.0, -1.0, 1.0)
    end
  end
  lenv.time = 1/60
  lenv:start()
  
  renv = poll.set("amp_in_r")
  renv.callback = function(x)
    x = x * 100
    if x < 1.0 then
      ramp_val = 0
    else
      ramp_val = lfo.scale(x, 0.0, 100.0, -1.0, 1.0)
    end
  end
  renv.time = 1/60
  renv:start()

  local lfo_metro = metro.init()
  lfo_metro.time = .01
  lfo_metro.count = -1
  lfo_metro.event = function()
    for i = 1, number_of_outputs do
      if params:get(i .. "lfo") == 2 then
        local slope
        if lfo[i].waveform == "sine" then
          slope = make_sine(i)
        elseif lfo[i].waveform == "square" then
          slope = make_square(i)
        elseif lfo[i].waveform == "s+h" then
          slope = make_sh(i)
        elseif lfo[i].waveform == "l env follower" then
          if lfo[i].polarity == "+" then
            slope = lamp_val
          else
            slope = -lamp_val
          end
        elseif lfo[i].waveform == "r env follower" then
          if lfo[i].polarity == "+" then
            slope = ramp_val
          else
            slope = -ramp_val
          end
        end
        lfo[i].prev = slope
        lfo[i].slope = math.max(-1.0, math.min(1.0, slope)) * (lfo[i].depth * 0.01) + lfo[i].offset
        lfo[i].counter = lfo[i].counter + lfo[i].freq
      end
    end
    lfo.process()
  end
  lfo_metro:start()
end


return lfo
