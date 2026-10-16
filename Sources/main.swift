import Foundation

func requireRoot() {
  guard geteuid() == 0 else {
    report("run this command with sudo")
    exit(1)
  }
}

func runAsRoot(_ command: () -> Bool) -> Never {
  requireRoot()
  exit(command() ? 0 : 1)
}

switch Array(CommandLine.arguments.dropFirst()) {
case ["daemon"]:
  requireRoot()
  AutoReboot.run()
case ["status"]:
  exit(Commands.status() ? 0 : 1)
case ["enable"]:
  runAsRoot { Commands.update { $0.enabled = true } }
case ["disable"]:
  runAsRoot { Commands.update { $0.enabled = false } }
case let arguments where arguments.count == 2 && arguments[0] == "lock-time":
  runAsRoot {
    guard let seconds = Config.lockedSeconds(from: arguments[1]) else {
      let shortest = Config.duration(from: Config.lockedSecondsRange.lowerBound)
      let longest = Config.duration(from: Config.lockedSecondsRange.upperBound)
      report(
        "\(arguments[1]) is not a duration from \(shortest) to \(longest)"
          + " with a unit of s, m, h, or d, such as 8h")
      return false
    }
    return Commands.update { $0.lockedSeconds = seconds }
  }
case ["uninstall"]:
  runAsRoot(Commands.uninstall)
default:
  FileHandle.standardError.write(
    Data(
      """
      usage: auto-reboot status
             auto-reboot enable
             auto-reboot disable
             auto-reboot lock-time <duration>
             auto-reboot uninstall

      """.utf8))
  exit(2)
}
