# Bluetooth Reference

The application connects to the Sony WF-SP800N using Bluetooth Classic RFCOMM.

## Device Address

- Target MAC address: `94:DB:56:63:A6:96`
- Code format: `94-db-56-63-a6-96`
- RFCOMM channel: `9`

The address is configured in `src/BluetoothManager.swift`:

```swift
var targetAddress = "94-db-56-63-a6-96"
```

If you are using a different headset, replace this value with its Bluetooth address before building. The headset must be paired with macOS first.
