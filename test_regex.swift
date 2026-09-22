import Foundation
let segmentPattern = #"(?:^|\n)?\[\[(table|image|video|bibliography|toc)(?::([a-zA-Z0-9\-]+))?\]\](?:\n)?"#
let regex = try! NSRegularExpression(pattern: segmentPattern, options: [])
let str = "Hello [[table:00D26499-0DAC-490C-A56A-4A0379F5B613]]"
let matches = regex.matches(in: str, options: [], range: NSRange(location: 0, length: str.utf16.count))
print("Matches: \(matches.count)")
