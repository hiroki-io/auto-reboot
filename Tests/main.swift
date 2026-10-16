import Foundation

let repositoryRoot = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()
  .deletingLastPathComponent()

var checks = 0
var failures = 0

@MainActor
func expect<Value: Equatable>(
  _ actual: Value?, _ expected: Value?, file: StaticString = #fileID, line: UInt = #line
) {
  checks += 1
  guard actual != expected else { return }
  failures += 1
  print("FAIL \(file):\(line): expected \(describe(expected)), got \(describe(actual))")
}

private func describe(_ value: (some Equatable)?) -> String {
  value.map { "\($0)" } ?? "nil"
}

testConfigDefaults()
testConfigTextRoundTrip()
testConfigFlags()
testConfigSeconds()
testConfigSyntax()
testConfigLoad()
testLockedSecondsFromDuration()
testDurationRoundTrip()
testInstallationValues()
testCurrentLockStarts()
testFileVaultIsOn()
testWakeScheduleMatches()

if failures == 0 {
  print("\(checks) checks passed")
  exit(0)
}
print("\(failures) of \(checks) checks failed")
exit(1)
