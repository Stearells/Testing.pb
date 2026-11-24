; ============================================================================
;  NO_COLOR environment variable must override #TESTING_COLOR_ON.
;
;  The runner sets NO_COLOR=1 for this process. Forced color mode would
;  otherwise return true even without a TTY, so this check is meaningful.
;
;  Expected: exit code 0.
; ============================================================================

#TESTING_COLOR_ON = 1

IncludeFile "../Testing.pbi"

Test(EnvironmentNoColor)
  Assert(Testing::IsColorEnabled() = #False, "NO_COLOR overrides COLOR_ON")
EndTest(EnvironmentNoColor)

RunAll()
