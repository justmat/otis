-- softcut setup for otis
--
-- two loops
--
-- v1 @justmat

sc = {}

-- overwrite this in user script for custom paths
sc.file_path = "/home/we/dust/audio/tape/tlps."

function sc.write_buffers()
  -- saves L/R buffers as stereo files in /home/we/dust/audio/tape
  local id = string.match(os.clock(), "....$")
  for i = 1, 2 do
    local loop_start = params:get(i .. "loop_start")
    local loop_end = params:get(i .. "loop_end")
    local full_path = sc.file_path .. i .. "." .. id .. ".wav"
    softcut.buffer_write_stereo(full_path, loop_start, loop_end)
  end
end


function sc.stereo()
  -- set softcut to stereo inputs
  softcut.level_input_cut(1, 1, 1)
  softcut.level_input_cut(2, 1, 0)
  softcut.level_input_cut(1, 2, 0)
  softcut.level_input_cut(2, 2, 1)
end


function sc.mono()
  --set softcut to mono input
  softcut.level_input_cut(1, 1, 1)
  softcut.level_input_cut(2, 1, 0)
  softcut.level_input_cut(1, 2, 1)
  softcut.level_input_cut(2, 2, 0)
end


function sc.set_input(n)
  if n == 1 then
    sc.stereo()
  else
    sc.mono()
  end
end

local fb_hold1 = .75
local fb_hold2 = .75

function sc.rec_control(id, state)
  if id == 1 then
    if state == 1 then
      softcut.rec_level(1, 1)
      params:set("1feedback", fb_hold1)
    else
      softcut.rec_level(1, 0)
      fb_hold1 = params:get("1feedback")
      params:set("1feedback", 1)
    end
  else 
    if state == 1 then
      softcut.rec_level(2, 1)
      params:set("2feedback", fb_hold2)
    else
      softcut.rec_level(2, 0)
      fb_hold2 = params:get("2feedback")
      params:set("2feedback", 1)
    end
  end
end


local function set_loop_start(i, v)
  v = util.clamp(v, 0, params:get(i .. "loop_end") - .01)
  params:set(i .. "loop_start", v)
  softcut.loop_start(i, v)
end


function sc.init()
  audio.level_cut(1.0)
  audio.level_adc_cut(1)
  audio.level_eng_cut(0)

  for i = 1, 2 do
    softcut.enable(i, 1)
    softcut.level(i, 1)
    softcut.buffer(i, i)

    softcut.rate(i, 3)
    softcut.play(i, 1)

    softcut.position(i, 1)
    softcut.fade_time(i, 0.25)

    softcut.loop(i, 1)
    softcut.loop_start(i, 0)
    softcut.loop_end(i, 60)

    softcut.rec(i, 1)
    softcut.rec_level(i, 1)
    softcut.pre_level(i, .75)

    softcut.rate_slew_time(i, 0)
    softcut.level_slew_time(1, 0.25)

    softcut.pre_filter_dry(i, 1)
    softcut.pre_filter_fc(i, 1200)
    softcut.pre_filter_fc_mod(i, 1)
    softcut.pre_filter_lp(i, 0)
    softcut.pre_filter_rq(i, 5)
    softcut.pre_filter_hp(i, 0)
    softcut.pre_filter_bp(i, 0)
    softcut.pre_filter_br(i, 0)
    
    softcut.post_filter_dry(i, 1)
    softcut.post_filter_fc(i, 1200)
    softcut.post_filter_lp(i, 0)
    softcut.post_filter_rq(i, 5)
    softcut.post_filter_hp(i, 0)
    softcut.post_filter_bp(i, 0)
    softcut.post_filter_br(i, 0)

  end
  params:add_separator("input settings")
  -- input
  params:add_option("input", "input", {"stereo", "mono (L)"}, 1)
  params:set_action("input", function(x) sc.set_input(x) end)
  -- input level
  params:add_control("sc_input_level", "sc input level", controlspec.new(0, 1, "lin", 0, 1))
  params:set_action("sc_input_level", function(x) audio.level_adc_cut(x) end)

  params:add_separator("save buffers")

  -- save buffer to disk
  params:add_trigger("write_to_tape", "write to tape")
  params:set_action("write_to_tape", function() sc.write_buffers() end)

  params:add_separator("loops")

  for i = 1, 2 do
    params:add_group("loop" .. i, 14)
    -- l/r volume controls
    params:add_control(i .. "vol", i .. " vol", controlspec.new(0, 1, "lin", 0, 1, ""))
    params:set_action(i .. "vol", function(x) softcut.level(i, x) end)
    -- tape speed controls
    params:add_control(i .. "speed", i .. " speed", controlspec.new(-4, 4, "lin", 0.01, 1, ""))
    params:set_action(i .. "speed", function(x) softcut.rate(i, x) end)
    -- tape speed slew controls
    params:add_control(i .. "speed_slew", i .. " speed slew", controlspec.new(0, 1, "lin", 0, 0.1, ""))
    params:set_action(i .. "speed_slew", function(x) softcut.rate_slew_time(i, x) end)
    -- tape start controls
    params:add_control(i .. "loop_start", i .. " loop start", controlspec.new(0.0, 59.99, "lin", .01, 0, "secs"))
    params:set_action(i .. "loop_start", function(x) set_loop_start(i, x) end)
    -- tape length controls
    params:add_control(i .. "loop_end", i .. " loop end", controlspec.new(.25, 60, "lin", .01, 2, "secs"))
    params:set_action(i .. "loop_end", function(x) softcut.loop_end(i, x) end)
    -- feedback controls
    params:add_control(i .. "feedback", i .. " feedback", controlspec.new(0, 1, "lin", 0, .75, ""))
    params:set_action(i .. "feedback", function(x) softcut.pre_level(i, x) end)
     -- l/r rec state
    params:add_number(i .. "rec", i .. " rec", 0, 1, 1)
    params:set_action(i .. "rec", function(v) sc.rec_control(i, v) end)
    -- pan controls
    params:add_control(i .. "pan", i .. " pan", controlspec.new(-1.0, 1.0, "lin", 0.01, i == 1 and -.5 or .5, ""))
    params:set_action(i .. "pan", function(x) softcut.pan(i, x) end)
    -- pan slew controls
    params:add_control(i .. "pan_slew", i.. " pan slew", controlspec.new(0, 1, "lin", 0.01, 0.1, ""))
    params:set_action(i .. "pan_slew", function(x) softcut.pan_slew_time(i, x) end)
  end
end

return sc
