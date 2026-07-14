import Foundation

struct HealthSample: Identifiable, Codable {
    let id: UUID
    let metric: Metric
    let value: Double
    let unit: String
    let date: Date
    let source: String
    init(metric: Metric, value: Double, unit: String, date: Date, source: String = "Apple Health") { id = UUID(); self.metric = metric; self.value = value; self.unit = unit; self.date = date; self.source = source }
}

enum Metric: String, Codable, CaseIterable { case heartRate, restingHeartRate, hrv, steps, sleep, respiratoryRate, walkingSpeed, vo2Max
    var title: String { rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized }
    var symbol: String { switch self { case .heartRate,.restingHeartRate: return "heart.fill"; case .steps: return "figure.walk"; case .sleep: return "moon.fill"; case .hrv: return "waveform.path.ecg"; default: return "chart.line.uptrend.xyaxis" } }
}

struct Insight: Identifiable { let id = UUID(); let metric: Metric; let current: Double; let baseline: Double; let change: Double; let confidence: String
    var headline: String { "\(metric.title) changed \(change >= 0 ? "+" : "")\(change, specifier: "%.1f")% from baseline" }
}

@MainActor final class ClinicalStore: ObservableObject {
    @Published var samples: [HealthSample] = []
    @Published var importName: String?
    @Published var isAnalyzing = false
    @Published var error: String?
    var hasData: Bool { !samples.isEmpty }
    var insights: [Insight] { TrendAnalyzer.insights(samples) }
    func importXML(url: URL) async { isAnalyzing = true; error = nil; defer { isAnalyzing = false }; do { samples = try await Task.detached { try HealthXMLParser().parse(url: url) }.value; importName = url.lastPathComponent } catch { error = error.localizedDescription } }
    func requestHealthKit() async { do { samples = try await HealthKitManager().readSamples(); importName = "Apple HealthKit" } catch { error = error.localizedDescription } }
}
