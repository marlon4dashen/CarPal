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
final class CoreBluetoothOBDClient: NSObject, BluetoothAdapterClient, OBDCommandClient, @unchecked Sendable {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CarPal",
        category: "OBDTransport"
    )
    private(set) var connectionState: AdapterConnectionState = .notChecked

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var writeCharacteristic: CBCharacteristic?
    @ObservationIgnored private var notifyCharacteristic: CBCharacteristic?
    @ObservationIgnored private var discoveredCharacteristics: [CBCharacteristic] = []
    @ObservationIgnored private var pendingServices = Set<CBUUID>()
    @ObservationIgnored private var supportedPIDs = Set<UInt8>()
    @ObservationIgnored private let parser = ELM327Parser()

    @ObservationIgnored private var powerContinuation: CheckedContinuation<Void, Error>?
    @ObservationIgnored private var discoveryContinuation: CheckedContinuation<DiscoveredAdapter, Error>?
    @ObservationIgnored private var connectionContinuation: CheckedContinuation<Void, Error>?
    @ObservationIgnored private var commandContinuation: CheckedContinuation<String, Error>?
    @ObservationIgnored private var commandBuffer = ""
    @ObservationIgnored private var commandToken: UUID?
    @ObservationIgnored private var discoveryToken: UUID?
    @ObservationIgnored private var connectionToken: UUID?

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

    func prepareConnection() async throws {
        let adapter = try await discoverSupportedAdapter()
        try await connect(to: adapter)
    }

    func initializeSession() async throws {
        _ = try await send("ATZ", timeout: .seconds(8), acceptsAnyResponse: true)
        for command in ["ATE0", "ATL0", "ATS0", "ATH0", "ATSP0"] {
            _ = try await send(command, acceptsAnyResponse: true)
        }
        let identity = try await send("ATI", acceptsAnyResponse: true)
        guard identity.localizedCaseInsensitiveContains("ELM") || identity.localizedCaseInsensitiveContains("OBD") else {
            throw OBDTransportError.invalidResponse(identity)
        }
    }

    func discoverSupport() async throws -> OBDSupportReport {
        var discovered = Set<UInt8>()
        var bases: [UInt8] = [0x00]
        while !bases.isEmpty {
            let base = bases.removeFirst()
            let response = try await send(String(format: "01%02X", base))
            let page = parser.supportedPIDs(base: base, response: response)
            discovered.formUnion(page)
            let nextBase = base + 0x20
            if page.contains(nextBase), nextBase <= 0x40 {
                bases.append(nextBase)
            }
        }
        supportedPIDs = discovered
#if DEBUG
        let pidList = discovered.sorted().map { String(format: "%02X", $0) }.joined(separator: ",")
        Self.logger.debug("Supported Mode 01 PIDs: \(pidList, privacy: .public)")
#endif

        let optional: [(UInt8, String)] = [
            (0x04, "Calculated engine load"), (0x0D, "Vehicle speed"),
            (0x11, "Throttle position"), (0x06, "Short-term fuel trim"),
            (0x07, "Long-term fuel trim")
        ]
        let required: [(UInt8, String)] = [
            (0x0C, "Engine RPM"), (0x05, "Coolant temperature"),
            (0x42, "Control-module voltage"), (0x03, "Fuel-system status")
        ]
        return OBDSupportReport(
            unavailableRequiredReadings: required.compactMap { supportedPIDs.contains($0.0) ? nil : $0.1 },
            unavailableOptionalReadings: optional.compactMap { supportedPIDs.contains($0.0) ? nil : $0.1 }
        )
    }

    func retrieveCoreData() async throws -> RawScanData {
        var values: [SensorMetric: Double] = [:]
        try await readMetric(.engineRPM, pid: 0x0C, byteCount: 2, into: &values) {
            (Double($0[0]) * 256 + Double($0[1])) / 4
        }
        try await readMetric(.vehicleSpeed, pid: 0x0D, into: &values) { Double($0[0]) }
        try await readMetric(.coolantTemperature, pid: 0x05, into: &values) { Double($0[0]) - 40 }
        try await readMetric(.calculatedEngineLoad, pid: 0x04, into: &values) { Double($0[0]) * 100 / 255 }
        try await readMetric(.throttlePosition, pid: 0x11, into: &values) { Double($0[0]) * 100 / 255 }
        try await readMetric(.shortTermFuelTrim, pid: 0x06, into: &values) { (Double($0[0]) - 128) * 100 / 128 }
        try await readMetric(.longTermFuelTrim, pid: 0x07, into: &values) { (Double($0[0]) - 128) * 100 / 128 }
        try await readMetric(.controlModuleVoltage, pid: 0x42, byteCount: 2, into: &values) {
            (Double($0[0]) * 256 + Double($0[1])) / 1_000
        }

        let dtcResponse = try await send("03", allowsNoData: true)
        let troubleCodes = isNoData(dtcResponse) ? [] : parser.troubleCodes(from: dtcResponse)
        let fuelSystemStatus = try await readFuelSystemStatus()
        let freezeFrameResponse = try? await send("0202", allowsNoData: true)
        let freezeFrameAvailable = freezeFrameResponse.map {
            !isNoData($0) && parser.payload(for: 0x02, pid: 0x02, in: $0) != nil
        } ?? false

        return RawScanData(
            values: values,
            troubleCodes: troubleCodes,
            troubleCodesAvailable: true,
            fuelSystemStatus: fuelSystemStatus,
            freezeFrameAvailable: freezeFrameAvailable
        )
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

    private func readMetric(
        _ metric: SensorMetric,
        pid: UInt8,
        byteCount: Int = 1,
        into values: inout [SensorMetric: Double],
        transform: ([UInt8]) -> Double
    ) async throws {
        guard supportedPIDs.contains(pid) else { return }
        let response = try await send(String(format: "01%02X", pid), allowsNoData: true)
        guard let payload = parser.payload(for: 0x01, pid: pid, in: response), payload.count >= byteCount else { return }
        values[metric] = transform(Array(payload.prefix(byteCount)))
    }

    private func readFuelSystemStatus() async throws -> String? {
        guard supportedPIDs.contains(0x03) else { return nil }
        let response = try await send("0103", allowsNoData: true)
        guard let status = parser.payload(for: 0x01, pid: 0x03, in: response)?.first else { return nil }
        return switch status {
        case 1: "Open loop: insufficient engine temperature"
        case 2: "Closed loop"
        case 4: "Open loop: engine load or deceleration"
        case 8: "Open loop: system failure"
        case 16: "Closed loop with oxygen-sensor fault"
        default: "Status reported (0x\(String(format: "%02X", status)))"
        }
    }

    private func send(
        _ command: String,
        timeout: Duration = .seconds(4),
        acceptsAnyResponse: Bool = false,
        allowsNoData: Bool = false
    ) async throws -> String {
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
                try? await Task.sleep(for: timeout)
                guard self?.commandToken == token else { return }
                self?.failPendingCommand(with: OBDTransportError.commandTimedOut(command))
            }
        }

        let cleaned = clean(response, echo: command)
#if DEBUG
        Self.logger.debug("ELM \(command, privacy: .public) -> \(cleaned, privacy: .public)")
#endif
        if isRejected(cleaned) || (!allowsNoData && isNoData(cleaned)) {
            throw OBDTransportError.adapterRejectedCommand(cleaned)
        }
        if !acceptsAnyResponse && cleaned.isEmpty {
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
        supportedPIDs = []
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
