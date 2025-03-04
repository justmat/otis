--
--          otis
--      stereo tape     _
--        delay/         | \
--          looper        | |
--                         | |
--    |\                   | |
--   /, ~\              / /
--  X     `-.........-------./ /
--   ~-. ~  ~              |
--      \             /   |
--       \  /_     ___\ /
--       | /\ ~~~~~   \ |
--       | | \           || |
--       | |\ \         || )
--      (_/ (_/       ((_/
--
--
--
-- there are three pages of
-- controls, mix, play, and edit.
--
-- navigate with enc 1.
-- ALT is key 1.
--
-- mix ----------
--
-- key2 = mute L
-- key3 = mute R
--
-- enc2 = vol L
-- enc3 = vol R
-- ALT + enc2 = pan L
-- ALT + enc3 = pan R
--
-- play ----------
--
-- key2 = flip L
-- key3 = flip R
-- ALT + key2 = skip L
-- ALT + key3 = skip R
--
-- enc2 = tape speed L
-- enc3 = tape speed R
-- ALT + enc2 = feedback L
-- ALT + enc3 = feedback R
--
-- edit ----------
--
-- key2 = rec on/off L
-- key3 = rec on/off R
-- ALT + key2 = clear buffer L
-- ALT + key3 = clear buffer R
--
-- enc2 = tape length L
-- enc3 = tape length R
-- ALT + enc2 = skip config
-- ALT + enc3 = speed config
--
-- ----------
--
-- v2.3 by @justmat
--
-- https://llllllll.co/t/22149


engine.name = "Decimator"

local g = grid.connect()
local g_alt = false

local sc = include("lib/tlps")
sc.file_path = "/home/we/dust/audio/tape/otis."

local m = midi.connect()

local alt = 0
local page = 2
local page_time = 1
local skip_time_L = 1
local skip_time_R = 1
local muted_L = false
local pre_mute_vol_L = 0
local muted_R = false
local pre_mute_vol_R = 0
local rec1 = true
local rec2 = true
local flipped_L = false
local flipped_R = false
local skipped_L = false
local skipped_R = false
local fine_adjust = false

local pages = {"mix", "play", "edit"}
local skip_options = {"start", "???", "coco"}
local skip_pos = {nil, nil}
local spds = include("lib/spds")
local speed_index = {4, 4} -- maybe move this to spds.lua?

local buf_snapshots = {{}, {}}
local buf_positions = {0, 0}
local buf_snapshots_max = {0, 0}

-- flip, skip, and speed controls
local function skip(n)
  -- reset loop to start, or jump to a random position
  local switch = params:get("skip_controls")
  if switch == 1 then
    softcut.position(n, params:get(n .. "loop_start"))
  elseif switch == 2 then
    local length = params:get(n .. "loop_end")
    softcut.position(n, lfo.scale(math.random(), params:get(n .. "loop_start"), 1.0, 0.25, length))
  elseif switch == 3 then
    if skip_pos[n] == nil then
      skip_pos[n] = positions[n]
    else
      softcut.position(n, skip_pos[n])
    end
    --print(n == 1 and "L" .. " " .. "skip position " .. skip_pos[n] or "R" .. " " .. "skip position " .. skip_pos[n])
  end
  -- for screen drawing
  if n == 1 then skip_time_L = util.time() end
  if n == 2 then skip_time_R = util.time() end
end


local function flip(n)
  -- flip tape direction
  local spd = params:get(n .. "speed")
  spd = -spd
  params:set(n .. "speed", spd)
  if n == 1 then
    flipped_L = not flipped_L
  else
    flipped_R = not flipped_R
  end
end


local function check_flip_set_speed(i, val)
  if i == 1 and flipped_L then
    params:set("1speed", -val)
  elseif i == 2 and flipped_R then
    params:set("2speed", -val)
  else
    params:set(i .. "speed", val)
  end
end


local function speed_control(n, d)
  -- free speed controls
  if params:get("speed_controls") == 1 then
    params:delta(n .. "speed", d)
  -- quantized speed controls
  else
    local speed_set = spds.names[params:get("speed_controls")]

    if d < 0 then
      speed_index[n] = util.clamp(speed_index[n] - 1, 1, #spds[speed_set])
    else
      speed_index[n] = util.clamp(speed_index[n] + 1, 1, #spds[speed_set])
    end
    params:set(n .. "speed", spds[speed_set][speed_index[n]])
  end
end


local function check_for_speed_modulation()
  local l,r,lfo = false,false, {0, 0}
  for i = 1, 4 do
    if params:get(i .. "lfo_target") == 10 then
      l = true
      lfo[1] = i
    elseif params:get(i .. "lfo_target") == 11 then
      r = true
      lfo[2] = i
    end
  end
  return l,r,lfo
end


-- for lib/hnds
lfo = include("lib/hnds")

local lfo_types = {"sine", "square", "s+h", "l env follower", "r env follower"}
local show_lfo_info = {false, false, false, false}
local lfo_index = nil


local lfo_targets = {
  "none",
  "sample_rate",
  "bit_depth",
  "1pan",
  "2pan",
  "1vol",
  "2vol",
  "1feedback",
  "2feedback",
  "1speed",
  "2speed",
  "rec L",
  "rec R",
  "flip L",
  "flip R",
  "skip L",
  "skip R",
  "saturation",
  "crossover",
  "tone",
  "hiss",
}


function lfo.process()
  for i = 1, 4 do
    local target = params:get(i .. "lfo_target")

    if params:get(i .. "lfo") == 2 then
      -- sample rate
      if target == 2 then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1, 1, 0.0, 48000.0))
      -- bit depth
      elseif target == 3 then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1, 1, 4.0, 32.0))
      -- left/right panning, volume, feedback
      elseif target > 3 and target <= 9 then
        params:set(lfo_targets[target], util.clamp(lfo[i].slope, -1, 1))
      -- speed
      elseif target == 10 then
        -- free speed/no speed control
        if params:get("speed_controls") == 1 then
          check_flip_set_speed(1, lfo[i].slope)
        -- quantized speed
        elseif params:get("speed_controls") > 1 then
          local speed_set = spds.names[params:get("speed_controls")]
          speed_index[1] = util.round(util.linlin(-1.0,1.0,1,#spds[speed_set], lfo[i].slope))
          check_flip_set_speed(1, spds[speed_set][speed_index[1]])
        end
      elseif target == 11 then
        -- free speed/no speed control
        if params:get("speed_controls") == 1 then
          check_flip_set_speed(2, lfo[i].slope)
        -- quantized speed
        elseif params:get("speed_controls") > 1 then
          local speed_set = spds.names[params:get("speed_controls")]
          speed_index[2] = util.round(util.linlin(-1.0,1.0,1,#spds[speed_set], lfo[i].slope))
          check_flip_set_speed(2, spds[speed_set][speed_index[2]])
        end
      -- record L on/off
      elseif target == 12 then
        if lfo[i].trig and lfo[i].slope > 0 then
          rec1 = not rec1
          params:set("1rec", rec1 == true and 1 or 0)
        end
      -- record R on/off
      elseif target == 13 then
        if lfo[i].trig and lfo[i].slope > 0 then
          rec2 = not rec2
          params:set("2rec", rec2 == true and 1 or 0)
        end
      -- flip L
      elseif target == 14 then
        if lfo[i].trig then
          flip(1)
        end
      -- flip R
      elseif target == 15 then
        if lfo[i].trig then
          flip(2)
        end
      -- skip L
      elseif target == 16 then
        if lfo[i].trig and lfo[i].slope > 0 then
          skipped_L = not skipped_L
          skip(1)
        end
      -- skip R
      elseif target == 17 then
        if lfo[i].trig and lfo[i].slope > 0 then
          skipped_R = not skipped_R
          skip(2)
        end
      elseif target == 18 then --saturation
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1, 1, 0.0, 400.0))
      elseif target == 19 then --crossover
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1, 1, 50, 10000.0))
      elseif target == 20 then --tone
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1, 1, 0.01, 1))
      elseif target == 21 then --noise
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1, 1, 0, 5))
      end
    end
  end
end


-- for softcut phase/position polls
positions = { -1, -1}

local function update_positions(i, pos)
  positions[i] = pos
end

-- norns controls --
-- encoders --
local function mix_enc(n, d)
  if alt == 1 then
      if n == 2 then
        params:delta("1pan", d)
      elseif n == 3 then
        params:delta("2pan", d)
      end
  else
    if n == 2 then
      if not muted_L then
        params:delta("1vol", d)
      end
    elseif n == 3 then
      if not muted_R then
        params:delta("2vol", d)
      end
    end
  end
end


local function play_enc(n, d)
  if alt == 1 then
    if n == 2 then
      params:delta("1feedback", d)
    elseif n == 3 then
      params:delta("2feedback", d)
    end
  else
    local l,r,lfo = check_for_speed_modulation()
    if n == 2 then
      if l then
        params:delta(lfo[1] .. "offset", d)
      else
        speed_control(n - 1, d)
      end
    elseif n == 3 then
      if r then
        params:delta(lfo[2] .. "offset", d)
      else
        speed_control(n - 1, d)
      end
    end
  end
end


local function edit_enc(n, d)
  if alt == 1 then
    if n == 2 then
      params:delta("1loop_end", d)
    elseif n == 3 then
      params:delta("2loop_end", d)
    end
  else
    if n == 2 then
      params:delta("1loop_start", d)
    elseif n == 3 then
      params:delta("2loop_start", d)
    end
  end
end


function enc(n, d)
  -- holding the lfo on/patch grid button will hijack the encoders
  -- if an lfo on/patch button is held store the lfo index in id
  -- otherwise id will be nil
  local id = nil
  for i = 1, 4 do
    if show_lfo_info[i] then
      id = i
    end
  end
  -- enc 1 navigation
  if n == 1 and not id then
    if alt == 1 then
      fine_adjust = d > 0 and true or false
    else
      page = util.clamp(page + d, 1, 3)
      page_time = util.time()
    end
  end

  if id then
    if n == 1 then
      params:delta(id .. "lfo_freq", d / 10)
    elseif n == 2 then
      params:delta(id .. "lfo_depth", d)
    elseif n == 3 then
      params:delta(id .. "offset", d)
    end
  elseif g_alt then
    -- hold grid alt to use enc 2 and 3 to slide your loops around
    if n == 2 then
      params:delta("1loop_start", d / 12)
      params:delta("1loop_end", d / 12)
    elseif n == 3 then
      params:delta("2loop_start", d / 12)
      params:delta("2loop_end", d / 12)
    end
  elseif page == 1 then
    mix_enc(n, fine_adjust == true and d * 0.01 or d)
  elseif page == 2 then
    play_enc(n, fine_adjust == true and d * 0.01 or d)
  elseif page == 3 then
    edit_enc(n, fine_adjust == true and d * 0.01 or d)
  end
end

-- keys --
local function mix_key(n, z)
  if n == 2 and z == 1 then
    if not muted_L then
      pre_mute_vol_L = params:get("1vol")
      softcut.level(1, 0)
      muted_L = true
    else
      softcut.level(1, pre_mute_vol_L)
      muted_L = false
    end
  elseif n == 3 and z == 1 then
    if not muted_R then
      pre_mute_vol_R = params:get("2vol")
      softcut.level(2, 0)
      muted_R = true
    else
      softcut.level(2, pre_mute_vol_R)
      muted_R = false
    end
  end
end


local function play_key(n, z)
  if alt == 1 then
    if n == 2 and z == 1 then
      skip(1)
    elseif n == 3 and z ==1 then
      skip(2)
    end
  else
    if n == 2 and z == 1 then
      flip(1)
    elseif n == 3 and z == 1 then
      flip(2)
    end
  end
end


local function edit_key(n, z)
  if alt == 1 then
    if n == 2 and z == 1 then
      softcut.buffer_clear_channel(1)
    elseif n == 3 and z == 1 then
      softcut.buffer_clear_channel(2)
    end
  else
    if n == 2 and z == 1 then
      rec1 = not rec1
      params:set("1rec", rec1 == true and 1 or 0)
    elseif n == 3 and z == 1 then
      rec2 = not rec2
      params:set("2rec", rec2 == true and 1 or 0)
    end
  end
end


function key(n, z)
  -- norns key 1 serves as an alt button
  if n == 1 then alt = z end
  -- holding the lfo on/patch grid button will hijack the norns keys
  -- if an lfo on/patch button is held store the lfo index in id
  -- otherwise id will be nil
  local id = nil
  for i = 1, 4 do
    if show_lfo_info[i] then
      id = i
    end
  end
  
  if id then
    if n == 2 and z == 1 then
      params:set(lfo_index .. "lfo_shape", params:get(lfo_index .. "lfo_shape") - 1)
    elseif n == 3 and z == 1 then
      params:set(lfo_index .. "lfo_shape", params:get(lfo_index .. "lfo_shape") + 1)
    end
  -- mix
  elseif page == 1 then
    mix_key(n, z)
  -- play
  elseif page == 2 then
    play_key(n, z)
  elseif page == 3 then
  -- edit
    edit_key(n, z)
  end
end

-- midi controls --
local function midi_control(data)
  local msg = midi.to_msg(data)
  if msg.type == "note_on" then
    if msg.note == 1 then
      softcut.buffer_clear_channel(1)
    elseif msg.note == 2 then
      softcut.buffer_clear_channel(2)
    elseif msg.note == 36 then
      edit_key(2, 1) -- rec L
    elseif msg.note == 37 then
      edit_key(3, 1) -- rec R
    elseif msg.note == 48 then
      play_key(2, 1) -- flip L
    elseif msg.note == 49 then
      play_key(3, 1) -- flip R
    elseif msg.note == 50 then
      skip(1)
      skip_time_L = util.time()
    elseif msg.note == 51 then
      skip(2)
      skip_time_R = util.time()
    end
  elseif msg.type == "note_off" then
  elseif msg.type == "cc" then
    if msg.cc == 112 then
      params:set("1feedback", util.linlin(0, 127, 0.00, 1.00, msg.val))
      params:set("2feedback", util.linlin(0, 127, 0.00, 1.00, msg.val))

    end
  end
end


function init()

  -- set the midi event function
  m.event = midi_control
  -- engine parameters
  params:add_separator("engine")
  -- sample rate
  params:add_control("sample_rate", "sample rate", controlspec.new(0, 48000, "lin", 10, 48000, ''))
  params:set_action("sample_rate", function(x) engine.srate(x) end)
  -- bit depth
  params:add_control("bit_depth", "bit depth", controlspec.new(4, 31, "lin", 0, 31, ''))
  params:set_action("bit_depth", function(x) engine.sdepth(x) end)
  -- tape sat
  params:add_control("saturation", "saturation", controlspec.new(0.1, 400, "exp", 1, 5, ''))
  params:set_action("saturation", function(x) engine.distAmount(x) end)
  -- crossover filter
  params:add_control("crossover", "crossover", controlspec.new(50, 10000, "exp", 10, 2000, ''))
  params:set_action("crossover", function(x) engine.crossover(x) end)
  -- bias
  params:add_control("tone", "tone", controlspec.new(0.001, 1, "lin", 0.001, 0.004, ''))
  params:set_action("tone", function(x) engine.highbias(x) end)
  -- tape hiss
  params:add_control("hiss", "hiss", controlspec.new(0, 10, "lin", 0.01, 0.001, ''))
  params:set_action("hiss", function(x) engine.hissAmount(x) end)

  params:add_separator("config")

  params:add_option("skip_controls", "skip controls", skip_options, 1)
  params:add_option("speed_controls", "speed controls", spds.names, 1)

  params:add{
    type = "option", id = "audio_routing", name = "audio routing", 
    options = {"in+cut->eng", "in->eng", "cut->eng"},
    -- min = 1, max = 3, 
    default = 1,
    action = function(value) 
      rerouting_audio = true
      clock.run(route_audio)
    end
    }

  -- setup softcut and start the phase polls
  sc.init()
  for i = 1, 2 do
    softcut.phase_quant(i, .005)
    softcut.event_phase(update_positions)
    softcut.poll_start_phase()
  end

  -- for lib/hnds
  for i = 1, 4 do
    lfo[i].lfo_targets = lfo_targets
  end
  lfo.init()

  params:bang()
  softcut.buffer_clear()
  -- timers for screen and grid redraws
  local screen_metro = metro.init()
  screen_metro.time = 1/30
  screen_metro.event = function() redraw() end
  screen_metro:start()

  local grid_metro = metro.init()
  grid_metro.time = 1/15
  grid_metro.event = function() grid_redraw() end
  grid_metro:start()


  -- timer to query buffer snapshot and play position
  local buf_snapshot_size = 128
  local buf_snapshot_metro = metro.init()
  buf_snapshot_metro.time = 1/15
  softcut.event_render(function (ch, start, secpersample, samples)
    buf_snapshots[ch] = samples
    buf_snapshots_max[ch] = table_getmax(samples)
  end)
  softcut.event_position(function (ch, position)
    buf_positions[ch] = position
  end)
  buf_snapshot_metro.event = function()
    softcut.render_buffer(1, 0, params:get("1loop_end"), buf_snapshot_size)
    softcut.render_buffer(2, 0, params:get("2loop_end"), buf_snapshot_size)
    softcut.query_position(1)
    softcut.query_position(2)
  end
  buf_snapshot_metro:start()

 audio.level_eng_cut(0)
end


function table_getmax(t)
  local max = 0
  for _,v in pairs(t) do
    if math.abs(v) > max then
      max = math.abs(v)
    end
  end
  return util.clamp(max, 0.01, 1)
end

-- screen drawing
local function draw_left()
  -- tape direction indicator
  screen.line_rel(0, -7)
  screen.line_rel(-3, 3)
  screen.line_rel(3, 3)
  screen.fill()
end


local function draw_right()
  -- tape direction indicator
  screen.line_rel(0, -7)
  screen.line_rel(3, 3)
  screen.line_rel(-3, 3)
  screen.fill()
end


local function draw_skip()
  -- skip indicator
  screen.line_rel(0, -5)
  screen.line_rel(-11, 0)
  screen.line_rel(0, 5)
  screen.line_rel(5, 0)
  screen.line_rel(-2, -2)
  screen.line_rel(0, 4)
  screen.line_rel(2, -2)
  screen.stroke()
end


local function draw_skip_rand()
  screen.text("???")
end


local function draw_skip_coco()
  screen.text("coco")
end


local function draw_page_mix()
  -- screen drawing for the mix page
  screen.level(alt == 1 and 3 or 15)
  screen.move(64, 15)
  screen.text_center("volume L : " .. string.format("%.2f", params:get("1vol")))
  screen.move(64, 23)
  screen.text_center("volume R : " .. string.format("%.2f", params:get("2vol")))
  screen.level(alt == 1 and 15 or 3)
  screen.move(64, 31)
  screen.text_center("pan L : " .. string.format("%.2f", params:get("1pan")))
  screen.move(64, 39)
  screen.text_center("pan R : " .. string.format("%.2f", params:get("2pan")))

  screen.level(muted_L == false and 3 or 15)
  screen.move(5, 52)
  screen.text("mute L")
  screen.level(muted_R == false and 3 or 15)
  screen.move(122, 52)
  screen.text_right("mute R")
end


local function draw_page_play()
  -- screen drawing for the play page
  local l,r,lfo = check_for_speed_modulation()
  screen.level(alt == 1 and 3 or 15)
  screen.move(64, 15)
  if l then
    screen.text_center("spd:" .. string.format("%.2f", math.abs(params:get("1speed"))) .. " " .. "offset:" .. params:get(lfo[1] .. "offset"))
  else
   screen.text_center("speed L : " .. string.format("%.2f", math.abs(params:get("1speed"))))
  end
  screen.move(64, 23)
  if r then
    screen.text_center("spd:" .. string.format("%.2f", math.abs(params:get("2speed"))) .. " " .. "offset:" .. params:get(lfo[2] .. "offset"))
  else
    screen.text_center("speed R : " .. string.format("%.2f", math.abs(params:get("2speed"))))
  end
  screen.level(alt == 1 and 15 or 3)
  screen.move(64, 31)
  screen.text_center("feedback L : " .. string.format("%.2f", params:get("1feedback")))
  screen.move(64, 39)
  screen.text_center("feedback R : " .. string.format("%.2f", params:get("2feedback")))

  screen.move(22, 16)
  screen.level(params:get("1speed") < 0 and 15 or 0)
  draw_left()
  screen.move(22, 24)
  screen.level(params:get("2speed") < 0 and 15 or 0)
  draw_left()
  screen.move(108, 16)
  screen.level(params:get("1speed") > 0 and 15 or 0)
  draw_right()
  screen.move(108, 24)
  screen.level(params:get("2speed") > 0 and 15 or 0)
  draw_right()

  screen.level(alt == 1 and 3 or 15)
  screen.move(5, 52)
  screen.text("flip")
  screen.move(122, 52)
  screen.text_right("flip")
  screen.level(alt == 1 and 15 or 3)
  screen.move(5, 60)
  screen.text("skip")
  screen.move(122, 60)
  screen.text_right("skip")

  if util.time() - skip_time_L < .15 then
    local switch = params:get("skip_controls")
    if switch == 1 then
      screen.move(18, 40)
      draw_skip()
    elseif switch == 2 then
      screen.move(7, 40)
      draw_skip_rand()
    elseif switch == 3 then
      screen.move(6, 40)
      draw_skip_coco()
    end
  end

  if util.time() - skip_time_R < .15 then
    local switch = params:get("skip_controls")
    if switch == 1 then
      screen.move(120, 40)
      draw_skip()
    elseif switch == 2 then
      screen.move(109, 40)
      draw_skip_rand()
    elseif switch == 3 then
      screen.move(108, 40)
      draw_skip_coco()
    end
  end
end


local function draw_page_edit()
  -- screen drawing for edit page
  screen.level(alt == 1 and 3 or 15)
  screen.move(64, 15)
  screen.text_center("loop start L : " .. string.format("%.2f", params:get("1loop_start")))
  screen.move(64, 23)
  screen.text_center("loop start R : " .. string.format("%.2f", params:get("2loop_start")))
  screen.level(alt == 1 and 15 or 3)
  screen.move(64, 31)
  screen.text_center("loop end L : " .. string.format("%.2f", params:get("1loop_end")))
  screen.move(64, 39)
  screen.text_center("loop end R : " .. string.format("%.2f", params:get("2loop_end")))

  screen.level(alt == 1 and 3 or 15)
  screen.move(5, 52)
  screen.text(params:get("1rec") == 1 and "rec : on" or "rec : off")
  screen.move(122, 52)
  screen.text_right(params:get("2rec") == 1 and "rec : on" or "rec : off")
  screen.level(alt == 1 and 15 or 3)
  screen.move(5, 60)
  screen.text("clear")
  screen.move(122, 60)
  screen.text_right("clear")
end


local function draw_lfo_info()
  screen.clear()
  screen.move(64, 5)
  screen.level(3)
  screen.text_center("lfo " .. lfo_index)
  screen.level(15)

  screen.move(5, 23)
  screen.text("target: " .. lfo_targets[params:get(lfo_index .. "lfo_target")])
  screen.move(75, 23)
  screen.text("shape: " .. lfo_types[params:get(lfo_index .. "lfo_shape")])
  screen.move(5, 33)
  screen.text("1. speed: " .. params:get(lfo_index .. "lfo_freq"))
  screen.move(75, 33)
  screen.text("2. depth: " .. params:get(lfo_index .. "lfo_depth"))
  screen.move(5, 43)
  screen.text("3. offset: " .. params:get(lfo_index .. "offset"))
end

function draw_single_page()
  screen.clear()
  screen.aa(0)
  screen.font_face(25)
  screen.font_size(6)

  draw_buffer(1, 28, 12)
  draw_buffer(2, 28, 45)

  draw_vbar(0, 20, params:get("1vol"), muted_L, (page == 1 and alt == 0))
  draw_vbar(0, 56, params:get("2vol"), muted_R, (page == 1 and alt == 0))

  draw_vbar(20, 20, params:get("1feedback"), false, (page == 2 and alt == 1))
  draw_vbar(20, 56, params:get("2feedback"), false, (page == 2 and alt == 1))

  draw_pan(12, 8, params:get("1pan"))
  draw_pan(12, 45, params:get("2pan"))

  draw_button(11, 17, rec1 and "REC" or "")
  draw_button(11, 54, rec2 and "REC" or "")

  draw_page_status()

  screen.update()
end

function draw_page_status()
  screen.level(10)
  local bt = "mute"
  local knobs = "level"
  if page == 1 then
    if alt == 1 then
      knobs = "pan"
    end
  elseif page == 2 then
    if alt == 0 then
      bt = "flip"
      knobs = "speed"
    else
      bt = "skip"
      knobs = "fdbk"
    end
  elseif page == 3 then
    if alt == 0 then
      bt = "rec"
      knobs = "start"
    else
      bt = "clear"
      knobs = "end"
    end
  end
  local txt = pages[page] .. ": " .. bt .. "/" .. knobs .. (fine_adjust and "(f)" or "(c)")
  if page == 1 then
    screen.move(0, 63)
    screen.text(txt)
  elseif page == 2 then
    screen.move(63, 63)
    screen.text_center(txt)
  elseif page == 3 then
    screen.move(127, 63)
    screen.text_right(txt)
  end
end


function draw_button(x, y, char)
  screen.level(10)
  screen.move(x, y)
  screen.text_center(char)
end

function draw_pan(x, y, val)
  -- draw "LR" for panning, crossfading the level to indicate position
  -- center if full level
  if math.abs(val) < 0.05 then
    screen.level(10)
    screen.move(x-1, y)
    screen.text_center("C")
    return
  end
  screen.level(util.linlin(-1, 1, 15, 0, val)//1)
  screen.move(x-1, y)
  screen.text_right("L")
  screen.level(util.linlin(-1, 1, 0, 15, val)//1)
  screen.move(x, y)
  screen.text("R")
end

function draw_vbar(x, y, val, off, active)
  local width = 2
  local max_height = 18
  local height = util.linlin(0, 1, 0, max_height, val)

  screen.level(3)
  screen.move(x, y-max_height+1)
  screen.line_rel(width, 0)
  screen.stroke()
  if off then
    screen.level(1)
  else
    screen.level(active and 15 or 4)
  end
  screen.rect(x, y-height, width, height)
  screen.fill()
end

function draw_buffer(n, x_off, y_off)
  screen.level(6)

  local max_height = 6
  local y_top = y_off - max_height
  local buf_width = 128 - x_off

  local buf = buf_snapshots[n]
  if #buf == 0 then return end -- not initialized
  local max = buf_snapshots_max[n]
  max = 1

  local x_pos = 0
  for i, s in ipairs(buf) do
    local height = util.round(math.abs(s) / max * max_height)
    screen.move(util.linlin(0, #buf-1, x_off, x_off+buf_width, x_pos), y_off - height)
    screen.line_rel(0, 2 * height)
    screen.stroke()
    x_pos = x_pos + 1
  end

  screen.level(3)
  screen.move(util.linlin(0, params:get(n .. "loop_end"), x_off, x_off+buf_width, buf_positions[n]), y_off - max_height)
  screen.line_rel(0, 2 * max_height)
  screen.stroke()

  -- edit: start
  local l_start = x_off + params:get(n .. "loop_start") / params:get(n .. "loop_end") * buf_width
  screen.level((page == 3 and alt == 0) and 15 or 3)
  screen.move(l_start+1, y_off - max_height)
  screen.line_rel(0, 2 * max_height)
  screen.stroke()

  l_start = util.clamp(l_start, x_off+8, x_off+buf_width - 32)
  screen.move(l_start, y_off + 2*max_height)
  screen.text_center(string.format("%.2f", params:get(n .. "loop_start")))

  -- edit: end
  screen.level((page == 3 and alt == 1) and 15 or 3)
  screen.move(x_off+buf_width, y_off - max_height)
  screen.line_rel(0, 2 * max_height)
  screen.stroke()
  screen.move(x_off+buf_width, y_off + 2*max_height)
  screen.text_right(string.format("%.2f", params:get(n .. "loop_end")))

  -- play: speed
  screen.level((page == 2 and alt == 0) and 15 or 5)
  local center = x_off + buf_width//2
  screen.move(center, y_top)
  local speed = params:get(n .. "speed")
  screen.text_center(string.format("%.2f", speed))

  screen.move(center, y_top+1)
  screen.line_rel(util.linlin(-4.0, 4.0, -45, 45, speed), 0)
  screen.stroke()

  local l,r,lfo = check_for_speed_modulation()
  if (n == 1 and l) or (n == 2 and r) then
    -- draw offset as small tick
    local offset = params:get(n .. "offset")
    screen.level(10)
    screen.move(center + util.linlin(-4.0, 4.0, -45, 45, offset), y_top-1)
    screen.line_rel(0, 3)
    screen.stroke()
  end

end

function redraw()
  -- TODO
  draw_single_page()
  do return end

  screen.clear()
  screen.aa(0)
  screen.font_face(25)
  screen.font_size(6)
  screen.move(30 * page, 5)
  -- current page indication
  if util.time() - page_time < .6 then
    screen.level(15)
    screen.text(pages[page])
  else
    screen.level(1)
    screen.text(pages[page])
  end
  -- indicate fine/coarse adjustments
  screen.move(5, 5)
  screen.level(alt == 1 and 15 or 1)
  screen.text_right(fine_adjust == true and " f" or " c")
  
  -- holding the lfo on/patch grid button will hijack the screen
  -- if an lfo on/patch button is held store the lfo index in id
  -- otherwise id will be nil
  local show = nil
  for i= 1, 4 do
    if show_lfo_info[i] then
      show = i
    end
  end

  if show then
    draw_lfo_info()
  elseif page == 1 then
    draw_page_mix()
  elseif page == 2 then
    draw_page_play()
  elseif page == 3 then
    draw_page_edit()
  end
  screen.update()
end

-- grid stuff

function g.key(x, y, z)
  -- grid alt key
  if x == 1 and y == 8 then
    g_alt = z == 1 and true or false
  end

  -- grid lfo patching
  for i = 1, 4 do
    if show_lfo_info[i] then
      if x >= 1 and x <= 2 and y == 1 then
        params:set(i .. "lfo_target", 12)
      elseif x >= 1 and x <= 2 and y == 5 then
        params:set(i .. "lfo_target", 13)
      elseif x == 4 and y == 1 then
        params:set(i .. "lfo_target", 14)
      elseif x == 4 and y == 5 then
        params:set(i .. "lfo_target", 15)
      elseif x == 1 and y == 2 or x == 8 and y == 2 then
        params:set(i .. "lfo_target", 10)
      elseif x == 1 and y == 6 or x == 8 and y == 6 then
        params:set(i .. "lfo_target", 11)
      elseif x == 5 and y == 1 then
        params:set(i .. "lfo_target", 16)
      elseif x == 5 and y == 5 then
        params:set(i .. "lfo_target", 17)
      elseif x >= 10 and x <= 14 and y == 3 then
        params:set(i .. "lfo_target", 4)
      elseif x >= 10 and x <= 14 and y == 7 then
        params:set(i .. "lfo_target", 5)
      end
    end
  end

  if z == 1 then
    -- record L/R on/off toggles
    if x == 1 and y == 1 then
      rec1 = true
      params:set("1rec", rec1 == true and 1 or 0)
    elseif x == 2 and y == 1 then
      rec1 = false
      params:set("1rec", rec1 == true and 1 or 0)
    elseif x == 1 and y == 5 then
      rec2 = true
      params:set("2rec", rec2 == true and 1 or 0)
    elseif x == 2 and y == 5 then
      rec2 = false
      params:set("2rec", rec2 == true and 1 or 0)
    end
    -- flip/skip L/R
    if x == 4 and y == 1 then
      flip(1)
    elseif x == 4 and y == 5 then
      flip(2)
    end
  
    if x == 5 and y == 1 and z == 1 then
      skip(1)
      skip_time_L = util.time()
    elseif x == 5 and y == 5 and z == 1 then
      skip(2)
      skip_time_R = util.time()
    end
    -- speed controls
    -- holding grid alt and pressing a speed button will return speed to 1
    -- otherwise increase or decrease speed, respecting the speed mode settings
    if x == 1 and y == 2 then
      if g_alt then
        params:set("1speed", 1)
      --elseif math.abs(params:get("1speed")) > 0.25 then
      elseif params:get("speed_controls") == 1 then
        params:delta("1speed", -3 / 7.5)
      else
        speed_control(1, -1)
      end
    end
    
    if x > 1 and x < 8 and y == 2 then
      if g_alt then
      else
        if params:get("speed_controls") > 1 then
          local n = x - 1
          params:set("1speed", spds[spds.names[params:get("speed_controls")]][n])
          speed_index[1] = n
        end
      end
    end
    
    if x == 8 and y == 2 then
      if g_alt then
        params:set("1speed", 1)
      elseif params:get("speed_controls") == 1 then
        params:delta("1speed", 3 / 7.5)
      else
        speed_control(1, 1)
      end
    end

    if x == 1 and y == 6 then
      if g_alt then
        params:set("2speed", 1)
      elseif params:get("speed_controls") == 1 then
        params:delta("2speed", -3 / 7.5)
      else
        speed_control(2, -1)
      end
    end

    if x > 1 and x < 8 and y == 6 then
      if g_alt then
      else
        if params:get("speed_controls") > 1 then
          local n = x - 1
          params:set("2speed", spds[spds.names[params:get("speed_controls")]][n])
          speed_index[2] = n
        end
      end
    end

    if x == 8 and y == 6 then
      if g_alt then
        params:set("2speed", 1)
      elseif params:get("speed_controls") == 1 then
        params:delta("2speed", 3 / 7.5)
      else
        speed_control(2, 1)
      end
    end

    -- holding grid alt will surface the L/R buffer clear buttons
    if x == 8 and y == 1 then
      if g_alt then
        softcut.buffer_clear_channel(1)
      end
    end
      
    if x == 8 and y == 5 then
      if g_alt then
        softcut.buffer_clear_channel(2)
      end
    end
    -- jump to rough position
    if x >= 9 and x <= 16 and y == 1 then
      local s, e = params:get("1loop_start"), params:get("1loop_end") 
      local p = util.linlin(9, 16, s, e, x)
      softcut.position(1, p)
    elseif x >= 9 and x <= 16 and y == 5 then
      local s, e = params:get("2loop_start"), params:get("2loop_end") 
      local p = util.linlin(9, 16, s, e, x)
      softcut.position(2, p)
    end
    -- set pan position
    if x > 9 and x <= 14 then
      local pan = util.linlin(10, 14, -1, 1, x)
      if y == 3  then 
        params:set("1pan", pan)
      elseif y == 7 then
        params:set("2pan", pan)
      end
    end
    -- double/half loop length
    if x == 10 and y == 2 or x == 14 and y == 2 then
      local s, e = params:get("1loop_start"), params:get("1loop_end") 
      local l = e - s
      local nl = x == 10 and l / 2 or l * 2
      params:set("1loop_end", s + nl)
    elseif x == 10 and y == 6  or x == 14 and y == 6 then
      local s, e = params:get("2loop_start"), params:get("2loop_end") 
      local l = e - s
      local nl = x == 10 and l / 2 or l * 2
      params:set("2loop_end", s + nl)
    end
  end
  -- lfo on/off
  -- hold grid alt and press either a lfo on/patch or lfo off button
  -- to clear the lfo target
  if x >= 3 and x <= 6 and y == 7 then
    lfo_index = x - 2
    --current_lfo = lfo_index
    if g_alt then
      params:set(lfo_index .. "lfo_target", 1)
    else
      params:set(lfo_index .. "lfo", 2)
      show_lfo_info[lfo_index] = z == 1 and true or false
    end
  end

  if x >= 3 and x <= 6 and y == 8 and z == 1 then
    lfo_index = x - 2
    if g_alt then
      params:set(lfo_index .. "lfo", 0)
      params:set(lfo_index .. "lfo_target", 1)
    else
      params:set(lfo_index .. "lfo", 0)
    end
  end
end


function grid_redraw()

  g:all(0)

  if rec1 then
    g:led(1, 1, 15)
    g:led(2, 1, 4)
  else
    g:led(1, 1, 4)
    g:led(2, 1, 15)
  end

  g:led(4, 1, 15)
  g:led(5, 1, 15)

  g:led(1, 2, 15)
  g:led(8, 2, 15)
  
  if params:get("speed_controls") > 1 then
    for i = 1, 6 do
      g:led(i + 1, 2, 4)
    end
    g:led(speed_index[1] + 1, 2, 15)
  end
  

  if rec2 then
    g:led(1, 5, 15)
    g:led(2, 5, 4)
  else
    g:led(1, 5, 4)
    g:led(2, 5, 15)
  end

  g:led(4, 5, 15)
  g:led(5, 5, 15)

  g:led(1, 6, 15)
  g:led(8, 6, 15)

  if params:get("speed_controls") > 1 then
    for i = 1, 6 do
      g:led(i + 1, 6, 4)
    end
    g:led(speed_index[2] + 1, 6, 15)
  end

  g:led(1, 8, g_alt == true and 15 or 4)
  if g_alt then
    g:led(8, 1, 15)
    g:led(8, 5, 15)
  end
  -- lfo on/off/slope-feedback
  for i = 1, 4 do
    g:led(i + 2, 7, params:get(i .. "lfo") == 2 and math.floor(util.linlin( -1, 1, 0, 15, lfo[i].slope)) or 4)
    g:led(i + 2, 8, params:get(i .. "lfo") == 2 and 4 or 15)
  end
  -- rough buffer position
  for i = 1, 2 do
    local loop_in, loop_out = params:get(i .. "loop_start"), params:get(i .. "loop_end")
    for j = 9, 16 do
      g:led(j, i == 1 and 1 or 5, 4)
    end
    g:led(math.floor(util.linlin(loop_in, loop_out, 9, 17, positions[i])), i == 1 and 1 or 5, 15)
  end
  -- loop length modifiers
  g:led(10, 2, 15)
  g:led(14, 2, 15)
  g:led(10, 6, 15)
  g:led(14, 6, 15)
  -- pan position
  for i = 1, 2 do
    for j = 10, 14 do
      g:led(j, i == 1 and 3 or 7, 4)
      g:led(math.floor(util.linlin(-1, 1, 10, 14, params:get(i == 1 and "1pan" or "2pan"))), i== 1 and 3 or 7, 15)
    end
  end
  g:refresh()
end

function route_audio()
    clock.sleep(0.5)
    local selected_route = params:get("audio_routing")
    if rerouting_audio == true then
      rerouting_audio = false
      if selected_route == 1 then -- audio in + softcut output -> supercollider
        os.execute("jack_connect crone:output_5 SuperCollider:in_1;")  
        os.execute("jack_connect crone:output_6 SuperCollider:in_2;")
        os.execute("jack_connect softcut:output_1 SuperCollider:in_1;")  
        os.execute("jack_connect softcut:output_2 SuperCollider:in_2;")
      elseif selected_route == 2 then --just audio in -> supercollider
        os.execute("jack_disconnect softcut:output_1 SuperCollider:in_1;")  
        os.execute("jack_disconnect softcut:output_2 SuperCollider:in_2;")
        os.execute("jack_connect crone:output_5 SuperCollider:in_1;")  
        os.execute("jack_connect crone:output_6 SuperCollider:in_2;")
      elseif selected_route == 3 then -- just softcut output -> supercollider
        os.execute("jack_disconnect crone:output_5 SuperCollider:in_1;")  
        os.execute("jack_disconnect crone:output_6 SuperCollider:in_2;")
        os.execute("jack_connect softcut:output_1 SuperCollider:in_1;")  
        os.execute("jack_connect softcut:output_2 SuperCollider:in_2;")
      end
    end
end

function cleanup ()
  if _print then print = _print end
  print("cleanup")
  metro.free_all()
  os.execute("jack_disconnect softcut:output_1 SuperCollider:in_1;")  
  os.execute("jack_disconnect softcut:output_2 SuperCollider:in_2;")
  os.execute("jack_connect crone:output_5 SuperCollider:in_1;")  
  os.execute("jack_connect crone:output_6 SuperCollider:in_2;")
  audio.level_eng_cut(1)
end
