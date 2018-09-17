import snabbdom
import kdom
import sugar
import jstrutils

echo "running main"

var i = 1

proc render(redraw: RedrawFunc): VNode =

  proc updateModel() =
    i += 1
    redraw()

  discard setTimeout(updateModel, 1000)
  h("div", "hello world " & i.toCstr)

mainLoop("ROOT", render)
