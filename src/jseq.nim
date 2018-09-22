import jsffi

type
  jseq*[T] = ref object

#proc newjSeq*[T](): jseq[T] {.importc: "[]".}

proc newjSeq*[T](): jseq[T] {.importcpp: "([])".}

proc add*[T](s: jseq[T], x: T) {.importcpp: "#.push(#)".}

