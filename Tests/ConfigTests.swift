import Foundation

@MainActor
func testConfigDefaults() {
  let empty = Config.parse("")
  expect(empty.config, Config())
  expect(empty.problems, [])
}

@MainActor
func testConfigTextRoundTrip() {
  let changed = Config(enabled: false, lockedSeconds: 600)
  expect(Config.parse(changed.text).config, changed)
}

@MainActor
func testConfigFlags() {
  expect(Config.parse("ENABLED=0").config.enabled, false)
  expect(Config.parse("ENABLED=1").config.enabled, true)

  // A typo in a flag must not disable auto reboot silently.
  for text in ["ENABLED=true", "ENABLED="] {
    let result = Config.parse(text)
    expect(result.config.enabled, true)
    expect(result.problems.count, 1)
  }
}

@MainActor
func testConfigSeconds() {
  let zero = Config.parse("LOCKED_SECONDS=0")
  expect(zero.config.lockedSeconds, 60)
  expect(zero.problems.count, 1)

  expect(Config.parse("LOCKED_SECONDS=-1").config.lockedSeconds, 60)
  expect(Config.parse("LOCKED_SECONDS=9223372036854775807").config.lockedSeconds, 2_592_000)

  let word = Config.parse("LOCKED_SECONDS=abc")
  expect(word.config.lockedSeconds, Config().lockedSeconds)
  expect(word.problems.count, 1)

  let good = Config.parse("LOCKED_SECONDS=600")
  expect(good.config.lockedSeconds, 600)
  expect(good.problems, [])
}

@MainActor
func testConfigSyntax() {
  let commented = Config.parse("# a note\n\nLOCKED_SECONDS=600 # inline\n")
  expect(commented.config.lockedSeconds, 600)
  expect(commented.problems, [])

  expect(Config.parse("LOCKED_SECONDS=600\nLOCKED_SECONDS=1800").config.lockedSeconds, 1800)

  let crlf = Config.parse("ENABLED=0\r\nLOCKED_SECONDS=600\r\n")
  expect(crlf.config.lockedSeconds, 600)
  expect(crlf.config.enabled, false)
  expect(crlf.problems, [])

  let typo = Config.parse("ENABLE=0")
  expect(typo.config, Config())
  expect(typo.problems.count, 1)

  expect(Config.parse("no equals sign here").problems, [])
}

@MainActor
func testConfigLoad() {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
  try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }

  let missing = Config.load(from: directory.appendingPathComponent("missing").path)
  expect(missing?.config, Config())
  expect(missing?.problems, [])

  let file = directory.appendingPathComponent("auto-reboot.conf")
  try! Data("LOCKED_SECONDS=600\n".utf8).write(to: file)
  expect(Config.load(from: file.path)?.config.lockedSeconds, 600)

  expect(Config.load(from: directory.path)?.config, nil)
}

@MainActor
func testLockedSecondsFromDuration() {
  expect(Config.lockedSeconds(from: "60s"), 60)
  expect(Config.lockedSeconds(from: "1m"), 60)
  expect(Config.lockedSeconds(from: "30m"), 1800)
  expect(Config.lockedSeconds(from: "8h"), 28800)
  expect(Config.lockedSeconds(from: "30d"), 2_592_000)

  for duration in [
    "", "h", "3600", "59s", "31d", "-1h", "+1h", "1.5h", "8H", "8hh", "1 h", "9223372036854775807d",
  ] {
    expect(Config.lockedSeconds(from: duration), nil)
  }
}

@MainActor
func testDurationRoundTrip() {
  for duration in ["61s", "90m", "8h", "25h", "30d"] {
    expect(Config.lockedSeconds(from: duration).map(Config.duration), duration)
  }
}
