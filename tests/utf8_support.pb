; ============================================================================
;  Full UTF-8 support: non-ASCII literals directly in a UTF-8 source file.
;
;  Expected: exit code 1 (one intentional failure), valid UTF-8 console/log/
;  JSON/XML, Unicode preserved in diagnostics, skip/pending reasons and
;  reports. The long skip reason also exercises surrogate-safe truncation.
; ============================================================================

#TESTING_OUTPUT_JSON = 1
#TESTING_JSON_FILE$ = "utf8/results.json"
#TESTING_OUTPUT_JUNIT = 1
#TESTING_JUNIT_FILE$ = "utf8/results.xml"
#TESTING_LOG_FILE$ = "utf8/results.log"

IncludeFile "../Testing.pbi"

Suite("UTF8Suite")

Test(CyrillicSourceLiterals)
  Define greeting.s = "Привет, мир"
  AssertStrEqual(greeting, "Привет, мир")
  AssertStrContains(greeting, "мир")
  AssertStrNotEqual(greeting, "Пока")
EndTest(CyrillicSourceLiterals)

Test(EmojiAndCjkSourceLiterals)
  Define text.s = "😀 中文 🚀"
  AssertStrEqual(text, "😀 中文 🚀")
  AssertStrContains(text, "中文")
  AssertStrEqual(Testing::JsonEscape(text), text)
  AssertStrEqual(Testing::XmlEscapeString("中文 & <tag>"), "中文 &amp; &lt;tag&gt;")
EndTest(EmojiAndCjkSourceLiterals)

Test(FailureWithUnicode)
  Define actual.s = "Пока"
  Define expected.s = "Привет"
  AssertStrEqual(actual, expected, "Сообщение: 😀 и 中文")
EndTest(FailureWithUnicode)

Test(SkipUnicode)
  SkipTest("Причина: 😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀")
EndTest(SkipUnicode)

Test(PendingUnicode)
  PendingTest("Ожидает реализации: 中文")
EndTest(PendingUnicode)

RunAll()
