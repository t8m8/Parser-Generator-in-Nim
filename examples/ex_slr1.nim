import lrparsing/slr1
import lrparsing/parsing

when isMainModule:
  var rules = """
    S -> E
    E -> E + T
    E -> T
    T -> T * num
    T -> num
  """

  var
    s: Syntax = parseRules(rules)
    automaton = buildLR0Automaton(s)
    table = buildSLR1Table(automaton)
    parser = newParser(s, table)

  var
    input = "num * num + num * num $"
    ast = parser.parse(input).buildAST(s)

  echo automaton
  echo ast