# Sony WF-SP800N RFCOMM Bluetooth Protocol & Address Specification

This document describes the reverse-engineered Bluetooth RFCOMM Channel 9 communication between Sony WF-SP800N headphones and the Android Sony Headphones Connect application. It covers the device address, opcodes, packet framing, byte layouts, and state management.

---

## 1. Connection Basics

| Parameter | Value | Description |
| :--- | :--- | :--- |
| **Device Model** | Sony WF-SP800N | True wireless sports headphones |
| **Target MAC Address** | `94:DB:56:63:A6:96` | (`94-db-56-63-a6-96`) |
| **Protocol / Transport** | Bluetooth Classic RFCOMM | RFCOMM connection over L2CAP |
| **RFCOMM Channel** | **Channel 9** (Channel ID: `0x09`) | SDP service: Serial Port / Sony Control |
| **Baud Rate / Speed** | Default RFCOMM | Synchronous packet stream |

---

## 2. Packet Framing & ACK Protocol

All packets between the headphones and the client use Sony's custom framing format:

### Packet Format

```
+------+------+------+--------------------------+-------------------+------+------+
| 0x3E | Type | Seq  | Payload Length (4 Bytes) |  Payload Data...  | Sum  | 0x3C |
| (1B) | (1B) | (1B) |         (Big-Endian)     |    (len Bytes)    | (1B) | (1B) |
+------+------+------+--------------------------+-------------------+------+------+
```

- **Start flag:** `0x3E` (ASCII `>`)
- **Frame Type:**
  - `0x0C`: Client commands
  - `0x01`: ACK (acknowledgement) packet
  - `0x0E`: Event/notification from the headphones
- **Sequence number (Seq):** `0x00` or `0x01` (one-bit modulo-2 counter).
- **Payload length:** Four-byte big-endian integer.
- **Checksum (Sum):** The low 8 bits (`sum & 0xFF`) of the sum of every byte from `Byte 1` (`Type`) through `Byte N` (the final payload byte).
- **End flag:** `0x3C` (ASCII `<`)

### ACK Rule

When a packet with `Type = 0x0C` or `0x0E` is received from the headphones, a valid ACK **must** be sent:

$$\text{ackSeq} = (\text{fseq} + 1) \pmod 2$$

- **ACK packet:** `3E 01 [ackSeq] 00 00 00 00 [(0x01 + ackSeq) & 0xFF] 3C`
- **Important:** If the received `fseq` is not acknowledged, or is acknowledged with the wrong sequence number, the headphones assume that no response was received and continuously retransmit the last packet once per second.

---

## 3. Command and Status Opcodes

| Function | Query Opcode | Response Opcode | Set Opcode | Notification Opcode |
| :--- | :---: | :---: | :---: | :---: |
| **Earbud Batteries** | `0x10 0x01` | `0x11 0x01` | — | `0x11 0x01` |
| **Charging Case Battery** | `0x10 0x02` | `0x11 0x02` | — | `0x11 0x02` |
| **Ambient Sound & ANC** | `0x66 0x02` | `0x67 0x02` | `0x68 0x02` | `0x69 0x02` |
| **Equalizer (EQ)** | `0x56 0x01` | `0x57 0x01` | `0x58 0x01` | `0x59 0x01` |
| **Clear Bass** | `0x56 0x01` | `0x57 0x01` | `0x58 0x01` | `0x59 0x01` |

---

## 4. Detailed Packet Byte Layouts and Parsing

### 4.1. Earbud Battery Status (`0x11 0x01`)
Reports the earbud battery percentages and charging states.

| Byte Index | Value | Meaning |
| :---: | :---: | :--- |
| `Byte 0` | `0x11` | Command group (battery info) |
| `Byte 1` | `0x01` | Subcommand (earbud battery) |
| `Byte 2` | `0x00 - 0x64` | **Left earbud battery percentage** (0 - 100, e.g. `0x32` = 50%) |
| `Byte 3` | `0x00 / 0x01` | **Left earbud charging state** (`0` = no, `1` = charging ⚡) |
| `Byte 4` | `0x00 - 0x64` | **Right earbud battery percentage** (0 - 100, e.g. `0x32` = 50%) |
| `Byte 5` | `0x00 / 0x01` | **Right earbud charging state** (`0` = no, `1` = charging ⚡) |

### 4.2. Charging Case Battery Status (`0x11 0x02`)
Reports the case battery percentage and charging state.

| Byte Index | Value | Meaning |
| :---: | :---: | :--- |
| `Byte 0` | `0x11` | Command group (battery info) |
| `Byte 1` | `0x02` | Subcommand (case battery) |
| `Byte 2` | `0x00 - 0x64` | **Case battery percentage** (0 - 100, e.g. `0x1E` = 30%) |
| `Byte 3` | `0x00 / 0x01` | **Case charging state** (`0` = no, `1` = charging ⚡) |

---

### 4.3. Ambient Sound Control & Noise Cancelling (`0x67 0x02` / `0x69 0x02`)
Reports the state of the ambient sound processing engine.

```
Byte sequence: [cmd] [sub] [b2] [b3] [b4] [b5] [b6] [b7]
ANC example  :  69    02    01   00   01   01   00   00
Ambient 10 example: 69    02    01   00   00   01   01   0A
Off example  :  69    02    00   00   01   01   01   00
```

| Byte Index | Parameter | Value and Description |
| :---: | :--- | :--- |
| `Byte 0` | Command ID | `0x67` (query response) or `0x69` (state-change notification) |
| `Byte 1` | Subcommand | `0x02` |
| `Byte 2` | **Master Switch** | `0x00`: **Off (Passive Isolation)**<br>`0x01`: **On (Processing Active)** |
| `Byte 3` | Reserved | `0x00` |
| `Byte 4` | **Mode Type** | `0x01`: **Noise Cancelling (ANC)**<br>`0x00`: **Ambient Sound** |
| `Byte 5` | Reserved | `0x01` |
| `Byte 6` | **Voice Focus** | `0x01`: **On**<br>`0x00`: **Off** *(always 0 in ANC mode)* |
| `Byte 7` | **Ambient Level** | `0x00`: no level for ANC mode.<br>`0x01 - 0x14`: Ambient Sound level (**1 to 20**) |

#### Correct Parser Logic:
```swift
if b2 == 0x00 {
    state.ncMode = .off
} else {
    // Master switch is on
    if b4 == 0x01 {
        state.ncMode = .anc
        state.voiceFocus = false
    } else if b4 == 0x00 {
        state.ncMode = .ambient
        state.voiceFocus = (b6 == 0x01)
        state.ambientLevel = b7
    }
}
```

#### Control Commands (`0x68 0x02`):
- **Turn Ambient Sound Control Off:**
  `68 02 00 00 01 01 00 00`
- **Turn Noise Cancelling (ANC) On:**
  `68 02 11 00 01 01 00 00`
- **Turn Ambient Sound On (level 1-20, Voice Focus on/off):**
  `68 02 11 00 00 01 [vf: 00/01] [level: 01-14]`
  *(Example: level 10, Voice Focus on: `68 02 11 00 00 01 01 0A`)*

---

### 4.4. Equalizer (EQ) and Clear Bass (`0x57 0x01` / `0x59 0x01`)
Manages predefined sound profiles and the Clear Bass level.

| Byte Index | Parameter | Value and Description |
| :---: | :--- | :--- |
| `Byte 0` | Command ID | `0x57` (query response) or `0x59` (set/notification) |
| `Byte 1` | Subcommand | `0x01` |
| `Byte 2` | **EQ Profile** | Selected preset ID (see table below) |
| `Byte 3` | Band Count | Usually `0x06` |
| `Byte 4` | **Clear Bass** | Clear Bass level: `0x00` (-10) to `0x14` (+10).<br>Calculation: `Actual Value = Byte Value - 10` |
| `Bytes 5-9` | 5-Band Frequencies | Gain values for 400Hz, 1kHz, 2.5kHz, 6.3kHz, and 16kHz |

#### EQ Preset ID Table (`Byte 2`):

| Hex Value | Profile Name | Original Name |
| :---: | :--- | :--- |
| `0x00` | **Off** | Off |
| `0x10` | **Bright** | Bright |
| `0x11` | **Excited** | Excited |
| `0x12` | **Mellow** | Mellow |
| `0x13` | **Relaxed** | Relaxed |
| `0x14` | **Vocal** | Vocal |
| `0x15` | **Treble Boost** | Treble Boost |
| `0x16` | **Bass Boost** | Bass Boost |
| `0x17` | **Speech** | Speech |
| `0xA0` | **Custom 1** | Custom 1 |
| `0xA1` | **Custom 2** | Custom 2 |
| `0xA2` | **Manual** | Manual |

#### Control Commands (`0x58 0x01`):
- **Change preset (example: Vocal):**
  `58 01 14 00`
- **Change preset (example: Bass Boost):**
  `58 01 16 00`
- **Set Clear Bass (-10 to +10):**
  `58 01 FF 06 [level+10] 0A 0A 0A 0A 0A`
  - Clear Bass = `0`: `58 01 FF 06 0A 0A 0A 0A 0A 0A`
  - Clear Bass = `+10`: `58 01 FF 06 14 0A 0A 0A 0A 0A`
  - Clear Bass = `-10`: `58 01 FF 06 00 0A 0A 0A 0A 0A`

---

## 5. Application State Management Rules

1. **Stale Query Protection (`lastUserActionTime`):**
  When the user changes a switch or slider, stale query responses (`0x67` / `0x57`) received immediately afterward are ignored for **1.5 seconds**. This prevents delayed packets from reverting the user's latest selection.

2. **Slider Debouncing:**
  `ncDebounceTimer` and `cbDebounceTimer` prevent transient RFCOMM notifications from moving the slider while the user is dragging it. One commit command is sent to the headphones after dragging stops (after 0.15 seconds).

3. **Preserve Settings When Ambient Sound Control Is Off:**
  When Ambient Sound Control is set to `.off`, the last selected ambient level (for example, 10) and Voice Focus preference are not reset; they remain in memory. When the switch is enabled again, the previous settings are restored automatically.
