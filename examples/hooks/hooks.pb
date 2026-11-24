; Lifecycle hooks: set up before every test and tear down even after failure.
EnableExplicit
IncludeFile "../../Testing.pbi"

Global g_connection.i
Global g_teardowns.i

BeforeEach()
  g_connection = 1
EndBeforeEach()

AfterEach()
  g_connection = 0
  g_teardowns + 1
EndAfterEach()

Test(FirstUsesConnection)
  Assert(g_connection = 1, "BeforeEach opened the connection")
  AssertEqual(g_teardowns, 0)
EndTest(FirstUsesConnection)

Test(SecondUsesFreshConnection)
  Assert(g_connection = 1, "BeforeEach reopened the connection")
  AssertEqual(g_teardowns, 1, "AfterEach ran for the previous test")
EndTest(SecondUsesFreshConnection)

RunAll()
