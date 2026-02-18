import SwiftTUI

/// Top bar showing the wax branding and search input.
struct HeaderView: View {
    let query: String
    let isSearching: Bool
    let onSearch: (String) -> Void

    var body: some View {
        VStack {
            HStack {
                Text("wax")
                    .bold()
                    .foregroundColor(.yellow)
                Text(" | sift semantic git search")
                    .foregroundColor(.gray)
            }
            HStack {
                Text(isSearching ? "[searching...]" : "[enter query]")
                    .foregroundColor(.gray)
                TextField(placeholder: "search commits...", action: onSearch)
            }
            Divider()
        }
    }
}
