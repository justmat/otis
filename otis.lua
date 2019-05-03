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
-- v0.4 by @justmat
--
-- https://llllllll.co/t/22149


local sc = include("lib/tlps")

local alt = 0
local page = 2
local page_time = 1
local skip_time_L = 1
local skip_time_R = 1
local muted_L = 0
local pre_mute_vol_L = 0
local muted_R = 0
local pre_mute_vol_R = 0
local rec1 = true
local rec2 = true

local pages = {"mix", "play", "edit"}
local skip_options = {"start", "???"}
local speed_options = {"free", "octaves"}


local function skip(n)
  -- reset loop to start, or random position
  if params:get("skip_controls") == 1 then
    softcut.position(n, 0)
  else
    local length = params:get(n .. "tape_len") + 0.5
    softcut.position(n, math.random(math.floor(length)))
  end
end


local function flip(n)
  -- flip tape direction
  local spd = params:get(n .. "speed")
  spd = -spd
  params:set(n .. "speed", spd)
end


local function speed_control(n, d)
  -- free controls
  if params:get("speed_controls") == 1 then
    params:delta(n - 1 .. "speed", d / 2)
  else
    -- quantized to octaves
    if d < 0 then
      params:set(n - 1 .. "speed", params:get(n - 1 .. "speed") / 2)
    else
      params:set(n - 1 .. "speed", params:get(n - 1 .."speed") * 2)
    end
  end
end


function init()
  sc.init()

  params:add_option("skip_controls", "skip controls", skip_options, 1)
  params:add_option("speed_controls", "speed controls", speed_options, 1)

  params:bang()
  softcut.buffer_clear()

  local screen_metro = metro.init()
  screen_metro.time = 1/30
  screen_metro.event = function() redraw() end
  screen_metro:start()
end

-- norns controls

function enc(n, d)
  -- navigation
  if n == 1 then
    page = util.clamp(page + d, 1, 3)
    page_time = util.time()
  end
  -- mix
  if page == 1 then
    if alt == 1 then
      if n == 2 then
        params:delta("1pan", d)
      elseif n == 3 then
        params:delta("2pan", d)
      end
    else
      if n == 2 then
        if muted_L == 0 then
          params:delta("1vol", d)
        end
      elseif n == 3 then
        if muted_R == 0 then
          params:delta("2vol", d)
        end
      end
    end
  -- play
  elseif page == 2 then
    if alt == 1 then
      if n == 2 then
        params:delta("1feedback", d)
      elseif n == 3 then
        params:delta("2feedback", d)
      end
    else
      if n == 2 or n == 3 then
        speed_control(n, d)
      end
    end
  elseif page == 3 then
  -- edit
    if alt == 1 then
      if n == 2 then
        params:set("skip_controls", util.clamp(params:get("skip_controls") + d, 1, 2))
      elseif n == 3 then
        params:set("speed_controls", util.clamp(params:get("skip_controls") + d, 1, 2))
      end
    else
      if n == 2 then
        params:delta("1tape_len", d)
      elseif n == 3 then
        params:delta("2tape_len", d)
      end
    end
  end
end


function key(n, z)
  if n == 1 then alt = z end
  -- mix
  if page == 1 then
    if n == 2 and z == 1 then
      if muted_L == 0 then
        pre_mute_vol_L = params:get("1vol")
        softcut.level(1, 0)
        muted_L = 1
      else
        softcut.level(1, pre_mute_vol_L)
        muted_L = 0
      end
    elseif n == 3 and z == 1 then
      if muted_R == 0 then
        pre_mute_vol_R = params:get("2vol")
        softcut.level(2, 0)
        muted_R = 1
      else
        softcut.level(2, pre_mute_vol_R)
        muted_R = 0
      end
    end
  -- play 
  elseif page == 2 then
    if alt == 1 then
      if n == 2 and z == 1 then
        skip(1)
        skip_time_L = util.time()
      elseif n == 3 and z ==1 then
        skip(2)
        skip_time_R = util.time()
      end
    else
      if n == 2 and z == 1 then
        flip(1)
      elseif n == 3 and z == 1 then
        flip(2)
      end
    end
  elseif page == 3 then
  -- edit
    if alt == 1 then
      if n == 2 and z == 1 then
        softcut.buffer_clear_channel(1)
      elseif n == 3 and z == 1 then
        softcut.buffer_clear_channel(2)
      end
    else
      if n == 2 and z == 1 then
        softcut.rec(1, rec1 == true and 0 or 1)
        rec1 = not rec1
      elseif n == 3 and z == 1 then
        softcut.rec(2, rec2 == true and 0 or 1)
        rec2 = not rec2
      end
    end
  end
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

  screen.level(muted_L == 0 and 3 or 15)
  screen.move(5, 52)
  screen.text("mute L")
  screen.level(muted_R == 0 and 3 or 15)
  screen.move(122, 52)
  screen.text_right("mute R")
end


local function draw_page_play()
  -- screen drawing for the play page
  screen.level(alt == 1 and 3 or 15)
  screen.move(64, 15)
  screen.text_center("speed L : " .. string.format("%.2f", math.abs(params:get("1speed"))))
  screen.move(64, 23)
  screen.text_center("speed R : " .. string.format("%.2f", math.abs(params:get("2speed"))))
  screen.level(alt == 1 and 15 or 3)
  screen.move(64, 31)
  screen.text_center("feedback L : " .. string.format("%.2f", params:get("1feedback")))
  screen.move(64, 39)
  screen.text_center("feedback R : " .. string.format("%.2f", params:get("2feedback")))

  screen.move(34, 16)
  screen.level(params:get("1speed") < 0 and 15 or 0)
  draw_left()
  screen.move(34, 24)
  screen.level(params:get("2speed") < 0 and 15 or 0)
  draw_left()
  screen.move(96, 16)
  screen.level(params:get("1speed") > 0 and 15 or 0)
  draw_right()
  screen.move(96, 24)
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
    if params:get("skip_controls") == 1 then
      screen.move(18, 40)
      draw_skip()
    else
      screen.move(7, 40)
      draw_skip_rand()
    end
  end

  if util.time() - skip_time_R < .15 then
    if params:get("skip_controls") == 1 then
      screen.move(120, 40)
      draw_skip()
    else
      screen.move(109, 40)
      draw_skip_rand()
    end
  end
end


local function draw_page_edit()
  -- screen drawing for edit page
  screen.level(alt == 1 and 3 or 15)
  screen.move(64, 15)
  screen.text_center("tape len L : " .. string.format("%.2f", params:get("1tape_len")))
  screen.move(64, 23)
  screen.text_center("tape len R : " .. string.format("%.2f", params:get("2tape_len")))
  screen.level(alt == 1 and 15 or 3)
  screen.move(64, 31)
  screen.text_center("skip controls : " .. skip_options[params:get("skip_controls")])
  screen.move(64, 39)
  screen.text_center("spd controls : " .. speed_options[params:get("speed_controls")])

  screen.level(alt == 1 and 3 or 15)
  screen.move(5, 52)
  screen.text(rec1 == true and "rec : on" or "rec : off")
  screen.move(122, 52)
  screen.text_right(rec2 == true and "rec : on" or "rec : off")
  screen.level(alt == 1 and 15 or 3)
  screen.move(5, 60)
  screen.text("clear")
  screen.move(122, 60)
  screen.text_right("clear")
end


function redraw()
  screen.clear()
  screen.aa(0)
  screen.font_face(25)
  screen.font_size(6)
  screen.move(30 * page, 5)
  -- current page indication
  if util.time() - page_time < 1.1 then
    screen.text(pages[page])
  end

  if page == 1 then
    draw_page_mix()
  elseif page == 2 then
    draw_page_play()
  elseif page == 3 then
    draw_page_edit()
  end
  screen.update()
end
