import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Parrot")
                        .font(.largeTitle.bold())

                    Text(AppLocalization.string("content.foundation_ready"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle("Parrot")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
