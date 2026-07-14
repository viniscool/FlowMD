import Foundation

/// Local-only bridge for a future iPhone MCP server. The app never sends HealthKit data to a remote service.
actor LocalMCPClient {
    struct Request: Codable { let method: String; let params: [String:String] }
    struct Response: Codable { let result: String?; let error: String? }
    private let endpoint: URL
    init(endpoint: URL = URL(string: "http://127.0.0.1:8787/mcp")!) { self.endpoint = endpoint }
    func ask(_ prompt: String) async -> String? { var request=URLRequest(url:endpoint); request.httpMethod="POST"; request.setValue("application/json",forHTTPHeaderField:"Content-Type"); request.httpBody=try? JSONEncoder().encode(Request(method:"insight",params:["prompt":prompt])); guard let (data,_) = try? await URLSession.shared.data(for:request) else { return nil }; return try? JSONDecoder().decode(Response.self,from:data).result }
}
