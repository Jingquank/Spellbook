import SpellbookCore
import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(SpellbookModel.self) private var model

    var body: some View {
        @Bindable var model = model

        Form {
            Section("Theme") {
                Picker("Appearance", selection: $model.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }

                Picker("Density", selection: $model.density) {
                    ForEach(InterfaceDensity.allCases) { density in
                        Text(density.label).tag(density)
                    }
                }

                Picker("Interface text", selection: $model.textScale) {
                    ForEach(InterfaceTextScale.allCases) { scale in
                        Text(scale.label).tag(scale)
                    }
                }
            }

            Section("Reader") {
                Picker("Text size", selection: $model.readerTextScale) {
                    ForEach(ReaderTextScale.allCases) { scale in
                        Text(scale.label).tag(scale)
                    }
                }
                Picker("Content width", selection: $model.readerWidth) {
                    ForEach(ReaderWidth.allCases) { width in
                        Text(width.label).tag(width)
                    }
                }
                Toggle("Wrap code blocks", isOn: $model.wrapsCode)
            }

            Section("Library") {
                Toggle("Always show package groups", isOn: $model.alwaysShowsPackageGroups)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
    }
}
