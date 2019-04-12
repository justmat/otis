--
--          otis
--      stereo tape     _
--        delay/         | \
--           looper       | |
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
-- there are two pages of
-- controls, play and edit.
--
-- navigate with enc 1.
-- ALT is key 1.
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
-- ALT + enc2 = pan L
-- ALT + enc3 = pan R
--
-- ----------
--
-- v0.2 by @justmat


local sc = include("lib/tooloops")

local alt = 0
local page = 1
local pages = {"play", "edit"}
local page_time = util.time()
local rec1 = true
local rec2 = true


local function skip(n)
  -- reset loop to start, or random position
  if params:get("skip_controls") == 1 then
    softcut.position(n, 0)
  else
    softcut.position(n, math.random(params:get(n .. "tape_len")))
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

  params:add_option("skip_controls", "skip controls", {"start", "???"}, 1)
  params:add_option("speed_controls", "speed controls", {"free", "quantized"}, 1)

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
    page = util.clamp(page + d, 1, 2)
    page_time = util.time()
  end
  --play
  if page == 1 then
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
  else
  -- edit
    if alt == 1 then
      if n == 2 then
        params:delta("1pan", d)
      elseif n == 3 then
        params:delta("2pan", d)
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
  -- play
  if page == 1 then
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
  else
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


function redraw()
  screen.clear()
  screen.aa(0)
  screen.font_face(25)
  screen.font_size(6)
  screen.move(5, 5)
  -- current page indication
  if util.time() - page_time < .6 then
    screen.text(pages[page])
  end
  -- play
  if page == 1 then
    screen.level(alt == 1 and 3 or 15)
    screen.move(64, 15)
    screen.text_center("speed L : " .. string.format("%.2f", math.abs(params:get("1speed"))))
    screen.move(64, 23)
    screen.text_center("speed R : " .. string.format("%.2f", math.abs(params:get("2speed"))))
    screen.level(alt == 1 and 15 or 3)
    screen.move(64, 31)
    screen.text_center("fdbk L : " .. string.format("%.2f", params:get("1feedback")))
    screen.move(64, 39)
    screen.text_center("fdbk R : " .. string.format("%.2f", params:get("2feedback")))

    screen.move(34, 16)
    screen.level(params:get("1speed") < 0 and 15 or 3)
    draw_left()
    screen.move(34, 24)
    screen.level(params:get("2speed") < 0 and 15 or 3)
    draw_left()
    screen.move(96, 16)
    screen.level(params:get("1speed") > 0 and 15 or 3)
    draw_right()
    screen.move(96, 24)
    screen.level(params:get("2speed") > 0 and 15 or 3)
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
  else
  -- edit
    screen.level(alt == 1 and 3 or 15)
    screen.move(64, 15)
    screen.text_center("tape len L : " .. string.format("%.2f", params:get("1tape_len")))
    screen.move(64, 23)
    screen.text_center("tape len R : " .. string.format("%.2f", params:get("2tape_len")))
    screen.level(alt == 1 and 15 or 3)
    screen.move(64, 31)
    screen.text_center("panning L : " .. string.format("%.2f", params:get("1pan")))
    screen.move(64, 39)
    screen.text_center("panning R : " .. string.format("%.2f", params:get("2pan")))

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
  screen.update()
end
