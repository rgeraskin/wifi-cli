#!/usr/bin/env swift

import Foundation
import CoreWLAN
import Security

// MARK: - Version
let VERSION = "0.1.0"

// MARK: - Helper Extensions
extension String {
    func padRight(to length: Int) -> String {
        return self.padding(toLength: length, withPad: " ", startingAt: 0)
    }
}

// MARK: - WiFi Manager
class WiFiManager {
    let client: CWWiFiClient
    var interface: CWInterface?
    var quiet: Bool = false
    var jsonOutput: Bool = false

    init(interfaceName: String? = nil, quiet: Bool = false, jsonOutput: Bool = false) throws {
        self.client = CWWiFiClient.shared()
        self.quiet = quiet
        self.jsonOutput = jsonOutput

        if let name = interfaceName {
            self.interface = client.interface(withName: name)
            if self.interface == nil {
                throw WiFiError.interfaceNotFound(name)
            }
        } else {
            self.interface = client.interface()
            if self.interface == nil {
                throw WiFiError.noInterfaceAvailable
            }
        }
    }

    // MARK: - Scan for Networks
    func scan() throws {
        guard let interface = interface else {
            throw WiFiError.noInterfaceAvailable
        }

        if !quiet && !jsonOutput {
            print("Scanning on interface: \(interface.interfaceName ?? "unknown")")
            print("Please wait...\n")
        }

        let networks = try interface.scanForNetworks(withName: nil)

        if networks.isEmpty {
            if jsonOutput {
                print("[]")
            } else if !quiet {
                print("No networks found")
            }
            return
        }

        let sortedNetworks = networks.sorted { $0.rssiValue > $1.rssiValue }

        if jsonOutput {
            struct NetworkInfo: Codable {
                let ssid: String
                let rssi: Int
                let channel: Int
                let security: String
            }
            let encoder = JSONEncoder()
            let items: [NetworkInfo] = sortedNetworks.map { network in
                let ssid = network.ssid ?? ""
                let rssi = network.rssiValue
                let channel = network.wlanChannel?.channelNumber ?? 0
                let security = securityTypeFromNetwork(network)
                return NetworkInfo(ssid: ssid, rssi: rssi, channel: channel, security: security)
            }
            if let data = try? encoder.encode(items), let json = String(data: data, encoding: .utf8) {
                print(json)
            } else {
                print("[]")
            }
        } else if quiet {
            // In quiet mode, print unique SSIDs sorted alphabetically
            let ssids = Set(sortedNetworks.map { $0.ssid ?? "<Hidden>" })
            for ssid in ssids.sorted() {
                print(ssid)
            }
        } else {
            print("Found \(sortedNetworks.count) networks:\n")
            print("SSID                             Signal(dBm)  Channel  Security")
            print("--------------------------------------------------------------------------------")

            for network in sortedNetworks {
                let ssid = network.ssid ?? "<Hidden>"
                let rssi = network.rssiValue
                let channel = network.wlanChannel?.channelNumber ?? 0
                let security = securityTypeFromNetwork(network)

                let ssidPadded = ssid.padRight(to: 32)
                let rssiStr = String(rssi).padRight(to: 12)
                let channelStr = String(channel).padRight(to: 8)

                print("\(ssidPadded) \(rssiStr) \(channelStr) \(security)")
            }
        }
    }

    // MARK: - MAC Address
    func macAddress() throws {
        guard let interface = interface else {
            throw WiFiError.noInterfaceAvailable
        }

        if let mac = interface.hardwareAddress() {
            if quiet {
                print(mac)
            } else {
                print("Wi-Fi MAC Address (\(interface.interfaceName ?? "unknown")): \(mac)")
            }
        } else {
            if !quiet {
                print("Unable to retrieve MAC address")
            }
        }
    }

    // MARK: - Power Control
    func powerStatus() throws {
        guard let interface = interface else {
            throw WiFiError.noInterfaceAvailable
        }

        let powered = interface.powerOn()
        if quiet {
            print(powered ? "on" : "off")
            return
        }
        let interfaceName = interface.interfaceName ?? "unknown"
        if powered {
            print("Wi-Fi device \(interfaceName) is currently powered on")
        } else {
            print("Wi-Fi device \(interfaceName) is currently powered off")
        }
    }

    func powerOn() throws {
        guard let interface = interface else {
            throw WiFiError.noInterfaceAvailable
        }

        try interface.setPower(true)
        if !quiet {
            print("Wi-Fi device \(interface.interfaceName ?? "unknown") powered on")
        }
    }

    func powerOff() throws {
        guard let interface = interface else {
            throw WiFiError.noInterfaceAvailable
        }

        try interface.setPower(false)
        if !quiet {
            print("Wi-Fi device \(interface.interfaceName ?? "unknown") powered off")
        }
    }

    // MARK: - Join Network
    func join(ssid: String, password: String) throws {
        guard let interface = interface else {
            throw WiFiError.noInterfaceAvailable
        }

        if !quiet {
            print("Scanning for network '\(ssid)'...")
        }
        let networks = try interface.scanForNetworks(withName: ssid)

        if networks.isEmpty {
            throw WiFiError.networkNotFound(ssid)
        }

        // When multiple APs broadcast the same SSID, select the one with strongest signal (highest RSSI)
        guard let network = networks.max(by: { $0.rssiValue < $1.rssiValue }) else {
            throw WiFiError.networkNotFound(ssid)
        }

        if !quiet {
            print("Found network, attempting to join...")
        }

        // If password is empty, try Keychain fallback first
        if password.isEmpty {
            if let keychainPassword = findWiFiPassword(ssid: ssid), !keychainPassword.isEmpty {
                try interface.associate(to: network, password: keychainPassword)
            } else {
                try interface.associate(to: network, password: nil)
            }
        } else {
            try interface.associate(to: network, password: password)
        }

        if !quiet {
            print("Successfully joined '\(ssid)'")
        }
    }

    // MARK: - Disconnect
    func disconnect() throws {
        guard let interface = interface else {
            throw WiFiError.noInterfaceAvailable
        }

        interface.disassociate()
        if !quiet {
            print("Disconnected from network")
        }
    }

    // MARK: - Show Password (requires keychain access)
    func showPassword(ssid: String) throws {
        if !quiet {
            print("Retrieving password for '\(ssid)' from keychain...")
        }

        if let password = findWiFiPassword(ssid: ssid) {
            if quiet {
                print(password)
            } else {
                print("Password: \(password)")
            }
        } else {
            if !quiet {
                print("Password not found in keychain for network '\(ssid)'")
            }
        }
    }

    // MARK: - List Interfaces
    func listInterfaces() {
        let interfaces = client.interfaceNames() ?? []

        if interfaces.isEmpty {
            if !quiet {
                print("No Wi-Fi interfaces found")
            }
            return
        }

        if jsonOutput {
            struct InterfaceInfo: Codable {
                let name: String
                let powerOn: Bool
                let ssid: String?
            }
            var infos: [InterfaceInfo] = []
            for name in interfaces {
                if let iface = client.interface(withName: name) {
                    infos.append(InterfaceInfo(name: name, powerOn: iface.powerOn(), ssid: iface.ssid()))
                }
            }
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(infos), let json = String(data: data, encoding: .utf8) {
                print(json)
            } else {
                print("[]")
            }
        } else if quiet {
            for name in interfaces {
                print(name)
            }
        } else {
            print("Available Wi-Fi interfaces:\n")
            for name in interfaces {
                if let iface = client.interface(withName: name) {
                    let status = iface.powerOn() ? "on" : "off"
                    let current = (iface.interfaceName == interface?.interfaceName) ? " (current)" : ""
                    var ssidInfo = ""
                    if let currentSsid = iface.ssid() {
                        ssidInfo = ", ssid: \(currentSsid)"
                    }
                    print("  \(name) - power: \(status)\(current)\(ssidInfo)")
                } else {
                    print("  \(name)")
                }
            }
        }
    }

    // MARK: - Helper Methods
    private func securityTypeFromNetwork(_ network: CWNetwork) -> String {
        if (network.supportsSecurity(.wpa3Personal) && network.supportsSecurity(.wpa2Personal)) ||
           (network.supportsSecurity(.wpa3Enterprise) && network.supportsSecurity(.wpa2Enterprise)) {
            return "WPA3 (transition)"
        }
        if network.supportsSecurity(.wpa3Personal) || network.supportsSecurity(.wpa3Enterprise) {
            return "WPA3"
        }
        if network.supportsSecurity(.wpa2Personal) || network.supportsSecurity(.wpa2Enterprise) {
            return "WPA2"
        }
        if network.supportsSecurity(.wpaPersonal) || network.supportsSecurity(.wpaEnterprise) {
            return "WPA"
        }
        if network.supportsSecurity(.dynamicWEP) {
            return "WEP"
        }
        return "Open"
    }

    // Attempts to retrieve Wi-Fi password for a given SSID from Keychain.
    private func findWiFiPassword(ssid: String) -> String? {
        // Primary query: service "AirPort", account = SSID
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "AirPort",
            kSecAttrAccount as String: ssid,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, let password = String(data: data, encoding: .utf8) {
            return password
        }

        // Fallback: add label commonly used by Wi-Fi items
        query[kSecAttrLabel as String] = "AirPort network password"
        result = nil
        status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, let password = String(data: data, encoding: .utf8) {
            return password
        }

        return nil
    }
}

// MARK: - Errors
enum WiFiError: Error, LocalizedError {
    case noInterfaceAvailable
    case interfaceNotFound(String)
    case networkNotFound(String)
    case invalidCommand
    case missingArguments(String)

    var errorDescription: String? {
        switch self {
        case .noInterfaceAvailable:
            return "No WiFi interface found"
        case .interfaceNotFound(let name):
            return "WiFi interface '\(name)' not found"
        case .networkNotFound(let ssid):
            return "Network '\(ssid)' not found"
        case .invalidCommand:
            return "Invalid command"
        case .missingArguments(let msg):
            return msg
        }
    }
}

// MARK: - CLI
func printUsage() {
    print("""
    wifi-cli v\(VERSION) - A command-line tool for managing Wi-Fi in macOS

    Usage: wifi-cli [-h] [-v] [-q] [--json] [-i|--interface INTERFACE] COMMAND [OPTIONS]

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

    Examples:
      wifi-cli scan
      wifi-cli --json scan
      wifi-cli -q scan
      wifi-cli interfaces
      wifi-cli join "MyNetwork" "password123"
      wifi-cli join "OpenNetwork" ""
      wifi-cli power off
      sudo wifi-cli disconnect
    """)
}

func printVersion() {
    print("wifi-cli version \(VERSION)")
}

// MARK: - Main
func main() {
    var args = CommandLine.arguments
    args.removeFirst() // Remove program name

    if args.isEmpty {
        printUsage()
        exit(1)
    }

    var interfaceName: String? = nil
    var quiet = false
    var jsonOutput = false

    // Parse global options
    while !args.isEmpty {
        let arg = args[0]

        if arg == "-h" || arg == "--help" {
            printUsage()
            exit(0)
        } else if arg == "-v" || arg == "--version" {
            printVersion()
            exit(0)
        } else if arg == "-i" || arg == "--interface" {
            args.removeFirst()
            if args.isEmpty {
                fputs("Error: -i/--interface requires an interface name\n", stderr)
                exit(1)
            }
            interfaceName = args.removeFirst()
        } else if arg == "--json" {
            args.removeFirst()
            jsonOutput = true
        } else if arg == "-q" || arg == "--quiet" {
            args.removeFirst()
            quiet = true
        } else {
            break
        }
    }

    // Validate flag combinations
    if jsonOutput && quiet {
        fputs("Error: --json and --quiet flags cannot be used together\n", stderr)
        exit(1)
    }

    if args.isEmpty {
        printUsage()
        exit(1)
    }

    let command = args.removeFirst()

    do {
        let wifi = try WiFiManager(interfaceName: interfaceName, quiet: quiet, jsonOutput: jsonOutput)

        switch command {
        case "scan":
            try wifi.scan()

        case "mac":
            try wifi.macAddress()

        case "join":
            guard args.count >= 1 else {
                throw WiFiError.missingArguments("join requires SSID and optional PASSWORD")
            }
            let ssid = args[0]
            let password = args.count >= 2 ? args[1] : ""
            try wifi.join(ssid: ssid, password: password)

        case "disconnect":
            try wifi.disconnect()

        case "showpass":
            guard args.count >= 1 else {
                throw WiFiError.missingArguments("showpass requires SSID")
            }
            try wifi.showPassword(ssid: args[0])

        case "power":
            guard args.count >= 1 else {
                throw WiFiError.missingArguments("power requires subcommand: status, on, or off")
            }

            let subcommand = args[0]
            switch subcommand {
            case "status":
                try wifi.powerStatus()
            case "on":
                try wifi.powerOn()
            case "off":
                try wifi.powerOff()
            default:
                print("Error: Invalid power subcommand '\(subcommand)'")
                print("Valid options: status, on, off")
                exit(1)
            }

        case "interfaces":
            wifi.listInterfaces()

        default:
            fputs("Error: Unknown command '\(command)'\n", stderr)
            printUsage()
            exit(1)
        }

    } catch {
        fputs("Error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

main()
