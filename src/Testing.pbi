IncludeFile "printc.pbi"

DeclareModule Testing
    #TESTING_USE_CONSOLE = #True
    
    Prototype testing_unit_t()
    
    Macro __qot
        "
    EndMacro
    
    Macro Test(TestName)
        CompilerIf Defined(TestName#_testingunit_, #PB_Procedure)
            CompilerError "Test '" + __qot#TestName#__qot + "' is already defined."
        CompilerEndIf
        
        Procedure TestName#_testingunit_()
    EndMacro
        
    Macro EndTest(TestName)
        CompilerIf Not Defined(TestName#_testingunit_, #PB_Procedure)
             CompilerError "Test '" + __qot#TestName#__qot# + "' is Not defined, use Test(" + __qot#TestName#__qot# + ") To Define."
        CompilerEndIf
         
        ProcedureReturn #True
        EndProcedure
        
        AddTestingUnit(@TestName#_testingunit_(), __qot#TestName#__qot#)
    EndMacro
    
    Macro Run(TestName)
        _Run(__qot#TestName#__qot)
    EndMacro
    
    Macro RunAll()
        _RunAll()
    EndMacro
    
    Macro _printc(text)
        CompilerIf Defined(TESTING_USE_CONSOLE, #PB_Constant)
            PrintC::printc(text)
        CompilerElse
            Debug text
        CompilerEndIf
    EndMacro
    
    Declare AddTestingUnit(*p_unit.testing_unit_t, test_name.s)
    Declare _Run(unit_name.s)
    Declare _RunAll()
    
    ; assertion
    Macro Assert(expression, description = "")
        If Not expression
            If Len(description)
                _printc("Assertion failed: Assert(" + __qot#expression#__qot + ") at line " + Str(#PB_Compiler_Line) + " (" + description + ")")
            EndIf
            
            ProcedureReturn #False
        EndIf
    EndMacro
    
    Macro AssertEqual(a, b, description = "")
        If Not a = b
            If Len(description)
                _printc("Assertion failed: AssertEqual(" + a + " = " + b + ") at line " + Str(#PB_Compiler_Line) + " (" + description + ")")
            EndIf
            
            ProcedureReturn #False
        EndIf
    EndMacro
    
    Macro AssertBigger(a, b, description = "")
        If Not a > b
            If Len(description)
                _printc("Assertion failed: AssertBigger(" + a + " > " + b + ") at line " + Str(#PB_Compiler_Line) + " (" + description + ")")
            EndIf
            
            ProcedureReturn #False
        EndIf
    EndMacro
    
    Macro AssertSmaller(a, b, description = "")
        If Not a < b
            If Len(description)
                _printc("Assertion failed: AssertSmaller(" + a + " < " + b + ") at line " + Str(#PB_Compiler_Line) + " (" + description + ")")
            EndIf
            
            ProcedureReturn #False
        EndIf
    EndMacro
    
    Macro AssertInRange(a, max, min = 0, description = "")
        If a < min Or a > max
            If Len(description)
                _printc("Assertion failed: AssertInRange(" + a + " [Range: " + min + ", " + max + "]) at line " + Str(#PB_Compiler_Line) + " (" + description + ")")
            EndIf
            
            ProcedureReturn #False
        EndIf
    EndMacro
    
EndDeclareModule

IncludeFile "testing.pb"
; IDE Options = PureBasic 6.10 LTS (Windows - x64)
; CursorPosition = 93
; FirstLine = 72
; Folding = ---
; DPIAware