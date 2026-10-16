import Foundation

private func shellValues(_ names: [String]) -> [String: String] {
  let script =
    ". \"$1/common.sh\" && shift && for name in \"$@\"; do printf '%s\\n' \"${!name}\"; done"
  let output = processOutput("/bin/bash", ["-c", script, "bash", repositoryRoot.path] + names)
  let values = output?.split(separator: "\n").map(String.init) ?? []
  guard values.count == names.count else { return [:] }
  return Dictionary(uniqueKeysWithValues: zip(names, values))
}

private func plist(_ path: String) -> [String: Any] {
  guard
    let data = FileManager.default.contents(
      atPath: repositoryRoot.appendingPathComponent(path).path),
    let object = try? PropertyListSerialization.propertyList(from: data, format: nil)
  else {
    return [:]
  }
  return object as? [String: Any] ?? [:]
}

@MainActor
func testInstallationValues() {
  let shell = shellValues(["LABEL", "BINARY", "COMMAND", "PLIST"])
  expect(shell["LABEL"], Installation.label)
  expect(shell["BINARY"], Installation.binaryPath)
  expect(shell["COMMAND"], Installation.commandPath)
  expect(shell["PLIST"], Installation.daemonPlistPath)

  let daemon = plist("\(Installation.label).plist")
  expect(daemon["Label"] as? String, Installation.label)
  expect(daemon["ProgramArguments"] as? [String], [Installation.binaryPath, "daemon"])
}
