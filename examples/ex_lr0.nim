import lrparsing/lr0
import lrparsing/parsing

when isMainModule:
  var rules = """
    S -> E
    E -> E + num
    E -> E * num
    E -> num
  """

  var
    s: Syntax = parseRules(rules)
    automaton = buildLR0Automaton(s)
    table = buildLR0Table(automaton)
    parser = newParser(s, table)

  var
    input = "num + num * num * num $"
    ast = parser.parse(input).buildAST(s)

  echo automaton
  echo ast