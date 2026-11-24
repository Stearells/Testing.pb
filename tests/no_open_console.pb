; ============================================================================
;  Embedding scenario: the host owns the console and calls OpenConsole()
;  itself, so the framework must not open it again.
;
;  Expected: exit code 0, normal output and a passing result.
; ============================================================================

#TESTING_NO_OPEN_CONSOLE = 1
#TESTING_SUITE$ = "CustomHost"

OpenConsole()
IncludeFile "../Testing.pbi"

Test(HostOpenedConsole)
  AssertEqual(6 * 6, 36)
EndTest(HostOpenedConsole)

RunAll()
