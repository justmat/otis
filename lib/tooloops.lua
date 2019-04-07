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
		-- hard panned l/r
		softcut.pan(i, i == 1 and 0 or 1)

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
		params:add_control(i .. "speed", i .. " speed", controlspec.new(-5, 5, "lin", 0, 3), "")
		params:set_action(i .. "speed", function(x) softcut.rate(i, x) end)
	end
end

return sc
