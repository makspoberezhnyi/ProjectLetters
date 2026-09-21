import Foundation

let selectionRange = NSRange(location: 0, length: 100)
let slice = NSRange(location: 0, length: 50)
let intersection = NSIntersectionRange(selectionRange, slice)
print("Intersection: \(intersection)")

let slice2 = NSRange(location: 50, length: 50)
let intersection2 = NSIntersectionRange(selectionRange, slice2)
print("Intersection2: \(intersection2)")
