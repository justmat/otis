-- softcut setup for tlps
--

sc = {}

function sc.init()
	audio.level_cut(1.0)
	audio.level_adc_cut(1)
	--audio.level_eng_cut(1)

	for i = 1, 2 do
		softcut.enable(i, 1)
		softcut.level(i, 1)
		softcut.level_input_cut(i, i, 1)
		softcut.buffer(i, i)
		-- hard panned l/r
		softcut.pan(i, .5)

		softcut.rate(i, 3)
		softcut.play(i, 1)

		softcut.position(i, 0)
		softcut.fade_time(i, 0.1)

		softcut.loop(i, 1)
		softcut.loop_start(i, 0)
		softcut.loop_end(i, 2)

		softcut.rec(i, 1)
		softcut.rec_level(i, 1)
		softcut.pre_level(i, .75)

		softcut.rate_slew_time(i, 0)
		softcut.level_slew_time(1,0.25)

		softcut.filter_dry(1, 0.125)
		softcut.filter_fc(1, 1200)
		softcut.filter_lp(1, 0)
		softcut.filter_bp(1, 1.0)
		softcut.filter_rq(1, 2.0)
	end

	for i = 1, 2 do
	  -- tape speed controls
		params:add_control(i .. "speed", i .. " speed", controlspec.new(-5, 5, "lin", 0.01, 3, ""))
		params:set_action(i .. "speed", function(x) softcut.rate(i, x) end)
		-- tape speed slew controls
		params:add_control(i .. "speed_slew", i .. " speed slew", controlspec.new(0, 1, "lin", 0, 0, ""))
		params:set_action(i .. "speed_slew", function(x) softcut.rate_slew_time(i, x) end)
		-- tape length controls
		params:add_control(i .. "tape_len", i .. " tape length", controlspec.new(.5, 12, "lin", 0, 2, "secs"))
		params:set_action(i .. "tape_len", function(x) softcut.loop_end(i, x) end)
		-- feedback controls
		params:add_control(i .. "feedback", i .. " feedback", controlspec.new(0, 1, "lin", 0, .75, ""))
		params:set_action(i .. "feedback", function(x) softcut.pre_level(i, x) end)
		-- pan controls
		params:add_control(i .. "pan", i .. " pan", controlspec.new(0, 1, "lin", 0, .5, ""))
		params:set_action(i .. "pan", function(x) softcut.pan(i, x) end)
		
		params:add_separator()
	end
end


return sc
