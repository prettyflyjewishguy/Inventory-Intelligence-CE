import SwiftUI
import Foundation
import UniformTypeIdentifiers
import AppKit

// Independent Community Edition prototype. No enterprise source or integration code included.
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

@MainActor final class InventoryStore: ObservableObject {
    @Published var devices: [DeviceRecord] = []
    @Published var error: String?
    @Published var sourceName = "No CSV loaded"

    func importCSV(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let rows = try CSVParser.parse(text)
            guard let header = rows.first else { throw CSVError.empty }
            let normalized = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            func index(_ names: [String]) -> Int? { names.compactMap { normalized.firstIndex(of: $0) }.first }
            guard let serialIndex = index(["serial", "serial number"]),
                  let modelIndex = index(["model", "model name"]) else { throw CSVError.missingColumns }
            let userIndex = index(["user", "assigned user", "username"])
            let dateIndex = index(["date added", "date_added", "enrollment date"])
            let iso = ISO8601DateFormatter()
            let day = DateFormatter(); day.locale = Locale(identifier: "en_US_POSIX"); day.dateFormat = "yyyy-MM-dd"
            let optionalFields: [[String]] = [
                ["processor", "chip", "cpu"], ["memory gb", "ram gb", "memory"],
                ["storage gb", "disk gb", "storage"], ["os version", "operating system", "macos version"],
                ["enrollment status", "enrollment"], ["management platform", "mdm", "management"],
                ["last inventory update", "last check-in", "last seen"], ["asset tag", "asset id"]
            ]
            let optionalIndices = optionalFields.map { index($0) }
            var result: [DeviceRecord] = []
            result.reserveCapacity(max(0, rows.count - 1))
            var seen = Set<String>()
            for row in rows.dropFirst() where row.contains(where: { !$0.isEmpty }) {
                guard row.count == header.count else { throw CSVError.malformedRow }
                let serial = row[serialIndex].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                guard !serial.isEmpty, seen.insert(serial).inserted else { throw CSVError.duplicateOrEmptySerial }
                let rawDate = dateIndex.map { row[$0].trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
                let parsedDate = rawDate.isEmpty ? nil : (day.date(from: rawDate) ?? iso.date(from: rawDate))
                if !rawDate.isEmpty && parsedDate == nil { throw CSVError.invalidDate }
                func field(_ offset: Int) -> String { optionalIndices[offset].map { row[$0].trimmingCharacters(in: .whitespacesAndNewlines) } ?? "" }
                let hardware = HardwareAttributes(
                    processor: field(0),
                    memoryGB: field(1),
                    storageGB: field(2),
                    osVersion: field(3),
                    enrollmentStatus: field(4),
                    managementPlatform: field(5),
                    lastInventoryUpdate: field(6),
                    assetTag: field(7)
                )
                result.append(DeviceRecord(serial: serial, model: row[modelIndex], assignedUser: userIndex.map { row[$0] } ?? "", dateAdded: parsedDate, hardware: hardware))
            }
            devices = result
            sourceName = url.lastPathComponent
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

enum CSVError: LocalizedError {
    case empty, missingColumns, malformedRow, duplicateOrEmptySerial, invalidDate, unclosedQuote
    var errorDescription: String? {
        switch self {
        case .empty: return "The CSV is empty."
        case .missingColumns: return "CSV requires Serial and Model columns."
        case .malformedRow: return "A CSV row does not match the header columns."
        case .duplicateOrEmptySerial: return "A serial is missing or duplicated."
        case .invalidDate: return "Dates must use YYYY-MM-DD or ISO 8601."
        case .unclosedQuote: return "A CSV field has an unclosed quote."
        }
    }
}

enum CSVParser {
    static func parse(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []; var row: [String] = []; var field = ""; var quoted = false
        let chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n")); var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if quoted && i + 1 < chars.count && chars[i+1] == "\"" { field.append("\""); i += 1 }
                else { quoted.toggle() }
            } else if c == "," && !quoted { row.append(field); field = "" }
            else if c == "\n" && !quoted { row.append(field); rows.append(row); row = []; field = "" }
            else { field.append(c) }
            i += 1
        }
        if quoted { throw CSVError.unclosedQuote }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}

enum Screen: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard", lookup = "Serial Lookup", reports = "Inventory Reports", analytics = "Lifecycle Analytics", planning = "Replacement Planning", intelligence = "Device Intelligence & Budget"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .lookup: return "magnifyingglass"
        case .reports: return "doc.text"
        case .analytics: return "chart.bar.xaxis"
        case .planning: return "calendar.badge.clock"
        case .intelligence: return "dollarsign.circle"
        }
    }
}

private enum ReportFilter: String, CaseIterable, Identifiable, Codable {
    case all = "All statuses", review = "Review replacement", withinWindow = "Within lifecycle window", unknown = "Unknown"
    var id: String { rawValue }
}

private enum ReportSort: String, CaseIterable, Identifiable, Codable {
    case serial = "Serial", model = "Model", user = "Assigned user", oldest = "Oldest first", newest = "Newest first"
    var id: String { rawValue }
}

private enum ReportPreset: String, CaseIterable, Identifiable {
    case all = "All inventory", review = "Replacement review", upcoming = "Upcoming replacements", missing = "Data quality"
    var id: String { rawValue }
}

private enum QualityScope: String, CaseIterable, Identifiable {
    case all = "All records", incomplete = "Any missing field", missingDate = "Missing date", missingUser = "Missing assignment", complete = "Complete records"
    var id: String { rawValue }
}

private enum ForecastWindow: Int, CaseIterable, Identifiable {
    case six = 6, twelve = 12, eighteen = 18, twentyFour = 24
    var id: Int { rawValue }
    var title: String { "\(rawValue) months" }
}

private enum ExportColumn: String, CaseIterable, Identifiable, Codable {
    case serial = "Serial", model = "Model", user = "Assigned User", reference = "Imported Reference Date", status = "Lifecycle Status", target = "Estimated Replacement Date", source = "CSV Source"
    var id: String { rawValue }
}

// Stage 7: saved report configurations are UI state, not inventory or provider data.
private struct SavedReportView: Identifiable, Codable {
    var id = UUID()
    let name: String
    let search: String
    let status: ReportFilter
    let sort: ReportSort
    let model: String
    let onlyAssigned: Bool
    let onlyDated: Bool
    let columns: Set<ExportColumn>
}

struct ContentView: View {
    @StateObject private var store = InventoryStore()
    @State private var screen: Screen? = .dashboard
    @State private var policy = PlanningPolicy.load()
    @State private var showPolicyEditor = false
    @State private var importing = false
    @State private var query = ""
    @State private var lookupPage = 0
    @State private var reportPage = 0
    @State private var analyticsPage = 0
    @State private var planningReviewPage = 0
    @State private var planningUpcomingPage = 0
    @State private var pageSize = 50
    @State private var exportProgress = ""
    @State private var selectedDevice: DeviceRecord?
    @State private var reportSearch = ""
    @State private var debouncedReportSearch = ""
    @State private var reportFilter: ReportFilter = .all
    @State private var reportSort: ReportSort = .serial
    @State private var exportError: String?
    @State private var forecastWindow: ForecastWindow = .twelve
    @State private var includedColumns: Set<ExportColumn> = Set(ExportColumn.allCases)
    @State private var showExportOptions = false
    @State private var reportOnlyAssigned = false
    @State private var reportOnlyDated = false
    @State private var reportModel = "All models"
    @State private var reportPreset: ReportPreset = .all
    @State private var qualityScope: QualityScope = .all
    @State private var showReportGuide = false
    @State private var showAppHelp = false
    @State private var savedReportViews: [SavedReportView] = []
    private let savedViewsKey = "org.inventoryintelligence.community.savedReportViews.v1"
    @State private var showAnalyticsSummary = false
    @State private var analyticsModelLimit = 8
    @State private var reportViewName = ""
    @State private var showSaveReportView = false
    @State private var selectedSavedReportID: UUID?
    @State private var reportNotice: String?
    private var matches: [DeviceRecord] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        return store.devices.filter { $0.serial.localizedCaseInsensitiveContains(term) }
    }

    private var reportRows: [DeviceRecord] {
        let filtered = store.devices.filter { device in
            let textMatches = debouncedReportSearch.isEmpty ||
                device.serial.localizedCaseInsensitiveContains(debouncedReportSearch) ||
                device.model.localizedCaseInsensitiveContains(debouncedReportSearch) ||
                device.assignedUser.localizedCaseInsensitiveContains(debouncedReportSearch)
            let statusMatches: Bool
            switch reportFilter {
            case .all: statusMatches = true
            case .review: statusMatches = policy.label(for: device) == "Review replacement"
            case .withinWindow: statusMatches = policy.label(for: device) == "Within lifecycle window"
            case .unknown: statusMatches = policy.label(for: device) == "Unknown"
            }
            let missingUser = device.assignedUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let qualityMatches: Bool
            switch qualityScope {
            case .all: qualityMatches = reportPreset != .missing || device.dateAdded == nil || missingUser
            case .incomplete: qualityMatches = device.dateAdded == nil || missingUser
            case .missingDate: qualityMatches = device.dateAdded == nil
            case .missingUser: qualityMatches = missingUser
            case .complete: qualityMatches = device.dateAdded != nil && !missingUser
            }
            return qualityMatches && textMatches && statusMatches && (reportModel == "All models" || device.model == reportModel) && (!reportOnlyAssigned || !device.assignedUser.isEmpty) && (!reportOnlyDated || device.dateAdded != nil)
        }
        switch reportSort {
        case .serial: return filtered.sorted { $0.serial.localizedStandardCompare($1.serial) == .orderedAscending }
        case .model: return filtered.sorted { $0.model.localizedStandardCompare($1.model) == .orderedAscending }
        case .user: return filtered.sorted { $0.assignedUser.localizedStandardCompare($1.assignedUser) == .orderedAscending }
        case .oldest: return filtered.sorted { ($0.dateAdded ?? .distantFuture) < ($1.dateAdded ?? .distantFuture) }
        case .newest: return filtered.sorted { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
        }
    }

    private var availableModels: [String] {
        ["All models"] + Array(Set(store.devices.map(\.model))).sorted()
    }

    private var missingUserCount: Int { store.devices.filter { $0.assignedUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count }
    private var missingDateCount: Int { store.devices.filter { $0.dateAdded == nil }.count }
    private var incompleteDevices: [DeviceRecord] {
        store.devices.filter { $0.dateAdded == nil || $0.assignedUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    private func applyPreset(_ preset: ReportPreset) {
        reportPreset = preset
        qualityScope = preset == .missing ? .incomplete : .all
        reportSearch = ""; reportFilter = .all; reportOnlyAssigned = false
        reportOnlyDated = false; reportModel = "All models"; reportSort = .serial
        switch preset {
        case .all: break
        case .review: reportFilter = .review
        case .upcoming: screen = .planning
        case .missing: reportFilter = .all
        }
    }

    private func loadSavedViews() {
        guard let data = UserDefaults.standard.data(forKey: savedViewsKey) else { return }
        do { savedReportViews = try JSONDecoder().decode([SavedReportView].self, from: data) }
        catch { reportNotice = "Saved report templates could not be loaded." }
    }

    private func persistSavedViews() {
        do {
            let data = try JSONEncoder().encode(savedReportViews)
            UserDefaults.standard.set(data, forKey: savedViewsKey)
        } catch { reportNotice = "Could not save report templates: \(error.localizedDescription)" }
    }

    private func saveReportView() {
        let name = reportViewName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        savedReportViews.removeAll { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
        let view = SavedReportView(name: name, search: reportSearch, status: reportFilter,
            sort: reportSort, model: reportModel, onlyAssigned: reportOnlyAssigned,
            onlyDated: reportOnlyDated, columns: includedColumns)
        savedReportViews.append(view)
        persistSavedViews()
        selectedSavedReportID = view.id
        reportNotice = "Saved report view: \(name)"
        showSaveReportView = false
        reportViewName = ""
    }

    private func restoreReportView(_ view: SavedReportView) {
        reportPreset = .all
        qualityScope = .all
        reportSearch = view.search
        reportFilter = view.status
        reportSort = view.sort
        reportModel = availableModels.contains(view.model) ? view.model : "All models"
        reportOnlyAssigned = view.onlyAssigned
        reportOnlyDated = view.onlyDated
        includedColumns = view.columns
        selectedSavedReportID = view.id
        reportNotice = "Restored \(view.name) · \(reportRows.count) matching devices"
    }

    private func exportSummary() {
        let now = DateFormatter()
        now.locale = Locale(identifier: "en_US_POSIX")
        now.dateFormat = "yyyy-MM-dd HH:mm"
        let lines = [
            "Inventory Intelligence CE | Report Summary",
            "Generated: \(now.string(from: .now))",
            "Source: \(store.sourceName)",
            "Source records: \(store.devices.count)",
            "Filtered report records: \(reportRows.count)",
            "Lifecycle status: \(reportFilter.rawValue)",
            "Model filter: \(reportModel)",
            "Sort: \(reportSort.rawValue)",
            "Search: \(reportSearch.isEmpty ? "None" : reportSearch)",
            "Require assigned user: \(reportOnlyAssigned ? "Yes" : "No")",
            "Require reference date: \(reportOnlyDated ? "Yes" : "No")",
            "Replacement review (full inventory): \(reviewCandidates.count)",
            "Unknown reference dates: \(missingDateCount)",
            "Missing assignments: \(missingUserCount)",
            "Selected export columns: \(ExportColumn.allCases.filter { includedColumns.contains($0) }.map(\.rawValue).joined(separator: ", "))",
            "Note: Imported dates are unverified; this report is for planning only."
        ]
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "inventory-report-summary.txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8) }
        catch { exportError = "Could not export summary: \(error.localizedDescription)" }
    }

    private var hasImportedSource: Bool { store.sourceName != "No CSV loaded" }

    private var inventorySummary: String {
        let count = store.devices.count
        return "\(count) \(count == 1 ? "device" : "devices") loaded from \(store.sourceName)."
    }

    var body: some View {
        NavigationSplitView {
            List(Screen.allCases, selection: $screen) { item in
                Label(item.rawValue, systemImage: item.symbol).tag(item)
            }
            .navigationTitle("Inventory Intelligence")
            .navigationSplitViewColumnWidth(min: 230, ideal: 250, max: 300)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(screen?.rawValue ?? "Dashboard").font(.largeTitle.bold())
                        Text("Community Edition · Local CSV preview").foregroundStyle(.secondary)
                    }
                    switch screen ?? .dashboard {
                    case .dashboard:
                        HStack(spacing: 14) {
                            dashboardMetric("Imported Macs", "\(store.devices.count)", "laptopcomputer", .blue, filter: .all)
                            dashboardMetric("Replacement review", "\(analyticsCount(.review))", "calendar.badge.exclamationmark", .orange, filter: .review)
                            dashboardMetric("Unknown dates", "\(analyticsCount(.unknown))", "questionmark.circle", .secondary, filter: .unknown)
                        }
                        if hasImportedSource {
                            HStack(spacing: 12) {
                                reportMetric("Within window", analyticsCount(.withinWindow), .green, filter: .withinWindow)
                                Button { screen = .planning } label: {
                                    reportMetricContent("Next \(forecastWindow.rawValue) months", forecastCandidates.count, .blue, selected: false)
                                }.buttonStyle(.plain).help("Open replacement forecasting")
                            }
                            feedbackPanel("Inventory ready", detail: inventorySummary, symbol: "checkmark.circle.fill", tint: .green)
                        } else {
                            feedbackPanel("Get started with a CSV", detail: "Select Import CSV to load a local file with Serial and Model columns.", symbol: "doc.badge.plus", tint: .blue)
                        }
                        Text("Local CSV preview only · No MDM connections or verified warranty data.")
                            .font(.caption).foregroundStyle(.secondary)
                    case .lookup:
                        TextField("Search serial number", text: $query).textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Search serial number")
                        if hasImportedSource {
                            Text(query.isEmpty ? "Enter a serial to search across all \(store.devices.count) imported devices" : "\(matches.count) matching \(matches.count == 1 ? "device" : "devices")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.devices.isEmpty {
                            ContentUnavailableView("Find a device", systemImage: "magnifyingglass", description: Text("Enter a serial number above. Browse the complete inventory in Inventory Reports."))
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else {
                            pagedDeviceRows(matches, page: $lookupPage, emptyTitle: "No matching serial numbers")
                        }
                    case .reports:
                        Text(hasImportedSource ? "Source: \(store.sourceName) · \(store.devices.count) devices" : "No CSV imported yet")
                            .font(.callout).foregroundStyle(.secondary)
                        if hasImportedSource {
                            HStack(spacing: 12) {
                                Picker("Report workflow", selection: $reportPreset) {
                                    ForEach(ReportPreset.allCases) { preset in Text(preset.rawValue).tag(preset) }
                                }
                                .onChange(of: reportPreset) { _, value in applyPreset(value) }
                                .frame(maxWidth: 270)
                                Spacer()
                                Button { showReportGuide = true } label: { Label("Report Guide", systemImage: "questionmark.circle") }
                            }
                            HStack(spacing: 10) {
                                Text("Saved report views").font(.subheadline.weight(.semibold))
                                if savedReportViews.isEmpty {
                                    Text("No saved report templates").font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Menu("Open saved view") {
                                        ForEach(savedReportViews) { view in
                                            Button(view.name) { restoreReportView(view) }
                                        }
                                    }
                                    if let id = selectedSavedReportID,
                                       let view = savedReportViews.first(where: { $0.id == id }) {
                                        Button("Remove \(view.name)") {
                                            savedReportViews.removeAll { $0.id == id }
                                            persistSavedViews()
                                            selectedSavedReportID = nil
                                            reportNotice = "Saved view removed"
                                        }.font(.caption)
                                    }
                                }
                                Spacer()
                                Button { showSaveReportView = true } label: {
                                    Label("Save Current View", systemImage: "bookmark")
                                }
                            }
                            if let reportNotice {
                                Text(reportNotice).font(.caption).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 12) {
                                reportMetric("Total", store.devices.count, .blue, filter: .all)
                                reportMetric("Review", store.devices.filter { policy.label(for: $0) == "Review replacement" }.count, .orange, filter: .review)
                                reportMetric("Within window", store.devices.filter { policy.label(for: $0) == "Within lifecycle window" }.count, .green, filter: .withinWindow)
                                reportMetric("Unknown", store.devices.filter { policy.label(for: $0) == "Unknown" }.count, .secondary, filter: .unknown)
                            }
                            HStack(spacing: 12) {
                                TextField("Search serial, model, or user", text: $reportSearch)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Search inventory report")
                                Picker("Status", selection: $reportFilter) {
                                    ForEach(ReportFilter.allCases) { option in Text(option.rawValue).tag(option) }
                                }
                                .frame(width: 205)
                                Picker("Sort", selection: $reportSort) {
                                    ForEach(ReportSort.allCases) { option in Text(option.rawValue).tag(option) }
                                }
                                .frame(width: 185)
                            }
                            HStack(spacing: 18) {
                                Picker("Model", selection: $reportModel) {
                                    ForEach(availableModels, id: \.self) { model in Text(model).tag(model) }
                                }.frame(maxWidth: 280)
                                Toggle("Assigned devices only", isOn: $reportOnlyAssigned)
                                Toggle("Known dates only", isOn: $reportOnlyDated)
                                Picker("Data quality", selection: $qualityScope) {
                                    ForEach(QualityScope.allCases) { option in Text(option.rawValue).tag(option) }
                                }.frame(maxWidth: 185)
                                Button("Reset filters") {
                                    reportSearch = ""; reportFilter = .all; reportSort = .serial
                                    reportOnlyAssigned = false; reportOnlyDated = false; reportModel = "All models"; reportPreset = .all; qualityScope = .all
                                }
                            }.font(.caption)
                            HStack {
                                Text("Showing \(reportRows.count) of \(store.devices.count) devices")
                                Spacer()
                                Button { showExportOptions = true } label: {
                                    Label("Configure Export", systemImage: "slider.horizontal.3")
                                }
                                Menu {
                                    Button("Export filtered inventory (CSV)") { exportCSV(reportRows, suggestedName: "inventory-report.csv") }
                                    Button("Export Excel workbook (.xlsx)") { exportExcel() }.disabled(reportRows.isEmpty)
                                        .disabled(reportRows.isEmpty)
                                    Button("Export report summary (TXT)") { exportSummary() }
                                    Button("Export data quality (CSV)") { exportQualityCSV() }
                                        .disabled(incompleteDevices.isEmpty)
                                } label: { Label("Export Options", systemImage: "square.and.arrow.up.on.square") }
                                Button { exportCSV(reportRows, suggestedName: "inventory-report.csv") } label: {
                                    Label("Export CSV", systemImage: "square.and.arrow.up")
                                }.disabled(reportRows.isEmpty)
                                .help("Export all filtered records, not only the visible page")
                                Button { exportExcel() } label: { Label("Export Excel", systemImage: "tablecells") }
                                    .disabled(reportRows.isEmpty)
                            }
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if hasImportedSource {
                            HStack(spacing: 12) {
                                Label("Missing dates: \(missingDateCount)", systemImage: "calendar.badge.exclamationmark")
                                Label("Unassigned: \(missingUserCount)", systemImage: "person.crop.circle.badge.questionmark")
                                Spacer()
                                Button("Export Data Quality") { exportQualityCSV() }
                                    .disabled(incompleteDevices.isEmpty)
                            }.font(.caption).foregroundStyle(.secondary)
                        }
                        pagedDeviceRows(reportRows, page: $reportPage, emptyTitle: "No matching devices")
                    case .intelligence:
                        PlanningIntelligenceView(devices: store.devices, sourceName: store.sourceName, policy: $policy)
                    case .analytics:
                        Text("Replacement timing is an estimate based on an imported date, not verified purchase or warranty eligibility.")
                            .font(.callout).foregroundStyle(.secondary)
                        if hasImportedSource {
                            Text(inventorySummary).font(.caption).foregroundStyle(.secondary)
                            analyticsOverview
                            analyticsBreakdown
                            analyticsModelsView
                            analyticsQualityView
                            analyticsPlanningView
                            feedbackPanel("Understanding lifecycle status", detail: "Review replacement: the configured replacement date has been reached. Within lifecycle window: the configured replacement date is in the future. Unknown: no usable reference date was provided. These categories support planning, not verified eligibility.", symbol: "info.circle", tint: .blue)
                            HStack {
                                Text("Devices by imported reference date")
                                    .font(.headline)
                                Spacer()
                                Text("Select a serial to view details")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        pagedDeviceRows(store.devices.sorted { ($0.dateAdded ?? .distantFuture) < ($1.dateAdded ?? .distantFuture) }, page: $analyticsPage, emptyTitle: "No inventory to display")
                    case .planning:
                        planningView
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Inventory Intelligence CE")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        importing = true
                    } label: {
                        Label("Import CSV", systemImage: "doc.badge.plus")
                            .labelStyle(.titleAndIcon)
                    }
                    .help("Import device inventory from a CSV file")
                }
            }
            .sheet(isPresented: $showSaveReportView) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Save Report View").font(.title2.bold())
                    Text("Save your current search, filters, sorting, and export columns. Templates are stored locally on this Mac and remain available after restarting the app.")
                        .foregroundStyle(.secondary)
                    TextField("View name", text: $reportViewName).textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Cancel") { showSaveReportView = false }
                        Spacer()
                        Button("Save View") { saveReportView() }
                            .disabled(reportViewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .keyboardShortcut(.defaultAction)
                    }
                }.padding(26).frame(width: 460)
            }
            .sheet(isPresented: $showReportGuide) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Reporting Workflows").font(.title2.bold())
                    Text("All inventory shows the complete imported dataset. Replacement review filters devices at or beyond the configured lifecycle threshold. Upcoming replacements opens the adjustable 6–24 month forecast. Data quality isolates records missing an assigned user or reference date.")
                    Text("Exports use the current report columns. Planning and data-quality exports use their respective device selections. All dates are imported reference dates, not verified purchase dates.")
                        .foregroundStyle(.secondary)
                    HStack { Spacer(); Button("Done") { showReportGuide = false }.keyboardShortcut(.defaultAction) }
                }.padding(26).frame(width: 510)
            }
            .sheet(isPresented: $showExportOptions) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Report Columns").font(.title2.bold())
                    Text("Choose fields for CSV exports. Filters and sorting remain applied.").foregroundStyle(.secondary)
                    ForEach(ExportColumn.allCases) { column in
                        Toggle(column.rawValue, isOn: Binding(
                            get: { includedColumns.contains(column) },
                            set: { enabled in
                                if enabled { includedColumns.insert(column) }
                                else if includedColumns.count > 1 { includedColumns.remove(column) }
                            }))
                    }
                    HStack {
                        Button("Select All") { includedColumns = Set(ExportColumn.allCases) }
                        Spacer()
                        Button("Done") { showExportOptions = false }.keyboardShortcut(.defaultAction)
                    }
                }.padding(26).frame(width: 410)
            }
            .sheet(item: $selectedDevice) { device in
                DeviceDetailsSheet(device: device, sourceName: store.sourceName, policy: policy)
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                switch result { case .success(let url): store.importCSV(url); case .failure(let error): store.error = error.localizedDescription }
            }
            .alert("Export error", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
            .alert("Import error", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "") }
        }
        .frame(minWidth: 1020, minHeight: 620)
        .onReceive(NotificationCenter.default.publisher(for: .ceImportCSV)) { _ in importing = true }
        .onReceive(NotificationCenter.default.publisher(for: .ceExportCSV)) { _ in screen = .reports; exportCSV(reportRows, suggestedName: "inventory-report.csv") }
        .onReceive(NotificationCenter.default.publisher(for: .ceExportExcel)) { _ in screen = .reports; exportExcel() }
        .onReceive(NotificationCenter.default.publisher(for: .ceExportQuality)) { _ in screen = .reports; exportQualityCSV() }
        .onReceive(NotificationCenter.default.publisher(for: .ceExportPlanning)) { _ in screen = .planning; exportCSV(store.devices.filter { policy.label(for: $0) == "Review replacement" }, suggestedName: "replacement-review.csv") }
        .onReceive(NotificationCenter.default.publisher(for: .ceShowHelp)) { _ in showAppHelp = true }
        .sheet(isPresented: $showAppHelp) { CEHelpWindow() }
        .onAppear { loadSavedViews(); debouncedReportSearch = reportSearch }
        .task(id: reportSearch) {
            // Cancel obsolete searches while the user is typing; keep exports tied to displayed filters.
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            debouncedReportSearch = reportSearch
        }
    }

    // Stage 4: presentation-only replacement planning derived from existing normalized records.
    // Increment 7: planning uses the same shared policy as all other screens and exports.
    private var reviewCandidates: [DeviceRecord] {
        store.devices.filter { policy.label(for: $0) == "Review replacement" }
            .sorted { ($0.dateAdded ?? .distantFuture) < ($1.dateAdded ?? .distantFuture) }
    }

    private var forecastCandidates: [DeviceRecord] {
        let now = Date.now
        let horizon = Calendar(identifier: .gregorian).date(byAdding: .month, value: forecastWindow.rawValue, to: now) ?? now
        return store.devices.filter { device in
            guard policy.label(for: device) == "Within lifecycle window",
                  let target = policy.target(for: device) else { return false }
            return target > now && target <= horizon
        }.sorted { ($0.dateAdded ?? .distantFuture) < ($1.dateAdded ?? .distantFuture) }
    }

    private var upcomingCandidates: [DeviceRecord] {
        let now = Date.now
        let horizon = Calendar(identifier: .gregorian).date(byAdding: .year, value: 1, to: now) ?? now
        return store.devices.filter { device in
            guard policy.label(for: device) == "Within lifecycle window",
                  let target = policy.target(for: device) else { return false }
            return target > now && target <= horizon
        }.sorted { ($0.dateAdded ?? .distantFuture) < ($1.dateAdded ?? .distantFuture) }
    }

    private func overdueCount(minimumMonths: Int) -> Int {
        let cutoff = Calendar(identifier: .gregorian).date(byAdding: .month, value: -minimumMonths, to: .now) ?? .now
        return reviewCandidates.filter { device in
            guard let target = policy.target(for: device) else { return false }
            return target <= cutoff
        }.count
    }

    private func exportPlanningQueue() {
        let queue = reviewCandidates + forecastCandidates
        exportCSV(queue, suggestedName: "replacement-planning-queue-\(forecastWindow.rawValue)-months.csv")
    }

    private func exportPlanningSummary() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let content = [
            "Inventory Intelligence CE — Replacement Planning Summary",
            "Generated: \(formatter.string(from: .now))",
            "Source: \(store.sourceName)",
            "Imported devices: \(store.devices.count)",
            "Review now: \(reviewCandidates.count)",
            "Estimated review budget USD: \(String(format: "%.2f", reviewCandidates.reduce(0) { $0 + policy.cost(for: $1.model) }))",
            "Default lifecycle years: \(policy.defaultYears)",
            "Overdue 24+ months: \(overdueCount(minimumMonths: 24))",
            "Overdue 12–23 months: \(overdueCount(minimumMonths: 12) - overdueCount(minimumMonths: 24))",
            "Overdue under 12 months: \(reviewCandidates.count - overdueCount(minimumMonths: 12))",
            "Forecast horizon: \(forecastWindow.rawValue) months",
            "Approaching threshold: \(forecastCandidates.count)",
            "Unknown reference dates: \(missingDateCount)",
            "Missing assignments: \(missingUserCount)",
            "Important: Planning estimates use unverified imported dates, not purchase verification, warranty eligibility, or replacement approval."
        ].joined(separator: "\n") + "\n"
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "replacement-planning-summary.txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try content.write(to: url, atomically: true, encoding: .utf8) }
        catch { exportError = "Could not export planning summary: \(error.localizedDescription)" }
    }

    private var planningView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Planning estimates use imported reference dates and configured lifecycle policies; they are not verified purchase dates, warranty eligibility, or replacement approvals.")
                .font(.callout).foregroundStyle(.secondary)
            if hasImportedSource {
                Text(inventorySummary).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text("Planning window").font(.headline)
                    Picker("Forecast horizon", selection: $forecastWindow) {
                        ForEach(ForecastWindow.allCases) { option in Text(option.title).tag(option) }
                    }.pickerStyle(.segmented).frame(maxWidth: 420)
                }
                HStack(spacing: 12) {
                    reportMetric("Review now", reviewCandidates.count, .orange, filter: .review)
                    planningMetric("Next \(forecastWindow.rawValue) months", forecastCandidates.count, .blue)
                    reportMetric("Unknown date", analyticsCount(.unknown), .gray, filter: .unknown)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Replacement intelligence").font(.headline)
                    Text("Prioritize devices already beyond the planning threshold, then review devices approaching it. Dates are unverified CSV reference dates.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        planningMetric("Overdue 24+ months", overdueCount(minimumMonths: 24), .orange)
                        planningMetric("Overdue 12–23 months", overdueCount(minimumMonths: 12) - overdueCount(minimumMonths: 24), .orange)
                        planningMetric("Overdue under 12 months", reviewCandidates.count - overdueCount(minimumMonths: 12), .orange)
                    }
                    HStack {
                        Text("Planning summary · review now: \(reviewCandidates.count) · next \(forecastWindow.rawValue) months: \(forecastCandidates.count) · missing dates: \(missingDateCount)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Export Planning Summary") { exportPlanningSummary() }
                        Button("Export Planning Queue") { exportPlanningQueue() }
                            .disabled(reviewCandidates.isEmpty && forecastCandidates.isEmpty)
                    }
                }
                .padding(18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                feedbackPanel("Planning horizon", detail: "Review now includes devices at or beyond its configured lifecycle threshold. The selected forecast horizon identifies devices expected to reach their configured lifecycle threshold within that period. Unknown dates require source data review.", symbol: "calendar.badge.clock", tint: .blue)
                HStack {
                    Text("Replacement review candidates").font(.headline)
                    Spacer()
                    Button { exportCSV(reviewCandidates, suggestedName: "replacement-review.csv") } label: {
                        Label("Export Candidates", systemImage: "square.and.arrow.up")
                    }.disabled(reviewCandidates.isEmpty)
                }
                pagedDeviceRows(reviewCandidates, page: $planningReviewPage, emptyTitle: "No devices require review", emptyDetail: "No imported devices currently exceed the configured lifecycle window.")
                HStack {
                    Text("Approaching review · next \(forecastWindow.rawValue) months").font(.headline)
                    Spacer()
                    Button { exportCSV(forecastCandidates, suggestedName: "upcoming-\(forecastWindow.rawValue)-months.csv") } label: {
                        Label("Export Upcoming", systemImage: "square.and.arrow.up")
                    }.disabled(forecastCandidates.isEmpty)
                }
                pagedDeviceRows(forecastCandidates, page: $planningUpcomingPage, emptyTitle: "No upcoming candidates", emptyDetail: "No devices are expected to reach the configured lifecycle threshold in the selected forecast horizon.")
            } else {
                feedbackPanel("Import inventory to plan replacements", detail: "Load a local CSV to review lifecycle candidates and export planning reports.", symbol: "doc.badge.plus", tint: .blue)
            }
        }
    }

    private func planningMetric(_ title: String, _ count: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(count)").font(.title2.bold()).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // Increment 5: Office Open XML workbook, created locally without third-party packages.
    // This is a new export path; the validated CSV exporter is left intact.
    private func exportExcel() {
        guard !reportRows.isEmpty else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "inventory-intelligence-report.xlsx"
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")!]
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        exportProgress = "Preparing Excel workbook…"
        let rows = reportRows
        let source = store.sourceName
        let columns = ExportColumn.allCases.filter { includedColumns.contains($0) }
        let now = Date()
        let quality = store.devices.filter { $0.dateAdded == nil || $0.assignedUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let review = store.devices.filter { policy.label(for: $0) == "Review replacement" }
        let all = store.devices
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        func values(_ record: DeviceRecord, _ selected: [ExportColumn]) -> [String] {
            let target = policy.target(for: record)
            let fields: [ExportColumn: String] = [
                .serial: record.serial, .model: record.model, .user: record.assignedUser,
                .reference: record.dateAdded.map { formatter.string(from: $0) } ?? "",
                .status: policy.label(for: record, asOf: now),
                .target: target.map { formatter.string(from: $0) } ?? "",
                .source: source
            ]
            return selected.map { fields[$0] ?? "" }
        }
        let sheets: [(String, [[String]])] = [
            ("Report Results", [columns.map(\.rawValue)] + rows.map { values($0, columns) }),
            ("Full Inventory", [ExportColumn.allCases.map(\.rawValue)] + all.map { values($0, ExportColumn.allCases) }),
            ("Replacement Review", [ExportColumn.allCases.map(\.rawValue)] + review.map { values($0, ExportColumn.allCases) }),
            ("Data Quality", [["Serial", "Model", "Assigned User", "Missing Date", "Missing Assignment", "Source"]] + quality.map { [ $0.serial, $0.model, $0.assignedUser, $0.dateAdded == nil ? "Yes" : "No", $0.assignedUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Yes" : "No", source ] }),
            ("Lifecycle Policy", [["Model", "Lifecycle Years", "Estimated Cost USD"]] + Array(Set(all.map(\.model))).sorted().map { [$0, String(policy.years(for: $0)), String(format: "%.2f", policy.cost(for: $0))] }),
            ("Summary", [ ["Metric", "Value"], ["Source", source], ["Inventory records", "\(all.count)"], ["Filtered records", "\(rows.count)"], ["Replacement review", "\(review.count)"], ["Missing reference date", "\(all.filter { $0.dateAdded == nil }.count)"], ["Missing assignment", "\(all.filter { $0.assignedUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count)"], ["Complete records", "\(all.count - quality.count)"], ["Default lifecycle years", "\(policy.defaultYears)"], ["Estimated review budget USD", String(format: "%.2f", review.reduce(0) { $0 + policy.cost(for: $1.model) })], ["Reference dates", "Imported, not verified purchase dates"] ])
        ]
        do {
            try CEWorkbookWriter.write(sheets: sheets, to: destination)
            reportNotice = "Exported Excel workbook with \(rows.count.formatted()) filtered records and \(sheets.count) worksheets"
        } catch { exportError = "Excel export failed: \(error.localizedDescription)" }
        exportProgress = ""
    }

    private func exportQualityCSV() {
        let rows = store.devices.filter { $0.dateAdded == nil || $0.assignedUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !rows.isEmpty else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "inventory-data-quality.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        func escape(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var lines = ["Serial,Model,Assigned User,Missing Reference Date,Missing Assignment,CSV Source"]
        for device in rows {
            let values = [device.serial, device.model, device.assignedUser, device.dateAdded == nil ? "Yes" : "No", device.assignedUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Yes" : "No", store.sourceName]
            lines.append(values.map(escape).joined(separator: ","))
        }
        do {
            try (lines.joined(separator: "\r\n") + "\r\n").write(to: url, atomically: true, encoding: .utf8)
            reportNotice = "Exported \(rows.count.formatted()) data-quality records"
        } catch { exportError = "Data-quality export failed: \(error.localizedDescription)" }
    }

    private func exportCSV(_ devices: [DeviceRecord], suggestedName: String) {
        guard !devices.isEmpty else { return }
        exportProgress = "Preparing \(devices.count.formatted()) records for export…"
        defer { exportProgress = "" }
        func escape(_ value: String) -> String {
            "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let columns = ExportColumn.allCases.filter { includedColumns.contains($0) }
        var lines = [columns.map { escape($0.rawValue) }.joined(separator: ",")]
        for device in devices {
            let target = policy.target(for: device)
            let fields: [ExportColumn: String] = [
                .serial: device.serial, .model: device.model, .user: device.assignedUser,
                .reference: device.dateAdded.map { dateFormatter.string(from: $0) } ?? "",
                .status: policy.label(for: device),
                .target: target.map { dateFormatter.string(from: $0) } ?? "",
                .source: store.sourceName
            ]
            lines.append(columns.map { escape(fields[$0] ?? "") }.joined(separator: ","))
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try (lines.joined(separator: "\r\n") + "\r\n").write(to: url, atomically: true, encoding: .utf8)
            reportNotice = "Exported \(devices.count.formatted()) records to \(url.lastPathComponent)"
        } catch {
            exportError = "Could not export the report: \(error.localizedDescription)"
        }
    }

    // Stage 3 uses the existing lifecycle labels; no date calculations or providers are changed.
    private func analyticsCount(_ filter: ReportFilter) -> Int {
        store.devices.filter { device in
            switch filter {
            case .all: return true
            case .review: return policy.label(for: device) == "Review replacement"
            case .withinWindow: return policy.label(for: device) == "Within lifecycle window"
            case .unknown: return policy.label(for: device) == "Unknown"
            }
        }.count
    }

    // Stage 8 Increment 2: read-only analytics derived from existing imported records.
    // No changes to the CSV parser, normalized model, or lifecycle classification.
    private var modelDistribution: [(name: String, count: Int)] {
        let groups = Dictionary(grouping: store.devices) { device in
            let name = device.model.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? "Unspecified model" : name
        }
        return groups.map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count == $1.count ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : $0.count > $1.count }
    }

    private var analyticsQualityView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inventory data quality").font(.headline)
            Text("Completeness checks use imported values; they do not verify source accuracy.")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                analyticsQualityCard("Missing reference date", missingDateCount, symbol: "calendar.badge.exclamationmark") {
                    reportPreset = .missing; qualityScope = .missingDate; reportFilter = .unknown; reportSearch = ""; reportModel = "All models"; reportOnlyAssigned = false; reportOnlyDated = false; screen = .reports
                }
                analyticsQualityCard("Missing assignment", missingUserCount, symbol: "person.crop.circle.badge.questionmark") {
                    reportPreset = .missing; qualityScope = .missingUser; reportFilter = .all; reportSearch = ""; reportModel = "All models"; reportOnlyAssigned = false; reportOnlyDated = false; screen = .reports
                }
                analyticsQualityCard("Complete records", store.devices.filter { $0.dateAdded != nil && !$0.assignedUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count, symbol: "checkmark.circle") {
                    reportPreset = .all; qualityScope = .complete; reportFilter = .all; reportSearch = ""; reportModel = "All models"; reportOnlyAssigned = true; reportOnlyDated = true; screen = .reports
                }
            }
            Text("Data-quality drilldowns now open the exact matching records. Use the Data quality picker to switch between missing dates, missing assignments, and complete records.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func analyticsQualityCard(_ title: String, _ count: Int, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
                Text(count.formatted()).font(.title2.bold())
                Text("View records →").font(.caption).foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }

    private var analyticsModelsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Device model distribution").font(.headline)
                Spacer()
                Text("\(modelDistribution.count) models").font(.caption).foregroundStyle(.secondary)
            }
            Text("Select a model to inspect matching devices in Inventory Reports.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(Array(modelDistribution.prefix(analyticsModelLimit)), id: \.name) { item in
                Button {
                    reportPreset = .all; reportFilter = .all; reportSearch = ""; reportModel = item.name
                    reportOnlyAssigned = false; reportOnlyDated = false; screen = .reports
                } label: {
                    HStack(spacing: 12) {
                        Text(item.name).lineLimit(1).frame(width: 190, alignment: .leading)
                        GeometryReader { geometry in
                            Capsule().fill(Color.blue.opacity(0.12))
                                .overlay(alignment: .leading) {
                                    Capsule().fill(Color.blue.opacity(0.70))
                                        .frame(width: geometry.size.width * CGFloat(item.count) / CGFloat(max(store.devices.count, 1)))
                                }
                        }.frame(height: 11)
                        Text("\(item.count) · \(Int(Double(item.count) / Double(max(store.devices.count, 1)) * 100))%")
                            .monospacedDigit().frame(width: 82, alignment: .trailing)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }.font(.subheadline).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            if modelDistribution.count > analyticsModelLimit {
                Button("Show all models") { analyticsModelLimit = modelDistribution.count }
                    .font(.caption)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var analyticsPlanningView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Replacement planning outlook").font(.headline)
                Spacer()
                Button("Open Replacement Planning") { screen = .planning }
            }
            Text("Forecast counts are estimates based on imported dates, not verified replacement eligibility.")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(ForecastWindow.allCases) { window in
                    let now = Date.now
                    let horizon = Calendar(identifier: .gregorian).date(byAdding: .month, value: window.rawValue, to: now) ?? now
                    let count = store.devices.filter { device in
                        guard policy.label(for: device) == "Within lifecycle window",
                              let target = policy.target(for: device) else { return false }
                        return target > now && target <= horizon
                    }.count
                    Button {
                        forecastWindow = window
                        screen = .planning
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Next \(window.rawValue) months").font(.caption).foregroundStyle(.secondary)
                            Text(count.formatted()).font(.title2.bold()).foregroundStyle(.blue)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var analyticsOverview: some View {
        HStack(spacing: 12) {
            reportMetric("Total", analyticsCount(.all), .blue, filter: .all)
            reportMetric("Review", analyticsCount(.review), .orange, filter: .review)
            reportMetric("Within window", analyticsCount(.withinWindow), .green, filter: .withinWindow)
            reportMetric("Unknown", analyticsCount(.unknown), .secondary, filter: .unknown)
        }
    }

    private var analyticsBreakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Lifecycle distribution").font(.headline)
            Text("Select a category to open its devices in Inventory Reports.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach([ReportFilter.review, .withinWindow, .unknown]) { filter in
                let count = analyticsCount(filter)
                let tint: Color = filter == .review ? .orange : (filter == .withinWindow ? .green : .gray)
                Button { selectReportFilter(filter) } label: {
                    HStack(spacing: 12) {
                        Text(filter.rawValue).frame(width: 165, alignment: .leading)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(tint.opacity(0.10))
                                Capsule().fill(tint.opacity(0.75))
                                    .frame(width: geometry.size.width * CGFloat(count) / CGFloat(max(store.devices.count, 1)))
                            }
                        }
                        .frame(height: 12)
                        Text("\(count) · \(Int(Double(count) / Double(max(store.devices.count, 1)) * 100))%")
                            .monospacedDigit().frame(width: 74, alignment: .trailing)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open \(filter.rawValue) devices in Inventory Reports")
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.07)))
    }

    private func selectReportFilter(_ filter: ReportFilter) {
        reportFilter = filter
        reportSearch = ""
        screen = .reports
    }

    private func dashboardMetric(_ title: String, _ value: String, _ icon: String, _ tint: Color, filter: ReportFilter) -> some View {
        Button { selectReportFilter(filter) } label: {
            tile(title, value, icon, tint)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .help("Show \(filter.rawValue.lowercased()) in Inventory Reports")
        .accessibilityLabel("Show \(title) devices in Inventory Reports")
    }

    private func reportMetric(_ title: String, _ count: Int, _ tint: Color, filter: ReportFilter) -> some View {
        Button { selectReportFilter(filter) } label: {
            reportMetricContent(title, count, tint, selected: reportFilter == filter)
        }
        .buttonStyle(.plain)
        .help("Filter report: \(filter.rawValue)")
        .accessibilityLabel("Filter report to \(title), \(count) devices")
        .accessibilityAddTraits(reportFilter == filter ? .isSelected : [])
    }

    private func reportMetricContent(_ title: String, _ count: Int, _ tint: Color, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            Text(count.formatted()).font(.title2.weight(.semibold)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? tint.opacity(0.65) : .primary.opacity(0.07), lineWidth: selected ? 2 : 1))
    }

    private func feedbackPanel(_ title: String, detail: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(tint).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tint.opacity(0.15)))
    }

    private func tile(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tint)
            Text(value).font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.07)))
    }

    // Presentation-only pagination: filter and sort the full dataset before slicing.
    // Exports continue to use the complete matching result, never just the visible page.
    private func pagedDeviceRows(_ rows: [DeviceRecord], page: Binding<Int>, emptyTitle: String,
                                 emptyDetail: String = "Adjust the filters or search to find devices.") -> some View {
        let totalPages = max(1, (rows.count + pageSize - 1) / pageSize)
        let safePage = min(max(0, page.wrappedValue), totalPages - 1)
        let start = safePage * pageSize
        let visible = Array(rows.dropFirst(start).prefix(pageSize))
        return VStack(alignment: .leading, spacing: 12) {
            if !rows.isEmpty {
                HStack {
                    Text("Showing \(start + 1)–\(start + visible.count) of \(rows.count.formatted()) devices")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Picker("Rows", selection: $pageSize) {
                        Text("25").tag(25); Text("50").tag(50); Text("100").tag(100)
                    }.frame(width: 115)
                    Button("Previous") { page.wrappedValue = max(0, safePage - 1) }
                        .disabled(safePage == 0)
                    Text("Page \(safePage + 1) of \(totalPages)").font(.caption).monospacedDigit()
                    Button("Next") { page.wrappedValue = min(totalPages - 1, safePage + 1) }
                        .disabled(safePage >= totalPages - 1)
                }
            }
            deviceRows(visible, emptyTitle: emptyTitle, emptyDetail: emptyDetail)
        }
    }

    // A content-sized grid avoids the empty filler rows drawn by macOS Table in a tall viewport.
    // This changes presentation only; inventory and lifecycle logic remain in the frozen core.
    private func deviceRows(_ rows: [DeviceRecord], emptyTitle: String = "No inventory to display",
                            emptyDetail: String = "Import a CSV with Serial and Model columns.") -> some View {
        Group {
            if rows.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: "tray", description: Text(emptyDetail))
                    .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 18) {
                        columnHeader("Serial").frame(maxWidth: .infinity, alignment: .leading)
                        columnHeader("Model").frame(maxWidth: .infinity, alignment: .leading)
                        columnHeader("Assigned User").frame(maxWidth: .infinity, alignment: .leading)
                        columnHeader("Lifecycle").frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(rows) { device in
                        Divider()
                        HStack(spacing: 18) {
                            Button {
                                selectedDevice = device
                            } label: {
                                HStack(spacing: 6) {
                                    Text(device.serial).fontWeight(.medium)
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .help("View details for \(device.serial)")
                            .accessibilityLabel("View details for serial \(device.serial)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text(device.model).frame(maxWidth: .infinity, alignment: .leading)
                            Text(device.assignedUser.isEmpty ? "—" : device.assignedUser)
                                .foregroundStyle(device.assignedUser.isEmpty ? Color.secondary : Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            lifecycleBadge(device).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 11)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.07)))
            }
        }
    }

    private func columnHeader(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.bottom, 10)
    }

    private func lifecycleBadge(_ device: DeviceRecord) -> some View {
        let label = policy.label(for: device)
        let tint: Color = label == "Review replacement" ? .orange : (label == "Unknown" ? .secondary : .green)
        return Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

extension Notification.Name {
    static let ceImportCSV = Notification.Name("ce.importCSV")
    static let ceExportCSV = Notification.Name("ce.exportCSV")
    static let ceExportExcel = Notification.Name("ce.exportExcel")
    static let ceExportQuality = Notification.Name("ce.exportQuality")
    static let ceExportPlanning = Notification.Name("ce.exportPlanning")
    static let ceShowHelp = Notification.Name("ce.showHelp")
}

private struct CEHelpWindow: View {
    @Environment(\.dismiss) private var dismiss

    private var helpText: String {
        guard let url = Bundle.main.url(forResource: "HELP", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "# Help unavailable\nSee Docs/HELP.md in the source repository."
        }
        return text
    }

    private var lines: [String] {
        helpText.components(separatedBy: .newlines)
    }

    @ViewBuilder
    private func helpLine(_ raw: String) -> some View {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty {
            Spacer().frame(height: 8)
        } else if line.hasPrefix("### ") {
            Text(String(line.dropFirst(4)))
                .font(.headline)
                .padding(.top, 10)
        } else if line.hasPrefix("## ") {
            Text(String(line.dropFirst(3)))
                .font(.title3.weight(.semibold))
                .padding(.top, 16)
        } else if line.hasPrefix("# ") {
            Text(String(line.dropFirst(2)))
                .font(.title2.bold())
                .padding(.top, 8)
        } else if line.hasPrefix("- ") {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("•").foregroundStyle(.secondary)
                Text(.init(String(line.dropFirst(2))))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text(.init(line))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.tint)
                    .font(.title2)
                Text("Inventory Intelligence CE Help")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        helpLine(line)
                    }
                }
                .textSelection(.enabled)
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 700, idealWidth: 850, minHeight: 520, idealHeight: 720)
    }
}

@main struct InventoryIntelligenceCommunityApp: App {
    private func dispatch(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }
    private func openReadmeInBrowser() {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "CERepositoryReadmeURL") as? String,
           let url = URL(string: urlString),
           ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
            NSWorkspace.shared.open(url)
        } else if let local = Bundle.main.url(forResource: "README", withExtension: "html") {
            NSWorkspace.shared.open(local)
        }
    }
    var body: some Scene {
        WindowGroup { ContentView() }
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("Import Inventory CSV…") { dispatch(.ceImportCSV) }
                        .keyboardShortcut("o", modifiers: .command)
                }
                CommandGroup(after: .newItem) {
                    Menu("Export") {
                        Button("Filtered Inventory CSV…") { dispatch(.ceExportCSV) }
                        Button("Excel Workbook…") { dispatch(.ceExportExcel) }
                        Divider()
                        Button("Data Quality CSV…") { dispatch(.ceExportQuality) }
                        Button("Replacement Review CSV…") { dispatch(.ceExportPlanning) }
                    }
                }
                CommandGroup(replacing: .help) {
                    Button("Inventory Intelligence Help") { dispatch(.ceShowHelp) }
                        .keyboardShortcut("?", modifiers: .command)
                    Divider()
                    Button("View README in Web Browser") { openReadmeInBrowser() }
                }
            }
    }
}


// UI Refinement 4, Stage 1: read-only presentation of existing normalized fields.
// No changes to DeviceRecord, Lifecycle, InventoryStore, or CSVParser.
private struct DeviceDetailsSheet: View {
    let device: DeviceRecord
    let sourceName: String
    let policy: PlanningPolicy
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var status: String { policy.label(for: device) }
    private var statusColor: Color {
        status == "Review replacement" ? .orange : (status == "Unknown" ? .secondary : .green)
    }
    private var dateDescription: String {
        guard let date = device.dateAdded else { return "Not provided in the imported CSV" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    private var explanation: String {
        switch status {
        case "Review replacement":
            return "The imported reference date has reached its configured lifecycle threshold. Review this device for possible replacement; this is a planning indicator, not a confirmed eligibility decision."
        case "Within lifecycle window":
            return "The imported reference date has not reached its configured lifecycle threshold. The device is within the configured lifecycle window."
        default:
            return "A usable reference date was not provided. The app cannot estimate a lifecycle status for this device."
        }
    }

    private var estimatedDate: String {
        guard let target = policy.target(for: device) else { return "Unavailable — reference date missing" }
        return target.formatted(date: .abbreviated, time: .omitted)
    }
    private var planningContext: String {
        guard let target = policy.target(for: device) else { return "Cannot forecast without a date" }
        if target <= .now { return "Threshold reached — review recommended" }
        let months = max(0, Calendar(identifier: .gregorian).dateComponents([.month], from: .now, to: target).month ?? 0)
        return "Approximately \(months) months until configured lifecycle threshold"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Device Details").font(.title2.bold())
                    Text(device.model.isEmpty ? "Model unavailable" : device.model)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                Text("Device Information").font(.headline)
                detailLine("Serial Number", value: device.serial)
                detailLine("Model", value: device.model.isEmpty ? "Not provided" : device.model)
                detailLine("Assigned User", value: device.assignedUser.isEmpty ? "Not provided" : device.assignedUser)
                detailLine("Imported Reference Date", value: dateDescription)
                detailLine("CSV Source", value: sourceName)
                if !device.hardware.processor.isEmpty || !device.hardware.memoryGB.isEmpty || !device.hardware.storageGB.isEmpty || !device.hardware.osVersion.isEmpty || !device.hardware.enrollmentStatus.isEmpty || !device.hardware.managementPlatform.isEmpty || !device.hardware.lastInventoryUpdate.isEmpty || !device.hardware.assetTag.isEmpty {
                    Divider()
                    Text("Hardware & Management").font(.headline)
                    if !device.hardware.processor.isEmpty { detailLine("Processor", value: device.hardware.processor) }
                    if !device.hardware.memoryGB.isEmpty { detailLine("Memory (GB)", value: device.hardware.memoryGB) }
                    if !device.hardware.storageGB.isEmpty { detailLine("Storage (GB)", value: device.hardware.storageGB) }
                    if !device.hardware.osVersion.isEmpty { detailLine("OS version", value: device.hardware.osVersion) }
                    if !device.hardware.enrollmentStatus.isEmpty { detailLine("Enrollment", value: device.hardware.enrollmentStatus) }
                    if !device.hardware.managementPlatform.isEmpty { detailLine("Management", value: device.hardware.managementPlatform) }
                    if !device.hardware.lastInventoryUpdate.isEmpty { detailLine("Last inventory update", value: device.hardware.lastInventoryUpdate) }
                    if !device.hardware.assetTag.isEmpty { detailLine("Asset tag", value: device.hardware.assetTag) }
                }
                Divider()
                Text("Data Quality").font(.headline)
                detailLine("Reference Date Quality", value: device.dateAdded == nil ? "Missing — investigate source" : "Present (unverified)")
                detailLine("Assignment Quality", value: device.assignedUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Missing — investigate source" : "Present")
                Divider()
                Text("Replacement Planning").font(.headline)
                detailLine("Estimated Replacement Date", value: estimatedDate)
                detailLine("Planning Context", value: planningContext)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text("Lifecycle Assessment").font(.headline)
                Spacer()
                Text(status).font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }
            Text(explanation).font(.callout).fixedSize(horizontal: false, vertical: true)
            Text("Reference dates are imported inventory values, not verified purchase dates. No warranty or MDM information is retrieved.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(device.serial, forType: .string)
                    copied = true
                } label: {
                    Label(copied ? "Serial Copied" : "Copy Serial Number", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                Spacer()
            }
        }
        .padding(28)
        .frame(width: 560)
    }

    private func detailLine(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label).foregroundStyle(.secondary).frame(width: 175, alignment: .leading)
            Text(value).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
    }
}

// Minimal standards-compliant XLSX package writer. Spreadsheet values are written as
// inline strings to preserve serial numbers and avoid external dependencies.
private enum CEWorkbookWriter {
    static func xml(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .filter { $0 == "\t" || $0 == "\n" || $0 == "\r" || $0.unicodeScalars.allSatisfy { $0.value >= 32 } }
    }
    static func column(_ index: Int) -> String {
        var value = index + 1
        var result = ""
        while value > 0 { value -= 1; result = String(UnicodeScalar(65 + value % 26)!) + result; value /= 26 }
        return result
    }
    static func write(sheets: [(String, [[String]])], to destination: URL) throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ce-xlsx-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let rels = root.appendingPathComponent("_rels", isDirectory: true)
        let xl = root.appendingPathComponent("xl", isDirectory: true)
        let xlRels = xl.appendingPathComponent("_rels", isDirectory: true)
        let worksheets = xl.appendingPathComponent("worksheets", isDirectory: true)
        for folder in [rels, xlRels, worksheets] { try fm.createDirectory(at: folder, withIntermediateDirectories: true) }
        func put(_ path: URL, _ content: String) throws { try content.write(to: path, atomically: true, encoding: .utf8) }
        let header = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        let ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
        for (index, sheet) in sheets.enumerated() {
            var content = header + "<worksheet xmlns=\"\(ns)\"><sheetData>"
            content.reserveCapacity(max(4096, sheet.1.count * 260))
            for (rowIndex, row) in sheet.1.enumerated() {
                content += "<row r=\"\(rowIndex + 1)\">"
                for (colIndex, value) in row.enumerated() {
                    let address = "\(column(colIndex))\(rowIndex + 1)"
                    content += "<c r=\"\(address)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xml(value))</t></is></c>"
                }
                content += "</row>"
            }
            content += "</sheetData></worksheet>"
            try put(worksheets.appendingPathComponent("sheet\(index + 1).xml"), content)
        }
        let types = header + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" + sheets.indices.map { "<Override PartName=\"/xl/worksheets/sheet\($0 + 1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" }.joined() + "</Types>"
        try put(root.appendingPathComponent("[Content_Types].xml"), types)
        try put(rels.appendingPathComponent(".rels"), header + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>")
        let workbook = header + "<workbook xmlns=\"\(ns)\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets>" + sheets.enumerated().map { "<sheet name=\"\(xml($0.element.0))\" sheetId=\"\($0.offset + 1)\" r:id=\"rId\($0.offset + 1)\"/>" }.joined() + "</sheets></workbook>"
        try put(xl.appendingPathComponent("workbook.xml"), workbook)
        let workbookRels = header + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" + sheets.indices.map { "<Relationship Id=\"rId\($0 + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\($0 + 1).xml\"/>" }.joined() + "</Relationships>"
        try put(xlRels.appendingPathComponent("workbook.xml.rels"), workbookRels)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--norsrc", ".", destination.path]
        process.currentDirectoryURL = root
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw NSError(domain: "CEWorkbookWriter", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Could not create XLSX archive"]) }
    }
}

// Increment 6: additive, provider-neutral intelligence and configurable planning.
// Increment 7: this policy is authoritative for all lifecycle classifications and exports.
private struct PlanningPolicy: Codable {
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

private struct PlanningIntelligenceView: View {
    let devices: [DeviceRecord]
    let sourceName: String
    @Binding var policy: PlanningPolicy
    @State private var notice = ""
    private var models: [String] { Array(Set(devices.map(\.model))).sorted() }
    private func due(_ months: Int, asOf now: Date = .now) -> [DeviceRecord] {
        let cutoff = Calendar(identifier: .gregorian).date(byAdding: .month, value: months, to: now) ?? now
        return devices.filter { device in
            guard let target = policy.target(for: device) else { return false }
            return target <= cutoff
        }
    }
    private func budget(_ records: [DeviceRecord]) -> Double { records.reduce(0) { $0 + policy.cost(for: $1.model) } }
    private func csv(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
    private func exportPlanning() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "community-replacement-budget.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = "yyyy-MM-dd"
        var lines = ["Serial,Model,Assigned User,Reference Date,Policy Years,Replacement Target,Estimated Cost USD,Enrollment Status,Management Platform,Last Inventory Update,Asset Tag"]
        for device in devices {
            let fields = [device.serial, device.model, device.assignedUser,
                          device.dateAdded.map { df.string(from: $0) } ?? "",
                          String(policy.years(for: device.model)),
                          policy.target(for: device).map { df.string(from: $0) } ?? "",
                          String(format: "%.2f", policy.cost(for: device.model)),
                          device.hardware.enrollmentStatus, device.hardware.managementPlatform,
                          device.hardware.lastInventoryUpdate, device.hardware.assetTag]
            lines.append(fields.map(csv).joined(separator: ","))
        }
        do {
            try (lines.joined(separator: "\r\n") + "\r\n").write(to: url, atomically: true, encoding: .utf8)
            notice = "Exported \(devices.count) records. Estimates are illustrative; unknown dates have no target."
        } catch { notice = "Export failed: \(error.localizedDescription)" }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Configurable lifecycle & budget planning").font(.title2.bold())
            Text("Shared lifecycle policies apply to Dashboard, Analytics, Replacement Planning, Device Details, CSV and Excel exports.")
                .foregroundStyle(.secondary)
            HStack {
                Stepper("Default lifecycle: \(policy.defaultYears) years", value: $policy.defaultYears, in: 1...12)
                Spacer()
                TextField("Default replacement cost (USD)", value: $policy.defaultCost, format: .number.precision(.fractionLength(2)))
                    .frame(width: 220)
            }
            .onChange(of: policy.defaultYears) { _, _ in policy.save() }
            .onChange(of: policy.defaultCost) { _, _ in policy.save() }
            Text("Model-specific policies").font(.headline)
            ForEach(models, id: \.self) { model in
                HStack {
                    Text(model).frame(maxWidth: .infinity, alignment: .leading)
                    Stepper("\(policy.years(for: model)) years", value: Binding(
                        get: { policy.years(for: model) },
                        set: { policy.overrides[model] = $0; policy.save() }
                    ), in: 1...12).frame(width: 165)
                    TextField("Estimated USD", value: Binding(
                        get: { policy.cost(for: model) },
                        set: { policy.modelCosts[model] = max(0, $0); policy.save() }
                    ), format: .number.precision(.fractionLength(2))).frame(width: 135)
                    Button("Reset") { policy.overrides.removeValue(forKey: model); policy.modelCosts.removeValue(forKey: model); policy.save() }
                }
            }
            Divider()
            Text("Cumulative replacement forecast").font(.headline)
            Text("Includes overdue devices in every forecast window; values are estimates, not approved budgets.")
                .foregroundStyle(.secondary)
            ForEach([0, 6, 12, 18, 24], id: \.self) { months in
                let records = due(months)
                HStack {
                    Text(months == 0 ? "Overdue / due now" : "Due within \(months) months")
                    Spacer()
                    Text("\(records.count) devices")
                    Text(budget(records), format: .currency(code: "USD"))
                        .frame(width: 155, alignment: .trailing)
                }
            }
            let unknown = devices.filter { policy.target(for: $0) == nil }.count
            Text("\(unknown) devices have no usable reference date and are excluded from forecasts.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Export Budget CSV") { exportPlanning() }.disabled(devices.isEmpty)
                if !notice.isEmpty { Text(notice).font(.caption).foregroundStyle(.secondary) }
            }
            Text("Inventory source: \(sourceName). Imported dates are planning references, not verified purchase dates.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
    }
}
