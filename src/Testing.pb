CompilerIf Defined(Testing::TESTING_USE_CONSOLE, #PB_Constant)
    OpenConsole("")
CompilerEndIf

Module Testing
    Global NewMap testing_units.i()
    
    Procedure AddTestingUnit(*p_unit.testing_unit_t, test_name.s)
        If Not *p_unit
            CompilerIf Defined(TESTING_USE_CONSOLE, #PB_Constant)
                _printc("Invalid test unit pointer.")
            CompilerElse
                Debug "Invalid test unit pointer."
            CompilerEndIf
            
            ProcedureReturn
        EndIf
        
        testing_units(test_name) = *p_unit
    EndProcedure
    
    Procedure _Run(unit_name.s)
        *pUnit.testing_unit_t = FindMapElement(testing_units(), unit_name)
        
        If Not *pUnit
            CompilerIf Defined(TESTING_USE_CONSOLE, #PB_Constant)
                _printc("Undeclared testing unit: " + unit_name)
            CompilerElse
                Debug "Undeclared testing unit: " + unit_name
            CompilerEndIf

            ProcedureReturn
        EndIf
        
        *pUnit = PeekI(*pUnit)
        ProcedureReturn *pUnit()
    EndProcedure
    
    Procedure _RunAll()
        passedCount.i = 0
        
        ForEach testing_units()
            testName.s = MapKey(testing_units())
            _printc("[TEST: " + testName + ~"]")
            
            result.i = _Run(testName)
            state.s = ""
            c = 0
            
            If Not result
                state = "FAILED"
                c = 12
            Else
                state = "SUCCESS"
                c = 10
                passedCount + 1
            EndIf
            
            CompilerIf Defined(TESTING_USE_CONSOLE, #PB_Constant)
                Print("-> ")
                ConsoleColor(c, 0)
                PrintN(state)
                ConsoleColor(7, 0)
                PrintN("")
            CompilerElse
                Debug state
                Debug ""
            CompilerEndIf
        Next
        
        _printc(Str(passedCount) + " of " + Str(MapSize(testing_units())) + ~" tests passed.")
    EndProcedure
EndModule
; IDE Options = PureBasic 6.10 LTS (Windows - x64)
; CursorPosition = 59
; FirstLine = 40
; Folding = --
; DPIAware