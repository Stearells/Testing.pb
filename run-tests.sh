#!/usr/bin/env bash
# ============================================================================
#  Testing.pb - POSIX test runner (Linux / macOS)
#
#  Usage:
#      ./run-tests.sh
#      PB_COMPILER=/path/to/pbcompiler ./run-tests.sh
#      PB_COMPILER_C=/path/to/pbcompilerc ./run-tests.sh
#      PB_BACKEND=fasm|c|both ./run-tests.sh
#
#  A compiler variable may point to the executable or to its directory.
#  Backends whose auto-detected compiler is missing are skipped. An explicitly
#  supplied path that does not exist is a test failure. If no backend runs at
#  all, the script exits with 1.
#
#  Exit code: 0 when every check passes, 1 otherwise.
# ============================================================================

set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD=""
PB=""
RAN=0

TOTAL=0
FAILED=0

# UTF-8 samples written as octal escapes so this script stays ASCII-only.
UTF8_PRIVET="$(printf '\320\237\321\200\320\270\320\262\320\265\321\202')"
UTF8_EMOJI="$(printf '\360\237\230\200')"
UTF8_CHINESE="$(printf '\344\270\255\346\226\207')"

section() {
  printf '\n%s\n%s\n%s\n' "==========================================================================" "$1" "=========================================================================="
}

ok() {
  TOTAL=$((TOTAL + 1))
  printf '  [ OK ] %s\n' "$1"
}

bad() {
  TOTAL=$((TOTAL + 1))
  FAILED=$((FAILED + 1))
  printf '  [FAIL] %s\n' "$1"
}

check() {
  if [ "$1" -eq 0 ]; then
    ok "$2"
  else
    bad "$2"
  fi
}

contains() {
  if grep -Fq "$2" "$1"; then
    ok "$3"
  else
    bad "$3"
  fi
}

not_contains() {
  if grep -Fq "$2" "$1"; then
    bad "$3"
  else
    ok "$3"
  fi
}

is_ascii() {
  # Allow TAB/CR/LF so the check also works on CRLF output from Windows.
  if LC_ALL=C tr -d '\011\012\015' < "$1" | LC_ALL=C grep -q '[^ -~]'; then
    bad "$2"
  else
    ok "$2"
  fi
}

is_utf8() {
  if command -v iconv >/dev/null 2>&1; then
    if iconv -f UTF-8 -t UTF-8 "$1" >/dev/null 2>&1; then
      ok "$2"
    else
      bad "$2"
    fi
  elif command -v python3 >/dev/null 2>&1; then
    if python3 -c 'import sys; open(sys.argv[1], encoding="utf-8", errors="strict").read()' "$1" >/dev/null 2>&1; then
      ok "$2"
    else
      bad "$2"
    fi
  else
    ok "$2 (not validated: iconv/python3 unavailable)"
  fi
}

# Prints the resolved compiler path and exits 0.
# Returns 1 when an explicit path is invalid (a test failure).
# Returns 2 when nothing was configured and auto-detection failed (skip).
resolve_compiler() {
  explicit="$1"
  fallback="$2"

  if [ -n "$explicit" ]; then
    candidate="$explicit"
    if [ -d "$candidate" ]; then
      candidate="$candidate/$fallback"
    fi
    if [ -f "$candidate" ] || command -v "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
    printf 'Explicit compiler not found: %s\n' "$candidate" >&2
    return 1
  fi

  if command -v "$fallback" >/dev/null 2>&1; then
    printf '%s\n' "$fallback"
    return 0
  fi
  return 2
}

run_suite() {
  name="$1"
  expected="$2"
  source="$ROOT/tests/$name.pb"
  exe="$BUILD/$name"

  if ! "$PB" "$source" /OUTPUT "$exe" /CONSOLE /QUIET >"$BUILD/$name.compile.log" 2>&1; then
    bad "$name compiles"
    return
  fi
  ok "$name compiles"

  ( cd "$BUILD" && "$exe" >"$name.out" 2>"$name.err" )
  code=$?
  if [ "$code" -eq "$expected" ]; then
    ok "$name exit code $code"
  else
    bad "$name exit code $code (expected $expected)"
  fi
}

run_checks() {
  local backend="$1"

  rm -rf "$BUILD"
  mkdir -p "$BUILD"

  section "Testing.pb POSIX smoke tests: $backend"

  run_suite framework_tests 0
  contains "$BUILD/framework_tests.out" "Suite: FrameworkSelfTests" "framework suite banner"
  contains "$BUILD/framework_tests.out" "RESULT: OK" "framework result"
  contains "$BUILD/framework_tests.out" "Total: 12  Passed: 10  Failed: 0  Skipped: 1  Pending: 1  Errors: 0" "framework summary"
  contains "$BUILD/framework_tests.out" "[SKIP] SkippedByDesign" "skip status"
  contains "$BUILD/framework_tests.out" "[PEND] PendingByDesign" "pending status"

  run_suite failure_expected 1
  contains "$BUILD/failure_expected.out" "AssertEqual failed -- \"one is not two\"" "failure message"
  contains "$BUILD/failure_expected.out" "expected: 2, actual: 1" "failure expected/actual"
  contains "$BUILD/failure_expected.out" "at failure_expected.pb:" "failure location"
  contains "$BUILD/failure_expected.out" "RESULT: FAILED (1 failure)" "failure result"

  run_suite error_expected 1
  contains "$BUILD/error_expected.out" "[ERR]  IntentionalError" "error status"
  contains "$BUILD/error_expected.out" "deliberate error" "error message"

  run_suite reports 1
  if [ -d "$BUILD/artifacts" ]; then ok "nested report directory created"; else bad "nested report directory created"; fi
  if [ -f "$BUILD/artifacts/reports.json" ] && [ -f "$BUILD/artifacts/reports.xml" ] && [ -f "$BUILD/artifacts/reports.log" ]; then
    ok "report files exist"
  else
    bad "report files exist"
  fi
  bom="$(head -c 3 "$BUILD/artifacts/reports.json" | od -An -tx1 | tr -d ' \n')"
  if [ "$bom" != "efbbbf" ]; then ok "JSON has no BOM"; else bad "JSON has no BOM"; fi
  contains "$BUILD/artifacts/reports.json" '"schema_version": 1' "JSON schema version"
  contains "$BUILD/artifacts/reports.json" '"status": "failed"' "JSON failed status"
  contains "$BUILD/artifacts/reports.xml" "<testsuites" "JUnit root element"
  contains "$BUILD/artifacts/reports.xml" '<failure message=' "JUnit failure element"
  is_utf8 "$BUILD/artifacts/reports.log" "log is UTF-8"
  contains "$BUILD/artifacts/reports.log" "$UTF8_PRIVET" "log preserves Cyrillic"
  if LC_ALL=C grep -q "$(printf '\033')" "$BUILD/artifacts/reports.log"; then
    bad "log has no ANSI escape"
  else
    ok "log has no ANSI escape"
  fi

  run_suite utf8_support 1
  if [ -d "$BUILD/utf8" ]; then ok "UTF-8 report directory created"; else bad "UTF-8 report directory created"; fi
  if [ -f "$BUILD/utf8/results.json" ] && [ -f "$BUILD/utf8/results.xml" ] && [ -f "$BUILD/utf8/results.log" ]; then
    ok "UTF-8 report files exist"
  else
    bad "UTF-8 report files exist"
  fi
  is_utf8 "$BUILD/utf8_support.out" "UTF-8 console is valid"
  contains "$BUILD/utf8_support.out" "$UTF8_PRIVET" "console preserves Cyrillic"
  contains "$BUILD/utf8_support.out" "$UTF8_EMOJI" "console preserves emoji"
  contains "$BUILD/utf8_support.out" "Total: 5  Passed: 2  Failed: 1  Skipped: 1  Pending: 1  Errors: 0" "UTF-8 summary"
  is_utf8 "$BUILD/utf8/results.json" "UTF-8 JSON is valid"
  contains "$BUILD/utf8/results.json" '"suite": "UTF8Suite"' "UTF-8 JSON suite"
  contains "$BUILD/utf8/results.json" "$UTF8_PRIVET" "JSON preserves Cyrillic"
  contains "$BUILD/utf8/results.json" "$UTF8_EMOJI" "JSON preserves emoji"
  contains "$BUILD/utf8/results.json" "$UTF8_CHINESE" "JSON preserves CJK"
  is_utf8 "$BUILD/utf8/results.xml" "UTF-8 JUnit is valid"
  contains "$BUILD/utf8/results.xml" "$UTF8_PRIVET" "JUnit preserves Cyrillic"
  contains "$BUILD/utf8/results.xml" "$UTF8_EMOJI" "JUnit preserves emoji"
  is_utf8 "$BUILD/utf8/results.log" "UTF-8 log is valid"
  contains "$BUILD/utf8/results.log" "$UTF8_PRIVET" "UTF-8 log preserves Cyrillic"
  contains "$BUILD/utf8/results.log" "$UTF8_EMOJI" "UTF-8 log preserves emoji"
  contains "$BUILD/utf8/results.log" "RESULT: FAILED (1 failure)" "UTF-8 log result"
  if LC_ALL=C grep -q "$(printf '\357\277\275')" "$BUILD/utf8/results.log"; then
    bad "truncation leaves no replacement character"
  else
    ok "truncation leaves no replacement character"
  fi

  run_suite ascii_only_expected 1
  is_ascii "$BUILD/ascii_only_expected.out" "ASCII-only console output"
  contains "$BUILD/ascii_only_expected.out" "RESULT: FAILED (1 failure)" "ASCII result line"

  run_suite quiet_expected 1
  not_contains "$BUILD/quiet_expected.out" "Testing.pb 1.0.0" "quiet hides banner"
  not_contains "$BUILD/quiet_expected.out" "[PASS]" "quiet hides passing tests"
  contains "$BUILD/quiet_expected.out" "[FAIL] FailShown" "quiet shows failures"
  contains "$BUILD/quiet_expected.out" "RESULT: FAILED (1 failure)" "quiet result line"

  run_suite verbose_expected 1
  contains "$BUILD/verbose_expected.out" "hook: BeforeEach" "verbose hook trace"
  contains "$BUILD/verbose_expected.out" "description: \"Integer division\"" "verbose description"

  run_suite repeatable 0
  if [ "$(grep -Fc "RESULT: OK" "$BUILD/repeatable.out")" -eq 2 ]; then
    ok "repeatable: two runs"
  else
    bad "repeatable: two runs"
  fi

  run_suite nested_macros 0
  contains "$BUILD/nested_macros.out" "RESULT: OK" "nested macros result"

  run_suite api_surface 0
  contains "$BUILD/api_surface.out" "RESULT: OK" "API surface result"

  run_suite run_named 0
  contains "$BUILD/run_named.out" "[PASS] SecondTest" "selected test ran"
  not_contains "$BUILD/run_named.out" "FirstTest" "unselected test did not run"

  run_suite directives 0
  contains "$BUILD/directives.out" "Suite: DirectiveSuite" "suite name directive"
  not_contains "$BUILD/directives.out" "[1/2]" "no progress outside a TTY"
  if [ -f "$BUILD/testing-results.json" ] && [ -f "$BUILD/testing-results.xml" ]; then
    ok "default report paths"
  else
    bad "default report paths"
  fi
  contains "$BUILD/testing-results.json" '"schema_version": 1' "default JSON schema"
  contains "$BUILD/testing-results.json" '"suite": "DirectiveSuite"' "default JSON suite"

  run_suite no_open_console 0
  contains "$BUILD/no_open_console.out" "Suite: CustomHost" "custom host suite"
  contains "$BUILD/no_open_console.out" "RESULT: OK" "custom host result"

  run_suite unicode_expected 0
  if LC_ALL=C grep -q "$(printf '\342\224\200')" "$BUILD/unicode_expected.out"; then
    ok "unicode U+2500 separator"
  else
    bad "unicode U+2500 separator"
  fi
  if [ -f "$BUILD/unicode/unicode.log" ]; then
    ok "unicode log exists"
  else
    bad "unicode log exists"
  fi
  is_utf8 "$BUILD/unicode/unicode.log" "unicode log is UTF-8"
  contains "$BUILD/unicode/unicode.log" "$(printf '\342\224\200')" "unicode log keeps U+2500"
  if LC_ALL=C grep -q "$(printf '\033')" "$BUILD/unicode/unicode.log"; then
    bad "unicode log has no ANSI escape"
  else
    ok "unicode log has no ANSI escape"
  fi

  run_suite color_modes 0
  contains "$BUILD/color_modes.out" "RESULT: OK" "color directive conflict result"

  NO_COLOR=1 run_suite env_no_color 0
  contains "$BUILD/env_no_color.out" "RESULT: OK" "NO_COLOR environment result"

  section "Examples"
  for pair in \
    "examples/basic/basic.pb:example_basic" \
    "examples/assertions/assertions.pb:example_assertions" \
    "examples/hooks/hooks.pb:example_hooks" \
    "examples/reports/reports.pb:example_reports"
  do
    rel="${pair%%:*}"
    name="${pair##*:}"
    exe="$BUILD/$name"

    if ! "$PB" "$ROOT/$rel" /OUTPUT "$exe" /CONSOLE /QUIET >"$BUILD/$name.compile.log" 2>&1; then
      bad "$rel compiles"
      continue
    fi
    ok "$rel compiles"

    ( cd "$BUILD" && "$exe" >"$name.out" 2>"$name.err" )
    code=$?
    if [ "$code" -eq 0 ]; then ok "$rel exits with 0"; else bad "$rel exits with 0"; fi
    contains "$BUILD/$name.out" "RESULT: OK" "$rel result line"
  done

  if [ -f "$BUILD/example-results.json" ] && [ -f "$BUILD/example-results.xml" ] && [ -f "$BUILD/example.log" ]; then
    ok "example report files exist"
  else
    bad "example report files exist"
  fi
}

case "${PB_BACKEND:-both}" in
  both) BACKENDS="fasm c" ;;
  fasm|c) BACKENDS="${PB_BACKEND}" ;;
  *)
    printf 'Invalid PB_BACKEND: %s (expected fasm, c or both)\n' "$PB_BACKEND" >&2
    exit 2
    ;;
esac

for backend in $BACKENDS; do
  if [ "$backend" = "fasm" ]; then
    resolved="$(resolve_compiler "${PB_COMPILER:-}" pbcompiler)"
    rc=$?
  else
    resolved="$(resolve_compiler "${PB_COMPILER_C:-}" pbcompilerc)"
    rc=$?
  fi

  if [ "$rc" -eq 1 ]; then
    bad "$backend: compiler configured but not found"
    continue
  fi
  if [ "$rc" -eq 2 ]; then
    printf 'SKIP %s: compiler not found\n' "$backend"
    continue
  fi

  PB="$resolved"
  BUILD="$ROOT/tests/.build/posix-$backend"
  RAN=$((RAN + 1))
  run_checks "$backend"
done

if [ "$RAN" -eq 0 ]; then
  printf '\nNo PureBasic compiler was found. Set PB_COMPILER/PB_COMPILER_C or install PureBasic.\n' >&2
  exit 1
fi

printf '\n==========================================================================\n'
if [ "$FAILED" -eq 0 ]; then
  printf 'ALL CHECKS PASSED: %s checks\n' "$TOTAL"
  exit 0
else
  printf 'FAILED: %s of %s checks\n' "$FAILED" "$TOTAL"
  exit 1
fi
