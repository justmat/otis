-- hnds
--
-- Lua lfo's for script
-- parameters.
-- ----------
--
-- v0.2 @justmat

local number_of_outputs = 4

local tau = math.pi * 2

local options = {
  lfotypes = {
    "sine",
    "square"
  }
}

local lfo = {}
for i = 1, number_of_outputs do
  lfo[i] = {
    freq = 0.01,
    counter = 1,
    waveform = options.lfotypes[1],
    slope = 0,
    depth = 100,
    offset = 0,
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
  return 1 * math.sin(((tau / 100) * (lfo[n].counter)) - (tau / (lfo[n].freq)))
end


local function make_square(n)
  return make_sine(n) >= 0 and 1 or -1
end


function lfo.init()
  for i = 1, number_of_outputs do
    params:add_separator()
    -- modulation destination
    params:add_option(i .. "lfo_target", i .. " lfo target", lfo[i].lfo_targets, 1)
    -- lfo shape
    params:add_option(i .. "lfo_shape", i .. " lfo shape", options.lfotypes, 1)
    params:set_action(i .. "lfo_shape", function(value) lfo[i].waveform = options.lfotypes[value] end)
    -- lfo offset
    params:add_control(i .."lfo_offset", i .. " lfo offset", controlspec.new(-400, 300, "lin", 5, 0, ""))
    params:set_action(i .. "lfo_offset", function(value) lfo[i].offset = value end)
    -- lfo speed
    params:add_control(i .. "lfo_freq", i .. " lfo freq", controlspec.new(0.001, 25.0, "lin", 0.001, math.random(100) * 0.001, ""))
    params:set_action(i .. "lfo_freq", function(value) lfo[i].freq = value end)
    -- lfo depth
    params:add_number(i .. "lfo_depth", i .. " lfo depth", 0, 100, 100)
    params:set_action(i .. "lfo_depth", function(value) lfo[i].depth = value end)
    -- lfo on/off
    params:add_option(i .. "lfo", i .. " lfo", {"off", "on"}, 1)
  end

  local lfo_metro = metro.init()
  lfo_metro.time = .01
  lfo_metro.count = -1
  lfo_metro.event = function()
    for i = 1, number_of_outputs do
      local slope
      if params:get(i .. "lfo") == 1 then
        break
      elseif lfo[i].waveform == "sine" then
        slope = make_sine(i)
      elseif lfo[i].waveform == "square" then
        slope = make_square(i)
      end
      lfo[i].slope = slope * (lfo[i].depth * 0.01) + (lfo[i].offset * 0.01)
      lfo[i].counter = lfo[i].counter + lfo[i].freq
    end
    lfo.process()
  end
  lfo_metro:start()
end


return lfo
