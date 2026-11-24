; ============================================================================
;  Verbose-mode test.
;
;  Expected: exit code 1; every failure detail is printed on its own labelled
;  line, hook execution is traced, and skip reasons are rendered.
; ============================================================================

#TESTING_VERBOSE = 1

IncludeFile "../Testing.pbi"

Suite("VerboseMode")

BeforeEach()
EndBeforeEach()

AfterEach()
EndAfterEach()

Test(VerboseFailure)
  AssertEqual(5, 7, "Integer division")
EndTest(VerboseFailure)

Test(VerboseSkip)
  SkipTest("why not")
EndTest(VerboseSkip)

RunAll()
