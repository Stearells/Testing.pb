; Assertion showcase. Every assertion in this file passes.
EnableExplicit
IncludeFile "../../Testing.pbi"

Structure Point3D
  x.i
  y.i
  z.i
  label.s
EndStructure

Test(Numeric)
  Define value.i = 7
  Define large.q = 5000000000

  Assert(value = 7)
  AssertEqual(value, 7)
  AssertNotEqual(value, 8)
  AssertBigger(value, 6)
  AssertSmaller(value, 8)
  AssertInRange(value, 10, 1)
  AssertEqual(large, 5000000000)
EndTest(Numeric)

Test(FloatingPoint)
  AssertApproxEqual(0.1 + 0.2, 0.3, 0.000001, "standard double tolerance")
EndTest(FloatingPoint)

Test(Strings)
  Define text.s = "Testing.pb"
  AssertStrEqual(text, "Testing.pb")
  AssertStrNotEqual(text, "testing.pb")
  AssertStrContains(text, "Testing")
EndTest(Strings)

Test(Lists)
  NewList actual.i()
  NewList expected.i()

  AddElement(actual())   : actual()   = 1
  AddElement(actual())   : actual()   = 2
  AddElement(expected()) : expected() = 1
  AddElement(expected()) : expected() = 2

  AssertListEqual(actual, expected, "integer lists")

  NewList namesA.s()
  NewList namesB.s()
  AddElement(namesA()) : namesA() = "one"
  AddElement(namesB()) : namesB() = "one"
  AssertStrListEqual(namesA, namesB, "string lists")
EndTest(Lists)

Test(Structures)
  Define first.Point3D
  Define second.Point3D

  first\x = 1   : first\y = 2   : first\z = 3   : first\label = "A"
  second\x = 1  : second\y = 2  : second\z = 3  : second\label = "A"

  AssertStructureEqual(first, second, Point3D, "same structure contents")
EndTest(Structures)

Test(Pointers)
  Define *buffer = AllocateMemory(64)
  AssertNotNull(*buffer)
  FreeMemory(*buffer)
  AssertNull(*buffer - *buffer)
EndTest(Pointers)

RunAll()
