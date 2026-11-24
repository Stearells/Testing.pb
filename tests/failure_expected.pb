; ============================================================================
;  Negative test: a failing assertion must report diagnostics, must not stop
;  the suite, and must still execute AfterEach.
;
;  Expected: exit code 1, exactly one [FAIL], and a passing second test.
; ============================================================================

EnableExplicit
IncludeFile "../Testing.pbi"

Suite("FailureDiagnostics")

Global g_after_ran.i

BeforeEach()
EndBeforeEach()

AfterEach()
  g_after_ran = #True
EndAfterEach()

Test(IntentionalFailure)
  AssertEqual(1, 2, "one is not two")
EndTest(IntentionalFailure)

Test(AfterEachStillRan)
  Assert(g_after_ran, "AfterEach runs after a failing test")
EndTest(AfterEachStillRan)

RunAll()
