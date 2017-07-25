import strutils, sequtils, future

type
  Token* = string

  Rule* = tuple[left: Token, right: seq[Token]]
  Syntax* = seq[Rule]

proc isNonTerminal*(s: Token): bool {.inline.} = isUpperAscii(s[0])

proc isTerminal*(s: Token): bool {.inline.} = not isNonTerminal(s)

proc tokenize*(rawRule: string): seq[Token] =
  rawRule.split().filter((s) => not s.startsWith(" ") and s.len != 0)

proc initRule(tokens: seq[Token]): Rule =
  (tokens[0], tokens[2..tokens.len-1])

proc parseRules*(rawRules: string): Syntax =
  result = newSeq[Rule]()
  for rawRule in rawRules.splitLines:
    var tokens = rawRule.tokenize()
    if "->" in tokens:
      result.add(initRule(tokens))

# ==============================================================================

proc terminals*(self: Syntax): seq[Token] =
  result = newSeq[Token]()
  for rule in self:
    for token in rule.right:
      if token.isTerminal:
        result.add(token)
  result = result.deduplicate()

proc nonTerminals*(self: Syntax): seq[Token] =
  result = newSeq[Token]()
  for rule in self:
    result.add(rule.left)
  result = result.deduplicate()

proc tokens*(self: Syntax): seq[Token] =
  concat(self.terminals, self.nonTerminals)