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
        
        Testing::AddTestingUnit(@TestName#_testingunit_(), __qot#TestName#__qot#)
    EndMacro
    
    Macro Run(TestName)
        Testing::_Run(__qot#TestName#__qot)
    EndMacro
    
    Macro RunAll()
        Testing::_RunAll()
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
EndDeclareModule

IncludeFile "testing.pb"
; IDE Options = PureBasic 6.10 LTS (Windows - x64)
; CursorPosition = 63
; FirstLine = 40
; Folding = --
; DPIAware