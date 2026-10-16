@MainActor
func testCurrentLockStarts() {
  let lockedAt = 1_000_000
  let starts = { (stamps: [Int: Int], previous: [Int: Int], nowOffset: Int, nowMonotonic: Int) in
    AutoReboot.currentLockStarts(
      stamps, previous: previous, now: lockedAt + nowOffset, nowMonotonic: nowMonotonic)
  }

  let first = starts([1: lockedAt], [:], 100, 50_000)
  expect(first, [1: 49_900])
  expect(starts([1: lockedAt], first, 110, 50_010), first)
  expect(starts([1: lockedAt], first, -36_000, 50_020), first)
  expect(starts([1: lockedAt + 5000], first, 5100, 50_030), first)

  expect(starts([1: lockedAt, 2: lockedAt + 200], first, 300, 50_200), [1: 49_900, 2: 50_100])
  expect(starts([2: lockedAt + 200], [1: 49_900, 2: 50_100], 400, 50_300), [2: 50_100])
  let unlocked = starts([:], first, 500, 50_400)
  expect(unlocked, [:])
  expect(starts([1: lockedAt + 600], unlocked, 610, 50_410), [1: 50_400])

  expect(starts([1: lockedAt], [:], -1000, 50_000), [1: 50_000])
}
