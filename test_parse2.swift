import Foundation

let segmentPattern = #"(?:^|\n)?\[\[(table|image|video|bibliography|toc)(?::([a-zA-Z0-9\-]+))?\]\](?:\n)?"#
let regex = try! NSRegularExpression(pattern: segmentPattern, options: [])

func parseCanvasSegments(for pageContent: String) -> [String] {
    let nsContent = pageContent as NSString
    let matches = regex.matches(in: pageContent, options: [], range: NSRange(location: 0, length: nsContent.length))
    
    var segments: [String] = []
    var lastLocation = 0
    
    for match in matches {
        let matchRange = match.range
        if matchRange.location > lastLocation {
            let textRange = NSRange(location: lastLocation, length: matchRange.location - lastLocation)
            let chunkText = nsContent.substring(with: textRange)
            segments.append("text: " + chunkText)
        }
        
        let kind = nsContent.substring(with: match.range(at: 1))
        let idStr = match.numberOfRanges >= 3 ? nsContent.substring(with: match.range(at: 2)) : ""
        
        if kind == "table" {
            // simulating documentController.tables.contains(...) == false
            // we do nothing!
        }
        
        lastLocation = matchRange.location + matchRange.length
    }
    
    if lastLocation < nsContent.length {
        let textRange = NSRange(location: lastLocation, length: nsContent.length - lastLocation)
        let chunkText = nsContent.substring(with: textRange)
        segments.append("text: " + chunkText)
    }
    
    return segments
}

print(parseCanvasSegments(for: "Hello [[table:00D26499-0DAC-490C-A56A-4A0379F5B613]] World"))
