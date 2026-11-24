; ============================================================================
;  Public API surface test.
;
;  Expected: exit code 0. The module can be opened with UseModule and the
;  documented helpers and constants are reachable.
; ============================================================================

EnableExplicit
IncludeFile "../Testing.pbi"

UseModule Testing

Suite("ApiSurface")

Test(ModuleHelpers)
  AssertStrEqual(#TESTING_VERSION$, "1.0.0")

  SetColor(#TESTING_COLOR_PASS)
  ResetColor()

  AssertStrEqual(JsonEscape(~"a\"b"), ~"a\\\"b")
  AssertStrEqual(JsonEscapeString("a" + Chr(9) + "b"), ~"a\\tb")
  AssertStrEqual(XmlEscapeString("a&b"), "a&amp;b")

  ; Prepare is idempotent and safe to call from user code.
  Prepare()
EndTest(ModuleHelpers)

RunAll()
