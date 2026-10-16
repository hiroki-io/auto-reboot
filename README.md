# Auto Reboot

Auto Reboot restarts a Mac that stays locked for a set period to put data on
[FileVault](https://support.apple.com/guide/deployment/intro-to-filevault-dep82064ec40/web)
volumes at rest. By default, it restarts a Mac that remains locked for 8 hours,
clearing the volume key to make physical extraction of data on the device more
difficult.

## Install

You need macOS 13 or later and Xcode or the Command Line Tools.

    git clone https://github.com/hiroki-io/auto-reboot.git
    cd auto-reboot
    ./install.sh

## Usage

Check the settings, the daemon, and FileVault:

    auto-reboot status

Change the lock time before a reboot, from 1m to 30d:

    sudo auto-reboot lock-time 4h

Turn auto reboot off, for example during a long job, and on again:

    sudo auto-reboot disable
    sudo auto-reboot enable

The commands store the settings in `/etc/auto-reboot.conf`. To see the log of
the daemon:

    /usr/bin/log show --last 1d --predicate 'subsystem == "io.hiroki.auto-reboot"'

## Uninstall

    sudo auto-reboot uninstall
