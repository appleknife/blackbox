import Combine
import CoreBluetooth
import SwiftUI

struct BLEDevice: Identifiable, Hashable {
    let id: UUID
    var name: String
    var rssi: Int
}

struct BLEField: Identifiable, Hashable {
    let id: String
    let uuid: String
    let properties: String
}

@MainActor
final class BLEExplorer: NSObject, ObservableObject {
    @Published private(set) var devices: [BLEDevice] = []
    @Published private(set) var fields: [BLEField] = []
    @Published private(set) var connected: String?
    @Published private(set) var state = "idle"
    @Published var message: String?
    @Published var output: String = ""

    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var listeners: [CBUUID: CBCharacteristic] = [:]

    func begin() {
        guard central == nil else {
            central?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            return
        }
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func stop() {
        central?.stopScan()
        state = "idle"
    }

    func connect(_ device: BLEDevice) {
        guard let peripheral = peripherals[device.id] else { return }
        fields = []
        output = ""
        state = "linking \(device.name)"
        central?.connect(peripheral)
    }

    func disconnect() {
        guard let name = connected, let peripheral = peripherals.values.first(where: { $0.name == name }) else { return }
        central?.cancelPeripheralConnection(peripheral)
        fields = []
        connected = nil
        state = "idle"
    }

    func read(_ field: BLEField) {
        guard let (peripheral, characteristic) = locate(field) else { return }
        peripheral.readValue(for: characteristic)
    }

    func toggleNotify(_ field: BLEField) {
        guard let (peripheral, characteristic) = locate(field) else { return }
        let on = !characteristic.isNotifying
        peripheral.setNotifyValue(on, for: characteristic)
        output = "\(field.uuid) notify \(on ? "on" : "off")"
    }

    func write(_ text: String, to field: BLEField) {
        guard let (peripheral, characteristic) = locate(field),
              let data = text.data(using: .utf8) else { return }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        output = "wrote \(data.count) bytes to \(field.uuid)"
    }

    private func locate(_ field: BLEField) -> (CBPeripheral, CBCharacteristic)? {
        guard let peripheral = peripherals.values.first(where: { $0.services?.contains(where: { service in
            service.characteristics?.contains(where: { $0.uuid.uuidString == field.uuid }) ?? false
        }) ?? false }), let characteristic = listeners[CBUUID(string: field.uuid)] else {
            message = "Characteristic no longer reachable."
            return nil
        }
        return (peripheral, characteristic)
    }
}

extension BLEExplorer: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                state = "scanning"
                central.scanForPeripherals(withServices: nil,
                                            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
                CaseLog.shared.record("RAD-01", "BLE scan started")
            case .unauthorized:
                state = "denied"
                message = "Bluetooth permission denied in Settings."
            default:
                state = "radio off"
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "unnamed"
        let id = peripheral.identifier
        let rssi = RSSI.intValue
        Task { @MainActor in
            self.peripherals[id] = peripheral
            peripheral.delegate = self
            if let index = self.devices.firstIndex(where: { $0.id == id }) {
                self.devices[index].rssi = rssi
                if self.devices[index].name == "unnamed" { self.devices[index].name = name }
            } else {
                self.devices.append(BLEDevice(id: id, name: name, rssi: rssi))
                CaseLog.shared.finding("RAD-01", "BLE device \(name)", fields: [
                    "rssi": "\(rssi)",
                    "id": id.uuidString
                ])
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.connected = peripheral.name ?? "device"
            self.state = "connected"
            CaseLog.shared.record("RAD-01", "Linked to \(peripheral.name ?? "device")")
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.state = "link failed"
            self.message = error?.localizedDescription ?? "Could not link."
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.connected = nil
            self.state = "idle"
            self.fields = []
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services { peripheral.discoverCharacteristics(nil, for: service) }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            let uuid = characteristic.uuid.uuidString
            var tags: [String] = []
            if characteristic.properties.contains(.read) { tags.append("read") }
            if characteristic.properties.contains(.write) { tags.append("write") }
            if characteristic.properties.contains(.notify) { tags.append("notify") }
            let field = BLEField(id: uuid, uuid: uuid, properties: tags.isEmpty ? "opaque" : tags.joined(separator: "+"))
            Task { @MainActor in
                self.listeners[characteristic.uuid] = characteristic
                if !self.fields.contains(field) {
                    self.fields.append(field)
                    CaseLog.shared.record("RAD-01", "Characteristic \(uuid) (\(field.properties))")
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        let hex = data.map { String(format: "%02x", $0) }.joined()
        let ascii = String(data: data, encoding: .utf8)
        let line = "\(characteristic.uuid.uuidString.prefix(8)) ← \(hex)\(ascii.map { "  \"\($0)\"" } ?? "")"
        Task { @MainActor in
            self.output = line
            CaseLog.shared.record("RAD-01", line)
        }
    }
}