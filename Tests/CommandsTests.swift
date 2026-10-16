@MainActor
func testFileVaultIsOn() {
  for status in [
    "FileVault is On.\n", "FileVault is On.\nFileVault master keychain appears to be installed.\n",
  ] {
    expect(Commands.fileVaultIsOn(status), true)
  }

  for status in [
    "", "FileVault is Off.\n", "FileVault is On.\nDecryption in progress: Percent completed = 12\n",
    "FileVault is On.\nEncryption in progress: Percent completed = 12\n", "FileVault is on.\n",
    "FileVault is On.\nEncryption paused.\n",
  ] {
    expect(Commands.fileVaultIsOn(status), false)
  }
}
