
##Features
- Supports + - * / operations
- Brackets () also work
- Detects overflows


##BNF for calculator:

    calculation ::= term("+"|"-" term)*
    term ::= number("*"|"/" number)*
    number ::= ("0"|"1"|"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9")+ | "(" calculation ")"
