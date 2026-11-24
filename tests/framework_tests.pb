; ============================================================================
;  Framework self-tests (positive path)
;
;  This suite must compile and exit with code 0. Skipped and pending tests are
;  intentional and do not affect the exit code.
; ============================================================================

EnableExplicit
IncludeFile "../Testing.pbi"

Suite("FrameworkSelfTests")

Structure SamplePoint
  x.i
  y.i
  label.s
EndStructure

Global g_before_count.i
Global g_after_count.i

BeforeEach()
  g_before_count + 1
EndBeforeEach()

AfterEach()
  g_after_count + 1
EndAfterEach()

Test(HookOrderAndIsolation)
  ; BeforeEach of the current test has already run, AfterEach has not.
  AssertEqual(g_before_count, g_after_count + 1, "hooks are paired per test")
  Assert(g_before_count >= 1)
EndTest(HookOrderAndIsolation)

Test(NumericAssertions)
  Define small.i = 42
  Define big.q = 9000000000

  AssertEqual(small, 42)
  AssertNotEqual(small, 43)
  AssertBigger(small, 41)
  AssertSmaller(small, 43)
  AssertInRange(small, 50, 40)
  AssertEqual(big, 9000000000)
  Assert(2 + 2 = 4, "arithmetic still works")
EndTest(NumericAssertions)

Test(StringAssertions)
  Define text.s = "PureBasic"
  AssertStrEqual(text, "PureBasic")
  AssertStrNotEqual(text, "purebasic")
  AssertStrContains(text, "Basic")
EndTest(StringAssertions)

Test(FloatAssertions)
  AssertApproxEqual(0.1 + 0.2, 0.3, 0.000001, "floating point tolerance")
  AssertApproxEqual(2.5, 2.5, 0.0)
EndTest(FloatAssertions)

Test(ListAssertions)
  NewList actual.i()
  NewList expected.i()

  AddElement(actual())   : actual()   = 10
  AddElement(actual())   : actual()   = 20
  AddElement(expected()) : expected() = 10
  AddElement(expected()) : expected() = 20

  SelectElement(actual(), 1)
  AssertListEqual(actual, expected, "numeric lists")
  AssertEqual(ListIndex(actual()), 1, "assertion restores the current element")

  NewList namesA.s()
  NewList namesB.s()

  AddElement(namesA()) : namesA() = "alpha"
  AddElement(namesA()) : namesA() = "beta"
  AddElement(namesB()) : namesB() = "alpha"
  AddElement(namesB()) : namesB() = "beta"

  AssertStrListEqual(namesA, namesB, "string lists")
EndTest(ListAssertions)

Test(StructureAssertions)
  Define left.SamplePoint
  Define right.SamplePoint

  left\x = 3   : left\y = 4   : left\label = "same"
  right\x = 3  : right\y = 4  : right\label = "same"

  AssertStructureEqual(left, right, SamplePoint, "equal structures")
EndTest(StructureAssertions)

Test(PointerAssertions)
  Define *memory = AllocateMemory(16)
  AssertNotNull(*memory)
  AssertNull(*memory - *memory)
  FreeMemory(*memory)
EndTest(PointerAssertions)

Test(EscapingHelpers)
  AssertStrEqual(Testing::#TESTING_VERSION$, "1.0.0")

  ; Quote, backslash, newline and tab must become JSON escapes.
  Define raw.s = ~"a\"b\\c" + #LF$ + #TAB$ + "x"
  Define escaped.s = Testing::JsonEscape(raw)
  AssertStrEqual(escaped, ~"a\\\"b\\\\c\\n\\tx")
  AssertStrEqual(Testing::JsonEscapeString(raw), escaped)
  AssertStrEqual(Testing::JsonEscape(Chr(1)), ~"\\u0001")

  AssertStrEqual(Testing::XmlEscapeString(~"a&b<c>\"d'"),
                 "a&amp;b&lt;c&gt;&quot;d&apos;")
  AssertStrEqual(Testing::XmlEscapeString(Chr(1)), " ")

  ; Non-ASCII text must be left untouched.
  Define unicodeText.s = Chr($41F) + Chr($440) + Chr($438) + Chr($432) + Chr($435) + Chr($442)
  AssertStrEqual(Testing::JsonEscape(unicodeText), unicodeText)
EndTest(EscapingHelpers)

Test(PublicColorHelpers)
  Testing::SetColor(Testing::#TESTING_COLOR_PASS)
  Testing::ResetColor()
  Assert(#True)
EndTest(PublicColorHelpers)

Test(SkippedByDesign)
  AssertEqual(g_before_count, g_after_count + 1, "hooks before skip")
  SkipTest("intentional skip")
  Assert(#False, "unreachable")
EndTest(SkippedByDesign)

Test(PendingByDesign)
  AssertEqual(g_before_count, g_after_count + 1, "hooks before pending")
  PendingTest("intentional pending")
  Assert(#False, "unreachable")
EndTest(PendingByDesign)

Test(HooksContinueAfterSpecialStatus)
  AssertEqual(g_before_count, g_after_count + 1, "hooks after skip/pending")
EndTest(HooksContinueAfterSpecialStatus)

RunAll()
