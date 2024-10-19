; CompilerIf Not #PB_Compiler_Debugger
;     OpenConsole("")
; CompilerEndIf

Module Testing
    Global NewMap testing_units.i()
    
    Procedure AddTestingUnit(*p_unit.testing_unit_t, test_name.s)
        If Not *p_unit
            Debug "Invalid test unit pointer."
            ProcedureReturn
        EndIf
        
        testing_units(test_name) = *p_unit
    EndProcedure
    
    Procedure _Run(unit_name.s)
        *pUnit.testing_unit_t = FindMapElement(testing_units(), unit_name)
        
        If Not *pUnit
            Debug "Undeclared testing unit: " + unit_name
            ProcedureReturn
        EndIf
        
        *pUnit = PeekI(*pUnit)
        ProcedureReturn *pUnit()
    EndProcedure
    
    Procedure _RunAll()
        passedCount.i = 0
        
        ForEach testing_units()
            testName.s = MapKey(testing_units())
            Debug "[TEST: " + testName + "]"
            result.i = _Run(testName)
            
            If Not result
                Debug "FAILED"
            Else
                Debug "SUCCESS"
                passedCount + 1
            EndIf
            
            Debug ""
        Next
        
        Debug Str(passedCount) + " of " + Str(MapSize(testing_units())) + " tests passed."
    EndProcedure
EndModule
; IDE Options = PureBasic 6.10 LTS (Windows - x64)
; CursorPosition = 12
; Folding = -
; DPIAware