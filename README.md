# KeepAwake

A macOS menu bar button that keeps your Mac awake. One click on, one click off.

One Swift file, no dependencies, no network access. Same sleep assertion as `caffeinate -i`, without a terminal left open.

## Install

Requires the Xcode Command Line Tools (`xcode-select --install`).

    git clone https://github.com/pr0d-CadenzIA/keep-awake.git
    cd keep-awake
    ./scripts/installer.sh

This compiles `src/main.swift`, installs `~/Applications/KeepAwake.app`, signs it ad hoc for your machine and launches it. Run the script again after changing the source. It stops without touching anything if a different app already sits at that path.

Built on macOS 27. The APIs it calls exist since macOS 12, but older versions have not been tested.

## Use

| Action | Result |
| --- | --- |
| Click the cup | Toggle |
| Right click | Show the state, or quit |

A filled orange cup means the Mac is kept awake. An outlined cup means normal sleep settings apply.

Menu and tooltip labels are in French.

## What it does and does not do

- It holds a `PreventUserIdleSystemSleep` assertion, which blocks idle system sleep.
- The display can still turn off.
- Closing the lid still puts the Mac to sleep.
- It stays active on battery until you turn it off.
- It always starts turned off, so a forgotten toggle does not survive a restart.
- macOS drops the assertion when the process ends, so a crash cannot leave the Mac awake.

To check that it is holding the assertion:

    pmset -g assertions | grep KeepAwake

## Launch at login

Not enabled by the installer. To add it: System Settings > General > Login Items > + > KeepAwake.

## Uninstall

Right click the cup, choose "Quitter KeepAwake", then:

    rm -rf ~/Applications/KeepAwake.app

## License

[MIT](LICENSE)
