#nullptr = 0
IncludeFile "../testing.pbi"

UseModule Testing

Test(OneOrTen)
    Assert(1 = 10, "One is not equal ten!")
EndTest(OneOrTen)
    

Test(MemoryPointer)
    *pMemory = 0
    Assert(*pMemory = #nullptr, "unreachable desc")
    Assert(*pMemory <> #nullptr, "Invalid memory access at address 0")
EndTest(MemoryPointer)


Test(MultiplyMagic)
    Assert(2 * 2 = 4, "unreachable desc")
EndTest(MultiplyMagic)


RunAll()
Input()
; IDE Options = PureBasic 6.10 LTS (Windows - x64)
; CursorPosition = 5
; DPIAware