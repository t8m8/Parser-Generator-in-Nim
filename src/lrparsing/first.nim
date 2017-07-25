import syntax
import tables, sequtils

var firstSet = newTable[Token, seq[Token]]()

proc first*(t: Token, syntax: Syntax): seq[Token] =
  if firstSet.hasKey(t):
    return firstSet[t]
  elif t.isTerminal:
    firstSet.add(t, @[t])
    return @[t]
  firstSet.add(t, @[])
  result = newSeq[Token]()
  for rule in syntax:
    if rule.left != t: continue
    var token = rule.right[0]
    if token.isTerminal:
      result.add(token)
    else:
      result.insert(first(token, syntax))
  result = result.deduplicate()
  firstSet.add(t, result)
