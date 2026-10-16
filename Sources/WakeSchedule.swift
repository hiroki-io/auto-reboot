import Foundation
import IOKit.pwr_mgt
import os

// The daemon does not run while the Mac sleeps, so it schedules a wake for the
// time of the reboot.
enum WakeSchedule {
  private static let log = Logger(subsystem: Installation.label, category: "wake-schedule")

  // The target mixes the system clock with the monotonic clock, so it moves by up
  // to a second between checks and by any change to the system clock. A wake a
  // minute early or late is fine.
  private static let tolerance = 60

  static func set(at target: Int?) {
    let scheduled = scheduledWakes()
    if matches(scheduled, target) { return }

    for date in scheduled {
      let result = IOPMCancelScheduledPowerEvent(
        date as CFDate, Installation.label as CFString, kIOPMAutoWake as CFString)
      if result != kIOReturnSuccess {
        log.error("cannot cancel a scheduled wake: \(result, privacy: .public)")
      }
    }

    guard let target else { return }
    let result = IOPMSchedulePowerEvent(
      Date(timeIntervalSince1970: TimeInterval(target)) as CFDate, Installation.label as CFString,
      kIOPMAutoWake as CFString)
    if result != kIOReturnSuccess {
      log.error("cannot schedule a wake: \(result, privacy: .public)")
    }
  }

  static func matches(_ scheduled: [Date], _ target: Int?) -> Bool {
    guard let target else { return scheduled.isEmpty }
    guard scheduled.count == 1 else { return false }
    return abs(Int(scheduled[0].timeIntervalSince1970) - target) <= tolerance
  }

  private static func scheduledWakes() -> [Date] {
    guard let events = IOPMCopyScheduledPowerEvents()?.takeRetainedValue() as? [[String: Any]]
    else {
      return []
    }
    return events.compactMap { event in
      guard event[kIOPMPowerEventAppNameKey] as? String == Installation.label,
        event[kIOPMPowerEventTypeKey] as? String == kIOPMAutoWake
      else {
        return nil
      }
      return event[kIOPMPowerEventTimeKey] as? Date
    }
  }
}
