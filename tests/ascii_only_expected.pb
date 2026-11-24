; ============================================================================
;  ASCII-only output test.
;
;  Expected: exit code 1, and every byte written to the console is < 128.
;  The suite deliberately contains one failure so that diagnostics are covered.
; ============================================================================

#TESTING_ASCII = 1

IncludeFile "../Testing.pbi"

Suite("AsciiOnly")

Test(PassAscii)
  AssertEqual(1, 1)
EndTest(PassAscii)

Test(FailAscii)
  AssertEqual(1, 2, "plain ascii description")
EndTest(FailAscii)

RunAll()
