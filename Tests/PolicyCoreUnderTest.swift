import Foundation
struct DeviceRecord: Identifiable, Codable {
    var id: String { serial }
    let serial: String
    let model: String
    let assignedUser: String
    let dateAdded: Date?
    var hardware: HardwareAttributes = .init()
}

struct HardwareAttributes: Codable {
    var processor = ""
    var memoryGB = ""
    var storageGB = ""
    var osVersion = ""
    var enrollmentStatus = ""
    var managementPlatform = ""
    var lastInventoryUpdate = ""
    var assetTag = ""
}

enum Lifecycle {
    static func yearsSince(_ date: Date?, asOf now: Date = .now) -> Int? {
        guard let date, date <= now else { return nil }
        return Calendar(identifier: .gregorian).dateComponents([.year], from: date, to: now).year
    }
    static func label(_ date: Date?, years: Int, asOf now: Date = .now) -> String {
        guard let date, date <= now,
              let target = Calendar(identifier: .gregorian).date(byAdding: .year, value: max(1, years), to: date) else { return "Unknown" }
        return target <= now ? "Review replacement" : "Within lifecycle window"
    }
}


struct PlanningPolicy: Codable {
    var defaultYears: Int = 4
    var overrides: [String: Int] = [:]
    var defaultCost: Double = 1800
    var modelCosts: [String: Double] = [:]
    static let key = "org.inventoryintelligence.community.planningPolicy.v1"
    static func load() -> Self {
        guard let data = UserDefaults.standard.data(forKey: key),
              let policy = try? JSONDecoder().decode(Self.self, from: data) else { return .init() }
        return policy
    }
    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) }
    }
    func label(for device: DeviceRecord, asOf now: Date = .now) -> String {
        Lifecycle.label(device.dateAdded, years: years(for: device.model), asOf: now)
    }
    func years(for model: String) -> Int { max(1, min(12, overrides[model] ?? defaultYears)) }
    func cost(for model: String) -> Double { max(0, modelCosts[model] ?? defaultCost) }
    func target(for device: DeviceRecord) -> Date? {
        guard let date = device.dateAdded else { return nil }
        return Calendar(identifier: .gregorian).date(byAdding: .year, value: years(for: device.model), to: date)
    }
}


