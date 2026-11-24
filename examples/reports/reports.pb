; Machine-readable reports. Run this example from a writable directory; it
; creates example-results.json, example-results.xml and example.log there.
#TESTING_OUTPUT_JSON = 1
#TESTING_JSON_FILE$ = "example-results.json"
#TESTING_OUTPUT_JUNIT = 1
#TESTING_JUNIT_FILE$ = "example-results.xml"
#TESTING_LOG_FILE$ = "example.log"

IncludeFile "../../Testing.pbi"

Suite("ReportsExample")

Test(PassingTest)
  AssertEqual(6 * 7, 42)
EndTest(PassingTest)

Test(SkippedFeature)
  SkipTest("requires a database server")
EndTest(SkippedFeature)

Test(PendingFeature)
  PendingTest("planned for the next release")
EndTest(PendingFeature)

RunAll()
