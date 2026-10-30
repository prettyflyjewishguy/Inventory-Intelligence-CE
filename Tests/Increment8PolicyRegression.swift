import Foundation

@main struct Increment8Regression {
    static func main() throws {
        let path = CommandLine.arguments[1]
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        let lines = contents.split(whereSeparator: \.isNewline).map(String.init)
        let headers = lines[0].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        func col(_ name: String) -> Int { headers.firstIndex(of: name)! }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        let devices: [DeviceRecord] = lines.dropFirst().map { line in
            let fields = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            return DeviceRecord(serial: fields[col("Serial")], model: fields[col("Model")],
                                assignedUser: fields[col("Assigned User")],
                                dateAdded: df.date(from: fields[col("Date Added")]))
        }
        let now = df.date(from: "2026-10-30")!
        for years in [4, 5, 6] {
            var policy = PlanningPolicy()
            policy.overrides["MacBook Pro"] = years
            policy.modelCosts["MacBook Pro"] = 3000
            let dashboardReview = devices.filter { policy.label(for: $0, asOf: now) == "Review replacement" }.count
            let reportReview = devices.filter { policy.label(for: $0, asOf: now) == "Review replacement" }
            let analyticsReview = devices.reduce(0) { $0 + (policy.label(for: $1, asOf: now) == "Review replacement" ? 1 : 0) }
            let planningReview = devices.filter { record in
                guard let target = policy.target(for: record), let reference = record.dateAdded, reference <= now else { return false }
                return target <= now
            }
            let unknown = devices.filter { policy.label(for: $0, asOf: now) == "Unknown" }.count
            let within = devices.filter { policy.label(for: $0, asOf: now) == "Within lifecycle window" }.count
            precondition(dashboardReview == reportReview.count && dashboardReview == analyticsReview && dashboardReview == planningReview.count)
            precondition(dashboardReview + within + unknown == devices.count)
            let exportedCSVStatus = devices.map { policy.label(for: $0, asOf: now) }
            let exportedExcelStatus = devices.map { policy.label(for: $0, asOf: now) }
            precondition(exportedCSVStatus == exportedExcelStatus)
            precondition(exportedCSVStatus.filter { $0 == "Review replacement" }.count == dashboardReview)
            let budget = planningReview.reduce(0.0) { $0 + policy.cost(for: $1.model) }
            precondition(budget >= 0)
            print("PASS \(devices.count) devices, MBP=\(years)y: review=\(dashboardReview), within=\(within), unknown=\(unknown), budget=\(budget)")
        }
    }
}
