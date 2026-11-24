; ============================================================================
;  Unicode decoration mode: separators use U+2500 and color is disabled so
;  the raw bytes are stable for byte-level checks.
;
;  A log file is enabled on purpose: configuring a log must not downgrade the
;  console or the log to ASCII decorations.
;
;  Expected: exit code 0, UTF-8 encoded U+2500 in the console and the log, and
;  a UTF-8 log without BOM.
; ============================================================================

#TESTING_UNICODE = 1
#TESTING_COLOR_OFF = 1
#TESTING_LOG_FILE$ = "unicode/unicode.log"

IncludeFile "../Testing.pbi"

Test(UnicodeSeparators)
  AssertEqual(1 + 1, 2)
EndTest(UnicodeSeparators)

RunAll()
