; ============================================================================
;  Directive conflict: #TESTING_NO_COLOR must win over #TESTING_COLOR_ON.
;
;  Expected: exit code 0, color disabled, normal ASCII output.
; ============================================================================

#TESTING_NO_COLOR = 1
#TESTING_COLOR_ON = 1

IncludeFile "../Testing.pbi"

Test(NoColorHasPriority)
  Assert(Testing::IsColorEnabled() = #False, "NO_COLOR wins over COLOR_ON")
EndTest(NoColorHasPriority)

RunAll()
