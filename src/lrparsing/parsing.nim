import syntax
import parsetable

import strutils, sequtils, tables

type
  Parser* = ref object of RootObj
    syntax: Syntax
    table: ParseTable
    stack: seq[int]
    pos: int

proc newParser*(syntax: Syntax, table: ParseTable): Parser =
  new(result)
  result.syntax = syntax
  result.table = table
  result.stack = newSeq[int]()
  result.pos = 0

proc parse(parser: var Parser, tokens: seq[string]): seq[int] =
  result = newSeq[int]()
  while true:
    var
      state = parser.stack[parser.stack.len-1]
      value = parser.table[(state, tokens[parser.pos])]
    case value.action:
    of Shift:
      parser.stack.add(value.goto)
      parser.pos.inc
    of Reduce:
      result.add(value.goto)
      var rule = parser.syntax[value.goto]
      for _ in 0..<rule.right.len:
        discard parser.stack.pop()
      var
        state = parser.stack[parser.stack.len-1]
        (_, next) = parser.table[(state, rule.left)]
      parser.stack.add(next)
    of Accept:
      break
    of None:
      discard

proc parse*(parser: var Parser, input: string): seq[int] =
  parser.stack = @[0]
  parser.pos = 0
  parser.parse(input.tokenize)


# ==============================================================================

type
  ASTNode = ref object of RootObj

  ASTList = ref object of ASTNode
    chs: seq[ASTNode]

  ASTValue = ref object of ASTNode
    val: string

proc newASTList(): ASTList =
  new(result)
  result.chs = newSeq[ASTNode]()

proc newASTValue(val: Token): ASTValue =
  new(result)
  result.val = val

proc `$`*(self: ASTNode): string =
  if self of ASTList:
    var strs = newSeq[string]()
    for ch in ASTList(self).chs:
      strs.add($ch)
    result = "(" & strs.join(",") & ")"
  else:
    result = ASTValue(self).val

proc buildAST(ruleIds: seq[int], syntax: Syntax, pos: var int): ASTNode =
  var
    cur = newASTList()
    id = ruleIds[pos]; pos.dec
  for token in syntax[id].right:
    if token.isTerminal():
      cur.chs.add(newASTValue(token))
    else:
      cur.chs.add(buildAST(ruleIds, syntax, pos))
  result = cur

proc buildAST*(ruleIds: seq[int], syntax: Syntax): ASTNode =
  var pos = ruleIds.len - 1
  buildAST(ruleIds, syntax, pos)