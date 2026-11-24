; ============================================================================
;  Repeatability test: RunAll(#False) can be called twice in one process.
;
;  Expected: exit code 0 and two complete reports in the output.
; ============================================================================

EnableExplicit
IncludeFile "../Testing.pbi"

Global g_runs.i

Test(Repeatable)
  g_runs + 1
  AssertEqual(1, 1)
EndTest(Repeatable)

Define firstRun.i = RunAll(#False)
Define secondRun.i = RunAll(#False)

If firstRun And secondRun And g_runs = 2
  End 0
Else
  End 1
EndIf
