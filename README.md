# PureBasic Unit Testing Framework: Testing.pb

A simple unit testing framework implementation in PureBasic.

## Overview

This repository contains a basic unit testing library (`Testing.pbi`) and its implementation (`Testing.pb`). The framework allows you to define, run, and assert test cases easily within your PureBasic applications.

## Features

- **Test Definition**: Use `Test()` and `EndTest()` macros to define individual tests.
- **Assertions**: Includes several assertion macros for checking conditions:
  - `Assert(expression, description)`
  - `AssertEqual(a, b, description)`
  - `AssertBigger(a, b, description)`
  - `AssertSmaller(a, b, description)`
  - `AssertInRange(a, max, min=0, description)`
- **Test Execution**: Provides macros to run specific tests or all defined tests:
  - `Run(test_name)`
  - `RunAll()`
- **Console/Debug Output**: Supports both console and debug output modes.

## Usage

1. Include the library in your project:  
```purebasic
IncludeFile "Testing.pbi"

; Define a test using macros:
Test(MyTest)
    ; Your test code here
    Assert(5 = 5, "Basic equality check")
EndTest(MyTest)
```

2. Run tests:

To run all tests:
```RunAll()```

To run a specific test:
```Run("MyTest")```

**Example**:
```purebasic
IncludeFile "Testing.pbi"

Test(SimpleAddition)
  result.i = 4 + 3
  AssertEqual(result, 7, "Adding 3 and 4 should give 7")
EndTest(SimpleAddition)

Test(NegativeCheck)
  AssertBigger(-5, -10, "Negative numbers comparison")
EndTest(NegativeCheck)

RunAll()
```

## Compilation Notes
The framework uses compiler directives for conditional compilation:
Define TESTING_USE_CONSOLE to enable console output mode.

## Limitations
This is a basic testing framework suitable for simple unit tests. It does not include features like:

Skipping tests

Marking tests as pending

Generating test reports

Comparing floating-point numbers precisely

etc.
