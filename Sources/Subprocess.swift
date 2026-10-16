import Foundation

private func makeProcess(_ executable: String, _ arguments: [String]) -> Process {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  process.standardError = FileHandle.nullDevice
  return process
}

func runProcess(_ executable: String, _ arguments: [String]) throws -> Int32 {
  let process = makeProcess(executable, arguments)
  process.standardOutput = FileHandle.nullDevice
  try process.run()
  process.waitUntilExit()
  return process.terminationStatus
}

// The read waits until every process that holds the pipe closes it, so use this
// only for commands that do not leave a child process running.
func processOutput(_ executable: String, _ arguments: [String]) -> String? {
  let process = makeProcess(executable, arguments)
  let pipe = Pipe()
  process.standardOutput = pipe
  guard (try? process.run()) != nil else { return nil }
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  process.waitUntilExit()
  return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
}
