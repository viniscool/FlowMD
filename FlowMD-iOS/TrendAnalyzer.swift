import Foundation

enum TrendAnalyzer {
    static func insights(_ samples: [HealthSample]) -> [Insight] {
        guard let latest = samples.map(\.date).max() else { return [] }; let recentStart = Calendar.current.date(byAdding: .day, value: -30, to: latest)!; let priorStart = Calendar.current.date(byAdding: .day, value: -60, to: latest)!
        return Metric.allCases.compactMap { metric in
            let recent = samples.filter { $0.metric == metric && $0.date >= recentStart }.map(\.value); let prior = samples.filter { $0.metric == metric && $0.date >= priorStart && $0.date < recentStart }.map(\.value); guard !recent.isEmpty, !prior.isEmpty else { return nil }; let r = recent.reduce(0,+)/Double(recent.count), p = prior.reduce(0,+)/Double(prior.count); guard p != 0 else { return nil }; let change = (r-p)/p*100; return abs(change) >= 8 ? Insight(metric: metric, current: r, baseline: p, change: change, confidence: abs(change) >= 15 ? "High" : "Medium") : nil
        }.sorted { abs($0.change) > abs($1.change) }
    }
    static func average(_ samples: [HealthSample], metric: Metric) -> Double? { let values = samples.filter { $0.metric == metric }.map(\.value); guard !values.isEmpty else { return nil }; return values.reduce(0,+)/Double(values.count) }
}
