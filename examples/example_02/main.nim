import snabbdom
import snabbdom_dsl
import kdom
import sugar
import jstrutils

echo "running main"

var drawCount = 1

proc render(redraw: RedrawFunc): VNode =

  proc updateModel() =
    drawCount += 1
    redraw()

  discard setTimeout(updateModel, 1000)

  let cond = true

  let nodes = buildHtml:
    tdiv:
      text "Draw count" & $drawCount
    tdiv:
      text "Hello World"
    tdiv():
      text "Hello"
      tdiv:
        text "inbetween"
      text "World"
    for i in 1 .. 10000:
      span: text $i
    if cond:
      text "true"
    else:
      text "false"

  h("div", nodes)

mainLoop("ROOT", render)
