import Foundation

final class HealthXMLParser: NSObject, XMLParserDelegate {
    private var output: [HealthSample] = []
    private let date = DateFormatter()
    private let map: [String: Metric] = [
        "HKQuantityTypeIdentifierHeartRate": .heartRate,
        "HKQuantityTypeIdentifierRestingHeartRate": .restingHeartRate,
        "HKQuantityTypeIdentifierHeartRateVariabilitySDNN": .hrv,
        "HKQuantityTypeIdentifierStepCount": .steps,
        "HKQuantityTypeIdentifierSleepAnalysis": .sleep,
        "HKQuantityTypeIdentifierRespiratoryRate": .respiratoryRate,
        "HKQuantityTypeIdentifierWalkingSpeed": .walkingSpeed,
        "HKQuantityTypeIdentifierVO2Max": .vo2Max
    ]
    override init() { date.locale = Locale(identifier: "en_US_POSIX"); date.dateFormat = "yyyy-MM-dd HH:mm:ss Z"; super.init() }
    func parse(url: URL) throws -> [HealthSample] { guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }; defer { url.stopAccessingSecurityScopedResource() }; let parser = XMLParser(contentsOf: url); parser?.delegate = self; guard parser?.parse() == true else { throw parser?.parserError ?? CocoaError(.fileReadCorruptFile) }; return output }
    func parser(_ parser: XMLParser, didStartElement name: String, attributes: [String : String] = [:]) { guard name == "Record", let metric = map[attributes["type"] ?? ""], let value = Double(attributes["value"] ?? ""), let date = date.date(from: attributes["startDate"] ?? "") else { return }; output.append(HealthSample(metric: metric, value: value, unit: attributes["unit"] ?? "", date: date, source: attributes["sourceName"] ?? "Apple Health")) }
}
