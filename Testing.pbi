; ============================================================================
;  Testing.pb - a self-contained unit-testing framework for PureBasic
;  Version 1.0.0
;
;  Single includable file. No modules to install, no external dependencies.
;  Include it before your tests:
;  
;  Stearells
; ============================================================================

CompilerIf Defined(TESTING_PB_INCLUDED, #PB_Constant)
  CompilerError "Testing.pbi is already included (TESTING_PB_INCLUDED)."
CompilerEndIf
#TESTING_PB_INCLUDED = #True

Macro __TESTING_QUOTE
  "
EndMacro

; ----------------------------------------------------------------------------
;  Declarations
; ----------------------------------------------------------------------------

DeclareModule Testing

  #TESTING_VERSION$ = "1.0.0"

  #TESTING_STATUS_RUNNING = 0
  #TESTING_STATUS_PASSED  = 1
  #TESTING_STATUS_FAILED  = 2
  #TESTING_STATUS_SKIPPED = 3
  #TESTING_STATUS_PENDING = 4
  #TESTING_STATUS_ERROR   = 5

  #TESTING_COLOR_DEFAULT  = 0
  #TESTING_COLOR_PASS     = 1
  #TESTING_COLOR_FAIL     = 2
  #TESTING_COLOR_SKIP     = 3
  #TESTING_COLOR_PENDING  = 4
  #TESTING_COLOR_HEADER   = 5
  #TESTING_COLOR_NAME     = 6
  #TESTING_COLOR_DIM      = 7
  #TESTING_COLOR_OK       = 8
  #TESTING_COLOR_ERROR    = 9

  Structure TestingResult
    name.s
    status.i
    duration_ms.i
    message.s
    description.s
    expected.s
    actual.s
    file.s
    line.i
    has_expected.i
    has_actual.i
  EndStructure

  Structure TestingSuiteResult
    name.s
    List tests.TestingResult()
    total.i
    passed.i
    failed.i
    skipped.i
    pending.i
    errors.i
    duration_ms.i
  EndStructure

  Prototype.i TestingProc()

  Declare.i AddTest(*proc.TestingProc, name.s)
  Declare.i SetBeforeEach(*proc.TestingProc)
  Declare.i SetAfterEach(*proc.TestingProc)
  Declare.i SetSuiteName(name.s)
  Declare Prepare()

  Declare ConfigureQuiet()
  Declare ConfigureVerbose()
  Declare ConfigureProgress()
  Declare SetAsciiMode(ascii_mode.i)
  Declare SetColorMode(color_mode.i)
  Declare SetLogFile(path.s)
  Declare EnableJSON(path.s)
  Declare EnableJUnit(path.s)
  Declare SetOpenConsole(enabled.i)
  Declare.i IsColorEnabled()

  Declare.i RunAllNow(exit_after.i)
  Declare.i RunNamed(name.s)

  Declare.i FailAssert(assert_name.s, expected.s, actual.s, description.s, file.s, line.i, has_expected.i)
  Declare.i FailListEqual(list_name.s, size_actual.i, size_expected.i, at_index.i, description.s, file.s, line.i)
  Declare.i SkipCurrent(reason.s, file.s, line.i)
  Declare.i PendingCurrent(reason.s, file.s, line.i)
  Declare.i ErrorCurrent(message.s, file.s, line.i)

  Declare.s JsonEscape(s.s)
  Declare   SetColor(kind.i)
  Declare   ResetColor()

  Declare.s JsonEscapeString(s.s)
  Declare.s XmlEscapeString(s.s)

EndDeclareModule

; ----------------------------------------------------------------------------
;  Implementation
; ----------------------------------------------------------------------------

Module Testing

  Declare __Init()

  ; --- registration ---------------------------------------------------------
  Structure __TestRegistration
    proc.TestingProc
    name.s
  EndStructure

  Global NewList g_tests.__TestRegistration()
  Global g_before.TestingProc
  Global g_after.TestingProc

  ; --- suite model ----------------------------------------------------------
  Global g_suite.TestingSuiteResult
  Global *g_current.TestingResult

  ; --- runtime configuration ------------------------------------------------
  Global g_initialized.i
  Global g_color.i
  Global g_ascii.i
  Global g_width.i
  Global g_tty.i
  Global g_quiet.i
  Global g_verbose.i
  Global g_progress.i
  Global g_mute.i
  Global g_log.i
  Global g_log_open.i

  Global g_color_mode.i = -1
  Global g_ascii_mode.i = 1
  Global g_open_console.i = 1
  Global g_log_file.s = ""
  Global g_json_enabled.i = 0
  Global g_json_file.s = ""
  Global g_junit_enabled.i = 0
  Global g_junit_file.s = ""

  ; ==========================================================================
  ;  Platform helpers
  ; ==========================================================================

  CompilerIf #PB_Compiler_OS = #PB_OS_Windows

    Structure __TestingCoord
      x.w
      y.w
    EndStructure

    Structure __TestingSmallRect
      Left.w
      Top.w
      Right.w
      Bottom.w
    EndStructure

    Structure __TestingConsoleInfo
      dwSize.__TestingCoord
      dwCursorPosition.__TestingCoord
      wAttributes.w
      srWindow.__TestingSmallRect
      dwMaximumWindowSize.__TestingCoord
    EndStructure

    Procedure.i __IsTTY()
      Protected mode.i
      ProcedureReturn Bool(GetConsoleMode_(GetStdHandle_(#STD_OUTPUT_HANDLE), @mode) <> 0)
    EndProcedure

    Procedure.i __ConsoleWidth()
      Protected info.__TestingConsoleInfo
      If GetConsoleScreenBufferInfo_(GetStdHandle_(#STD_OUTPUT_HANDLE), @info) <> 0
        ProcedureReturn info\srWindow\Right - info\srWindow\Left + 1
      EndIf
      ProcedureReturn 0
    EndProcedure

  CompilerElseIf #PB_Compiler_OS = #PB_OS_Linux Or #PB_Compiler_OS = #PB_OS_MacOS

    ImportC ""
      isatty(fd.i)
      ioctl(fd.i, request.i, *arg)
    EndImport

    Structure __TestingWinSize
      ws_row.w
      ws_col.w
      ws_xpixel.w
      ws_ypixel.w
    EndStructure

    CompilerIf #PB_Compiler_OS = #PB_OS_Linux
      #__TESTING_TIOCGWINSZ = $5413
    CompilerElse
      #__TESTING_TIOCGWINSZ = $40087468
    CompilerEndIf

    Procedure.i __IsTTY()
      ProcedureReturn Bool(isatty(1) <> 0)
    EndProcedure

    Procedure.i __ConsoleWidth()
      Protected ws.__TestingWinSize
      If ioctl(1, #__TESTING_TIOCGWINSZ, @ws) = 0
        ProcedureReturn ws\ws_col
      EndIf
      ProcedureReturn 0
    EndProcedure

  CompilerElse

    Procedure.i __IsTTY()
      ProcedureReturn #False
    EndProcedure

    Procedure.i __ConsoleWidth()
      ProcedureReturn 0
    EndProcedure

  CompilerEndIf

  ; ==========================================================================
  ;  Small string helpers
  ; ==========================================================================

  Procedure.s __RepeatChar(ch.s, count.i)
    If count <= 0
      ProcedureReturn ""
    EndIf
    ProcedureReturn RSet("", count, ch)
  EndProcedure

  Procedure.i __IsHighSurrogate(c.i)
    ProcedureReturn Bool(c >= $D800 And c <= $DBFF)
  EndProcedure

  Procedure.s __SafeLeft(s.s, count.i)
    If count <= 0
      ProcedureReturn ""
    EndIf
    If count >= Len(s)
      ProcedureReturn s
    EndIf
    If __IsHighSurrogate(Asc(Mid(s, count, 1)))
      count - 1
    EndIf
    ProcedureReturn Left(s, count)
  EndProcedure

  Procedure.s __FitString(s.s, width.i)
    If width <= 0
      ProcedureReturn ""
    EndIf
    If Len(s) <= width
      ProcedureReturn s
    EndIf
    If width <= 3
      ProcedureReturn __SafeLeft(s, width)
    EndIf
    ProcedureReturn __SafeLeft(s, width - 3) + "..."
  EndProcedure

  Procedure.s __OneLine(s.s)
    Protected r.s = s
    r = ReplaceString(r, #CRLF$, ~"\\n")
    r = ReplaceString(r, #CR$, ~"\\n")
    r = ReplaceString(r, #LF$, ~"\\n")
    r = ReplaceString(r, #TAB$, ~"\\t")
    ProcedureReturn r
  EndProcedure

  Procedure.s __QuotedDisplay(s.s)
    Protected r.s = __OneLine(s)
    r = ReplaceString(r, ~"\"", ~"\\\"")
    ProcedureReturn ~"\"" + r + ~"\""
  EndProcedure

  Procedure.s __Seconds(ms.i)
    Protected whole.i = ms / 1000
    Protected frac.i = ms % 1000
    If frac < 0 : frac = -frac : EndIf
    ProcedureReturn Str(whole) + "." + RSet(Str(frac), 3, "0")
  EndProcedure

  Procedure.s __StatusName(status.i)
    Select status
      Case #TESTING_STATUS_PASSED  : ProcedureReturn "passed"
      Case #TESTING_STATUS_FAILED  : ProcedureReturn "failed"
      Case #TESTING_STATUS_SKIPPED : ProcedureReturn "skipped"
      Case #TESTING_STATUS_PENDING : ProcedureReturn "pending"
      Case #TESTING_STATUS_ERROR   : ProcedureReturn "error"
    EndSelect
    ProcedureReturn "error"
  EndProcedure

  Procedure.s __StatusTag(status.i)
    Select status
      Case #TESTING_STATUS_PASSED  : ProcedureReturn "[PASS]"
      Case #TESTING_STATUS_FAILED  : ProcedureReturn "[FAIL]"
      Case #TESTING_STATUS_SKIPPED : ProcedureReturn "[SKIP]"
      Case #TESTING_STATUS_PENDING : ProcedureReturn "[PEND]"
      Case #TESTING_STATUS_ERROR   : ProcedureReturn "[ERR]"
    EndSelect
    ProcedureReturn "[ERR]"
  EndProcedure

  Procedure.i __StatusColor(status.i)
    Select status
      Case #TESTING_STATUS_PASSED  : ProcedureReturn #TESTING_COLOR_PASS
      Case #TESTING_STATUS_FAILED  : ProcedureReturn #TESTING_COLOR_FAIL
      Case #TESTING_STATUS_SKIPPED : ProcedureReturn #TESTING_COLOR_SKIP
      Case #TESTING_STATUS_PENDING : ProcedureReturn #TESTING_COLOR_PENDING
      Case #TESTING_STATUS_ERROR   : ProcedureReturn #TESTING_COLOR_ERROR
    EndSelect
    ProcedureReturn #TESTING_COLOR_ERROR
  EndProcedure

  ; ==========================================================================
  ;  Color handling
  ; ==========================================================================

  Procedure.i __ConsoleColorFor(kind.i)
    Select kind
      Case #TESTING_COLOR_PASS    : ProcedureReturn 10
      Case #TESTING_COLOR_FAIL    : ProcedureReturn 12
      Case #TESTING_COLOR_SKIP    : ProcedureReturn 14
      Case #TESTING_COLOR_PENDING : ProcedureReturn 11
      Case #TESTING_COLOR_HEADER  : ProcedureReturn 15
      Case #TESTING_COLOR_NAME    : ProcedureReturn 15
      Case #TESTING_COLOR_DIM     : ProcedureReturn 8
      Case #TESTING_COLOR_OK      : ProcedureReturn 10
      Case #TESTING_COLOR_ERROR   : ProcedureReturn 12
    EndSelect
    ProcedureReturn 7
  EndProcedure

  Procedure SetColor(kind.i)
    If g_color
      ConsoleColor(__ConsoleColorFor(kind), 0)
    EndIf
  EndProcedure

  Procedure ResetColor()
    If g_color
      ConsoleColor(7, 0)
    EndIf
  EndProcedure
  
  Procedure.i __DetectColor()
    If g_color_mode = 0
      ProcedureReturn #False
    EndIf

    If Len(GetEnvironmentVariable("NO_COLOR")) > 0
      ProcedureReturn #False
    EndIf

    If g_color_mode = 1
      ProcedureReturn #True
    EndIf

    ProcedureReturn g_tty
  EndProcedure

  ; --------------------------------------------------------------------------
  ;  Runtime configuration
  ; --------------------------------------------------------------------------

  Procedure ConfigureQuiet()
    g_quiet = #True
  EndProcedure

  Procedure ConfigureVerbose()
    g_verbose = #True
  EndProcedure

  Procedure ConfigureProgress()
    g_progress = #True
  EndProcedure

  Procedure SetAsciiMode(ascii_mode.i)
    g_ascii_mode = Bool(ascii_mode <> 0)
    If g_initialized
      g_ascii = g_ascii_mode
    EndIf
  EndProcedure

  Procedure SetColorMode(color_mode.i)
    If color_mode < 0
      g_color_mode = -1
    Else
      g_color_mode = Bool(color_mode <> 0)
    EndIf
    If g_initialized
      g_color = __DetectColor()
    EndIf
  EndProcedure

  Procedure SetLogFile(path.s)
    g_log_file = path
  EndProcedure

  Procedure EnableJSON(path.s)
    g_json_enabled = #True
    g_json_file = path
  EndProcedure

  Procedure EnableJUnit(path.s)
    g_junit_enabled = #True
    g_junit_file = path
  EndProcedure

  Procedure SetOpenConsole(enabled.i)
    g_open_console = Bool(enabled <> 0)
  EndProcedure

  Procedure.i IsColorEnabled()
    ProcedureReturn Bool(g_color <> 0)
  EndProcedure

  Procedure Prepare()
    __Init()
  EndProcedure

  ; ==========================================================================
  ;  Initialisation
  ; ==========================================================================

  Procedure __Init()
    If g_initialized
      ProcedureReturn
    EndIf
    g_initialized = #True

    If g_open_console
      OpenConsole("")
    EndIf

    g_tty = __IsTTY()

    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      If g_tty
        SetConsoleOutputCP_(65001)
      EndIf
    CompilerEndIf

    g_width = __ConsoleWidth()
    If g_width < 80  : g_width = 80  : EndIf
    If g_width > 120 : g_width = 120 : EndIf

    g_ascii = Bool(g_ascii_mode <> 0)

    g_color = __DetectColor()

    If g_suite\name = ""
      g_suite\name = "Default"
    EndIf
  EndProcedure

  Procedure __EnsureParentDirectory(file.s)
    Protected dir.s = GetPathPart(file)
    If dir = ""
      ProcedureReturn
    EndIf

    Protected sep.s = #PS$
    Protected normalized.s = dir
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      normalized = ReplaceString(normalized, "/", sep)
    CompilerEndIf

    While Len(normalized) > 1 And Right(normalized, 1) = sep
      normalized = Left(normalized, Len(normalized) - 1)
    Wend

    Protected prefix.s = ""
    If Len(normalized) >= 2 And Mid(normalized, 2, 1) = ":"
      prefix = Left(normalized, 2)
      normalized = Mid(normalized, 3)
      If Left(normalized, 1) = sep
        prefix + sep
        normalized = Mid(normalized, 2)
      EndIf
    ElseIf Left(normalized, 1) = sep
      prefix = sep
      normalized = Mid(normalized, 2)
    EndIf

    Protected current.s = prefix
    Protected parts.i = CountString(normalized, sep)
    Protected index.i
    Protected part.s

    For index = 1 To parts + 1
      part = StringField(normalized, index, sep)
      If part <> ""
        If current <> "" And Right(current, 1) <> sep
          current + sep
        EndIf
        current + part
        CreateDirectory(current)
      EndIf
    Next index
  EndProcedure

  Procedure __OpenLog()
    If g_log_file <> "" And g_log = 0
      __EnsureParentDirectory(g_log_file)
      g_log = CreateFile(#PB_Any, g_log_file)
      If g_log
        g_log_open = #True
      Else
        ConsoleError("Testing.pb: cannot open log file: " + g_log_file)
      EndIf
    EndIf
  EndProcedure

  Procedure __CloseLog()
    If g_log
      CloseFile(g_log)
      g_log = 0
    EndIf
    g_log_open = #False
  EndProcedure

  ; ==========================================================================
  ;  Output primitives (console + optional log)
  ; ==========================================================================

  Procedure __Raw(s.s)
    If Not g_mute
      Print(s)
    EndIf
    If g_log
      WriteString(g_log, s, #PB_UTF8)
    EndIf
  EndProcedure

  Procedure __Part(s.s, kind.i)
    If g_color And Not g_mute
      ConsoleColor(__ConsoleColorFor(kind), 0)
    EndIf
    __Raw(s)
    If g_color And Not g_mute
      ConsoleColor(7, 0)
    EndIf
  EndProcedure

  Procedure __NewLine()
    If Not g_mute
      PrintN("")
    EndIf
    If g_log
      WriteStringN(g_log, "", #PB_UTF8)
    EndIf
  EndProcedure

  Procedure __Line(s.s, kind.i)
    __Part(s, kind)
    __NewLine()
  EndProcedure

  Procedure.s __Separator()
    If g_ascii
      ProcedureReturn __RepeatChar("-", g_width)
    EndIf

    ProcedureReturn __RepeatChar("─", g_width)
  EndProcedure

  ; ==========================================================================
  ;  Terminal renderer
  ; ==========================================================================

  Procedure __RenderHeader()
    __Line("Testing.pb " + #TESTING_VERSION$, #TESTING_COLOR_HEADER)
    __Line("Suite: " + __OneLine(g_suite\name), #TESTING_COLOR_HEADER)
    __Line(__Separator(), #TESTING_COLOR_DIM)
  EndProcedure

  Procedure __RenderAtLine(*r.TestingResult)
    Protected fileName.s = GetFilePart(*r\file)
    Protected prefix.s = "at "
    If fileName <> ""
      prefix + fileName
      If *r\line > 0
        prefix + ":" + Str(*r\line)
      EndIf
    Else
      prefix + "(unknown)"
    EndIf
    __Line("       " + prefix, #TESTING_COLOR_DIM)
  EndProcedure

  Procedure __RenderFailureBlock(*r.TestingResult)
    If g_verbose
      __RenderAtLine(*r)

      If *r\message <> ""
        __Part("       message:  ", #TESTING_COLOR_DEFAULT)
        __Part(__OneLine(*r\message), #TESTING_COLOR_FAIL)
        __NewLine()
      EndIf

      If *r\has_expected
        __Part("       expected: ", #TESTING_COLOR_DEFAULT)
        __Part(__OneLine(*r\expected), #TESTING_COLOR_PASS)
        __NewLine()
      EndIf

      If *r\has_actual
        __Part("       actual:   ", #TESTING_COLOR_DEFAULT)
        __Part(__OneLine(*r\actual), #TESTING_COLOR_FAIL)
        __NewLine()
      EndIf

      If *r\description <> ""
        __Part("       description: ", #TESTING_COLOR_DEFAULT)
        __Part(__QuotedDisplay(*r\description), #TESTING_COLOR_DEFAULT)
        __NewLine()
      EndIf
    Else
      If *r\message <> ""
        __Part("       ", #TESTING_COLOR_DEFAULT)
        __Part(__OneLine(*r\message), #TESTING_COLOR_FAIL)
        If *r\description <> ""
          __Part(" -- " + __QuotedDisplay(*r\description), #TESTING_COLOR_DEFAULT)
        EndIf
        __NewLine()
      ElseIf *r\description <> ""
        __Part("       " + __QuotedDisplay(*r\description), #TESTING_COLOR_DEFAULT)
        __NewLine()
      EndIf

      If *r\has_expected And *r\has_actual
        __Part("       expected: ", #TESTING_COLOR_DEFAULT)
        __Part(__OneLine(*r\expected), #TESTING_COLOR_PASS)
        __Part(", actual: ", #TESTING_COLOR_DEFAULT)
        __Part(__OneLine(*r\actual), #TESTING_COLOR_FAIL)
        __NewLine()
      EndIf

      __RenderAtLine(*r)
    EndIf
  EndProcedure

  Procedure __RenderTest(*r.TestingResult)
    Protected status_color.i = __StatusColor(*r\status)
    Protected tag.s = LSet(__StatusTag(*r\status), 7)
    Protected name_width.i
    Protected lineText.s

    If *r\status = #TESTING_STATUS_SKIPPED Or *r\status = #TESTING_STATUS_PENDING
      Protected reason.s
      If *r\status = #TESTING_STATUS_SKIPPED
        reason = *r\message
        If reason = "" : reason = "skipped" : EndIf
      Else
        reason = *r\message
        If reason = "" : reason = "pending" : EndIf
      EndIf

      Protected max_reason.i = g_width - 7 - 12
      If max_reason < 8 : max_reason = 8 : EndIf
      reason = __FitString(__OneLine(reason), max_reason)

      name_width = g_width - 7 - Len(reason)
      If name_width < 8 : name_width = 8 : EndIf

      __Part(tag, status_color)
      __Part(LSet(__FitString(__OneLine(*r\name), name_width), name_width), #TESTING_COLOR_NAME)
      __Part(reason, status_color)
      __NewLine()
    Else
      Protected time_text.s = RSet(Str(*r\duration_ms), 5) + " ms"
      name_width = g_width - 7 - Len(time_text)
      If name_width < 8 : name_width = 8 : EndIf

      __Part(tag, status_color)
      __Part(LSet(__FitString(__OneLine(*r\name), name_width), name_width), #TESTING_COLOR_NAME)
      __Part(time_text, #TESTING_COLOR_DIM)
      __NewLine()

      If *r\status = #TESTING_STATUS_FAILED Or *r\status = #TESTING_STATUS_ERROR
        __RenderFailureBlock(*r)
      EndIf
    EndIf
  EndProcedure

  Procedure __RenderSummary()
    Protected bad.i = g_suite\failed + g_suite\errors
    Protected seconds.s = __Seconds(g_suite\duration_ms)

    __Line(__Separator(), #TESTING_COLOR_DIM)

    Protected line.s = "Total: " + Str(g_suite\total) +
                       "  Passed: " + Str(g_suite\passed) +
                       "  Failed: " + Str(g_suite\failed) +
                       "  Skipped: " + Str(g_suite\skipped) +
                       "  Pending: " + Str(g_suite\pending) +
                       "  Errors: " + Str(g_suite\errors)
    __Line(line, #TESTING_COLOR_DEFAULT)
    __Line("Time:    " + seconds + "s", #TESTING_COLOR_DIM)

    If bad = 0
      __Line("RESULT: OK", #TESTING_COLOR_OK)
    Else
      Protected plural.s = " failures"
      If bad = 1 : plural = " failure" : EndIf
      __Line("RESULT: FAILED (" + Str(bad) + plural + ")", #TESTING_COLOR_FAIL)
    EndIf
  EndProcedure

  ; ==========================================================================
  ;  Progress indicator (TTY only)
  ; ==========================================================================

  Procedure __Progress(index.i, total.i)
    If Not (g_progress And g_tty And Not g_quiet And Not g_mute)
      ProcedureReturn
    EndIf
    Print(#CR$ + "[" + Str(index) + "/" + Str(total) + "]")
  EndProcedure

  Procedure __ProgressClear()
    If Not (g_progress And g_tty And Not g_quiet And Not g_mute)
      ProcedureReturn
    EndIf
    Print(#CR$ + Space(20) + #CR$)
  EndProcedure

  Procedure __Trace(s.s)
    If Not g_verbose
      ProcedureReturn
    EndIf
    Protected old_mute.i = g_mute
    g_mute = g_quiet
    __ProgressClear()
    __Line(s, #TESTING_COLOR_DIM)
    g_mute = old_mute
  EndProcedure

  ; ==========================================================================
  ;  Registration API (called by macros)
  ; ==========================================================================

  Procedure.i AddTest(*proc.TestingProc, name.s)
    If *proc = 0
      ProcedureReturn #False
    EndIf
    AddElement(g_tests())
    g_tests()\proc = *proc
    g_tests()\name = name
    ProcedureReturn #True
  EndProcedure

  Procedure.i SetBeforeEach(*proc.TestingProc)
    g_before = *proc
    ProcedureReturn #True
  EndProcedure

  Procedure.i SetAfterEach(*proc.TestingProc)
    g_after = *proc
    ProcedureReturn #True
  EndProcedure

  Procedure.i SetSuiteName(name.s)
    If name = ""
      name = "Default"
    EndIf
    g_suite\name = name
    ProcedureReturn #True
  EndProcedure

  ; ==========================================================================
  ;  Result recording (called by assert macros; never prints anything)
  ; ==========================================================================

  Procedure.i FailAssert(assert_name.s, expected.s, actual.s, description.s, file.s, line.i, has_expected.i)
    If Not *g_current
      ConsoleError("Testing.pb: assertion outside of a test: " + assert_name)
      ProcedureReturn #False
    EndIf

    *g_current\status = #TESTING_STATUS_FAILED
    *g_current\message = assert_name + " failed"
    *g_current\description = description
    *g_current\expected = expected
    *g_current\actual = actual
    *g_current\file = file
    *g_current\line = line
    *g_current\has_expected = has_expected
    *g_current\has_actual = has_expected
    ProcedureReturn #True
  EndProcedure

  Procedure.i FailListEqual(list_name.s, size_actual.i, size_expected.i, at_index.i, description.s, file.s, line.i)
    Protected expected.s
    Protected actual.s
    Protected message.s = list_name + " failed"

    If size_actual <> size_expected
      expected = "size " + Str(size_expected)
      actual = "size " + Str(size_actual)
    Else
      message = list_name + " failed: lists differ at index " + Str(at_index)
      expected = "equal lists"
      actual = "difference at index " + Str(at_index)
    EndIf

    If Not *g_current
      ConsoleError("Testing.pb: assertion outside of a test: " + list_name)
      ProcedureReturn #False
    EndIf

    *g_current\status = #TESTING_STATUS_FAILED
    *g_current\message = message
    *g_current\description = description
    *g_current\expected = expected
    *g_current\actual = actual
    *g_current\file = file
    *g_current\line = line
    *g_current\has_expected = #True
    *g_current\has_actual = #True
    ProcedureReturn #True
  EndProcedure

  Procedure.i __SetSpecialStatus(status.i, message.s, file.s, line.i)
    If Not *g_current
      ConsoleError("Testing.pb: status change outside of a test")
      ProcedureReturn #False
    EndIf

    If *g_current\status = #TESTING_STATUS_RUNNING Or *g_current\status = #TESTING_STATUS_PASSED
      *g_current\status = status
      *g_current\message = message
      *g_current\file = file
      *g_current\line = line
    EndIf
    ProcedureReturn #True
  EndProcedure

  Procedure.i SkipCurrent(reason.s, file.s, line.i)
    ProcedureReturn __SetSpecialStatus(#TESTING_STATUS_SKIPPED, reason, file, line)
  EndProcedure

  Procedure.i PendingCurrent(reason.s, file.s, line.i)
    ProcedureReturn __SetSpecialStatus(#TESTING_STATUS_PENDING, reason, file, line)
  EndProcedure

  Procedure.i ErrorCurrent(message.s, file.s, line.i)
    If Not *g_current
      ConsoleError("Testing.pb: error outside of a test: " + message)
      ProcedureReturn #False
    EndIf
    *g_current\status = #TESTING_STATUS_ERROR
    *g_current\message = message
    *g_current\file = file
    *g_current\line = line
    ProcedureReturn #True
  EndProcedure

  ; ==========================================================================
  ;  Escaping helpers
  ; ==========================================================================

  Procedure.s JsonEscapeString(s.s)
    Protected out.s
    Protected i.i
    Protected c.i
    Protected ch.s

    For i = 1 To Len(s)
      ch = Mid(s, i, 1)
      c = Asc(ch)
      Select c
        Case 34  : out + ~"\\\""
        Case 92  : out + ~"\\\\"
        Case 8   : out + ~"\\b"
        Case 9   : out + ~"\\t"
        Case 10  : out + ~"\\n"
        Case 12  : out + ~"\\f"
        Case 13  : out + ~"\\r"
        Default
          If c < 32
            out + ~"\\u" + RSet(Hex(c), 4, "0")
          Else
            out + ch
          EndIf
      EndSelect
    Next i

    ProcedureReturn out
  EndProcedure

  Procedure.s JsonEscape(s.s)
    ProcedureReturn JsonEscapeString(s)
  EndProcedure

  Procedure.s XmlEscapeString(s.s)
    Protected out.s
    Protected i.i
    Protected c.i
    Protected ch.s

    For i = 1 To Len(s)
      ch = Mid(s, i, 1)
      c = Asc(ch)
      Select c
        Case 38 : out + "&amp;"
        Case 60 : out + "&lt;"
        Case 62 : out + "&gt;"
        Case 34 : out + "&quot;"
        Case 39 : out + "&apos;"
        Default
          If c < 32 And c <> 9 And c <> 10 And c <> 13
            out + " "
          Else
            out + ch
          EndIf
      EndSelect
    Next i

    ProcedureReturn out
  EndProcedure

  ; ==========================================================================
  ;  JSON report
  ; ==========================================================================

  Procedure.s __JStr(s.s)
    ProcedureReturn ~"\"" + JsonEscapeString(s) + ~"\""
  EndProcedure

  Procedure __WriteJSON(path.s)
    __EnsureParentDirectory(path)
    Protected f.i = CreateFile(#PB_Any, path)
    If f = 0
      ConsoleError("Testing.pb: cannot write JSON report: " + path)
      ProcedureReturn
    EndIf

    WriteStringN(f, "{", #PB_UTF8)
    WriteStringN(f, ~"  \"schema_version\": 1,", #PB_UTF8)
    WriteStringN(f, ~"  \"framework\": \"Testing.pb\",", #PB_UTF8)
    WriteStringN(f, ~"  \"suite\": " + __JStr(g_suite\name) + ",", #PB_UTF8)
    WriteStringN(f, ~"  \"duration_ms\": " + Str(g_suite\duration_ms) + ",", #PB_UTF8)
    WriteStringN(f, ~"  \"summary\": {", #PB_UTF8)
    WriteStringN(f, ~"    \"total\": " + Str(g_suite\total) + ~", \"passed\": " + Str(g_suite\passed) + ~", \"failed\": " + Str(g_suite\failed) + ",", #PB_UTF8)
    WriteStringN(f, ~"    \"skipped\": " + Str(g_suite\skipped) + ~", \"pending\": " + Str(g_suite\pending) + ~", \"errors\": " + Str(g_suite\errors), #PB_UTF8)
    WriteStringN(f, "  },", #PB_UTF8)
    WriteStringN(f, ~"  \"tests\": [", #PB_UTF8)

    ForEach g_suite\tests()
      Protected message.s = g_suite\tests()\message
      If g_suite\tests()\description <> ""
        If message <> "" : message + " -- " : EndIf
        message + g_suite\tests()\description
      EndIf

      Protected line.s = ~"    {\"name\": " + __JStr(g_suite\tests()\name)
      line + ~", \"status\": " + __JStr(__StatusName(g_suite\tests()\status))
      line + ~", \"duration_ms\": " + Str(g_suite\tests()\duration_ms)
      line + ~", \"message\": " + __JStr(message)
      line + ~", \"description\": " + __JStr(g_suite\tests()\description)
      line + ~", \"expected\": " + __JStr(g_suite\tests()\expected)
      line + ~", \"actual\": " + __JStr(g_suite\tests()\actual)
      line + ~", \"file\": " + __JStr(g_suite\tests()\file)
      line + ~", \"line\": " + Str(g_suite\tests()\line)
      line + "}"
      If ListIndex(g_suite\tests()) < ListSize(g_suite\tests()) - 1
        line + ","
      EndIf
      WriteStringN(f, line, #PB_UTF8)
    Next
    WriteStringN(f, "  ]", #PB_UTF8)
    WriteStringN(f, "}", #PB_UTF8)
    CloseFile(f)
  EndProcedure

  ; ==========================================================================
  ;  JUnit XML report
  ; ==========================================================================

  Procedure __WriteJUnit(path.s)
    __EnsureParentDirectory(path)
    Protected f.i = CreateFile(#PB_Any, path)
    If f = 0
      ConsoleError("Testing.pb: cannot write JUnit report: " + path)
      ProcedureReturn
    EndIf

    Protected suite_name.s = XmlEscapeString(__OneLine(g_suite\name))
    Protected skipped_total.i = g_suite\skipped + g_suite\pending
    Protected total_time.s = __Seconds(g_suite\duration_ms)

    WriteStringN(f, ~"<?xml version=\"1.0\" encoding=\"UTF-8\"?>", #PB_UTF8)
    WriteStringN(f, ~"<testsuites name=\"" + suite_name + ~"\" tests=\"" + Str(g_suite\total) + ~"\" failures=\"" + Str(g_suite\failed) + ~"\" errors=\"" + Str(g_suite\errors) + ~"\" skipped=\"" + Str(skipped_total) + ~"\" time=\"" + total_time + ~"\">", #PB_UTF8)
    WriteStringN(f, ~"  <testsuite name=\"" + suite_name + ~"\" tests=\"" + Str(g_suite\total) + ~"\" failures=\"" + Str(g_suite\failed) + ~"\" errors=\"" + Str(g_suite\errors) + ~"\" skipped=\"" + Str(skipped_total) + ~"\" time=\"" + total_time + ~"\">", #PB_UTF8)

    ForEach g_suite\tests()
      Protected test_name.s = XmlEscapeString(__OneLine(g_suite\tests()\name))
      Protected test_time.s = __Seconds(g_suite\tests()\duration_ms)
      Protected message.s = g_suite\tests()\message
      If g_suite\tests()\description <> ""
        If message <> "" : message + " -- " : EndIf
        message + g_suite\tests()\description
      EndIf

      WriteStringN(f, ~"    <testcase classname=\"" + suite_name + ~"\" name=\"" + test_name + ~"\" time=\"" + test_time + ~"\">", #PB_UTF8)

      Select g_suite\tests()\status
        Case #TESTING_STATUS_FAILED
          Protected details.s = "assertion: " + g_suite\tests()\message + #LF$
          If g_suite\tests()\has_expected
            details + "expected: " + g_suite\tests()\expected + #LF$
          EndIf
          If g_suite\tests()\has_actual
            details + "actual: " + g_suite\tests()\actual + #LF$
          EndIf
          If g_suite\tests()\description <> ""
            details + "description: " + g_suite\tests()\description + #LF$
          EndIf
          details + "at " + g_suite\tests()\file + ":" + Str(g_suite\tests()\line)

          WriteStringN(f, ~"      <failure message=\"" + XmlEscapeString(__OneLine(message)) + ~"\" type=\"AssertionFailed\">" + XmlEscapeString(details) + "</failure>", #PB_UTF8)

        Case #TESTING_STATUS_ERROR
          WriteStringN(f, ~"      <error message=\"" + XmlEscapeString(__OneLine(message)) + ~"\" type=\"Error\">" + XmlEscapeString(g_suite\tests()\message) + "</error>", #PB_UTF8)

        Case #TESTING_STATUS_SKIPPED
          WriteStringN(f, ~"      <skipped message=\"" + XmlEscapeString(__OneLine(message)) + ~"\"/>", #PB_UTF8)

        Case #TESTING_STATUS_PENDING
          WriteStringN(f, ~"      <skipped message=\"" + XmlEscapeString(__OneLine(message)) + ~"\"/>", #PB_UTF8)
      EndSelect

      WriteStringN(f, "    </testcase>", #PB_UTF8)
    Next

    WriteStringN(f, "  </testsuite>", #PB_UTF8)
    WriteStringN(f, "</testsuites>", #PB_UTF8)
    CloseFile(f)
  EndProcedure

  ; ==========================================================================
  ;  Report dispatch
  ; ==========================================================================

  Procedure __WriteReports()
    If g_json_enabled
      __WriteJSON(g_json_file)
    EndIf
    If g_junit_enabled
      __WriteJUnit(g_junit_file)
    EndIf
  EndProcedure

  ; ==========================================================================
  ;  Runner
  ; ==========================================================================

  Procedure __ResetSuite()
    ClearList(g_suite\tests())
    g_suite\total = 0
    g_suite\passed = 0
    g_suite\failed = 0
    g_suite\skipped = 0
    g_suite\pending = 0
    g_suite\errors = 0
    g_suite\duration_ms = 0
    *g_current = 0
  EndProcedure

  Procedure __CountResult(*r.TestingResult)
    g_suite\total + 1
    Select *r\status
      Case #TESTING_STATUS_PASSED  : g_suite\passed + 1
      Case #TESTING_STATUS_FAILED  : g_suite\failed + 1
      Case #TESTING_STATUS_SKIPPED : g_suite\skipped + 1
      Case #TESTING_STATUS_PENDING : g_suite\pending + 1
      Case #TESTING_STATUS_ERROR   : g_suite\errors + 1
      Default                      : g_suite\errors + 1
    EndSelect
  EndProcedure

  Procedure __RunOne(proc.TestingProc, test_name.s, index.i, total.i)
    AddElement(g_suite\tests())
    *g_current = @g_suite\tests()
    *g_current\name = test_name
    *g_current\status = #TESTING_STATUS_RUNNING
    *g_current\duration_ms = 0
    *g_current\message = ""
    *g_current\description = ""
    *g_current\expected = ""
    *g_current\actual = ""
    *g_current\file = ""
    *g_current\line = 0
    *g_current\has_expected = #False
    *g_current\has_actual = #False

    __Trace("-> " + test_name)

    Protected started.i = ElapsedMilliseconds()

    If g_before
      __Trace("       hook: BeforeEach")
      g_before()
    EndIf

    If *g_current\status = #TESTING_STATUS_RUNNING
      proc()
    EndIf

    If g_after
      __Trace("       hook: AfterEach")
      g_after()
    EndIf

    *g_current\duration_ms = ElapsedMilliseconds() - started

    If *g_current\status = #TESTING_STATUS_RUNNING
      *g_current\status = #TESTING_STATUS_PASSED
    EndIf

    __CountResult(*g_current)

    Protected console_visible.i = Bool(Not g_quiet Or
                                       *g_current\status = #TESTING_STATUS_FAILED Or
                                       *g_current\status = #TESTING_STATUS_ERROR)
    If g_log Or console_visible
      Protected old_mute.i = g_mute
      g_mute = Bool(Not console_visible)
      __ProgressClear()
      __RenderTest(*g_current)
      __Progress(index, total)
      g_mute = old_mute
    EndIf

    *g_current = 0
  EndProcedure

  Procedure.i RunAllNow(exit_after.i)
    __Init()
    __ResetSuite()
    __OpenLog()

    If Not g_quiet Or g_log
      Protected old_mute_header.i = g_mute
      g_mute = Bool(g_quiet)
      __ProgressClear()
      __RenderHeader()
      g_mute = old_mute_header
    EndIf

    Protected total.i = ListSize(g_tests())
    Protected index.i = 0
    Protected started.i = ElapsedMilliseconds()

    ForEach g_tests()
      index + 1
      Protected p.TestingProc = g_tests()\proc
      Protected n.s = g_tests()\name
      __RunOne(p, n, index, total)
    Next

    g_suite\duration_ms = ElapsedMilliseconds() - started

    __ProgressClear()
    __RenderSummary()
    __WriteReports()
    __CloseLog()

    If exit_after
      If g_suite\failed + g_suite\errors > 0
        End 1
      Else
        End 0
      EndIf
    EndIf

    ProcedureReturn Bool(g_suite\failed + g_suite\errors = 0)
  EndProcedure

  Procedure.i RunNamed(name.s)
    __Init()
    __ResetSuite()
    __OpenLog()

    Protected old_mute.i = g_mute
    g_mute = Bool(g_quiet)
    __ProgressClear()
    __RenderHeader()
    g_mute = old_mute

    Protected found.TestingProc = 0
    ForEach g_tests()
      If g_tests()\name = name
        found = g_tests()\proc
        Break
      EndIf
    Next

    If found = 0
      old_mute = g_mute
      g_mute = Bool(g_quiet)
      __Line("Unknown test: " + __OneLine(name), #TESTING_COLOR_FAIL)
      g_mute = old_mute
      __CloseLog()
      ProcedureReturn #False
    EndIf

    __RunOne(found, name, 1, 1)
    g_suite\duration_ms = g_suite\tests()\duration_ms

    __ProgressClear()
    __RenderSummary()
    __WriteReports()
    __CloseLog()

    If g_suite\total = 1 And (g_suite\passed = 1 Or g_suite\skipped = 1 Or g_suite\pending = 1)
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
  EndProcedure

EndModule

; ============================================================================
;  Compiler directive handling
; ============================================================================

CompilerIf Defined(TESTING_QUIET, #PB_Constant)
  Testing::ConfigureQuiet()
CompilerEndIf

CompilerIf Defined(TESTING_VERBOSE, #PB_Constant)
  Testing::ConfigureVerbose()
CompilerEndIf

CompilerIf Defined(TESTING_PROGRESS, #PB_Constant)
  Testing::ConfigureProgress()
CompilerEndIf

CompilerIf Defined(TESTING_UNICODE, #PB_Constant)
  Testing::SetAsciiMode(0)
CompilerEndIf

CompilerIf Defined(TESTING_ASCII, #PB_Constant)
  Testing::SetAsciiMode(1)
CompilerEndIf

CompilerIf Defined(TESTING_NO_COLOR, #PB_Constant)
  Testing::SetColorMode(0)
CompilerElseIf Defined(TESTING_ASCII, #PB_Constant)
  Testing::SetColorMode(0)
CompilerElseIf Defined(TESTING_COLOR_ON, #PB_Constant)
  Testing::SetColorMode(1)
CompilerElseIf Defined(TESTING_COLOR_OFF, #PB_Constant)
  Testing::SetColorMode(0)
CompilerEndIf

CompilerIf Defined(TESTING_NO_OPEN_CONSOLE, #PB_Constant)
  Testing::SetOpenConsole(0)
CompilerEndIf

CompilerIf Defined(TESTING_SUITE$, #PB_Constant)
  Testing::SetSuiteName(#TESTING_SUITE$)
CompilerEndIf

CompilerIf Defined(TESTING_LOG_FILE$, #PB_Constant)
  Testing::SetLogFile(#TESTING_LOG_FILE$)
CompilerEndIf

CompilerIf Defined(TESTING_OUTPUT_JSON, #PB_Constant)
  CompilerIf Defined(TESTING_JSON_FILE$, #PB_Constant)
    Testing::EnableJSON(#TESTING_JSON_FILE$)
  CompilerElse
    Testing::EnableJSON("testing-results.json")
  CompilerEndIf
CompilerEndIf

CompilerIf Defined(TESTING_OUTPUT_JUNIT, #PB_Constant)
  CompilerIf Defined(TESTING_JUNIT_FILE$, #PB_Constant)
    Testing::EnableJUnit(#TESTING_JUNIT_FILE$)
  CompilerElse
    Testing::EnableJUnit("testing-results.xml")
  CompilerEndIf
CompilerEndIf

Testing::Prepare()

; ============================================================================
;  Public API macros
; ============================================================================

; --- test definition --------------------------------------------------------

Macro Test(TestName)
  CompilerIf Defined(TestName#_testingunit_, #PB_Procedure)
    CompilerError "Testing.pb: this test is already defined."
  CompilerEndIf
  Procedure TestName#_testingunit_()
EndMacro

Macro EndTest(TestName)
  EndProcedure
  Testing::AddTest(@TestName#_testingunit_(), __TESTING_QUOTE#TestName#__TESTING_QUOTE)
EndMacro

; --- lifecycle hooks -------------------------------------------------------

Macro BeforeEach()
  Procedure __Testing_BeforeEach()
EndMacro

Macro EndBeforeEach()
  EndProcedure
  Testing::SetBeforeEach(@__Testing_BeforeEach())
EndMacro

Macro AfterEach()
  Procedure __Testing_AfterEach()
EndMacro

Macro EndAfterEach()
  EndProcedure
  Testing::SetAfterEach(@__Testing_AfterEach())
EndMacro

; --- suite name ------------------------------------------------------------

Macro Suite(name)
  Testing::SetSuiteName(name)
EndMacro

; --- running ---------------------------------------------------------------

Macro RunAll(exitAfter = #True)
  Testing::RunAllNow(exitAfter)
EndMacro

Macro Run(TestName)
  Testing::RunNamed(__TESTING_QUOTE#TestName#__TESTING_QUOTE)
EndMacro

; --- skip / pending / error ------------------------------------------------

Macro SkipTest(reason = "")
  Testing::SkipCurrent(reason, #PB_Compiler_File, #PB_Compiler_Line)
  ProcedureReturn #False
EndMacro

Macro PendingTest(reason = "")
  Testing::PendingCurrent(reason, #PB_Compiler_File, #PB_Compiler_Line)
  ProcedureReturn #False
EndMacro

Macro FailTest(message = "")
  Testing::ErrorCurrent(message, #PB_Compiler_File, #PB_Compiler_Line)
  ProcedureReturn #False
EndMacro

; --- assertions ------------------------------------------------------------

Macro Assert(expression, description = "")
  If Not (expression)
    Testing::FailAssert("Assert", "true", "false", description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    ProcedureReturn #False
  EndIf
EndMacro

Macro AssertEqual(actual, expected, description = "")
  If Not ((actual) = (expected))
    Testing::FailAssert("AssertEqual", Str(expected), Str(actual), description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    ProcedureReturn #False
  EndIf
EndMacro

Macro AssertNotEqual(actual, not_expected, description = "")
  If (actual) = (not_expected)
    Testing::FailAssert("AssertNotEqual", "<> " + Str(not_expected), Str(actual), description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    ProcedureReturn #False
  EndIf
EndMacro

Macro AssertBigger(actual, threshold, description = "")
  If Not ((actual) > (threshold))
    Testing::FailAssert("AssertBigger", "> " + Str(threshold), Str(actual), description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    ProcedureReturn #False
  EndIf
EndMacro

Macro AssertSmaller(actual, threshold, description = "")
  If Not ((actual) < (threshold))
    Testing::FailAssert("AssertSmaller", "< " + Str(threshold), Str(actual), description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    ProcedureReturn #False
  EndIf
EndMacro

Macro AssertInRange(actual, max, min = 0, description = "")
  If (actual) < (min) Or (actual) > (max)
    Testing::FailAssert("AssertInRange", "[" + Str(min) + ", " + Str(max) + "]", Str(actual), description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    ProcedureReturn #False
  EndIf
EndMacro

Macro AssertApproxEqual(actual, expected, epsilon, description = "")
  If IsNaN((actual)) Or IsNaN((expected)) Or Abs((actual) - (expected)) > (epsilon)
    Testing::FailAssert("AssertApproxEqual", StrD((expected), 6), StrD((actual), 6), description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    ProcedureReturn #False
  EndIf
EndMacro

Macro AssertStrEqual(actual, expected, description = "")
  If (actual) <> (expected)
    Testing::FailAssert("AssertStrEqual", expected, actual, description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    ProcedureReturn #False
  EndIf
EndMacro

Macro AssertStrNotEqual(actual, not_expected, description = "")
  If (actual) = (not_expected)
    Testing::FailAssert("AssertStrNotEqual", "<> " + not_expected, actual, description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    ProcedureReturn #False
  EndIf
EndMacro

Macro AssertStrContains(haystack, needle, description = "")
  If FindString(haystack, needle) = 0
    Testing::FailAssert("AssertStrContains", "contains " + needle, haystack, description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    ProcedureReturn #False
  EndIf
EndMacro

Macro AssertNull(pointer, description = "")
  If (pointer) <> 0
    Testing::FailAssert("AssertNull", "0", Str(pointer), description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    ProcedureReturn #False
  EndIf
EndMacro

Macro AssertNotNull(pointer, description = "")
  If (pointer) = 0
    Testing::FailAssert("AssertNotNull", "<> 0", "0", description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    ProcedureReturn #False
  EndIf
EndMacro

Macro AssertListEqual(listActual, listExpected, description = "")
  Define __testing_posA = ListIndex(listActual())
  Define __testing_posB = ListIndex(listExpected())
  Define __testing_sizeA = ListSize(listActual())
  Define __testing_sizeB = ListSize(listExpected())
  Define __testing_ok = #True
  Define __testing_at = -1
  Define __testing_i = 0

  If __testing_sizeA <> __testing_sizeB
    __testing_ok = #False
    __testing_at = 0
  Else
    ForEach listActual()
      If SelectElement(listExpected(), __testing_i) = 0
        __testing_ok = #False
        __testing_at = __testing_i
        Break
      EndIf
      If listActual() <> listExpected()
        __testing_ok = #False
        __testing_at = __testing_i
        Break
      EndIf
      __testing_i + 1
    Next
  EndIf

  If __testing_posA >= 0 : SelectElement(listActual(), __testing_posA) : Else : ResetList(listActual()) : EndIf
  If __testing_posB >= 0 : SelectElement(listExpected(), __testing_posB) : Else : ResetList(listExpected()) : EndIf

  If __testing_ok = #False
    Testing::FailListEqual("AssertListEqual", __testing_sizeA, __testing_sizeB, __testing_at, description, #PB_Compiler_File, #PB_Compiler_Line)
    ProcedureReturn #False
  EndIf
EndMacro

Macro AssertStrListEqual(listActual, listExpected, description = "")
  Define __testing_sposA = ListIndex(listActual())
  Define __testing_sposB = ListIndex(listExpected())
  Define __testing_ssizeA = ListSize(listActual())
  Define __testing_ssizeB = ListSize(listExpected())
  Define __testing_sok = #True
  Define __testing_sat = -1
  Define __testing_si = 0
  Define __testing_sexp.s = ""
  Define __testing_sact.s = ""

  If __testing_ssizeA <> __testing_ssizeB
    __testing_sok = #False
    __testing_sat = 0
  Else
    ForEach listActual()
      If SelectElement(listExpected(), __testing_si) = 0
        __testing_sok = #False
        __testing_sat = __testing_si
        Break
      EndIf
      If listActual() <> listExpected()
        __testing_sok = #False
        __testing_sat = __testing_si
        __testing_sexp = listExpected()
        __testing_sact = listActual()
        Break
      EndIf
      __testing_si + 1
    Next
  EndIf

  If __testing_sposA >= 0 : SelectElement(listActual(), __testing_sposA) : Else : ResetList(listActual()) : EndIf
  If __testing_sposB >= 0 : SelectElement(listExpected(), __testing_sposB) : Else : ResetList(listExpected()) : EndIf

  If __testing_sok = #False
    If __testing_ssizeA <> __testing_ssizeB
      Testing::FailAssert("AssertStrListEqual", "size " + Str(__testing_ssizeB), "size " + Str(__testing_ssizeA), description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    Else
      Testing::FailAssert("AssertStrListEqual at index " + Str(__testing_sat), __testing_sexp, __testing_sact, description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    EndIf
    ProcedureReturn #False
  EndIf
EndMacro

Macro AssertStructureEqual(actual, expected, structureName, description = "")
  If CompareStructure(@actual, @expected, structureName) = 0
    Testing::FailAssert("AssertStructureEqual", "equal structures", "different structures", description, #PB_Compiler_File, #PB_Compiler_Line, 1)
    ProcedureReturn #False
  EndIf
EndMacro

; IDE Options = PureBasic 6.41 (Windows - x64)
; Folding = --------------------
; EnableXP
; DPIAware