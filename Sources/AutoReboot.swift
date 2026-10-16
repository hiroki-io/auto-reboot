import Foundation
import IOKit
import os

@MainActor
enum AutoReboot {
  private static let log = Logger(subsystem: Installation.label, category: "auto-reboot")

  private static var lockStarts: [Int: Int] = [:]

  private static var reportedConsoleReadFailure = false

  private static var lastShutdownAttempt: Int?

  // Every check reads the config, so the daemon logs the problems only when they change.
  private static var reportedConfigProblems: [String] = []

  static func run() {
    // Without this, the Mac wakes for a reboot after launchd stops the daemon.
    signal(SIGTERM, SIG_IGN)
    let termination = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    termination.setEventHandler {
      WakeSchedule.set(at: nil)
      exit(0)
    }
    termination.resume()

    check()
    // A session that is unlocked and locked again between two checks keeps its old
    // lock start, so the interval must be shorter than a person can do that.
    let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
      MainActor.assumeIsolated { check() }
    }
    timer.tolerance = 0.2

    withExtendedLifetime(termination) { RunLoop.main.run() }
  }

  private static func check() {
    let (config, problems) = Config.load() ?? Config.unreadable
    if problems != reportedConfigProblems {
      reportedConfigProblems = problems
      for problem in problems {
        log.error("\(Installation.configPath, privacy: .public): \(problem, privacy: .public)")
      }
    }

    let now = Int(Date().timeIntervalSince1970)
    let nowMonotonic = monotonicSeconds()
    // A failed read counts as no lock. If the daemon kept the old starts, it could
    // reboot a session that was unlocked and locked again while reads failed.
    let lockTimestamps = config.enabled ? sessionLockTimestamps(now: now) : [:]
    if lockTimestamps == nil && !reportedConsoleReadFailure {
      log.error("cannot read the console sessions")
    }
    reportedConsoleReadFailure = lockTimestamps == nil
    lockStarts = currentLockStarts(
      lockTimestamps ?? [:], previous: lockStarts, now: now, nowMonotonic: nowMonotonic)
    guard let lockStart = lockStarts.values.min() else {
      WakeSchedule.set(at: nil)
      return
    }

    let locked = nowMonotonic - lockStart
    let remaining = config.lockedSeconds - locked

    WakeSchedule.set(at: remaining > 0 ? now + remaining : nil)

    guard remaining <= 0 else { return }
    // The daemon keeps running for a few seconds after shutdown starts the reboot,
    // and a failing shutdown would log an error every second, so wait a minute.
    if let lastShutdownAttempt, nowMonotonic - lastShutdownAttempt < 60 { return }
    lastShutdownAttempt = nowMonotonic

    log.notice("locked for \(locked, privacy: .public)s; rebooting")
    reboot()
  }

  // Only the first check of a lock uses the system clock, so a later change to
  // the system clock does not affect the count. A session that stays locked
  // keeps its start, because some actions at the lock screen may change its
  // lock timestamp without a password.
  static func currentLockStarts(
    _ lockTimestamps: [Int: Int], previous: [Int: Int], now: Int, nowMonotonic: Int
  ) -> [Int: Int] {
    var starts: [Int: Int] = [:]
    for (session, lockTimestamp) in lockTimestamps {
      starts[session] = previous[session] ?? nowMonotonic - max(0, now - lockTimestamp)
    }
    return starts
  }

  // Clock adjustments do not change this value, and it includes sleep.
  private static func monotonicSeconds() -> Int {
    Int(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / 1_000_000_000)
  }

  // HID idle time resets at the lock screen, so it cannot measure the lock time.
  private static func sessionLockTimestamps(now: Int) -> [Int: Int]? {
    let root = IORegistryGetRootEntry(kIOMainPortDefault)
    guard root != 0 else { return nil }
    defer { IOObjectRelease(root) }

    let property = IORegistryEntryCreateCFProperty(
      root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0)
    guard let sessions = property?.takeRetainedValue() as? [[String: Any]] else { return nil }

    // Fast user switching moves a locked session off console, and the volume key
    // stays in memory, so that session must still count.
    var lockTimestamps: [Int: Int] = [:]
    for session in sessions where session["CGSSessionScreenIsLocked"] as? Bool == true {
      // A session without an ID or a lock timestamp must still count as locked.
      // Sessions without an ID share a key, so the daemon keeps the earliest timestamp.
      let id = session["kCGSSessionIDKey"] as? Int ?? -1
      let lockTimestamp = session["CGSSessionScreenLockedTime"] as? Int ?? now
      lockTimestamps[id] = min(lockTimestamps[id] ?? lockTimestamp, lockTimestamp)
    }
    return lockTimestamps
  }

  private static func reboot() {
    do {
      let status = try runProcess("/sbin/shutdown", ["-r", "now"])
      if status != 0 {
        log.error("/sbin/shutdown exited with \(status, privacy: .public)")
      }
    } catch {
      log.error("cannot run /sbin/shutdown: \(error.localizedDescription, privacy: .public)")
    }
  }
}
