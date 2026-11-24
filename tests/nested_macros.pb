; ============================================================================
;  Macro composition test.
;
;  Expected: exit code 0. Assertion macros must work inside user macros,
;  conditions and loops.
; ============================================================================

EnableExplicit
IncludeFile "../Testing.pbi"

Suite("MacroComposition")

Macro ExpectOne(value)
  AssertEqual(value, 1, "nested assertion macro")
EndMacro

Procedure.i AddOne(value.i)
  ProcedureReturn value + 1
EndProcedure

Test(NestedMacrosInControlFlow)
  Define flag.i = 1
  Define index.i

  If flag = 1
    ExpectOne(1)
  Else
    Assert(#False, "unexpected branch")
  EndIf

  For index = 1 To 3
    ExpectOne(1)
  Next index

  If Not (flag = 0)
    AssertEqual(AddOne(1), 2, "procedure call inside assertion")
  EndIf
EndTest(NestedMacrosInControlFlow)

RunAll()
