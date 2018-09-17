#import snabbdom except Node
import macros
import jsffi

#type
#  VNodes* = seq[VNode]


type
  Node* = ref object
    tag: cstring
    #children: Nodes
    children: seq[JsObject]

  Nodes* = seq[Node]

proc newNode*(tag: cstring): Node =
  Node(tag: tag, children: newSeq[JsObject]())


proc newNode*(tag: cstring, children: seq[JsObject]): Node =
  Node(tag: tag, children: children)



proc buildNodesBlock(body: NimNode, level: int): NimNode



proc buildNodes(body: NimNode, level: int): NimNode =

  template appendElement(tmp, tag, childrenBlock) {.dirty.} =
    bind newNode, toJs
    let tmp = newNode(tag.cstring)
    nodes.add(tmp.toJs())
    tmp.children = childrenBlock

  template appendElementNoChildren(tmp, tag) {.dirty.} =
    bind newNode, toJs
    let tmp = newNode(tag.cstring)
    nodes.add(tmp.toJs())

  template appendText(textNode) {.dirty.} =
    bind toJs
    nodes.add(toJs(cstring(textNode)))

  template embedSeq(nodesSeqExpr) {.dirty.} =
    bind toJs
    for node in nodesSeqExpr:
      nodes.add(node.toJs())

  let n = copyNimTree(body)
  # echo level, " ", n.kind
  # echo n.treeRepr

  const nnkCallKindsNoInfix = {nnkCall, nnkPrefix, nnkPostfix, nnkCommand, nnkCallStrLit}

  case n.kind
  of nnkCallKindsNoInfix:
    let tmp = genSym(nskLet, "tmp")
    let tagStr = $(n[0])
    let tag = newStrLitNode(tagStr)
    if tagStr == "embed":
      let nodesSeqExpr = n[1]
      result = getAst(embedSeq(nodesSeqExpr))
    elif tagStr == "call":
      result = n[1]
    elif tagStr == "text":
      #let attributes = dummyTextAttributes(n[1])
      result = getAst(appendText(n[1]))
    else:
      # if the last element is an nnkStmtList (block argument)
      # => full recursion to build block statement for children
      let childrenBlock =
        if n.len >= 2 and n[^1].kind == nnkStmtList:
          buildNodesBlock(n[^1], level+1)
        else:
          newNimNode(nnkEmpty)
      #let attributes = extractAttributes(n)
      # echo attributes.repr
      # TODO: handle nil cases explicitly by constructing empty seqs to avoid nil issues
      result = getAst(appendElement(tmp, tag, childrenBlock))
  of nnkIdent:
    # Currently a single ident is treated as an empty tag. Not sure if
    # there more important use cases. Maybe `embed` them?
    let tmp = genSym(nskLet, "tmp")
    let tag = newStrLitNode($n)
    #let attributes = newEmptyNode()
    result = getAst(appendElementNoChildren(tmp, tag))

  of nnkForStmt, nnkIfExpr, nnkElifExpr, nnkElseExpr,
      nnkOfBranch, nnkElifBranch, nnkExceptBranch, nnkElse,
      nnkConstDef, nnkWhileStmt, nnkIdentDefs, nnkVarTuple:
    # recurse for the last son:
    result = copyNimTree(n)
    let L = n.len
    if L > 0:
      result[L-1] = buildNodes(result[L-1], level+1)

  of nnkStmtList, nnkStmtListExpr, nnkWhenStmt, nnkIfStmt, nnkTryStmt,
      nnkFinally:
    # recurse for every child:
    result = copyNimNode(n)
    for x in n:
      result.add buildNodes(x, level+1)

  of nnkCaseStmt:
    # recurse for children, but don't add call for case ident
    result = copyNimNode(n)
    result.add n[0]
    for i in 1 ..< n.len:
      result.add buildNodes(n[i], level+1)

  of nnkVarSection, nnkLetSection, nnkConstSection:
    result = n
  of nnkInfix:
    result = n

  else:
    error "Unhandled node kind: " & $n.kind & "\n" & n.repr

  #result = elements


proc buildNodesBlock(body: NimNode, level: int): NimNode =
  ## This proc finializes the node building by wrapping everything
  ## in a block which provides and returns the `nodes` variable.
  template resultTemplate(elementBuilder) {.dirty.} =
    bind JsObject
    block:
      var nodes = newSeq[JsObject]()
      elementBuilder
      nodes

  let elements = buildNodes(body, level)
  result = getAst(resultTemplate(elements))
  if level == 0:
    echo result.repr
    echo "End of buildNodesBlock"


macro buildHtml*(body: untyped): seq[JsObject] =
  echo " --------- body ----------- "
  echo body.treeRepr
  echo " --------- body ----------- "

  let kids = newProc(procType=nnkDo, body=body)
  expectKind kids, nnkDo
  result = buildNodesBlock(body(kids), 0)
  echo "End of buildHtml"