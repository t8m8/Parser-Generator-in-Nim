import lrparsing/lr1
import lrparsing/parsing

when isMainModule:
  var rules = """
    S -> A
    A -> E = E
    A -> id
    E -> E + T
    E -> T
    T -> id
    T -> num
  """

  var
    s: Syntax = parseRules(rules)
    automaton = buildLR0Automaton(s)
    table = buildLR1Table(automaton)
    parser = newParser(s, table)

  var
    input = "id + num = num + id $"
    ast = parser.parse(input).buildAST(s)

  echo automaton
  echo ast