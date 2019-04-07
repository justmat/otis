-- not a coco
-- not a quantus

sc = include("lib/tooloops")

local alt = 0


local function skip(n)
  -- reset loop to start
  softcut.position(n, 1)
end


local function flip(n)
  -- flip tape direction
  local spd = params:get(n .. "speed")
  spd = -spd
  softcut.rate(n, spd)
end


function init()
  sc.init()
  redraw()
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
  screen.move(64, 32)
  screen.text_center("tlps")
  screen.update()
end