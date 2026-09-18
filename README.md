# Sony WF-SP800N Control

macOS menu bar app for controlling Sony WF-SP800N headphones over Bluetooth.

## Build

Requirements:

- macOS 12 or newer
- Xcode Command Line Tools

Build the app with:

```sh
./build.sh
open SonyControl.app
```

## Bluetooth Configuration

The app connects to the Sony WF-SP800N over Bluetooth Classic RFCOMM. The default device address and RFCOMM channel are documented in [BLUETOOTH.md](BLUETOOTH.md). The packet framing, ACK rules, opcodes, and state parsing details are documented in [SONY_PROTOCOL_SPEC.md](SONY_PROTOCOL_SPEC.md).

Before building, pair the headset with macOS. To use a different headset, update `targetAddress` in `src/BluetoothManager.swift`.

## Localization

The interface supports English and Turkish. English is used by default; Turkish is selected automatically when Turkish is the preferred macOS language.

