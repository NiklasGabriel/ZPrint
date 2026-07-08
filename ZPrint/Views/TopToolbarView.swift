import SwiftUI

struct TopToolbarView: View {
    @Binding var mode: MainDocumentMode

    var body: some View {
        HStack {
            Text("ZPrint")
                .font(.headline)

            Spacer()

            Picker("Modus", selection: $mode) {
                ForEach(MainDocumentMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview {
    TopToolbarView(mode: .constant(.editor))
}
