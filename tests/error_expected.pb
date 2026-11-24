; ============================================================================
;  Negative test: FailTest() records an "error" status, with message and
;  source location, and the remaining tests still run.
;
;  Expected: exit code 1, one [ERR], one [PASS].
; ============================================================================

EnableExplicit
IncludeFile "../Testing.pbi"

Suite("ErrorDiagnostics")

Test(IntentionalError)
  FailTest("deliberate error")
EndTest(IntentionalError)

Test(RecoveryAfterError)
  AssertEqual(2 + 2, 4)
EndTest(RecoveryAfterError)

RunAll()
