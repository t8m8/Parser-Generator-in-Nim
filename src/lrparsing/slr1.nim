import syntax
export syntax

import strutils, sequtils

type
  LR0Item* = tuple[rule: Rule, ruleId, bullet: int]
  LR0ItemSet* = seq[LR0Item]

  LR0Node = seq[LR0ItemSet]
  LR0Edge = seq[tuple[src, dst: int, token: Token]]

  LR0Automaton* = ref object of RootObj
    syntax: Syntax
    nodes: LR0Node
    edges: LR0Edge

proc finished*(self: LR0Item): bool =
  self.rule.right.len <= self.bullet

proc next*(self: LR0Item): Token =
  self.rule.right[self.bullet]

proc inc(self: LR0Item): LR0Item =
  (self.rule, self. ruleId, self.bullet + 1)


proc `$`*(self: LR0Item): string =
  var right = newSeq[string]()
  for i in 0..<self.rule.right.len:
    if i == self.bullet:
      right.add("・")
    right.add(self.rule.right[i])
  if self.finished:
    right.add("・")
  result = self.rule.left & " -> " & right.join(" ")


# ==============================================================================

import algorithm

proc `==`*(a, b: LR0ItemSet): bool =
  if a.len != b.len:
    return false
  var cmp = proc(a: LR0Item, b: LR0Item): int =
    if a.ruleId != b.ruleId:
      return a.ruleId - b.ruleId
    elif a.bullet != b.bullet:
      return a.bullet - b.bullet
  var (sa, sb) = (a.sorted(cmp), b.sorted(cmp))
  result = true
  for i in 0..<sa.len:
    if sa[i] != sb[i]: result = false

proc growed(itemSet: LR0ItemSet, syntax: Syntax): LR0ItemSet =
  result = newSeq[LR0Item]()
  result.insert(itemSet)
  for item in itemSet:
    if item.finished() or item.next.isTerminal: continue
    for ruleId, rule in syntax:
      if rule.left != item.next: continue
      result.add((rule, ruleId, 0))
  result = result.deduplicate()
  if result != itemSet:
    result = result.growed(syntax)

proc inc(itemSet: LR0ItemSet, token: string): LR0ItemSet =
  result = newSeq[LR0Item]()
  for item in itemSet:
    if item.finished: continue
    if item.next() == token:
      result.add(item.inc)

proc `$`*(self: LR0ItemSet): string =
  var itemStrs = newSeq[string]()
  for item in self:
    itemStrs.add($item)
  result = itemStrs.join("\n")

# ==============================================================================

proc len*(self: LR0Automaton): int =
  self.nodes.len

proc contains*(automaton: LR0Automaton, itemSet: LR0ItemSet): bool =
  for node in automaton.nodes:
    if node == itemSet:
      return true

proc nodeId*(automaton: LR0Automaton, itemSet: LR0ItemSet): int =
  for i, node in automaton.nodes:
    if node == itemSet:
      return i

proc addNode(self: var LR0Automaton, itemSet: LR0ItemSet) =
  self.nodes.add(itemSet)

proc addEdge(self: var LR0Automaton, src, dst: int, token: Token) =
  self.edges.add((src, dst, token))

proc add*(self: var LR0Automaton, itemSet: LR0ItemSet, cur: int = 0) =
  var itemSet = itemSet.growed(self.syntax)
  self.addNode(itemSet)
  for token in self.syntax.tokens:
    var nextSet = inc(itemSet, token)
    if nextSet.len == 0:
      continue
    if self.contains(nextSet):
      var nextIdx = self.nodeId(nextSet)
      self.addEdge(cur, nextIdx, token)
    else:
      var nextIdx = self.len
      self.addEdge(cur, nextIdx, token)
      self.add(nextSet, nextIdx)

proc newLR0Automaton*(syntax: Syntax): LR0Automaton =
  new(result)
  result.syntax = syntax
  result.nodes = newSeq[LR0ItemSet]()
  result.edges = newSeq[(int, int, Token)]()

proc buildLR0Automaton*(syntax: Syntax): LR0Automaton =
  var
    automaton = newLR0Automaton(syntax)
    initialSet = @[(syntax[0], 0, 0)]
  automaton.add(initialSet)
  result = automaton

proc `$`*(self: LR0Node): string =
  var nodeStrs = newSeq[string]()
  for i, node in self:
    nodeStrs.add("Node" & $i)
    nodeStrs.add($node)
  result = nodeStrs.join("\n")

proc `$`*(self: LR0Edge): string =
  var edgeStrs = newSeq[string]()
  for edge in self:
    edgeStrs.add(
      "Node" & $edge.src & " -> Node" & $edge.dst & " [" & $edge.token & "]")
  result = edgeStrs.join("\n")

proc `$`*(self: LR0Automaton, indentSize: int = 2): string =
  result = "Node\n"
  result &= ($self.nodes).indent(indentSize)
  result &= "\n\n"
  result &= "Edge\n"
  result &= ($self.edges).indent(indentSize)

# ==============================================================================

import tables

var
  firstSet = newTable[Token, seq[Token]]()
  followSet = newTable[Token, seq[Token]]()

proc first(nt: Token, syntax: Syntax): seq[Token] =
  if firstSet.hasKey(nt):
    return firstSet[nt]
  firstSet.add(nt, @[])
  result = newSeq[Token]()
  for rule in syntax:
    if rule.left != nt: continue
    var token = rule.right[0]
    if token.isTerminal:
      result.add(token)
    else:
      result.insert(first(token, syntax))
  result = result.deduplicate()
  firstSet.add(nt, result)

proc follow(nt: Token, syntax: Syntax): seq[Token] =
  if followSet.hasKey(nt):
    return followSet[nt]
  followSet.add(nt, if nt == "S": @["$"] else: @[])
  result = newSeq[Token]()
  for rule in syntax:
    if rule.right[rule.right.len-1] == nt:
      result.add(follow(rule.left, syntax))
  for rule in syntax:
    if rule.left != nt: continue
    for i, token in rule.right:
      if i in {0, rule.right.len-1}: continue
      if token.isTerminal:
        result.add(token)
      else:
        result.add(first(token, syntax))
  result = result.deduplicate()
  followSet[nt].add(result)
  result = followSet[nt].deduplicate()
  followSet.add(nt, result)

# ==============================================================================

import parsetable
export parsetable

type
  LR0Table = ParseTable

proc buildSLR1Table*(automaton: LR0Automaton): LR0Table =
  result = newParseTable()
  for edge in automaton.edges:
    if edge.token.isTerminal:
      result.add((edge.src, edge.token), (Shift, edge.dst))
    else:
      result.add((edge.src, edge.token), (None, edge.dst))

  for nodeId, node in automaton.nodes:
    for item in node:
      if not item.finished: continue
      if item.rule.left == "S":
        result.add((nodeId, "$"), (Accept, -1))
      else:
        for t in follow(item.rule.left, automaton.syntax):
          result.add((nodeId, t), (Reduce, item.ruleId))
