enum Installation {
  static let label = "io.hiroki.auto-reboot"

  // A root LaunchDaemon must not run from a directory that a non-root account can write.
  static let binaryPath = "/Library/PrivilegedHelperTools/\(label)"
  static let commandPath = "/usr/local/bin/auto-reboot"
  static let daemonPlistPath = "/Library/LaunchDaemons/\(label).plist"
  static let configPath = "/etc/auto-reboot.conf"
}
