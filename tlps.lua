-- not a coco
-- not a quantus


local sc = include("lib/tooloops")

local alt = 0


local function skip(n)
  -- reset loop to start
  softcut.position(n, 1)
end


local function flip(n)
  -- flip tape direction
  local spd = params:get(n .. "speed")
  spd = -spd
  params:set(n .. "speed", spd)
end


function init()
  sc.init()
  
  local screen_metro = metro.init()
  screen_metro.time = 1/30
  screen_metro.event = function() redraw() end
  screen_metro:start()
end


function enc(n, d)
  if alt == 1 then
    if n == 2 then
      params:delta("1feedback", d)
    elseif n == 3 then
      params:delta("2feedback", d)
    end
  else
    if n == 2 then
      params:delta("1speed", d)
    elseif n == 3 then
      params:delta("2speed", d)
    end
  end
end


function key(n, z)
  if n == 1 then alt = z end
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
  

function redraw()
  screen.clear()
  screen.aa(0)
  screen.font_face(25)
  screen.font_size(6)
  
  screen.level(alt == 1 and 3 or 15)
  screen.move(64, 15)
  screen.text_center("speed L : " .. math.abs(params:get("1speed")))
  screen.move(64, 23)
  screen.text_center("speed R : " .. math.abs(params:get("2speed")))
  screen.level(alt == 1 and 15 or 3)
  screen.move(64, 31)
  screen.text_center("fdbk L : " .. params:get("1feedback"))
  screen.move(64, 39)
  screen.text_center("fdbk R : " .. params:get("2feedback"))
  screen.level(alt == 1 and 3 or 15)
  screen.move(5, 52)
  screen.text("flip L")
  screen.move(96, 52)
  screen.text("flip R")
  screen.level(alt == 1 and 15 or 3)
  screen.move(5, 60)
  screen.text("skip L")
  screen.move(96, 60)
  screen.text("skip R")
  screen.update()
end