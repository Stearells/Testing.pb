IncludeFile "../testing.pbi"
UseModule Testing

#nullptr = 0

Test(OneOrTen)
    Assert(Bool(Not 1 = 10), "One is not equal ten!")
EndTest(OneOrTen)
    

Test(Assert_MemoryPointer)
    *pMemory = 0
    Assert(*pMemory = #nullptr, "unreachable desc")
    Assert(Bool(Not *pMemory <> #nullptr), "Invalid memory access at address 0")
EndTest(Assert_MemoryPointer)


Test(Assert_MultiplyMagic)
    Assert(2 * 2 = 4, "unreachable desc")
EndTest(Assert_MultiplyMagic)


Test(Assert_Const)
    Assert(Bool(Not #False))
EndTest(Assert_Const)
    

Test(Assert_Const2)
    Assert(#True)
EndTest(Assert_Const2)


Test(AssertEqualInt)
    AssertEqual(1, 1)
EndTest(AssertEqualInt)
    

Test(AssertEqualStr)
    AssertEqual("hello", "hello")
EndTest(AssertEqualStr)


Test(AssertEqualConst)
    AssertEqual(#Null, #nullptr)
EndTest(AssertEqualConst)


Test(AssertBiggerThan)
    AssertBigger(30, 20)
EndTest(AssertBiggerThan)
    

Test(AssertSmallerThan)
    AssertSmaller(20, 30)
EndTest(AssertSmallerThan)


Test(AssertRange)
    AssertInRange(2, 4, 1)
EndTest(AssertRange)

RunAll()
Input()
; IDE Options = PureBasic 6.10 LTS (Windows - x64)
; CursorPosition = 60
; FirstLine = 31
; DPIAware