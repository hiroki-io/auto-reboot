import Foundation

@MainActor
func testWakeScheduleMatches() {
  let target = 1_790_000_000
  let at = { (offset: Int) in [Date(timeIntervalSince1970: TimeInterval(target + offset))] }

  expect(WakeSchedule.matches([], nil), true)
  expect(WakeSchedule.matches(at(0), nil), false)
  expect(WakeSchedule.matches([], target), false)
  expect(WakeSchedule.matches(at(0), target), true)
  expect(WakeSchedule.matches(at(2), target), true)
  expect(WakeSchedule.matches(at(-2), target), true)
  expect(WakeSchedule.matches(at(3600), target), false)
  expect(WakeSchedule.matches(at(0) + at(1), target), false)
}
