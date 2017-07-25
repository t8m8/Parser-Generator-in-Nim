import syntax
import tables, sequtils

var firstSet = newTable[Token, seq[Token]]()

proc first*(nt: Token, syntax: Syntax): seq[Token] =
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
