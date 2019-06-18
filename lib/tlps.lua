-- softcut setup for otis
--
-- two loops
--
-- v0.2 @justmat

sc = {}


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
    softcut.loop_end(i, 16)

    softcut.rec(i, 1)
    softcut.rec_offset(i, -0.06)
    softcut.rec_level(i, 1)
    softcut.pre_level(i, .75)

    softcut.rate_slew_time(i, 0)
    softcut.level_slew_time(1,0.25)

    softcut.filter_dry(i, 1)
    softcut.filter_fc(i, 1200)
    softcut.filter_fc_mod(i, 1)
    softcut.filter_lp(i, 1)
    softcut.filter_rq(i, 5)
    softcut.filter_hp(i, 0)
    softcut.filter_bp(i, 0)
    softcut.filter_br(i, 0)

  end

  -- input
  params:add_option("input", "input", {"stereo", "mono (L)"}, 1)
  params:set_action("input", function(x) sc.set_input(x) end)
  -- input level
  params:add_control("input_level", "input level", controlspec.new(0, 1, "lin", 0, .75))
  params:set_action("input_level", function(x) audio.level_adc_cut(x) end)
  -- engine level
  params:add_control("engine_level", "engine level", controlspec.new(0, 1, "lin", 0, 0))
  params:set_action("engine_level", function(x) audio.level_eng_cut(x) end)

  params:add_separator()

  for i = 1, 2 do
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
    params:add_control(i .. "tape_start", i .. " tape start", controlspec.new(0.0, 15.9, "lin", .01, 0, "secs"))
    params:set_action(i .. "tape_start", function(x) softcut.loop_start(i, x) end)
    -- tape length controls
    params:add_control(i .. "tape_len", i .. " tape length", controlspec.new(.25, 16, "lin", .01, 2, "secs"))
    params:set_action(i .. "tape_len", function(x) softcut.loop_end(i, x) end)
    -- feedback controls
    params:add_control(i .. "feedback", i .. " feedback", controlspec.new(0, 1, "lin", 0, .75, ""))
    params:set_action(i .. "feedback", function(x) softcut.pre_level(i, x) end)
    -- pan controls
    params:add_control(i .. "pan", i .. " pan", controlspec.new(0.0, 1.0, "lin", 0.01, i == 1 and .7 or .3, ""))
    params:set_action(i .. "pan", function(x) softcut.pan(i, x) end)

    params:add_separator()
  end
end


return sc
