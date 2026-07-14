import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: ClinicalStore
    @State private var tab = 0
    @State private var showImporter = false
    var body: some View {
        TabView(selection: $tab) {
            DashboardView(showImporter: $showImporter).tabItem { Label("Overview", systemImage: "square.grid.2x2") }.tag(0)
            InsightsView().tabItem { Label("Insights", systemImage: "sparkles") }.tag(1)
            PatientView().tabItem { Label("Patient", systemImage: "person.crop.circle") }.tag(2)
            SettingsView(showImporter: $showImporter).tabItem { Label("Import", systemImage: "arrow.up.doc") }.tag(3)
        }.tint(Color(red: 0.28, green: 0.58, blue: 0.48))
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.xml]) { result in
                if case .success(let urls) = result, let url = urls.first { Task { await store.importXML(url: url) } }
            }
    }
}

struct DashboardView: View {
    @EnvironmentObject var store: ClinicalStore
    @Binding var showImporter: Bool
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text("CLINICAL WORKSPACE").font(.caption).tracking(1.5).foregroundStyle(.secondary)
            Text("Good morning, Doctor").font(.largeTitle.bold())
            HStack { Stat(title: "Records", value: store.hasData ? store.samples.count.formatted() : "—", icon: "waveform.path.ecg"); Stat(title: "Insights", value: "\(store.insights.count)", icon: "sparkles") }
            if store.hasData { SummaryCard(); TrendCard() } else { EmptyState(showImporter: $showImporter) }
        }.padding() }.navigationTitle("FlowMD") }
    }
}

struct Stat: View {
    let title: String; let value: String; let icon: String
    var body: some View { VStack(alignment: .leading) { Image(systemName: icon).foregroundStyle(.green); Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.title2.bold()) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.white, in: .rect(cornerRadius: 14)).shadow(color: .black.opacity(0.05), radius: 8) }
}

struct EmptyState: View { @Binding var showImporter: Bool
    var body: some View { VStack(spacing: 12) { Image(systemName: "heart.text.square").font(.system(size: 42)).foregroundStyle(.green); Text("Connect your health data").font(.title3.bold()); Text("Import an Apple Health XML export or authorize HealthKit on this iPhone.").multilineTextAlignment(.center).foregroundStyle(.secondary); Button("Import Health XML") { showImporter = true }.buttonStyle(.borderedProminent) }.frame(maxWidth: .infinity).padding(32).background(.white, in: .rect(cornerRadius: 18)) }
}

struct SummaryCard: View { @EnvironmentObject var store: ClinicalStore
    var body: some View { VStack(alignment: .leading, spacing: 10) { Label("LIVE ANALYSIS", systemImage: "sparkles").font(.caption.bold()).foregroundStyle(.orange); Text(store.insights.first?.headline ?? "No significant deviation detected").font(.headline); Text("Analysis uses the patient’s own longitudinal baseline and remains on-device.").font(.subheadline).foregroundStyle(.secondary) }.padding().background(.white, in: .rect(cornerRadius: 16)) }
}

struct TrendCard: View { @EnvironmentObject var store: ClinicalStore
    var body: some View { VStack(alignment: .leading) { Text("Signals analyzed").font(.headline); ForEach(Metric.allCases.filter { TrendAnalyzer.average(store.samples, metric: $0) != nil }, id: \.self) { metric in HStack { Image(systemName: metric.symbol).frame(width: 24); Text(metric.title); Spacer(); Text("\(TrendAnalyzer.average(store.samples, metric: metric)!, specifier: "%.1f")").bold() }.padding(.vertical, 6) } }.padding().background(.white, in: .rect(cornerRadius: 16)) }
}

struct InsightsView: View { @EnvironmentObject var store: ClinicalStore
    var body: some View { NavigationStack { List { if store.insights.isEmpty { Text("Import HealthKit data to generate personalized insights.").foregroundStyle(.secondary) }; ForEach(store.insights) { insight in VStack(alignment: .leading) { Label(insight.confidence + " confidence", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(.green); Text(insight.headline).font(.headline); Text("Current \(insight.current, specifier: "%.1f") · Baseline \(insight.baseline, specifier: "%.1f")").font(.caption).foregroundStyle(.secondary) } } }.navigationTitle("Agentic insights") }
    }
}

struct PatientView: View { @EnvironmentObject var store: ClinicalStore
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) { Text("MY HEALTH PROFILE").font(.caption).tracking(1.4).foregroundStyle(.secondary); Text("My Health Profile").font(.largeTitle.bold()); SummaryCard(); ForEach(store.insights.prefix(3)) { insight in HStack { Image(systemName: insight.metric.symbol).foregroundStyle(.green); VStack(alignment: .leading) { Text(insight.metric.title).bold(); Text(insight.headline).font(.caption).foregroundStyle(.secondary) } } } }.padding() }.navigationTitle("Patient") }
    }
}

struct SettingsView: View { @EnvironmentObject var store: ClinicalStore; @Binding var showImporter: Bool
    var body: some View { NavigationStack { Form { Section("Data source") { Button("Import Health XML") { showImporter = true }; Button("Authorize HealthKit") { Task { await store.requestHealthKit() } } }; Section("Privacy") { Text("Health data is processed locally on this iPhone. The optional MCP bridge is localhost-only.").font(.footnote) } }.navigationTitle("Import & Settings") }
    }
}
