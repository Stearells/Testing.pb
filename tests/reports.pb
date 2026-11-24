; ============================================================================
;  Report generation test.
;
;  Produces JSON, JUnit XML and a log file under ./artifacts, creating that
;  directory if it does not exist. Expected: exit code 1; console decorations
;  stay ASCII while Unicode text is preserved; JSON/XML/log are valid UTF-8;
;  the log has no color escape sequences.
; ============================================================================

#TESTING_ASCII = 1
#TESTING_OUTPUT_JSON = 1
#TESTING_JSON_FILE$ = "artifacts/reports.json"
#TESTING_OUTPUT_JUNIT = 1
#TESTING_JUNIT_FILE$ = "artifacts/reports.xml"
#TESTING_LOG_FILE$ = "artifacts/reports.log"

IncludeFile "../Testing.pbi"

Suite("ReportSuite")

Test(PassPlain)
  AssertEqual(2 + 2, 4)
EndTest(PassPlain)

Test(QuotingAndUnicode)
  Define greeting.s = Chr($41F) + Chr($440) + Chr($438) + Chr($432) + Chr($435) + Chr($442)
  Define message.s = ~"quote \" slash \\ tab" + #TAB$ + "line" + #LF$ + "next " + greeting
  AssertEqual(1, 2, message)
EndTest(QuotingAndUnicode)

Test(SkippedOne)
  SkipTest("no network")
EndTest(SkippedOne)

Test(PendingOne)
  PendingTest("not implemented")
EndTest(PendingOne)

Test(ErrorOne)
  FailTest("boom & <tag>")
EndTest(ErrorOne)

Test(PassAfterError)
  AssertStrEqual("ok", "ok")
EndTest(PassAfterError)

RunAll()
