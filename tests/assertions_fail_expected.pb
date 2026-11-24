; ============================================================================
;  Negative test: every assertion family must produce expected/actual details,
;  a description, and an exact source location.
;
;  Expected: exit code 1, all 16 tests fail, suite continues to the end.
; ============================================================================

EnableExplicit
IncludeFile "../Testing.pbi"

Structure SamplePoint
  x.i
  y.i
EndStructure

Suite("AssertionDiagnostics")

Test(EqualFails)
  AssertEqual(5, 7, "numbers")
EndTest(EqualFails)

Test(NotEqualFails)
  AssertNotEqual(3, 3, "not equal")
EndTest(NotEqualFails)

Test(BiggerFails)
  AssertBigger(1, 2, "bigger")
EndTest(BiggerFails)

Test(SmallerFails)
  AssertSmaller(3, 2, "smaller")
EndTest(SmallerFails)

Test(InRangeFails)
  AssertInRange(11, 10, 1, "range")
EndTest(InRangeFails)

Test(ApproxEqualFails)
  AssertApproxEqual(1.0, 1.1, 0.01, "approx")
EndTest(ApproxEqualFails)

Test(StrEqualFails)
  AssertStrEqual("actual", "expected", "strings")
EndTest(StrEqualFails)

Test(StrNotEqualFails)
  AssertStrNotEqual("duplicate", "duplicate", "string inequality")
EndTest(StrNotEqualFails)

Test(StrContainsFails)
  AssertStrContains("hello", "zzz", "substring")
EndTest(StrContainsFails)

Test(NullFails)
  Define *memory = AllocateMemory(8)
  AssertNull(*memory, "pointer is set")
EndTest(NullFails)

Test(NotNullFails)
  AssertNotNull(0, "pointer is null")
EndTest(NotNullFails)

Test(ListSizeFails)
  NewList actual.i()
  NewList expected.i()
  AddElement(actual()) : actual() = 1
  AssertListEqual(actual, expected, "list size")
EndTest(ListSizeFails)

Test(ListElementFails)
  NewList itemsA.i()
  NewList itemsB.i()

  AddElement(itemsA()) : itemsA() = 1
  AddElement(itemsA()) : itemsA() = 2
  AddElement(itemsB()) : itemsB() = 1
  AddElement(itemsB()) : itemsB() = 3

  AssertListEqual(itemsA, itemsB, "list element")
EndTest(ListElementFails)

Test(StrListElementFails)
  NewList wordsA.s()
  NewList wordsB.s()

  AddElement(wordsA()) : wordsA() = "one"
  AddElement(wordsA()) : wordsA() = "two"
  AddElement(wordsB()) : wordsB() = "one"
  AddElement(wordsB()) : wordsB() = "TWO"

  AssertStrListEqual(wordsA, wordsB, "string list element")
EndTest(StrListElementFails)

Test(StructureFails)
  Define left.SamplePoint
  Define right.SamplePoint

  left\x = 1  : left\y = 2
  right\x = 1 : right\y = 3

  AssertStructureEqual(left, right, SamplePoint, "structure")
EndTest(StructureFails)

Test(BooleanFails)
  Assert(1 = 2, "boolean")
EndTest(BooleanFails)

RunAll()
