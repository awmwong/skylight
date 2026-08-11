import SwiftUI

/// Menu bar section listing saved region presets. Recall and delete act on
/// presets already loaded from RegionStore. Saving the current region needs
/// a live share session to know what "current" means, so that entry stays
/// disabled until a currentRegionProvider is supplied.
struct PresetsMenuSection: View {
    let presets: [RegionPreset]
    let onRecall: (RegionPreset) -> Void
    let onDelete: (RegionPreset) -> Void
    let currentRegionProvider: (() -> Region?)?
    let onSaveCurrentRegion: (Region) -> Void

    var body: some View {
        Section("Presets") {
            if presets.isEmpty {
                Text("No saved presets")
            }
            ForEach(presets, id: \.name) { preset in
                Menu(preset.name) {
                    Button("Recall") { onRecall(preset) }
                    Button("Delete") { onDelete(preset) }
                }
            }
            Button("Save Current Region…") {
                guard let region = currentRegionProvider?() else { return }
                onSaveCurrentRegion(region)
            }
            .disabled(currentRegionProvider == nil)
        }
    }
}
