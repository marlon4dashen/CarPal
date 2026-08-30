import CoreBluetooth
import Foundation
import Observation
import OSLog

enum OBDTransportError: Error, CustomStringConvertible {
    case bluetoothUnavailable(CBManagerState)
    case adapterNotFound
    case connectionFailed(String)
    case serialChannelUnavailable
    case notificationsUnavailable
    case commandTimedOut(String)
    case invalidResponse(String)
    case adapterRejectedCommand(String)

    var description: String {
        switch self {
        case let .bluetoothUnavailable(state): "Bluetooth unavailable (state: \(state.rawValue))"
        case .adapterNotFound: "Veepeak OBDCheck BLE advertisement not found"
        case let .connectionFailed(reason): "BLE connection failed: \(reason)"
        case .serialChannelUnavailable: "No writable/notifiable serial GATT characteristics found"
        case .notificationsUnavailable: "Could not subscribe to adapter responses"
        case let .commandTimedOut(command): "ELM327 command timed out: \(command)"
        case let .invalidResponse(response): "Invalid ELM327 response: \(response)"
        case let .adapterRejectedCommand(response): "ELM327 rejected command: \(response)"
        }
    }
}

@MainActor
@Observable
final class CoreBluetoothOBDClient: NSObject, BluetoothAdapterClient, ELMCommandExecuting, @unchecked Sendable {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CarPal",
        category: "OBDTransport"
    )
    private(set) var connectionState: AdapterConnectionState = .notChecked {
        didSet { connectionStateHandler?(connectionState) }
    }

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var writeCharacteristic: CBCharacteristic?
    @ObservationIgnored private var notifyCharacteristic: CBCharacteristic?
    @ObservationIgnored private var discoveredCharacteristics: [CBCharacteristic] = []
    @ObservationIgnored private var pendingServices = Set<CBUUID>()
    @ObservationIgnored private var connectionStateHandler: (@MainActor @Sendable (AdapterConnectionState) -> Void)?

    @ObservationIgnored private var powerContinuation: CheckedContinuation<Void, Error>?
    @ObservationIgnored private var discoveryContinuation: CheckedContinuation<DiscoveredAdapter, Error>?
    @ObservationIgnored private var connectionContinuation: CheckedContinuation<Void, Error>?
    @ObservationIgnored private var commandContinuation: CheckedContinuation<String, Error>?
    @ObservationIgnored private var commandBuffer = ""
    @ObservationIgnored private var commandToken: UUID?
    @ObservationIgnored private var discoveryToken: UUID?
    @ObservationIgnored private var connectionToken: UUID?

    func setConnectionStateHandler(
        _ handler: (@MainActor @Sendable (AdapterConnectionState) -> Void)?
    ) {
        connectionStateHandler = handler
        handler?(connectionState)
    }

    func discoverSupportedAdapter() async throws -> DiscoveredAdapter {
        if isSerialConnectionReady, let peripheral {
            return DiscoveredAdapter(
                id: peripheral.identifier,
                name: peripheral.name ?? "Veepeak OBDCheck BLE"
            )
        }
        disconnect()
        connectionState = .searching
        let central = prepareCentral()
        try await waitUntilPoweredOn(central)

        return try await withCheckedThrowingContinuation { continuation in
            let token = UUID()
            discoveryContinuation = continuation
            discoveryToken = token
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            scheduleDiscoveryTimeout(token: token)
        }
    }

    func connect(to adapter: DiscoveredAdapter) async throws {
        if isSerialConnectionReady, peripheral?.identifier == adapter.id {
            return
        }
        guard let central, let peripheral, peripheral.identifier == adapter.id else {
            throw OBDTransportError.connectionFailed("Discovered peripheral is no longer available")
        }

        connectionState = .searching
        try await withCheckedThrowingContinuation { continuation in
            let token = UUID()
            connectionContinuation = continuation
            connectionToken = token
            central.connect(peripheral, options: nil)
            scheduleConnectionTimeout(token: token)
        }
    }

    func disconnect() {
        central?.stopScan()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        let power = powerContinuation
        let discovery = discoveryContinuation
        let connection = connectionContinuation
        powerContinuation = nil
        discoveryContinuation = nil
        connectionContinuation = nil
        discoveryToken = nil
        connectionToken = nil
        failPendingCommand(with: CancellationError())
        clearConnection()
        connectionState = .disconnected
        power?.resume(throwing: CancellationError())
        discovery?.resume(throwing: CancellationError())
        connection?.resume(throwing: CancellationError())
    }

    private func prepareCentral() -> CBCentralManager {
        if let central { return central }
        let manager = CBCentralManager(delegate: self, queue: .main)
        central = manager
        return manager
    }

    private var isSerialConnectionReady: Bool {
        peripheral?.state == .connected
            && writeCharacteristic != nil
            && notifyCharacteristic?.isNotifying == true
    }

    private func waitUntilPoweredOn(_ central: CBCentralManager) async throws {
        if central.state == .poweredOn { return }
        if ![.unknown, .resetting].contains(central.state) {
            throw OBDTransportError.bluetoothUnavailable(central.state)
        }
        try await withCheckedThrowingContinuation { powerContinuation = $0 }
    }

    func execute(_ request: ELMCommandRequest) async throws -> String {
        let command = request.command
        guard commandContinuation == nil,
              let peripheral,
              let writeCharacteristic else {
            throw OBDTransportError.connectionFailed("Serial channel is not ready or another command is active")
        }

        commandBuffer = ""
        let token = UUID()
        commandToken = token
        let writeType: CBCharacteristicWriteType = writeCharacteristic.properties.contains(.writeWithoutResponse)
            ? .withoutResponse
            : .withResponse
        let data = Data("\(command)\r".utf8)

        let response = try await withCheckedThrowingContinuation { continuation in
            commandContinuation = continuation
            peripheral.writeValue(data, for: writeCharacteristic, type: writeType)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: request.timeout)
                guard self?.commandToken == token else { return }
                self?.failPendingCommand(with: OBDTransportError.commandTimedOut(command))
            }
        }

        let cleaned = clean(response, echo: command)
#if DEBUG
        Self.logger.debug("ELM command \(command, privacy: .public) returned \(cleaned.utf8.count) bytes")
#endif
        if isRejected(cleaned) || (!request.allowsNoData && isNoData(cleaned)) {
            throw OBDTransportError.adapterRejectedCommand(cleaned)
        }
        if !request.acceptsAnyResponse && cleaned.isEmpty {
            throw OBDTransportError.invalidResponse(response)
        }
        return cleaned
    }

    private func clean(_ response: String, echo: String) -> String {
        response
            .replacingOccurrences(of: ">", with: "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.caseInsensitiveCompare(echo) != .orderedSame && !$0.localizedCaseInsensitiveContains("SEARCHING") }
            .joined(separator: "\n")
    }

    private func isNoData(_ response: String) -> Bool {
        response.localizedCaseInsensitiveContains("NO DATA")
    }

    private func isRejected(_ response: String) -> Bool {
        ["UNABLE TO CONNECT", "STOPPED", "ERROR", "?"].contains {
            response.localizedCaseInsensitiveContains($0)
        }
    }

    private func scheduleDiscoveryTimeout(token: UUID) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard let self,
                  self.discoveryToken == token,
                  let continuation = self.discoveryContinuation else { return }
            self.discoveryContinuation = nil
            self.discoveryToken = nil
            self.central?.stopScan()
            self.connectionState = .disconnected
            continuation.resume(throwing: OBDTransportError.adapterNotFound)
        }
    }

    private func scheduleConnectionTimeout(token: UUID) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard let self,
                  self.connectionToken == token,
                  let continuation = self.connectionContinuation else { return }
            self.connectionContinuation = nil
            self.connectionToken = nil
            self.disconnect()
            continuation.resume(throwing: OBDTransportError.connectionFailed("Timed out preparing GATT serial channel"))
        }
    }

    private func finishConnection() {
        connectionState = .connected(name: peripheral?.name ?? "Veepeak OBDCheck BLE")
        connectionToken = nil
        connectionContinuation?.resume()
        connectionContinuation = nil
    }

    private func failConnection(_ error: Error) {
        let continuation = connectionContinuation
        connectionContinuation = nil
        connectionToken = nil
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        clearConnection()
        connectionState = .disconnected
        continuation?.resume(throwing: error)
    }

    private func failPendingCommand(with error: Error) {
        let continuation = commandContinuation
        commandContinuation = nil
        commandToken = nil
        commandBuffer = ""
        continuation?.resume(throwing: error)
    }

    private func clearConnection() {
        peripheral?.delegate = nil
        peripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        discoveredCharacteristics = []
        pendingServices = []
    }

    private func selectSerialCharacteristics() throws {
        let writers = discoveredCharacteristics.filter {
            $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse)
        }
        let notifiers = discoveredCharacteristics.filter {
            $0.properties.contains(.notify) || $0.properties.contains(.indicate)
        }
        guard let writer = writers.first,
              let notifier = notifiers.first(where: { $0.service?.uuid == writer.service?.uuid }) ?? notifiers.first else {
            throw OBDTransportError.serialChannelUnavailable
        }
        writeCharacteristic = writer
        notifyCharacteristic = notifier
        peripheral?.setNotifyValue(true, for: notifier)
    }
}

extension CoreBluetoothOBDClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if let continuation = powerContinuation {
                powerContinuation = nil
                continuation.resume()
            }
        case .unknown, .resetting:
            break
        default:
            let error = OBDTransportError.bluetoothUnavailable(central.state)
            let power = powerContinuation
            let discovery = discoveryContinuation
            let connection = connectionContinuation
            powerContinuation = nil
            discoveryContinuation = nil
            connectionContinuation = nil
            discoveryToken = nil
            connectionToken = nil
            central.stopScan()
            failPendingCommand(with: error)
            clearConnection()
            connectionState = .disconnected
            power?.resume(throwing: error)
            discovery?.resume(throwing: error)
            connection?.resume(throwing: error)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard discoveryContinuation != nil else { return }
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
        let normalized = name.lowercased().replacingOccurrences(of: " ", with: "")
        guard normalized.contains("veepeak") || normalized.contains("obdcheck") else { return }

        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        discoveryContinuation?.resume(returning: DiscoveredAdapter(id: peripheral.identifier, name: name))
        discoveryContinuation = nil
        discoveryToken = nil
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        discoveredCharacteristics = []
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        failConnection(OBDTransportError.connectionFailed(error?.localizedDescription ?? "Peripheral rejected connection"))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connectionContinuation != nil {
            failConnection(OBDTransportError.connectionFailed(error?.localizedDescription ?? "Peripheral disconnected"))
        } else {
            failPendingCommand(with: OBDTransportError.connectionFailed(error?.localizedDescription ?? "Peripheral disconnected"))
            clearConnection()
            connectionState = .disconnected
        }
    }
}

extension CoreBluetoothOBDClient: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            failConnection(OBDTransportError.connectionFailed(error.localizedDescription))
            return
        }
        let services = peripheral.services ?? []
        guard !services.isEmpty else {
            failConnection(OBDTransportError.serialChannelUnavailable)
            return
        }
        pendingServices = Set(services.map(\.uuid))
        services.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            failConnection(OBDTransportError.connectionFailed(error.localizedDescription))
            return
        }
        discoveredCharacteristics.append(contentsOf: service.characteristics ?? [])
        pendingServices.remove(service.uuid)
        guard pendingServices.isEmpty else { return }
        do {
            try selectSerialCharacteristics()
        } catch {
            failConnection(error)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == notifyCharacteristic?.uuid else { return }
        if let error {
            failConnection(OBDTransportError.connectionFailed(error.localizedDescription))
        } else if characteristic.isNotifying {
            finishConnection()
        } else {
            failConnection(OBDTransportError.notificationsUnavailable)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == notifyCharacteristic?.uuid, commandContinuation != nil else { return }
        if let error {
            failPendingCommand(with: error)
            return
        }
        guard let data = characteristic.value,
              let chunk = String(data: data, encoding: .utf8) else { return }
        commandBuffer += chunk.replacingOccurrences(of: "\r", with: "\n")
        guard commandBuffer.contains(">") else { return }

        let response = commandBuffer
        let continuation = commandContinuation
        commandContinuation = nil
        commandToken = nil
        commandBuffer = ""
        continuation?.resume(returning: response)
    }
}
