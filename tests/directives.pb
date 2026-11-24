; ============================================================================
;  Directive coverage: suite name, default JSON/JUnit paths, progress and
;  forced no-color.
;
;  Expected: exit code 0, suite name from #TESTING_SUITE$, reports written to
;  the documented default file names, no progress marker when not a TTY.
; ============================================================================

#TESTING_SUITE$ = "DirectiveSuite"
#TESTING_PROGRESS = 1
#TESTING_COLOR_OFF = 1
#TESTING_OUTPUT_JSON = 1
#TESTING_OUTPUT_JUNIT = 1

IncludeFile "../Testing.pbi"

Test(DefaultPathsAndSuite)
  AssertEqual(3 + 4, 7)
EndTest(DefaultPathsAndSuite)

Test(SkipStillCounts)
  SkipTest("not applicable here")
EndTest(SkipStillCounts)

RunAll()
