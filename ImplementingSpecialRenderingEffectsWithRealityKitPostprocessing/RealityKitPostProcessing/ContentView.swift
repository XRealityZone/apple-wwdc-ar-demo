/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's main SwiftUI view.
*/

import Foundation
import SwiftUI
import RealityKit
import MetalKit
import ARKit

@available(iOS 15.0, *)
struct ContentView: View {
    @State var selection: ApplicationState.ModeEntry? = ApplicationState.shared.noProcessingEntry
    
    var body: some View {
        HStack {
            RealityViewContainer()
                .edgesIgnoringSafeArea(.all)
            List() {
                Section() {
                    SelectionCell(entry: ApplicationState.shared.noProcessingEntry, selectedEntry: self.$selection)
                }
                ForEach(ApplicationState.shared.availableCategories) {entry in
                    Section(entry.category.description) {
                        ForEach(entry.modes) {
                            SelectionCell(entry: $0, selectedEntry: self.$selection)
                        }
                    }
                }
                
            }.frame(width: 300)
        }
    }
}

struct SelectionCell: View {
    let entry: ApplicationState.ModeEntry
    
    @Binding var selectedEntry: ApplicationState.ModeEntry?
    
    var body: some View {
        HStack {
            Text(entry.mode.description)
            Spacer()
            if entry == selectedEntry {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .onTapGesture {
            selectedEntry = entry
            ApplicationState.shared.mode = entry.mode
        }
    }
}

#if DEBUG
@available(iOS 15.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
