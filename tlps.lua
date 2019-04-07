-- not a coco
-- not a quantus

sc = include("lib/tooloops")

function init()
  sc.init()
  redraw()
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