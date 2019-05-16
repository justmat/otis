-- hnds
--
-- Lua lfo's for script
-- parameters.
-- ----------
--
-- v0.1 @justmat

local number_of_outputs = 4

local tau = math.pi * 2

local options = {
  lfotypes = {
    "sine",
    "square"
  }
}


math.randomseed(os.time())
math.random(); math.random(); math.random()


local lfo = {}
for i = 1, number_of_outputs do
  lfo[i] = {
    freq = 0.01,
    counter = 1,
    waveform = 1,
    slope = 0,
    min_val = 0,
    max_val = 100
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
  lfo[n].slope = 1 * math.sin(((tau / 100) * (lfo[n].counter)) - (tau / (lfo[n].freq)))

end


local function make_square(n)
  if (lfo[n].counter + lfo[n].freq) % 360 <= 180.0 then
    lfo[n].slope = 1.0
  else
    lfo[n].slope =  -1.0
  end
end


function lfo.init()
  for i = 1, number_of_outputs do
    params:add_separator()
    -- modualtion destination
    params:add_option(i .. "lfo_target", i .. " lfo target", lfo[i].lfo_targets, 1)
    -- lfo shape
    params:add_option(i .. "lfo_shape", i .. " lfo shape", options.lfotypes, 1)
    params:set_action(i .. "lfo_shape", function(value) lfo[i].waveform = options.lfotypes[value] end)
    -- lfo max value
    params:add_number(i .. "lfo_max", i .. " lfo max", 1.0, 100.0, 100)
    params:set_action(i .. "lfo_max", function(value) lfo[i].max_val = value end)
    -- lfo min value
    params:add_number(i .. "lfo_min", i .. " lfo min", 0.0, 99.0, 0)
    params:set_action(i .. "lfo_min", function(value) lfo[i].min_val = value end)
    -- lfo speed
    params:add_control(i .. "lfo_freq", i .. " lfo freq", controlspec.new(0.001, 1.0, "lin", 0.001, math.random(100) * 0.001, ""))
    params:set_action(i .. "lfo_freq", function(value) lfo[i].freq = value end)
    -- lfo on/off
    params:add_option(i .. "lfo", i .. " lfo", {"off", "on"}, 1)
  end

  lfo_metro = metro.init()
  lfo_metro.time = .01
  lfo_metro.count = -1
  lfo_metro.event = function()
    for i = 1, 4 do
      lfo[i].prev = lfo[i].slope
      if params:get(i .. "lfo") == 1 then
        break
      elseif lfo[i].waveform == "sine" then
        make_sine(i)
      elseif lfo[i].waveform == "square" then
        make_square(i)
      end
      lfo[i].slope = math.max(-1.0, math.min(1.0, lfo[i].slope))
      lfo[i].counter = (lfo[i].counter + lfo[i].freq) % 360
    end
    lfo.process()
  end
  lfo_metro:start()

end


return lfo
