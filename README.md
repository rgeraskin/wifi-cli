# wifi-cli

A command-line tool for managing Wi-Fi on macOS, written in Swift using the CoreWLAN framework.

It doesn't use a deprecated `airport` tool under the hood. So works on recent macOS versions.

## Features

This tool provides WiFi management capabilities:

- 📡 **Scan** for wireless networks with detailed information
- 🔌 **Connect/Disconnect** from networks
- 🔐 **Password retrieval** from keychain
- ⚡ **Power control** (on/off)
- 🔧 **MAC address** display

It uses native macOS frameworks instead of command-line utilities, so no external dependencies required.

## Installation

Installation simply copies the script into a directory on your PATH.

I intentionally do not build or ship a binary to avoid macOS Location Services permission prompts and code-signing/notarization hassles. The tool runs directly with the Swift interpreter instead.

### Using Homebrew

```bash
brew install rgeraskin/homebrew/wifi-cli
```

### Manual Installation

```bash
# Install to /usr/local/bin (default PREFIX)
make install

# Or specify a custom installation path
PREFIX=~/.local make install
```

## Usage

```
wifi-cli v0.1.0 - A command-line tool for managing Wi-Fi in macOS

Usage: wifi-cli [-h] [-v] [-q] [--json] [-i INTERFACE] COMMAND [OPTIONS]

Commands:
  scan                 Scan for wireless networks
  interfaces           List available Wi-Fi interfaces
  mac                  Show Wi-Fi device hardware (MAC) address
  join SSID [PASSWORD] Join a wireless network (use empty string "" for open networks)
  disconnect           Disconnect from current network
  showpass SSID        Show password for network (requires keychain access)
  power status         Show Wi-Fi power status
  power on             Turn Wi-Fi power on
  power off            Turn Wi-Fi power off

Options:
  -h, --help           Show this help message
  -v, --version        Show version
  -q, --quiet          Quiet mode (minimal output)
  --json               Output JSON (scan and interfaces commands only)
  -i, --interface      Specify Wi-Fi interface (default: first available)

Notes:
  - The --json and --quiet flags cannot be used together
  - When joining an open network, provide an empty string "" as the password
  - Quiet scan prints unique SSIDs (deduplicated) sorted alphabetically
  - When password is omitted for a secured network, Keychain will be tried
```

## Examples

### Scan for Networks

```bash
$ wifi-cli scan
Scanning on interface: en0
Please wait...

Found 15 networks:

SSID                             Signal(dBm)  Channel  Security
--------------------------------------------------------------------------------
MyNetwork                        -45          6        WPA2
CoffeeShop-Guest                 -67          11       Open
Neighbor-5G                      -72          36       WPA3
...
```

#### JSON output

```bash
$ wifi-cli --json scan
[
  {"ssid":"MyNetwork","rssi":-45,"channel":6,"security":"WPA2"},
  {"ssid":"Neighbor-5G","rssi":-72,"channel":36,"security":"WPA3"}
]
```

### List Wi-Fi Interfaces

```bash
$ wifi-cli interfaces
Available Wi-Fi interfaces:

  en0 - power: on (current)
  en1 - power: off

# JSON output
$ wifi-cli --json interfaces
[
  {"name":"en0","powerOn":true},
  {"name":"en1","powerOn":false}
]
```

### Join a Network

```bash
# Join a protected network
$ wifi-cli join "MyNetwork" "password123"
Scanning for network 'MyNetwork'...
Found network, attempting to join...
Successfully joined 'MyNetwork'

# Join an open network (use empty string "" for password)
$ wifi-cli join "OpenNetwork" ""
Scanning for network 'OpenNetwork'...
Found network, attempting to join...
Successfully joined 'OpenNetwork'

# Join a protected network using stored Keychain password (omit password)
$ wifi-cli join "MyNetwork"
Scanning for network 'MyNetwork'...
Found network, attempting to join...
Successfully joined 'MyNetwork'
```

### Disconnect from Network

```bash
$ wifi-cli disconnect
Disconnected from network
```

### Show Network Password

```bash
$ wifi-cli showpass "MyNetwork"
Retrieving password for 'MyNetwork' from keychain...
Password: password123

### Quiet Scan Output

```bash
$ wifi-cli -q scan
CoffeeShop-Guest
MyNetwork
Neighbor-5G
```

### Power Control

```bash
# Check power status
$ wifi-cli power status
Wi-Fi device en0 is currently powered on

# Turn WiFi off
$ wifi-cli power off
Wi-Fi device en0 powered off

# Turn WiFi on
$ wifi-cli power on
Wi-Fi device en0 powered on
```

### Show MAC Address

```bash
$ wifi-cli mac
Wi-Fi MAC Address (en0): aa:bb:cc:dd:ee:ff
```

## Requirements

- Swift (I use Swift 6.2, maybe it works with older versions)

To get the `swift` command on macOS:

- Install Xcode from the App Store (includes Swift), or
- Install the Command Line Tools:

```bash
xcode-select --install
```

Verify installation:

```bash
swift --version
```

## Implementation Details

This tool is built using:
- **Swift** for modern, safe, and performant code
- **CoreWLAN** framework for WiFi management
- **Security** framework for keychain access

Inspired by [tuladhar/macOS-wifi-cli](https://github.com/tuladhar/macOS-wifi-cli).

## Development

### Run Tests

```bash
make test
```

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
