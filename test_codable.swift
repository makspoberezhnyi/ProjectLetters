import Foundation

struct Old: Codable {
    var title: String
}

struct New: Codable {
    var title: String
    var columnWidths: [CGFloat]?
}

let old = Old(title: "Hello")
let data = try! JSONEncoder().encode(old)
if let new = try? JSONDecoder().decode(New.self, from: data) {
    print("Success: \(new)")
} else {
    print("Failure")
}
