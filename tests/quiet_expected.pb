; ============================================================================
;  Quiet-mode test.
;
;  Expected: exit code 1; console has no banner, no passing-test lines and no
;  [PASS] text, but keeps the failure, summary and RESULT line. The log file
;  must still contain the complete report.
; ============================================================================

#TESTING_QUIET = 1
#TESTING_LOG_FILE$ = "quiet.log"

IncludeFile "../Testing.pbi"

Suite("QuietMode")

Test(PassHidden)
  AssertEqual(1, 1)
EndTest(PassHidden)

Test(FailShown)
  AssertEqual(1, 2, "visible failure")
EndTest(FailShown)

RunAll()
