# ============================================================================
#  Testing.pb - release test runner
#
#  Usage:
#      .\run-tests.ps1                     # x64 and x86, fasm backend
#      .\run-tests.ps1 -Architecture x64   # one architecture
#      .\run-tests.ps1 -Architecture x86
#      .\run-tests.ps1 -Backend c          # C backend (pbcompilerc.exe)
#      .\run-tests.ps1 -Backend both       # fasm and C when available
#      .\run-tests.ps1 -CompilerX64 "C:\PB\Compilers\pbcompiler.exe"
#      .\run-tests.ps1 -CompilerC64 "C:\PB\Compilers\pbcompilerc.exe"
#
#  A compiler parameter may point to the executable or to its directory.
#  Missing auto-detected compilers are skipped; an explicitly supplied path
#  that does not exist is a test failure. If no compiler runs at all, the
#  script exits with 1.
#
#  Exit code: 0 when every check passes, 1 otherwise.
# ============================================================================

[CmdletBinding()]
param(
  [ValidateSet('x64', 'x86', 'both')]
  [string]$Architecture = 'both',

  [ValidateSet('fasm', 'c', 'both')]
  [string]$Backend = 'fasm',

  [string]$CompilerX64 = '',
  [string]$CompilerX86 = '',
  [string]$CompilerC64 = '',
  [string]$CompilerC86 = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$script:totalChecks = 0
$script:failedChecks = 0

# Sample UTF-8 text built from code points so this runner stays ASCII-only.
$utf8Privet = -join ([char[]](0x41F, 0x440, 0x438, 0x432, 0x435, 0x442))
$utf8Poka = -join ([char[]](0x41F, 0x43E, 0x43A, 0x430))
$utf8Emoji = [char]::ConvertFromUtf32(0x1F600)
$utf8Chinese = -join ([char[]](0x4E2D, 0x6587))
$utf8PrivetBytes = [System.Text.Encoding]::UTF8.GetBytes($utf8Privet)
$utf8EmojiBytes = [System.Text.Encoding]::UTF8.GetBytes($utf8Emoji)

function Write-Section([string]$text) {
  Write-Host ''
  Write-Host ('=' * 74) -ForegroundColor DarkGray
  Write-Host $text -ForegroundColor Cyan
  Write-Host ('=' * 74) -ForegroundColor DarkGray
}

function Assert-That([bool]$condition, [string]$label) {
  $script:totalChecks++
  if ($condition) {
    Write-Host ('  [ OK ] ' + $label) -ForegroundColor Green
  } else {
    $script:failedChecks++
    Write-Host ('  [FAIL] ' + $label) -ForegroundColor Red
  }
}

function Assert-Contains([string]$text, [string]$needle, [string]$label) {
  Assert-That ($text.Contains($needle)) ($label + " [contains " + $needle + "]")
}

function Assert-NotContains([string]$text, [string]$needle, [string]$label) {
  Assert-That (-not $text.Contains($needle)) ($label + " [does not contain " + $needle + "]")
}

function Assert-Matches([string]$text, [string]$pattern, [string]$label) {
  Assert-That ($text -match $pattern) ($label + " [matches " + $pattern + "]")
}

function Count-Text([string]$text, [string]$needle) {
  if ($needle.Length -eq 0) { return 0 }
  $count = 0
  $position = 0
  while (($position = $text.IndexOf($needle, $position, [StringComparison]::Ordinal)) -ge 0) {
    $count++
    $position += $needle.Length
  }
  return $count
}

function Assert-AsciiBytes([byte[]]$bytes, [string]$label) {
  $maximum = 0
  if ($bytes.Length -gt 0) {
    $maximum = ($bytes | Measure-Object -Maximum).Maximum
  }
  Assert-That ($maximum -lt 128) ($label + " [max byte " + $maximum + " < 128]")
  Assert-That (-not ($bytes -contains 27)) ($label + " [no ESC/ANSI byte]")
}

function Assert-Utf8Bytes([byte[]]$bytes, [string]$label) {
  $valid = $true
  try {
    $strict = New-Object System.Text.UTF8Encoding($false, $true)
    $null = $strict.GetString($bytes)
  } catch {
    $valid = $false
  }
  Assert-That $valid ($label + " [valid UTF-8]")
  Assert-That (-not ($bytes -contains 27)) ($label + " [no ESC/ANSI byte]")
}

function Assert-ContainsBytes([byte[]]$haystack, [byte[]]$needle, [string]$label) {
  $found = $false
  if ($needle.Length -gt 0 -and $haystack.Length -ge $needle.Length) {
    for ($i = 0; $i -le ($haystack.Length - $needle.Length); $i++) {
      $match = $true
      for ($j = 0; $j -lt $needle.Length; $j++) {
        if ($haystack[$i + $j] -ne $needle[$j]) {
          $match = $false
          break
        }
      }
      if ($match) {
        $found = $true
        break
      }
    }
  }
  Assert-That $found ($label + " [UTF-8 byte sequence present]")
}

function Get-CompilerSpec([string]$arch, [string]$backendName, [string]$explicitPath) {
  $exeName = if ($backendName -eq 'c') { 'pbcompilerc.exe' } else { 'pbcompiler.exe' }

  if ($explicitPath -ne '') {
    $candidate = $explicitPath
    if (Test-Path -LiteralPath $candidate -PathType Container) {
      $candidate = Join-Path $candidate $exeName
    }
    return [pscustomobject]@{ Path = $candidate; Required = $true }
  }

  # Existing environment override: PB_COMPILER_X64 / PB_COMPILER_X86. The C
  # backend additionally accepts PB_COMPILER_C_X64 / PB_COMPILER_C_X86.
  $envName = if ($backendName -eq 'c') { 'PB_COMPILER_C_' + $arch.ToUpper() } else { 'PB_COMPILER_' + $arch.ToUpper() }
  $override = [Environment]::GetEnvironmentVariable($envName)
  if (-not $override -and $backendName -eq 'fasm') {
    $override = [Environment]::GetEnvironmentVariable('PB_' + $arch.ToUpper())
  }
  if ($override) {
    $candidate = $override
    if (Test-Path -LiteralPath $candidate -PathType Container) {
      $candidate = Join-Path $candidate $exeName
    }
    return [pscustomobject]@{ Path = $candidate; Required = $true }
  }

  $defaultDir = if ($arch -eq 'x64') {
    'C:\Program Files\PureBasic\Compilers'
  } else {
    'C:\Program Files (x86)\PureBasic\Compilers'
  }
  return [pscustomobject]@{ Path = (Join-Path $defaultDir $exeName); Required = $false }
}

function Run-Program([string]$exe, [string]$workDir, [string]$outFile, [string]$errFile) {
  # cmd.exe preserves the process exit code and writes raw bytes to the files.
  $code = 0
  Push-Location -LiteralPath $workDir
  try {
    & $env:ComSpec /c "`"$exe`" > `"$outFile`" 2> `"$errFile`""
    $code = $LASTEXITCODE
  } finally {
    Pop-Location
  }
  return $code
}

$suites = @(
  'framework_tests',
  'failure_expected',
  'error_expected',
  'assertions_fail_expected',
  'reports',
  'utf8_support',
  'ascii_only_expected',
  'quiet_expected',
  'verbose_expected',
  'repeatable',
  'nested_macros',
  'api_surface',
  'run_named',
  'directives',
  'no_open_console',
  'unicode_expected',
  'color_modes',
  'env_no_color'
)

$expectedExit = @{
  'framework_tests'          = 0
  'failure_expected'         = 1
  'error_expected'           = 1
  'assertions_fail_expected' = 1
  'reports'                  = 1
  'utf8_support'             = 1
  'ascii_only_expected'      = 1
  'quiet_expected'           = 1
  'verbose_expected'         = 1
  'repeatable'               = 0
  'nested_macros'            = 0
  'api_surface'              = 0
  'run_named'                = 0
  'directives'               = 0
  'no_open_console'          = 0
  'unicode_expected'         = 0
  'color_modes'              = 0
  'env_no_color'             = 0
}

$architectures = switch ($Architecture) {
  'both' { @('x64', 'x86') }
  default { @($Architecture) }
}

$backendNames = switch ($Backend) {
  'both' { @('fasm', 'c') }
  default { @($Backend) }
}

$jobs = @()
$skippedCompilers = @()

foreach ($arch in $architectures) {
  foreach ($backendName in $backendNames) {
    $explicit = switch ($arch + '/' + $backendName) {
      'x64/fasm' { $CompilerX64 }
      'x86/fasm' { $CompilerX86 }
      'x64/c'    { $CompilerC64 }
      'x86/c'    { $CompilerC86 }
      default    { '' }
    }

    $spec = Get-CompilerSpec $arch $backendName $explicit
    if (Test-Path -LiteralPath $spec.Path -PathType Leaf) {
      $jobs += [pscustomobject]@{
        Arch     = $arch
        Backend  = $backendName
        Compiler = (Resolve-Path -LiteralPath $spec.Path).Path
      }
    } elseif ($spec.Required) {
      Assert-That $false ($arch + ' ' + $backendName + ': compiler exists at ' + $spec.Path)
    } else {
      $skippedCompilers += ($arch + ' ' + $backendName + ': ' + $spec.Path)
      Write-Host ('SKIP ' + $arch + ' ' + $backendName + ': compiler not found (' + $spec.Path + ')') -ForegroundColor Yellow
    }
  }
}

if ($jobs.Count -eq 0) {
  Write-Host ''
  Write-Host 'No PureBasic compiler was found. Set -CompilerX64/-CompilerX86/-CompilerC64/-CompilerC86 or install PureBasic.' -ForegroundColor Red
  exit 1
}

$overallStart = Get-Date

foreach ($job in $jobs) {
  Write-Section ("Testing.pb test run: " + $job.Arch + ", " + $job.Backend + " backend")

  $compiler = $job.Compiler
  Write-Host ("Compiler: " + $compiler) -ForegroundColor DarkGray

  $buildDir = Join-Path $root ("tests\.build\" + $job.Arch + "-" + $job.Backend)
  if (Test-Path -LiteralPath $buildDir) {
    Remove-Item -LiteralPath $buildDir -Recurse -Force
  }
  New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

  foreach ($suite in $suites) {
    $source = Join-Path $root ("tests\" + $suite + ".pb")
    $exe = Join-Path $buildDir ($suite + ".exe")
    $stdoutFile = Join-Path $buildDir ($suite + ".stdout.txt")
    $stderrFile = Join-Path $buildDir ($suite + ".stderr.txt")

    Write-Host ''
    Write-Host ("-> " + $suite) -ForegroundColor White

    if (-not (Test-Path -LiteralPath $source)) {
      Assert-That $false ($suite + ": source file exists")
      continue
    }

    $compileOutput = (& $compiler $source /OUTPUT $exe /CONSOLE /QUIET 2>&1 | Out-String)
    $compileCode = $LASTEXITCODE
    Assert-That ($compileCode -eq 0) ($suite + ": compiles")
    if ($compileCode -ne 0) {
      if ($compileOutput.Trim().Length -gt 0) {
        Write-Host $compileOutput.Trim() -ForegroundColor DarkYellow
      }
      continue
    }

    $savedNoColor = [Environment]::GetEnvironmentVariable('NO_COLOR')
    if ($suite -eq 'env_no_color') {
      [Environment]::SetEnvironmentVariable('NO_COLOR', '1')
    }

    try {
      $exitCode = Run-Program $exe $buildDir $stdoutFile $stderrFile
    } finally {
      [Environment]::SetEnvironmentVariable('NO_COLOR', $savedNoColor)
    }

    $outBytes = [System.IO.File]::ReadAllBytes($stdoutFile)
    $errBytes = [System.IO.File]::ReadAllBytes($stderrFile)
    $outText = [System.Text.Encoding]::UTF8.GetString($outBytes)
    $errText = [System.Text.Encoding]::UTF8.GetString($errBytes)

    Assert-That ($exitCode -eq $expectedExit[$suite]) ($suite + ": exit code " + $exitCode + " (expected " + $expectedExit[$suite] + ")")
    Assert-That ($errBytes.Length -eq 0) ($suite + ": no stderr output")
    if ($errBytes.Length -gt 0) {
      Write-Host $errText.Trim() -ForegroundColor DarkYellow
    }

    switch ($suite) {
      'framework_tests' {
        Assert-Contains $outText 'Suite: FrameworkSelfTests' 'suite name'
        Assert-Contains $outText 'RESULT: OK' 'result line'
        Assert-That ((Count-Text $outText '[PASS]') -eq 10) 'ten passing tests'
        Assert-Contains $outText '[SKIP] SkippedByDesign' 'skip status'
        Assert-Contains $outText '[PEND] PendingByDesign' 'pending status'
        Assert-Contains $outText 'intentional skip' 'skip reason'
        Assert-Contains $outText 'intentional pending' 'pending reason'
        Assert-Contains $outText 'Total: 12  Passed: 10  Failed: 0  Skipped: 1  Pending: 1  Errors: 0' 'one-line summary'
        Assert-Matches $outText '(?m)^\[PASS\] HookOrderAndIsolation\s+[0-9]+ ms\r?$' 'status field and right-aligned time'
        $lastLine = @($outText -split "`r?`n" | Where-Object { $_ -ne '' })[-1]
        Assert-That ($lastLine -eq 'RESULT: OK') 'RESULT is the last line'
      }

      'failure_expected' {
        Assert-That ((Count-Text $outText '[FAIL]') -eq 1) 'exactly one failure'
        Assert-Contains $outText 'AssertEqual failed -- "one is not two"' 'assertion message and description'
        Assert-Contains $outText 'expected: 2, actual: 1' 'expected and actual values'
        Assert-Matches $outText '(?m)^       at failure_expected\.pb:[0-9]+\r?$' 'indented source location'
        Assert-Contains $outText '[PASS] AfterEachStillRan' 'AfterEach ran after failure'
        Assert-Contains $outText 'RESULT: FAILED (1 failure)' 'failure result line'
      }

      'error_expected' {
        Assert-Contains $outText '[ERR]  IntentionalError' 'error status'
        Assert-Contains $outText 'deliberate error' 'error message'
        Assert-Matches $outText '(?m)^       at error_expected\.pb:[0-9]+\r?$' 'error source location'
        Assert-Contains $outText '[PASS] RecoveryAfterError' 'suite continued after error'
        Assert-Contains $outText 'Errors: 1' 'error counter'
        Assert-Contains $outText 'RESULT: FAILED (1 failure)' 'error affects result'
      }

      'assertions_fail_expected' {
        Assert-That ((Count-Text $outText '[FAIL]') -eq 16) 'all sixteen assertions failed'
        Assert-Contains $outText 'AssertEqual failed -- "numbers"' 'AssertEqual message'
        Assert-Contains $outText 'AssertNotEqual failed -- "not equal"' 'AssertNotEqual message'
        Assert-Contains $outText 'expected: > 2, actual: 1' 'AssertBigger details'
        Assert-Contains $outText 'expected: < 2, actual: 3' 'AssertSmaller details'
        Assert-Contains $outText 'expected: [1, 10], actual: 11' 'AssertInRange details'
        Assert-Contains $outText 'AssertApproxEqual failed -- "approx"' 'AssertApproxEqual message'
        Assert-Contains $outText 'AssertStrEqual failed -- "strings"' 'AssertStrEqual message'
        Assert-Contains $outText 'AssertStrNotEqual failed -- "string inequality"' 'AssertStrNotEqual message'
        Assert-Contains $outText 'AssertStrContains failed -- "substring"' 'AssertStrContains message'
        Assert-Contains $outText 'AssertNull failed -- "pointer is set"' 'AssertNull message'
        Assert-Contains $outText 'AssertNotNull failed -- "pointer is null"' 'AssertNotNull message'
        Assert-Contains $outText 'AssertListEqual failed -- "list size"' 'list size mismatch'
        Assert-Contains $outText 'lists differ at index 1' 'list element mismatch'
        Assert-Contains $outText 'AssertStrListEqual at index 1 failed' 'string list mismatch'
        Assert-Contains $outText 'AssertStructureEqual failed -- "structure"' 'structure mismatch'
        Assert-Contains $outText 'Assert failed -- "boolean"' 'boolean assertion'
        Assert-Contains $outText 'Total: 16  Passed: 0  Failed: 16  Skipped: 0  Pending: 0  Errors: 0' 'summary counters'
      }

      'reports' {
        $artifacts = Join-Path $buildDir 'artifacts'
        $jsonPath = Join-Path $artifacts 'reports.json'
        $xmlPath = Join-Path $artifacts 'reports.xml'
        $logPath = Join-Path $artifacts 'reports.log'

        Assert-That (Test-Path -LiteralPath $artifacts -PathType Container) 'nested report directory was created'
        Assert-That (Test-Path -LiteralPath $jsonPath) 'JSON report exists'
        Assert-That (Test-Path -LiteralPath $xmlPath) 'JUnit report exists'
        Assert-That (Test-Path -LiteralPath $logPath) 'log file exists'

        if (Test-Path -LiteralPath $jsonPath) {
          $jsonBytes = [System.IO.File]::ReadAllBytes($jsonPath)
          Assert-That (-not ($jsonBytes.Length -ge 3 -and $jsonBytes[0] -eq 0xEF -and $jsonBytes[1] -eq 0xBB -and $jsonBytes[2] -eq 0xBF)) 'JSON has no UTF-8 BOM'
          try {
            $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
            $jsonText = $strictUtf8.GetString($jsonBytes)
            $json = $jsonText | ConvertFrom-Json
            Assert-That $true 'JSON parses'
          } catch {
            Assert-That $false ('JSON parses: ' + $_.Exception.Message)
            $json = $null
          }

          if ($json -ne $null) {
            Assert-That ($json.schema_version -eq 1) 'JSON schema_version is 1'
            Assert-That ($json.framework -eq 'Testing.pb') 'JSON framework name'
            Assert-That ($json.suite -eq 'ReportSuite') 'JSON suite name'
            Assert-That ($json.summary.total -eq 6) 'JSON total'
            Assert-That ($json.summary.passed -eq 2) 'JSON passed count'
            Assert-That ($json.summary.failed -eq 1) 'JSON failed count'
            Assert-That ($json.summary.skipped -eq 1) 'JSON skipped count'
            Assert-That ($json.summary.pending -eq 1) 'JSON pending count'
            Assert-That ($json.summary.errors -eq 1) 'JSON error count'
            Assert-That (@($json.tests).Count -eq 6) 'JSON test array length'

            $byName = @{}
            foreach ($test in $json.tests) { $byName[$test.name] = $test }
            Assert-That ($byName['PassPlain'].status -eq 'passed') 'JSON passed status'
            Assert-That ($byName['QuotingAndUnicode'].status -eq 'failed') 'JSON failed status'
            Assert-That ($byName['SkippedOne'].status -eq 'skipped') 'JSON skipped status'
            Assert-That ($byName['PendingOne'].status -eq 'pending') 'JSON pending status'
            Assert-That ($byName['ErrorOne'].status -eq 'error') 'JSON error status'

            $failedTest = $byName['QuotingAndUnicode']
            Assert-That ($failedTest.expected -eq '2' -and $failedTest.actual -eq '1') 'JSON expected/actual'
            Assert-That ($failedTest.line -gt 0) 'JSON source line'
            Assert-That ($failedTest.file.Contains('reports.pb')) 'JSON source file'
            Assert-Matches ([string]$failedTest.description) '[^\x00-\x7F]' 'JSON preserves non-ASCII UTF-8 text'
            Assert-That ($failedTest.description.Contains('quote " slash \ tab')) 'JSON escapes quotes and backslashes'
            Assert-That ($failedTest.message.Contains('AssertEqual failed')) 'JSON carries assertion message'
          }
        }

        if (Test-Path -LiteralPath $xmlPath) {
          try {
            [xml]$xml = [System.IO.File]::ReadAllText($xmlPath, [System.Text.Encoding]::UTF8)
            Assert-That $true 'JUnit XML parses'
          } catch {
            Assert-That $false ('JUnit XML parses: ' + $_.Exception.Message)
            $xml = $null
          }

          if ($xml -ne $null) {
            $rootNode = $xml.testsuites
            Assert-That ($rootNode.tests -eq '6') 'JUnit tests attribute'
            Assert-That ($rootNode.failures -eq '1') 'JUnit failures attribute'
            Assert-That ($rootNode.errors -eq '1') 'JUnit errors attribute'
            Assert-That ($rootNode.skipped -eq '2') 'JUnit skipped includes pending'
            Assert-That ($xml.SelectNodes('//testcase').Count -eq 6) 'JUnit testcase count'
            Assert-That ($xml.SelectNodes('//testcase/failure').Count -eq 1) 'JUnit failure element'
            Assert-That ($xml.SelectNodes('//testcase/error').Count -eq 1) 'JUnit error element'
            Assert-That ($xml.SelectNodes('//testcase/skipped').Count -eq 2) 'JUnit skipped elements'
          }
        }

        Assert-Utf8Bytes $outBytes 'report console is valid UTF-8'
        Assert-ContainsBytes $outBytes $utf8PrivetBytes 'report console preserves Cyrillic text'

        if (Test-Path -LiteralPath $logPath) {
          $logBytes = [System.IO.File]::ReadAllBytes($logPath)
          Assert-Utf8Bytes $logBytes 'log is valid UTF-8'
          Assert-That (-not ($logBytes.Length -ge 3 -and $logBytes[0] -eq 0xEF -and $logBytes[1] -eq 0xBB -and $logBytes[2] -eq 0xBF)) 'log has no UTF-8 BOM'
          Assert-ContainsBytes $logBytes $utf8PrivetBytes 'log preserves Cyrillic text'
          $logText = (New-Object System.Text.UTF8Encoding($false, $true)).GetString($logBytes)
          Assert-Contains $logText 'Testing.pb 1.0.0' 'log banner'
          Assert-Contains $logText 'Suite: ReportSuite' 'log suite name'
          Assert-Contains $logText '[PASS] PassPlain' 'log contains passing test'
          Assert-Contains $logText '[FAIL] QuotingAndUnicode' 'log contains failing test'
          Assert-Contains $logText 'RESULT: FAILED (2 failures)' 'log result line'
        }
      }

      'utf8_support' {
        $utf8Dir = Join-Path $buildDir 'utf8'
        $jsonPath = Join-Path $utf8Dir 'results.json'
        $xmlPath = Join-Path $utf8Dir 'results.xml'
        $logPath = Join-Path $utf8Dir 'results.log'

        Assert-That (Test-Path -LiteralPath $utf8Dir -PathType Container) 'UTF-8 report directory was created'
        Assert-That (Test-Path -LiteralPath $jsonPath) 'UTF-8 JSON report exists'
        Assert-That (Test-Path -LiteralPath $xmlPath) 'UTF-8 JUnit report exists'
        Assert-That (Test-Path -LiteralPath $logPath) 'UTF-8 log exists'

        Assert-Utf8Bytes $outBytes 'UTF-8 console output is valid'
        Assert-ContainsBytes $outBytes $utf8PrivetBytes 'console preserves Cyrillic UTF-8'
        Assert-ContainsBytes $outBytes $utf8EmojiBytes 'console preserves emoji UTF-8'
        Assert-Contains $outText '[FAIL] FailureWithUnicode' 'Unicode failure line'
        Assert-Contains $outText '[SKIP] SkipUnicode' 'Unicode skip line'
        Assert-Contains $outText '[PEND] PendingUnicode' 'Unicode pending line'
        Assert-Contains $outText 'Total: 5  Passed: 2  Failed: 1  Skipped: 1  Pending: 1  Errors: 0' 'UTF-8 summary'
        Assert-Contains $outText 'RESULT: FAILED (1 failure)' 'UTF-8 result line'

        if (Test-Path -LiteralPath $jsonPath) {
          $jsonBytes = [System.IO.File]::ReadAllBytes($jsonPath)
          Assert-That (-not ($jsonBytes.Length -ge 3 -and $jsonBytes[0] -eq 0xEF -and $jsonBytes[1] -eq 0xBB -and $jsonBytes[2] -eq 0xBF)) 'UTF-8 JSON has no BOM'
          Assert-ContainsBytes $jsonBytes $utf8PrivetBytes 'JSON preserves Cyrillic UTF-8'
          Assert-ContainsBytes $jsonBytes $utf8EmojiBytes 'JSON preserves emoji UTF-8'
          try {
            $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
            $jsonText = $strictUtf8.GetString($jsonBytes)
            $json = $jsonText | ConvertFrom-Json
            Assert-That $true 'UTF-8 JSON parses'
          } catch {
            Assert-That $false ('UTF-8 JSON parses: ' + $_.Exception.Message)
            $json = $null
          }

          if ($json -ne $null) {
            Assert-That ($json.suite -eq 'UTF8Suite') 'UTF-8 JSON suite name'
            Assert-That ($json.summary.total -eq 5) 'UTF-8 JSON total'
            Assert-That ($json.summary.failed -eq 1) 'UTF-8 JSON failed count'
            Assert-That ($json.summary.skipped -eq 1) 'UTF-8 JSON skipped count'
            Assert-That ($json.summary.pending -eq 1) 'UTF-8 JSON pending count'

            $byName = @{}
            foreach ($test in $json.tests) { $byName[$test.name] = $test }
            Assert-That ($byName['CyrillicSourceLiterals'].status -eq 'passed') 'UTF-8 source literals pass'
            Assert-That ($byName['EmojiAndCjkSourceLiterals'].status -eq 'passed') 'UTF-8 emoji/CJK literals pass'
            Assert-That ($byName['FailureWithUnicode'].expected -eq $utf8Privet) 'JSON expected Unicode'
            Assert-That ($byName['FailureWithUnicode'].actual -eq $utf8Poka) 'JSON actual Unicode'
            Assert-That ($byName['FailureWithUnicode'].description.Contains($utf8Emoji)) 'JSON Unicode description'
            Assert-That ($byName['SkipUnicode'].message.Contains($utf8Emoji)) 'JSON Unicode skip reason'
            Assert-That ($byName['PendingUnicode'].message.Contains($utf8Chinese)) 'JSON CJK pending reason'
          }
        }

        if (Test-Path -LiteralPath $xmlPath) {
          $xmlBytes = [System.IO.File]::ReadAllBytes($xmlPath)
          Assert-Utf8Bytes $xmlBytes 'UTF-8 JUnit XML is valid'
          Assert-ContainsBytes $xmlBytes $utf8PrivetBytes 'JUnit preserves Cyrillic UTF-8'
          Assert-ContainsBytes $xmlBytes $utf8EmojiBytes 'JUnit preserves emoji UTF-8'
          try {
            [xml]$xml = [System.IO.File]::ReadAllText($xmlPath, [System.Text.Encoding]::UTF8)
            Assert-That $true 'UTF-8 JUnit XML parses'
          } catch {
            Assert-That $false ('UTF-8 JUnit XML parses: ' + $_.Exception.Message)
            $xml = $null
          }

          if ($xml -ne $null) {
            Assert-That ($xml.SelectNodes('//testcase').Count -eq 5) 'UTF-8 JUnit testcase count'
            Assert-That ($xml.SelectNodes('//testcase/failure').Count -eq 1) 'UTF-8 JUnit failure element'
            $failureNode = $xml.SelectSingleNode('//testcase[@name="FailureWithUnicode"]/failure')
            Assert-That ($failureNode -ne $null) 'UTF-8 JUnit failure node'
            if ($failureNode -ne $null) {
              Assert-That ($failureNode.InnerText.Contains($utf8Privet)) 'JUnit failure preserves expected text'
              Assert-That ($failureNode.InnerText.Contains($utf8Emoji)) 'JUnit failure preserves description'
            }
          }
        }

        if (Test-Path -LiteralPath $logPath) {
          $logBytes = [System.IO.File]::ReadAllBytes($logPath)
          Assert-Utf8Bytes $logBytes 'UTF-8 log is valid'
          Assert-That (-not ($logBytes.Length -ge 3 -and $logBytes[0] -eq 0xEF -and $logBytes[1] -eq 0xBB -and $logBytes[2] -eq 0xBF)) 'UTF-8 log has no BOM'
          Assert-ContainsBytes $logBytes $utf8PrivetBytes 'log preserves Cyrillic UTF-8'
          Assert-ContainsBytes $logBytes $utf8EmojiBytes 'log preserves emoji UTF-8'
          $logText = (New-Object System.Text.UTF8Encoding($false, $true)).GetString($logBytes)
          Assert-Contains $logText 'Testing.pb 1.0.0' 'UTF-8 log banner'
          Assert-Contains $logText 'Suite: UTF8Suite' 'UTF-8 log suite'
          Assert-Contains $logText '[FAIL] FailureWithUnicode' 'UTF-8 log failing test'
          Assert-Contains $logText '[SKIP] SkipUnicode' 'UTF-8 log skip test'
          Assert-Contains $logText 'RESULT: FAILED (1 failure)' 'UTF-8 log result'

          $skipLine = ($logText -split "`r?`n" | Where-Object { $_.StartsWith('[SKIP] SkipUnicode') } | Select-Object -First 1)
          Assert-That ($skipLine -ne $null) 'UTF-8 log skip line exists'
          if ($skipLine -ne $null) {
            Assert-That ($skipLine.EndsWith('...')) 'truncated Unicode reason ends with ellipsis'
            Assert-That ([char]::IsLowSurrogate($skipLine[$skipLine.Length - 4])) 'truncation keeps a complete surrogate pair'
            Assert-That (-not $skipLine.Contains([char]0xFFFD)) 'truncation leaves no replacement character'
          }
        }
      }

      'ascii_only_expected' {
        Assert-AsciiBytes $outBytes 'console output is ASCII-only'
        $asciiText = [System.Text.Encoding]::ASCII.GetString($outBytes)
        Assert-Contains $asciiText 'Suite: AsciiOnly' 'ASCII suite banner'
        Assert-Contains $asciiText 'AssertEqual failed -- "plain ascii description"' 'ASCII compact diagnostic'
        Assert-Contains $asciiText '[FAIL] FailAscii' 'ASCII failure line'
        Assert-Contains $asciiText 'plain ascii description' 'ASCII description'
        Assert-Contains $asciiText 'RESULT: FAILED (1 failure)' 'ASCII result line'
      }

      'quiet_expected' {
        Assert-NotContains $outText 'Testing.pb 1.0.0' 'quiet hides banner'
        Assert-NotContains $outText 'Suite:' 'quiet hides suite line'
        Assert-NotContains $outText '[PASS]' 'quiet hides passing tests'
        Assert-Contains $outText '[FAIL] FailShown' 'quiet shows failures'
        Assert-Contains $outText 'visible failure' 'quiet shows description'
        Assert-Contains $outText 'Total: 2  Passed: 1  Failed: 1  Skipped: 0  Pending: 0  Errors: 0' 'quiet summary'
        Assert-Contains $outText 'RESULT: FAILED (1 failure)' 'quiet result line'

        $quietLogPath = Join-Path $buildDir 'quiet.log'
        Assert-That (Test-Path -LiteralPath $quietLogPath) 'quiet log exists'
        if (Test-Path -LiteralPath $quietLogPath) {
          $quietLogBytes = [System.IO.File]::ReadAllBytes($quietLogPath)
          Assert-AsciiBytes $quietLogBytes 'quiet log is ASCII'
          $quietLog = [System.Text.Encoding]::ASCII.GetString($quietLogBytes)
          Assert-Contains $quietLog 'Testing.pb 1.0.0' 'quiet log has banner'
          Assert-Contains $quietLog '[PASS] PassHidden' 'quiet log has passing test'
          Assert-Contains $quietLog '[FAIL] FailShown' 'quiet log has failing test'
        }
      }

      'verbose_expected' {
        Assert-Contains $outText '-> VerboseFailure' 'verbose test trace'
        Assert-Contains $outText 'hook: BeforeEach' 'BeforeEach trace'
        Assert-Contains $outText 'hook: AfterEach' 'AfterEach trace'
        Assert-Contains $outText 'message:  AssertEqual failed' 'verbose message line'
        Assert-Contains $outText 'expected: 7' 'verbose expected line'
        Assert-Contains $outText 'actual:   5' 'verbose actual line'
        Assert-Contains $outText 'description: "Integer division"' 'verbose description line'
        Assert-Matches $outText '(?m)^       at verbose_expected\.pb:[0-9]+\r?$' 'verbose location line'
        Assert-Contains $outText '[SKIP] VerboseSkip' 'verbose skip status'
        Assert-Contains $outText 'why not' 'verbose skip reason'
      }

      'repeatable' {
        Assert-That ((Count-Text $outText 'RESULT: OK') -eq 2) 'two complete runs'
        Assert-That ((Count-Text $outText '[PASS] Repeatable') -eq 2) 'test ran twice'
      }

      'nested_macros' {
        Assert-Contains $outText '[PASS] NestedMacrosInControlFlow' 'nested macros compile and pass'
        Assert-Contains $outText 'RESULT: OK' 'nested macro result'
      }

      'api_surface' {
        Assert-Contains $outText '[PASS] ModuleHelpers' 'module API test'
        Assert-Contains $outText 'RESULT: OK' 'module API result'
      }

      'run_named' {
        Assert-Contains $outText '[PASS] SecondTest' 'selected test ran'
        Assert-NotContains $outText 'FirstTest' 'unselected test did not run'
        Assert-Contains $outText 'Total: 1  Passed: 1  Failed: 0  Skipped: 0  Pending: 0  Errors: 0' 'single-test summary'
        Assert-Contains $outText 'RESULT: OK' 'single-test result'
      }

      'directives' {
        Assert-Contains $outText 'Suite: DirectiveSuite' '#TESTING_SUITE$ sets the suite name'
        Assert-Contains $outText 'Total: 2  Passed: 1  Failed: 0  Skipped: 1  Pending: 0  Errors: 0' 'directive suite summary'
        Assert-Contains $outText 'RESULT: OK' 'directive suite result'
        Assert-NotContains $outText '[1/2]' 'progress stays off when not a TTY'

        $defaultJson = Join-Path $buildDir 'testing-results.json'
        $defaultXml = Join-Path $buildDir 'testing-results.xml'
        Assert-That (Test-Path -LiteralPath $defaultJson) 'default JSON path was used'
        Assert-That (Test-Path -LiteralPath $defaultXml) 'default JUnit path was used'

        if (Test-Path -LiteralPath $defaultJson) {
          try {
            $directiveJson = [System.IO.File]::ReadAllText($defaultJson, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
            Assert-That ($directiveJson.schema_version -eq 1) 'default JSON schema_version'
            Assert-That ($directiveJson.suite -eq 'DirectiveSuite') 'default JSON suite name'
            Assert-That ($directiveJson.summary.total -eq 2) 'default JSON total'
            Assert-That ($directiveJson.summary.skipped -eq 1) 'default JSON skipped'
          } catch {
            Assert-That $false ('default JSON parses: ' + $_.Exception.Message)
          }
        }

        if (Test-Path -LiteralPath $defaultXml) {
          try {
            [xml]$directiveXml = [System.IO.File]::ReadAllText($defaultXml, [System.Text.Encoding]::UTF8)
            Assert-That ($directiveXml.testsuites.tests -eq '2') 'default JUnit tests'
            Assert-That ($directiveXml.testsuites.skipped -eq '1') 'default JUnit skipped'
          } catch {
            Assert-That $false ('default JUnit parses: ' + $_.Exception.Message)
          }
        }
      }

      'no_open_console' {
        Assert-That ($outText.Trim().Length -gt 0) 'host-opened console produced output'
        Assert-Contains $outText 'Suite: CustomHost' '#TESTING_SUITE$ with a custom host'
        Assert-Contains $outText '[PASS] HostOpenedConsole' 'custom host test passed'
        Assert-Contains $outText 'RESULT: OK' 'custom host result'
      }

      'unicode_expected' {
        Assert-Contains $outText 'RESULT: OK' 'unicode mode result'
        $u2500 = 0
        for ($i = 0; $i -le $outBytes.Length - 3; $i++) {
          if ($outBytes[$i] -eq 0xE2 -and $outBytes[$i + 1] -eq 0x94 -and $outBytes[$i + 2] -eq 0x80) {
            $u2500++
          }
        }
        Assert-That ($u2500 -eq 160) ('unicode separator U+2500 fills both rules with 80 characters [' + $u2500 + ']')

        $unicodeLogPath = Join-Path $buildDir 'unicode\unicode.log'
        Assert-That (Test-Path -LiteralPath $unicodeLogPath) 'unicode log exists'
        if (Test-Path -LiteralPath $unicodeLogPath) {
          $unicodeLogBytes = [System.IO.File]::ReadAllBytes($unicodeLogPath)
          Assert-Utf8Bytes $unicodeLogBytes 'unicode log is valid UTF-8'
          Assert-That (-not ($unicodeLogBytes.Length -ge 3 -and $unicodeLogBytes[0] -eq 0xEF -and $unicodeLogBytes[1] -eq 0xBB -and $unicodeLogBytes[2] -eq 0xBF)) 'unicode log has no BOM'
          $logU2500 = 0
          for ($i = 0; $i -le $unicodeLogBytes.Length - 3; $i++) {
            if ($unicodeLogBytes[$i] -eq 0xE2 -and $unicodeLogBytes[$i + 1] -eq 0x94 -and $unicodeLogBytes[$i + 2] -eq 0x80) {
              $logU2500++
            }
          }
          Assert-That ($logU2500 -eq 160) ('unicode log keeps U+2500 separators [' + $logU2500 + ']')
        }
      }

      'color_modes' {
        Assert-Contains $outText '[PASS] NoColorHasPriority' 'NO_COLOR/COLOR_ON conflict test passed'
        Assert-Contains $outText 'RESULT: OK' 'color conflict result'
        Assert-That (-not ($outBytes -contains 27)) 'no ANSI escape in forced conflict mode'
      }

      'env_no_color' {
        Assert-Contains $outText '[PASS] EnvironmentNoColor' 'NO_COLOR environment overrides COLOR_ON'
        Assert-Contains $outText 'RESULT: OK' 'environment color result'
      }
    }
  }

  $examples = @(
    @{ Path = 'examples\basic\basic.pb';      Name = 'example_basic';      Summary = 'Total: 2' },
    @{ Path = 'examples\assertions\assertions.pb'; Name = 'example_assertions'; Summary = 'Total: 6' },
    @{ Path = 'examples\hooks\hooks.pb';      Name = 'example_hooks';      Summary = 'Total: 2' },
    @{ Path = 'examples\reports\reports.pb';  Name = 'example_reports';    Summary = 'Total: 3' }
  )

  foreach ($example in $examples) {
    $source = Join-Path $root $example.Path
    $name = $example.Name
    $exe = Join-Path $buildDir ($name + '.exe')
    $stdoutFile = Join-Path $buildDir ($name + '.stdout.txt')
    $stderrFile = Join-Path $buildDir ($name + '.stderr.txt')

    Write-Host ''
    Write-Host ("-> " + $example.Path) -ForegroundColor White

    $compileOutput = (& $compiler $source /OUTPUT $exe /CONSOLE /QUIET 2>&1 | Out-String)
    $compileCode = $LASTEXITCODE
    Assert-That ($compileCode -eq 0) ($name + ': compiles')
    if ($compileCode -ne 0) {
      if ($compileOutput.Trim().Length -gt 0) {
        Write-Host $compileOutput.Trim() -ForegroundColor DarkYellow
      }
      continue
    }

    $exitCode = Run-Program $exe $buildDir $stdoutFile $stderrFile
    $outBytes = [System.IO.File]::ReadAllBytes($stdoutFile)
    $errBytes = [System.IO.File]::ReadAllBytes($stderrFile)
    $outText = [System.Text.Encoding]::UTF8.GetString($outBytes)

    Assert-That ($exitCode -eq 0) ($name + ': exits with 0')
    Assert-That ($errBytes.Length -eq 0) ($name + ': no stderr output')
    Assert-Contains $outText 'RESULT: OK' ($name + ': result line')
    Assert-Contains $outText $example.Summary ($name + ': test count')

    if ($name -eq 'example_reports') {
      Assert-That (Test-Path -LiteralPath (Join-Path $buildDir 'example-results.json')) 'example JSON report exists'
      Assert-That (Test-Path -LiteralPath (Join-Path $buildDir 'example-results.xml')) 'example JUnit report exists'
      Assert-That (Test-Path -LiteralPath (Join-Path $buildDir 'example.log')) 'example log exists'
    }
  }
}

if ($skippedCompilers.Count -gt 0) {
  Write-Host ''
  Write-Host ('Skipped compiler configurations: ' + $skippedCompilers.Count) -ForegroundColor Yellow
  foreach ($skipped in $skippedCompilers) {
    Write-Host ('  - ' + $skipped) -ForegroundColor DarkYellow
  }
}

$elapsed = (Get-Date) - $overallStart
Write-Host ''
Write-Host ('=' * 74) -ForegroundColor DarkGray
if ($script:failedChecks -eq 0) {
  Write-Host ("ALL CHECKS PASSED: " + $script:totalChecks + " checks in " + [Math]::Round($elapsed.TotalSeconds, 1) + "s") -ForegroundColor Green
  exit 0
} else {
  Write-Host ("FAILED: " + $script:failedChecks + " of " + $script:totalChecks + " checks in " + [Math]::Round($elapsed.TotalSeconds, 1) + "s") -ForegroundColor Red
  exit 1
}
