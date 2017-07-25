import syntax, tables

type
  Action* = enum
    Shift,
    Reduce,
    Accept,
    None,

  PKey = tuple[nodeId: int, token: Token]
  PValue = tuple[action: Action, goto: int]
  ParseTable* = TableRef[PKey, PValue]

proc newParseTable*(): TableRef[PKey, PValue] =
  newTable[PKey, PValue]()