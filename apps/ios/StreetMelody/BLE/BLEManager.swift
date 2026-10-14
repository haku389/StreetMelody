import CoreBluetooth
import Foundation
import Combine

// MARK: - BLE定数

private enum BLEConstants {
    /// StreetMelody 専用サービスUUID
    static let serviceUUID = CBUUID(string: "E7A1B2C3-D4E5-F6A7-B8C9-D0E1F2A3B4C5")
    /// ユーザーID を読み取るキャラクタリスティックUUID
    static let userIDCharUUID = CBUUID(string: "A1B2C3D4-E5F6-A7B8-C9D0-E1F2A3B4C5D6")
    static let cooldownHours: TimeInterval = 6 * 3600
}

// MARK: - BLEManager
//
// すれちがい（近距離）で実ユーザーの user_id を交換する。
// iOS は manufacturer data を広告できないため、共有サービスUUIDを広告し、
// 検出側が GATT 接続して user_id キャラクタリスティックを read する正攻法を用いる。
// （フォアグラウンド同士で成立。バックグラウンドは iOS の制約あり。）

final class BLEManager: NSObject, ObservableObject {

    @Published private(set) var isScanning = false
    @Published private(set) var nearbyUsers: [NearbyUser] = []   // すれちがった実ユーザー（新しい順）

    /// 新しいユーザーとすれちがった時に呼ぶ（VM がフォロー導線などに使う）。
    var onNewNearby: ((NearbyUser) -> Void)?

    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!

    private var myUserId: String?
    private var connecting: [UUID: CBPeripheral] = [:]   // 接続中の peripheral を保持
    private var lastExchangeMap: [String: Date] = [:]    // user_id -> 最終交換
    private var hourlyCount = 0
    private var hourlyReset = Date()

    init(repository: MelodyRepository) {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
    }

    // MARK: Public

    /// 自分の user_id を広告し、スキャンを開始（すれちがい開始）。
    func start(userId: String) {
        myUserId = userId
        startAdvertisingIfReady()
        startScan()
    }

    func startScan() {
        guard centralManager.state == .poweredOn, !isScanning else { return }
        isScanning = true
        centralManager.scanForPeripherals(withServices: [BLEConstants.serviceUUID],
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScan() {
        if centralManager.state == .poweredOn { centralManager.stopScan() }
        isScanning = false
    }

    // MARK: Advertising（peripheral 側 = 自分の user_id を提供）

    private func startAdvertisingIfReady() {
        guard peripheralManager.state == .poweredOn, let uid = myUserId else { return }
        peripheralManager.removeAllServices()
        let ch = CBMutableCharacteristic(type: BLEConstants.userIDCharUUID,
                                         properties: [.read],
                                         value: Data(uid.utf8),   // 固定値＝read で自動応答
                                         permissions: [.readable])
        let service = CBMutableService(type: BLEConstants.serviceUUID, primary: true)
        service.characteristics = [ch]
        peripheralManager.add(service)
        if peripheralManager.isAdvertising { peripheralManager.stopAdvertising() }
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BLEConstants.serviceUUID],
            CBAdvertisementDataLocalNameKey: "StreetMelody",
        ])
    }

    // MARK: すれちがい記録

    private func canExchange(with userId: String) -> Bool {
        if userId == myUserId { return false }
        if let last = lastExchangeMap[userId], Date().timeIntervalSince(last) < BLEConstants.cooldownHours { return false }
        if Date().timeIntervalSince(hourlyReset) > 3600 { hourlyCount = 0; hourlyReset = Date() }
        return hourlyCount < 10
    }

    private func record(userId: String, rssi: Int) {
        guard canExchange(with: userId) else { return }
        lastExchangeMap[userId] = Date()
        hourlyCount += 1
        let user = NearbyUser(id: userId, userId: userId, rssi: rssi, detectedAt: Date())
        nearbyUsers.removeAll { $0.userId == userId }
        nearbyUsers.insert(user, at: 0)
        onNewNearby?(user)
    }
}

// MARK: - CBCentralManagerDelegate（検出 → 接続 → read）

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { startScan() } else { isScanning = false }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // クールダウン済みの既知ユーザーは何度も繋がない（rssiだけ更新）
        connecting[peripheral.identifier] = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([BLEConstants.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connecting[peripheral.identifier] = nil
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connecting[peripheral.identifier] = nil
    }
}

// MARK: - CBPeripheralDelegate（user_id を read）

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let s = peripheral.services?.first(where: { $0.uuid == BLEConstants.serviceUUID }) else {
            centralManager.cancelPeripheralConnection(peripheral); return
        }
        peripheral.discoverCharacteristics([BLEConstants.userIDCharUUID], for: s)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let c = service.characteristics?.first(where: { $0.uuid == BLEConstants.userIDCharUUID }) else {
            centralManager.cancelPeripheralConnection(peripheral); return
        }
        peripheral.readValue(for: c)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value, let uid = String(data: data, encoding: .utf8), uid.count == 36 {
            record(userId: uid, rssi: -60)
        }
        centralManager.cancelPeripheralConnection(peripheral)
        connecting[peripheral.identifier] = nil
    }
}

// MARK: - CBPeripheralManagerDelegate（自分を広告）

extension BLEManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn { startAdvertisingIfReady() }
    }
}
