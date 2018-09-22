import snabbdom
import macros
import jsffi
import jseq


proc tanslateTagName(s: string): string =
  if s == "tdiv":
    "div"
  else:
    s

# forward declaration required
proc buildNodesBlock(body: NimNode, level: int): NimNode


proc buildAppendBlock(nodesSymbol: NimNode, body: NimNode, level: int): NimNode =

  template appendElement(nodesSymbol, tmp, tag, childrenBlock) =
    bind h, toJs
    let childNodes = childrenBlock
    let tmp = h(tag.cstring, childNodes)
    nodesSymbol.add(tmp.toJs())

  template appendElementNoChildren(nodesSymbol, tmp, tag) =
    bind h, toJs
    let tmp = h(tag.cstring)
    nodesSymbol.add(tmp.toJs())

  template appendText(nodesSymbol, textNode) =
    bind toJs
    nodesSymbol.add(toJs(cstring(textNode)))

  template embedSeq(nodesSymbol, nodesSeqExpr) =
    bind toJs
    for node in nodesSeqExpr:
      nodesSymbol.add(node.toJs())

  let n = copyNimTree(body)

  const nnkCallKindsNoInfix = {nnkCall, nnkPrefix, nnkPostfix, nnkCommand, nnkCallStrLit}

  case n.kind
  of nnkCallKindsNoInfix:
    let tmp = genSym(nskLet, "tmp")
    let tagStr = $(n[0])
    let tag = newStrLitNode(tanslateTagName(tagStr))
    if tagStr == "embed":
      let nodesSeqExpr = n[1]
      result = getAst(embedSeq(nodesSymbol, nodesSeqExpr))
    elif tagStr == "call":
      result = n[1]
    elif tagStr == "text":
      result = getAst(appendText(nodesSymbol, n[1]))
    else:
      # if the last element is an nnkStmtList (block argument)
      # => full recursion to build block statement for children
      if n.len >= 2 and n[^1].kind == nnkStmtList:
        let childrenBlock = buildNodesBlock(n[^1], level+1)
        result = getAst(appendElement(nodesSymbol, tmp, tag, childrenBlock))
      else:
        error "Empty children nodes are not supported"
  of nnkIdent:
    # Currently a single ident is treated as an empty tag. Not sure if
    # there more important use cases. Maybe `embed` them?
    let tmp = genSym(nskLet, "tmp")
    let tag = newStrLitNode(tanslateTagName($n))
    #let attributes = newEmptyNode()
    result = getAst(appendElementNoChildren(nodesSymbol, tmp, tag))

  of nnkForStmt, nnkIfExpr, nnkElifExpr, nnkElseExpr,
      nnkOfBranch, nnkElifBranch, nnkExceptBranch, nnkElse,
      nnkConstDef, nnkWhileStmt, nnkIdentDefs, nnkVarTuple:
    # recurse for the last son:
    result = copyNimTree(n)
    let L = n.len
    if L > 0:
      result[L-1] = buildAppendBlock(nodesSymbol, result[L-1], level+1)

  of nnkStmtList, nnkStmtListExpr, nnkWhenStmt, nnkIfStmt, nnkTryStmt,
      nnkFinally:
    # recurse for every child:
    result = copyNimNode(n)
    for x in n:
      result.add buildAppendBlock(nodesSymbol, x, level+1)

  of nnkCaseStmt:
    # recurse for children, but don't add call for case ident
    result = copyNimNode(n)
    result.add n[0]
    for i in 1 ..< n.len:
      result.add buildAppendBlock(nodesSymbol, n[i], level+1)

  of nnkVarSection, nnkLetSection, nnkConstSection:
    result = n
  of nnkInfix:
    result = n

  else:
    error "Unhandled node kind: " & $n.kind & "\n" & n.repr


proc buildNodesBlock(body: NimNode, level: int): NimNode =
  ## This proc finializes the node building by wrapping everything
  ## in a block which provides and returns the `nodes` variable.
  template nodesBlock(nodesSymbol, appendBlock) =
    bind newjSeq, JsObject
    block:
      # As a performance optimization we use a native JS array
      # here to avoid calls to newSeq & nimCopy.
      var nodesSymbol = newjSeq[JsObject]()
      appendBlock
      nodesSymbol

  let nodesSymbol = genSym(nskVar, "nodes")
  let appendBlock = buildAppendBlock(nodesSymbol, body, level)

  result = getAst(nodesBlock(nodesSymbol, appendBlock))
  if level == 0:
    echo result.repr


macro buildHtml*(body: untyped): VNodes =
  echo " --------- body ----------- "
  echo body.treeRepr
  echo " --------- body ----------- "

  # Previously it was necessary to wrap the body into a do
  # block and extract the body again. Not sure if this was
  # due to a limitation in the compiler. It looks like this
  # isn't required...

  # let kids = newProc(procType=nnkDo, body=body)
  # echo "body: ", body.repr
  # echo "kids: ", kids.repr
  # echo "body(kids): ", body(kids).repr
  # result = buildNodesBlock(body(kids), 0)

  result = buildNodesBlock(body, 0)
