import SwiftUI

struct TestView: View {
    @Binding var num: Int
    
    var body: some View {
        Button("Test") {
            let oldNum = num
            let binding = _num
            let closure = {
                binding.wrappedValue = oldNum
            }
            closure()
        }
    }
}
