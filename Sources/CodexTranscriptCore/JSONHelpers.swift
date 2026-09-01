import Foundation

typealias JSONObject = [String: Any]

func jsonObject(from data: Data) -> JSONObject? {
    (try? JSONSerialization.jsonObject(with: data)) as? JSONObject
}

func string(_ value: Any?) -> String? {
    if let value = value as? String { return value }
    if let value = value as? NSNumber { return value.stringValue }
    return nil
}

func dictionary(_ value: Any?) -> JSONObject? { value as? JSONObject }
func array(_ value: Any?) -> [Any]? { value as? [Any] }

func prettyJSON(_ value: Any) -> String {
    guard JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
          let text = String(data: data, encoding: .utf8) else {
        return String(describing: value)
    }
    return text
}

func parsePossiblyJSONString(_ value: Any?) -> String {
    guard let raw = string(value) else { return "" }
    guard let data = raw.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data),
          JSONSerialization.isValidJSONObject(obj) else { return raw }
    return prettyJSON(obj)
}

func markdownFence(for text: String, language: String = "text") -> String {
    var ticks = "```"
    while text.contains(ticks) { ticks += "`" }
    return "\(ticks)\(language)\n\(text)\n\(ticks)"
}

func extractMessageText(_ payload: JSONObject) -> String {
    if let message = string(payload["message"]), !message.isEmpty { return message }
    guard let content = array(payload["content"]) else { return "" }
    let pieces = content.compactMap { item -> String? in
        guard let obj = dictionary(item) else { return nil }
        if let text = string(obj["text"]) { return text }
        if let value = string(obj["value"]) { return value }
        if let input = string(obj["input_text"]) { return input }
        if let output = string(obj["output_text"]) { return output }
        return nil
    }
    return pieces.joined(separator: "\n")
}

func parseDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
}

func yamlEscaped(_ value: String) -> String {
    "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n") + "\""
}
