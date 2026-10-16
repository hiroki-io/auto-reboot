import Foundation

struct Config: Equatable {
  var enabled = true
  var lockedSeconds = 28800

  // A reboot ends the work of whoever is logged in, so the floor is a minute.
  // The ceiling prevents an overflow when AutoReboot calculates the wake time.
  static let lockedSecondsRange = 60...2_592_000

  static let unreadable = (config: Config(), problems: ["cannot read the file, using the defaults"])

  // A missing file means the defaults. nil means that the file exists but cannot
  // be read, so a command must not replace it with the defaults.
  static func load(from path: String = Installation.configPath) -> (
    config: Config, problems: [String]
  )? {
    do {
      return parse(try String(contentsOfFile: path, encoding: .utf8))
    } catch CocoaError.fileReadNoSuchFile {
      return (Config(), [])
    } catch {
      return nil
    }
  }

  static func parse(_ text: String) -> (config: Config, problems: [String]) {
    var config = Config()
    var problems: [String] = []
    for line in text.split(whereSeparator: \.isNewline) {
      guard let (key, value) = setting(in: line) else { continue }
      switch key {
      case "ENABLED":
        config.enabled = flag(key, value, fallback: config.enabled, &problems)
      case "LOCKED_SECONDS":
        config.lockedSeconds = seconds(key, value, fallback: config.lockedSeconds, &problems)
      default:
        problems.append("\(key) is not a setting")
      }
    }
    return (config, problems)
  }

  private static let units: [(name: Character, seconds: Int)] = [
    ("d", 86400), ("h", 3600), ("m", 60), ("s", 1),
  ]

  static func lockedSeconds(from duration: String) -> Int? {
    guard let unit = units.first(where: { $0.name == duration.last })?.seconds else { return nil }
    let number = duration.dropLast()
    guard !number.isEmpty, number.allSatisfy({ $0.isASCII && $0.isNumber }),
      let value = Int(number)
    else {
      return nil
    }
    let (seconds, overflow) = value.multipliedReportingOverflow(by: unit)
    return !overflow && lockedSecondsRange.contains(seconds) ? seconds : nil
  }

  static func duration(from seconds: Int) -> String {
    let unit = units.first { seconds % $0.seconds == 0 }!
    return "\(seconds / unit.seconds)\(unit.name)"
  }

  var text: String {
    """
    ENABLED=\(enabled ? 1 : 0)
    LOCKED_SECONDS=\(lockedSeconds)

    """
  }

  private static func setting(in line: Substring) -> (key: String, value: String)? {
    let content = line.prefix { $0 != "#" }
    guard let equals = content.firstIndex(of: "=") else { return nil }
    let key = content[..<equals].trimmingCharacters(in: .whitespaces)
    let value = content[content.index(after: equals)...].trimmingCharacters(in: .whitespaces)
    return (key, value)
  }

  private static func flag(
    _ key: String, _ value: String, fallback: Bool, _ problems: inout [String]
  ) -> Bool {
    switch value {
    case "1": return true
    case "0": return false
    default:
      problems.append("\(key)=\(value) is not 0 or 1, using \(fallback ? 1 : 0)")
      return fallback
    }
  }

  private static func seconds(
    _ key: String, _ value: String, fallback: Int, _ problems: inout [String]
  ) -> Int {
    guard let number = Int(value) else {
      problems.append("\(key)=\(value) is not a number, using \(fallback)")
      return fallback
    }
    if lockedSecondsRange.contains(number) { return number }

    let clamped = min(max(number, lockedSecondsRange.lowerBound), lockedSecondsRange.upperBound)
    problems.append(
      "\(key)=\(number) is outside \(lockedSecondsRange.lowerBound) to \(lockedSecondsRange.upperBound), using \(clamped)"
    )
    return clamped
  }
}
