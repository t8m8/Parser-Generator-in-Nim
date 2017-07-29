import syntax
export syntax

import first

import strutils, sequtils

type
  LR1Item* = tuple[rule: Rule, ruleId, bullet: int, la: seq[Token]]
  LR1ItemSet* = seq[LR1Item]

  LR1Node = seq[LR1ItemSet]
  LR1Edge = seq[tuple[src, dst: int, token: Token]]

  LR1Automaton* = ref object of RootObj
    syntax: Syntax
    nodes: LR1Node
    edges: LR1Edge

proc `~=`*(a, b: LR1Item): bool =
  a.rule == b.rule and a.ruleId == b.ruleId and a.bullet == b.bullet

proc `!~=`*(a, b: LR1Item): bool = not(a ~= b)

proc finished*(self: LR1Item): bool =
  self.rule.right.len <= self.bullet

proc nextToken*(self: LR1Item): Token =
  self.rule.right[self.bullet]

proc next(self: LR1Item): LR1Item =
  (self.rule, self. ruleId, self.bullet + 1, self.la)

proc `$`*(self: LR1Item): string =
  var right = newSeq[string]()
  for i in 0..<self.rule.right.len:
    if i == self.bullet:
      right.add("・")
    right.add(self.rule.right[i])
  if self.finished:
    right.add("・")
  result = self.rule.left & " -> " & right.join(" ") & "[" & self.la.join(",") & "]"


# ==============================================================================

import algorithm

proc `~=`*(a, b: LR1ItemSet): bool =
  if a.len != b.len:
    return false
  var cmp = proc(a: LR1Item, b: LR1Item): int =
    if a.ruleId != b.ruleId:
      return a.ruleId - b.ruleId
    elif a.bullet != b.bullet:
      return a.bullet - b.bullet
  var (sa, sb) = (a.sorted(cmp), b.sorted(cmp))
  result = true
  for i in 0..<sa.len:
    if sa[i] !~= sb[i]: result = false

proc `!~=`*(a, b: LR1ItemSet): bool = not(a ~= b)

proc `==`*(a, b: LR1ItemSet): bool =
  if a.len != b.len:
    return false
  var cmp = proc(a: LR1Item, b: LR1Item): int =
    if a.ruleId != b.ruleId:
      return a.ruleId - b.ruleId
    elif a.bullet != b.bullet:
      return a.bullet - b.bullet
  var (sa, sb) = (a.sorted(cmp), b.sorted(cmp))
  result = true
  for i in 0..<sa.len:
    if sa[i] != sb[i]: result = false

proc `!=`*(a, b: LR1ItemSet): bool = not(a == b)

proc addOrMerge(self: var LR1ItemSet, val: LR1Item) =
  for i, item in self:
    if item.ruleId == val.ruleId:
      self[i].la.insert(val.la)
      self[i].la = self[i].la.deduplicate()
      return
  self.add(val)

proc growed(itemSet: LR1ItemSet, syntax: Syntax): LR1ItemSet =
  result = newSeq[LR1Item]()
  result.insert(itemSet)
  for item in itemSet:
    if item.finished() or item.nextToken.isTerminal: continue
    for ruleId, rule in syntax:
      if rule.left != item.nextToken: continue
      if item.next.finished():
        result.addOrMerge((rule, ruleId, 0, item.la))
      else:
        result.addOrMerge((rule, ruleId, 0, first(item.next.nextToken, syntax)))
  result = result.deduplicate()
  if result != itemSet:
    result = result.growed(syntax)

proc next(itemSet: LR1ItemSet, token: string): LR1ItemSet =
  result = newSeq[LR1Item]()
  for item in itemSet:
    if item.finished: continue
    if item.nextToken() == token:
      result.add(item.next)

proc `$`*(self: LR1ItemSet): string =
  var itemStrs = newSeq[string]()
  for item in self:
    itemStrs.add($item)
  result = itemStrs.join("\n")

# ==============================================================================

proc len*(self: LR1Automaton): int =
  self.nodes.len

proc contains*(automaton: LR1Automaton, itemSet: LR1ItemSet): bool =
  for node in automaton.nodes:
    if node == itemSet:
      return true

proc nodeId*(automaton: LR1Automaton, itemSet: LR1ItemSet): int =
  for i, node in automaton.nodes:
    if node == itemSet:
      return i

proc addNode(self: var LR1Automaton, itemSet: LR1ItemSet) =
  self.nodes.add(itemSet)

proc addEdge(self: var LR1Automaton, src, dst: int, token: Token) =
  self.edges.add((src, dst, token))

proc add*(self: var LR1Automaton, itemSet: LR1ItemSet, cur: int = 0) =
  var itemSet = itemSet.growed(self.syntax)
  self.addNode(itemSet)
  for token in self.syntax.tokens:
    var nextSet = next(itemSet, token)
    if nextSet.len == 0:
      continue
    if self.contains(nextSet):
      var nextIdx = self.nodeId(nextSet)
      self.addEdge(cur, nextIdx, token)
    else:
      var nextIdx = self.len
      self.addEdge(cur, nextIdx, token)
      self.add(nextSet, nextIdx)

proc merged*(a, b: LR1ItemSet): LR1ItemSet =
  result = newSeq[LR1Item]()
  for s in a:
    for t in b:
      if s ~= t:
        var la = concat(s.la, t.la).deduplicate().sorted(cmp)
        result.add((s.rule, s.ruleId, s.bullet, la))

proc merge*(self: var LR1Automaton) =
  var ids = newSeq[int](self.nodes.len)
  for i in 0..<self.nodes.len:
    ids[i] = i
  for i in 0..<self.nodes.len:
    if ids[i] < 0: continue
    for j in 0..<i:
      if ids[j] < 0: continue
      if self.nodes[i] ~= self.nodes[j]:
        ids[j] = -i
        self.nodes[i] = merged(self.nodes[i], self.nodes[j])
  var merged = newSeq[LR1ItemSet]()
  for i in 0..<self.nodes.len:
    if ids[i] < 0: continue
    merged.add(self.nodes[ids[i]])
    ids[i] = merged.len - 1
    for j in 0..<self.nodes.len:
      if ids[j] == -i:
        ids[j] = -merged.len + 1
  self.nodes = merged
  for i in 0..<self.edges.len:
    self.edges[i].src = abs(ids[self.edges[i].src])
    self.edges[i].dst = abs(ids[self.edges[i].dst])
  self.edges = self.edges.deduplicate()

proc newLR0Automaton*(syntax: Syntax): LR1Automaton =
  new(result)
  result.syntax = syntax
  result.nodes = newSeq[LR1ItemSet]()
  result.edges = newSeq[(int, int, Token)]()

proc buildLR0Automaton*(syntax: Syntax): LR1Automaton =
  var
    automaton = newLR0Automaton(syntax)
    initialSet = @[(syntax[0], 0, 0, @["$"])]
  automaton.add(initialSet)
  automaton.merge()
  result = automaton

proc `$`*(self: LR1Node): string =
  var nodeStrs = newSeq[string]()
  for i, node in self:
    nodeStrs.add("Node" & $i)
    nodeStrs.add($node)
  result = nodeStrs.join("\n")

proc `$`*(self: LR1Edge): string =
  var edgeStrs = newSeq[string]()
  for edge in self:
    edgeStrs.add(
      "Node" & $edge.src & " -> Node" & $edge.dst & " [" & $edge.token & "]")
  result = edgeStrs.join("\n")

proc `$`*(self: LR1Automaton, indentSize: int = 2): string =
  result = "Node\n"
  result &= ($self.nodes).indent(indentSize)
  result &= "\n\n"
  result &= "Edge\n"
  result &= ($self.edges).indent(indentSize)

# ==============================================================================

import tables
import parsetable
export parsetable

type
  LR1Table = ParseTable

proc buildLR1Table*(automaton: LR1Automaton): LR1Table =
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
      elif item.finished:
        for la in item.la:
          result.add((nodeId, la), (Reduce, item.ruleId))
