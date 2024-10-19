Module PrintC
    Global NewMap tokens.i()
    tokens("text") = CreateRegularExpression(#PB_Any, "[A-Za-z]")
    tokens("number") = CreateRegularExpression(#PB_Any, "[0-9]")
    tokens("block") = CreateRegularExpression(#PB_Any, "[\[\]\(\){}]")
    
    Procedure printc(text.s)
        For i = 1 To Len(text)
            sym.s = Mid(text, i, 1)
            token.s = ""
            
            ForEach tokens()
                If MatchRegularExpression(tokens(), sym)
                    token = MapKey(tokens())
                    Break
                EndIf
            Next
            
            Select token
                Case "text"
                    ConsoleColor(7, 0)
                Case "number"
                    ConsoleColor(14, 0)
                Case "block"
                    ConsoleColor(5, 0)
                Default
                    ConsoleColor(8, 0)
            EndSelect
            
            Print(sym)
            ConsoleColor(7, 0)
        Next i
    EndProcedure
EndModule
; IDE Options = PureBasic 6.10 LTS (Windows - x64)
; CursorPosition = 33
; FirstLine = 9
; Folding = -
; DPIAware