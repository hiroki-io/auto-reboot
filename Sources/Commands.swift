import Foundation

func report(_ message: String) {
  FileHandle.standardError.write(Data("auto-reboot: \(message)\n".utf8))
}

enum Commands {
  static func status() -> Bool {
    let (config, problems) = Config.load() ?? Config.unreadable
    var warnings = problems.map { "\(Installation.configPath): \($0)" }

    let daemon = processOutput("/bin/launchctl", ["print", "system/\(Installation.label)"])
    let running = daemon?.contains("state = running") == true
    if !running {
      warnings.append("the daemon is not running, so auto reboot does not work")
    }
    let fileVault = fileVaultStatus()
    if !config.enabled {
      warnings.append("run \"sudo auto-reboot enable\" to turn on auto reboot")
    } else if let warning = fileVault.warning {
      warnings.append(warning)
    }

    printSettings(config)
    printRow("Daemon", running ? "running" : "not running")
    printRow("FileVault", fileVault.summary)
    warnings.forEach(report)
    return warnings.isEmpty
  }

  static func printSettings(_ config: Config) {
    printRow("Auto reboot", config.enabled ? "enabled" : "disabled")
    printRow("Lock time", Config.duration(from: config.lockedSeconds))
  }

  static func printRow(_ label: String, _ value: String) {
    print("\(label):".padding(toLength: 13, withPad: " ", startingAt: 0) + value)
  }

  static func fileVaultStatus() -> (summary: String, warning: String?) {
    switch processOutput("/usr/bin/fdesetup", ["status"]) {
    case nil:
      return (
        "unknown",
        "cannot read the FileVault status, so auto reboot may not protect the data on the disk"
      )
    case let fileVault? where fileVault.hasPrefix("FileVault is Off"):
      return ("off", "FileVault is off, so auto reboot does not protect the data on the disk")
    case let fileVault? where !fileVaultIsOn(fileVault):
      let text = fileVault.split(whereSeparator: \.isNewline).joined(separator: " ")
      return (
        "not fully on",
        "fdesetup status reports \"\(text)\", so auto reboot may not protect all the data on the disk"
      )
    default:
      return ("on", nil)
    }
  }

  // fdesetup adds lines while it converts the disk, and the disk is then not fully
  // encrypted. The man page documents only a line about the master keychain.
  static func fileVaultIsOn(_ status: String) -> Bool {
    let lines = status.split(whereSeparator: \.isNewline)
    return lines.first == "FileVault is On."
      && lines.dropFirst().allSatisfy { $0.contains("master keychain") }
  }

  static func update(_ change: (inout Config) -> Void) -> Bool {
    let path = Installation.configPath
    guard let loaded = Config.load() else {
      report("cannot read \(path)")
      return false
    }
    for problem in loaded.problems {
      report("\(path): \(problem)")
    }
    var config = loaded.config
    change(&config)

    do {
      try Data(config.text.utf8).write(to: URL(fileURLWithPath: path), options: .atomic)
      // An atomic write keeps the owner and the mode of the old file.
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o644, .ownerAccountID: 0, .groupOwnerAccountID: 0],
        ofItemAtPath: path)
    } catch {
      report("cannot write \(path): \(error.localizedDescription)")
      return false
    }
    if !loaded.problems.isEmpty {
      report("\(path): removed or replaced these lines in the file")
    }
    printSettings(config)
    return true
  }

  // The daemon cancels its scheduled wake when launchd stops it.
  static func uninstall() -> Bool {
    _ = try? runProcess("/bin/launchctl", ["bootout", "system/\(Installation.label)"])

    // If the removal of the binary fails, the user can still run uninstall again.
    let paths = [
      Installation.daemonPlistPath, Installation.configPath, Installation.binaryPath,
      Installation.commandPath,
    ]
    for path in paths {
      do {
        try FileManager.default.removeItem(atPath: path)
      } catch CocoaError.fileNoSuchFile {
      } catch {
        report("cannot remove \(path): \(error.localizedDescription)")
        return false
      }
    }
    return true
  }
}
