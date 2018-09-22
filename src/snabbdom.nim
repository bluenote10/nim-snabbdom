import kdom
import jsffi
import jseq
import sugar

{.emit: """

/*
console.log("Loading snabbdom");
console.log(snabbdom_style);

// ----------------------------------------------------------------------------
// https://gist.github.com/Risto-Stevcev/d51f45997f1a818b6d21492475e07913
// ----------------------------------------------------------------------------
var patch = snabbdom.init([
    snabbdom_style,
    snabbdom_class,
    snabbdom_props,
    snabbdom_attributes,
    snabbdom_eventlisteners
]);

// ----------------------------------------------------------------------------
// Target syntax
// ----------------------------------------------------------------------------
import snabbdom = require("snabbdom");

import snabbdom_class = require('snabbdom/modules/class');
import snabbdom_props = require('snabbdom/modules/props');
import snabbdom_style = require('snabbdom/modules/style');
import snabbdom_eventlisteners = require('snabbdom/modules/eventlisteners');
import h = require('snabbdom/h');

var patch = snabbdom.init([
  snabbdom_class.default,
  snabbdom_props.default,
  snabbdom_style.default,
  snabbdom_eventlisteners.default,
]);

import { VNode } from "snabbdom/vnode";
import main from "./renderer/main";

let oldNode: Element | VNode = document.getElementById("ROOT")!;
let i = 0;

function redraw() {
  console.log(i);
  let newNode = main.render(redraw);
  patch(oldNode, newNode);
  i += 1;
  oldNode = newNode;
}

redraw();
*/

""".}

proc debug*[T](x: T) {.importc: "console.log", varargs.}

type
  Module* = ref object of RootObj
  #Snabbdom* = ref object of Module
  SnabbdomStyle* = ref object of Module
  SnabbdomClass* = ref object of Module
  SnabbdomProps* = ref object of Module
  SnabbdomAttributes* = ref object of Module
  SnabbdomEventListeners* = ref object of Module

#var snabbdom* {.importc: "snabbdom".}: Snabbdom
var snabbdomStyle* {.importc: "snabbdom_style".}: SnabbdomStyle
var snabbdomClass* {.importc: "snabbdom_class".}: SnabbdomClass
var snabbdomProps* {.importc: "snabbdom_props".}: SnabbdomProps
var snabbdomAttributes* {.importc: "snabbdom_attributes".}: SnabbdomAttributes
var snabbdomEventListeners* {.importc: "snabbdom_eventlisteners".}: SnabbdomEventListeners

type
  Patch* = ref object

#proc init*(snabbdom: Snabbdom, modules: seq[Module]): Patch {.importcpp: "#.init(#)".}
proc init*(modules: seq[Module]): Patch {.importcpp: "snabbdom.init(#)".}


type
  VNode* = ref object
  VNodes* = jseq[JsObject] # seq[JsObject]

proc h*(name: cstring): VNode {.importcpp: "h.default(#)".}
proc h*(name: cstring, content: cstring): VNode {.importcpp: "h.default(#, #)".}
proc h*(name: cstring, children: VNodes): VNode {.importcpp: "h.default(#, #)".}

proc patch*(p: Patch, element: Element, newNode: VNode) {.importcpp: "#(#, #)".}
proc patch*(p: Patch, oldNode: VNode, newNode: VNode) {.importcpp: "#(#, #)".}


type
  RedrawFunc* = proc()


proc mainLoop*(rootElementName: cstring, render: RedrawFunc -> VNode) =
  let modules: seq[Module] = @[snabbdom_style.Module]
  let patch = snabbdom.init(modules)

  var oldNode: VNode = nil

  proc redraw() =
    {.emit: """
      var performance = window.performance;
      var t0 = performance.now();
    """.}
    let newNode = render(redraw)
    {.emit: """
      var t1 = performance.now();
      console.log("Rendering call took " + (t1 - t0) + " milliseconds.")
    """.}

    if oldNode.isNil:
      let rootElement = document.getElementById(rootElementName)
      patch.patch(rootElement, newNode)
    else:
      patch.patch(oldNode, newNode)

    oldNode = newNode

  redraw()


