; Minimal example: Test() -> assertions -> EndTest() -> RunAll().
EnableExplicit
IncludeFile "../../Testing.pbi"

Test(Addition)
  AssertEqual(2 + 2, 4)
EndTest(Addition)

Test(Greeting)
  Define greeting.s = "Hello, PureBasic"
  AssertStrEqual(greeting, "Hello, PureBasic")
  AssertStrContains(greeting, "PureBasic")
EndTest(Greeting)

RunAll()
