import syntax, first
export first
import tables, sequtils

var followSet = newTable[Token, seq[Token]]()

proc follow*(nt: Token, syntax: Syntax): seq[Token] =
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
