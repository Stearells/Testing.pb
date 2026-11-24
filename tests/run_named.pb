; ============================================================================
;  Single-test runner test.
;
;  Expected: exit code 0, report contains only the selected test and shows
;  total = 1.
; ============================================================================

EnableExplicit
IncludeFile "../Testing.pbi"

Suite("RunSelected")

Test(FirstTest)
  AssertEqual(1, 1)
EndTest(FirstTest)

Test(SecondTest)
  AssertEqual(2, 2)
EndTest(SecondTest)

Define ok.i = Run(SecondTest)

If ok
  End 0
Else
  End 1
EndIf
