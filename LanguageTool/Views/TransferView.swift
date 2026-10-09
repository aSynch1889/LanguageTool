import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TransferView: View {
    @EnvironmentObject private var shell: AppShellViewModel
    @Environment(\.colorScheme) private var colorScheme
    /// Owned by `AppShellView` so Convert ↔ Review does not wipe input/output paths.
    @ObservedObject var viewModel: TransferViewModel

    // Language selection state
    @State private var searchText = ""
    @State private var selectedCategory: LanguageCategory = .all
    
    private let columns = [
        GridItem(.adaptive(minimum: 160))
    ]

    // Computed properties for language filtering
    private var filteredLanguages: [Language] {
        let categoryFiltered = Language.languagesForCategory(selectedCategory)
        let searchFiltered = searchText.isEmpty ? categoryFiltered : Language.searchLanguages(searchText).filter { categoryFiltered.contains($0) }
        return searchFiltered
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        platformSelectionCard
                        fileSelectionCard
                        languageSelectionCard

                        if viewModel.showResult {
                            resultsCard
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .animation(.easeInOut(duration: 0.4), value: viewModel.showResult)
                        }
                    }
                    .padding()
                    .frame(maxWidth: 800)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: viewModel.isLoading ? 3 : 0)

                // Always visible: skip-existing + primary conversion actions.
                conversionActionBar
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)

            if viewModel.isLoading {
                loadingView
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
            }
        }
        .allowsHitTesting(!viewModel.isLoading)
        .id(viewModel.languageChanged)
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            viewModel.languageChanged.toggle()
        }
        .onChange(of: viewModel.showSuccessActions) { wasShowing, show in
            // Only react to false → true; ignore remounts that still hold a previous true.
            guard show, !wasShowing else { return }
            Task { @MainActor in
                guard let request = viewModel.makeReviewRequest(preferOutput: true) else { return }
                shell.requestReview(request)
            }
        }
    }

    /// Pinned footer so Start Conversion is discoverable without scrolling.
    private var conversionActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Skip Existing Translations".localized, isOn: $viewModel.skipExistingTranslations)
                        .toggleStyle(.checkbox)
                        .help("When enabled, only missing translations will be generated. Existing translations will be preserved.".localized)

                    Text("When enabled, only missing translations will be generated. Existing translations will be preserved.".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 320, alignment: .leading)

                Spacer(minLength: 8)

                HStack(spacing: 10) {
                    Button(action: viewModel.resetAll) {
                        Label("Reset".localized, systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLoading)

                    Button {
                        openInReview(preferOutput: false)
                    } label: {
                        Label("Open in Review".localized, systemImage: "tablecells")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLoading || !viewModel.isInputSelected)

                    if viewModel.isLoading {
                        Button(action: viewModel.cancelConversion) {
                            Label("Cancel".localized, systemImage: "stop.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                    } else {
                        Button(action: viewModel.convertToLocalization) {
                            Label("Start Conversion".localized, systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!viewModel.isInputSelected || !viewModel.isOutputSelected || viewModel.selectedLanguages.isEmpty)
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(ThemeSurface.card(for: colorScheme))
        }
    }

    private func openInReview(preferOutput: Bool) {
        guard let request = viewModel.makeReviewRequest(preferOutput: preferOutput) else { return }
        shell.requestReview(request)
    }
    
    private var platformSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Select Platform".localized, systemImage: "apps.iphone")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Picker(
                "Platform".localized,
                selection: Binding(
                    get: { viewModel.selectedPlatform },
                    set: { newValue in
                        guard newValue != viewModel.selectedPlatform else { return }
                        // Defer: Picker mutates during view updates; resetAll publishes many fields.
                        Task { @MainActor in
                            viewModel.selectPlatform(newValue)
                        }
                    }
                )
            ) {
                ForEach(PlatformType.allCases, id: \.self) { platform in
                    Text(platform.description)
                        .tag(platform)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
        .cardStyle()
    }
    
    private var fileSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("File Selection".localized, systemImage: "doc.badge.plus")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(alignment: .center, spacing: 16) {
                ModernFileSelector(
                    title: "Choose Input File".localized,
                    subtitle: "Input File".localized,
                    selectedPath: viewModel.isInputSelected ? viewModel.inputPath : nil,
                    isSelected: viewModel.isInputSelected,
                    onSelect: viewModel.selectInputFile,
                    onDrop: viewModel.handleDroppedFile
                )

                ModernFileSelector(
                    title: "Choose Output Location".localized,
                    subtitle: "Output Location".localized,
                    selectedPath: viewModel.isOutputSelected ? viewModel.outputPath : nil,
                    isSelected: viewModel.isOutputSelected,
                    onSelect: viewModel.selectOutputPath,
                    onDrop: { _ in false }
                )
            }

            // File info summary
            if viewModel.isInputSelected || viewModel.isOutputSelected {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    HStack {
                        Text("Selected Files".localized)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        if viewModel.isInputSelected && viewModel.isOutputSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if viewModel.isInputSelected {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(.blue)
                                    .font(.caption2)

                                Text("Input: %@".localizedFormat(URL(fileURLWithPath: viewModel.inputPath).lastPathComponent))
                                    .font(.caption)
                                    .foregroundStyle(.primary)

                                Spacer()
                            }
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                        }

                        if viewModel.isOutputSelected {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption2)

                                Text("Output: %@".localizedFormat(URL(fileURLWithPath: viewModel.outputPath).lastPathComponent))
                                    .font(.caption)
                                    .foregroundStyle(.primary)

                                Spacer()
                            }
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.3), value: viewModel.isInputSelected)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isOutputSelected)
            }
        }
        .cardStyle()
    }
    
    private var languageSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Select Target Languages".localized, systemImage: "globe")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("%lld selected".localizedFormat(viewModel.selectedLanguages.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Search and filter controls
            VStack(spacing: 8) {
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.caption)

                        TextField("Search languages...".localized, text: $searchText)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    // Trigger re-filtering
                                }
                            }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(ThemeSurface.inset(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))

                    Menu {
                        ForEach(LanguageCategory.allCases, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                                searchText = "" // Clear search when changing category
                            }) {
                                HStack {
                                    Text(category.displayName)
                                    if selectedCategory == category {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label(selectedCategory.displayName, systemImage: "line.3.horizontal.decrease.circle")
                            .font(.subheadline)
                    }
                    .menuStyle(.borderedButton)
                    .fixedSize()
                }

                // Quick action buttons
                HStack(spacing: 8) {
                    Button(action: selectAllFiltered) {
                        Label("Select All".localized, systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)

                    Button(action: clearAllFiltered) {
                        Label("Clear All".localized, systemImage: "xmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)

                    Button(action: selectCommonLanguages) {
                        Label("Common".localized, systemImage: "star.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)

                    Spacer()

                    if !searchText.isEmpty || selectedCategory != .all {
                        Text("%lld shown".localizedFormat(filteredLanguages.count))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
            }

            // Language grid with virtualization
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(filteredLanguages) { language in
                        ModernLanguageCard(
                            language: language,
                            isSelected: viewModel.selectedLanguages.contains(language)
                        )
                        .onTapGesture {
                            toggleLanguage(language)
                        }
                        .id(language.code) // Stable identity for view reuse
                    }
                }
                .padding(.horizontal, 4)
                .animation(.easeInOut(duration: 0.3), value: filteredLanguages.count)
            }
            .frame(height: 250)
            .background(ThemeSurface.inset(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
        }
        .cardStyle()
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                "Conversion Results".localized,
                systemImage: viewModel.lastConversionSucceeded ? "checkmark.circle" : "xmark.circle"
            )
                .font(.headline.weight(.semibold))
                .foregroundStyle(viewModel.lastConversionSucceeded ? .green : .red)

            Text(viewModel.conversionResult)
                .font(.body)
                .foregroundStyle(viewModel.lastConversionSucceeded ? .green : .red)

            if viewModel.showSuccessActions {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Output Location".localized)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)

                        Text(URL(fileURLWithPath: viewModel.outputPath).lastPathComponent)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: viewModel.openInFinder) {
                            Label("Show in Finder".localized, systemImage: "folder")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            openInReview(preferOutput: true)
                        } label: {
                            Label("View in Review".localized, systemImage: "tablecells")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)

                        Button(action: viewModel.syncToSource) {
                            Label("Sync to Source".localized, systemImage: "arrow.triangle.2.circlepath")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)

                        Button(action: viewModel.exportToCSV) {
                            Label("Export CSV".localized, systemImage: "arrow.down.doc")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(ThemeSurface.inset(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .cardStyle()
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)

            VStack(spacing: 4) {
                Text("Translating...".localized)
                    .font(.headline.weight(.medium))

                Text("This may take a few minutes depending on the number of languages selected".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(ThemeSurface.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 20, y: 5)
    }

    // MARK: - Language Selection Helper Methods
    private func selectAllFiltered() {
        viewModel.selectedLanguages.formUnion(filteredLanguages)
    }

    private func clearAllFiltered() {
        let filteredSet = Set(filteredLanguages)
        viewModel.selectedLanguages.subtract(filteredSet)
        // Ensure at least one language remains selected
        if viewModel.selectedLanguages.isEmpty {
            viewModel.selectedLanguages.insert(Language.supportedLanguages[0])
        }
    }

    private func selectCommonLanguages() {
        viewModel.selectedLanguages = Set(Language.commonLanguages)
    }

    private func toggleLanguage(_ language: Language) {
        if viewModel.selectedLanguages.contains(language) {
            if viewModel.selectedLanguages.count > 1 {
                viewModel.selectedLanguages.remove(language)
            }
        } else {
            viewModel.selectedLanguages.insert(language)
        }
    }
}


// 自定义按钮样式
// MARK: - Modern File Selector
struct ModernFileSelector: View {
    let title: String
    let subtitle: String
    let selectedPath: String?
    let isSelected: Bool
    let onSelect: () -> Void
    let onDrop: ([NSItemProvider]) -> Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Button(action: onSelect) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.dashed")
                        .foregroundStyle(isSelected ? .green : .blue)
                        .font(.title2)
                        .animation(.easeInOut(duration: 0.2), value: isSelected)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isSelected ? "File Selected".localized : title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        if let path = selectedPath, isSelected {
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Click to browse or drag & drop files here".localized)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    if !isSelected {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .background(ThemeSurface.inset(for: colorScheme), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? .green.opacity(0.3) : .blue.opacity(0.3), lineWidth: 1.5)
                        .opacity(isSelected ? 1 : 0.5)
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                )
            }
            .buttonStyle(.plain)
        }
        .onDrop(of: [.fileURL], isTargeted: nil, perform: onDrop)
    }
}

// MARK: - Modern Language Card
struct ModernLanguageCard: View {
    let language: Language
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .blue : .secondary)
                .font(.system(size: 16))
                .animation(.easeInOut(duration: 0.2), value: isSelected)

            VStack(alignment: .leading, spacing: 1) {
                Text(language.localizedName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(language.code.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? .blue.opacity(0.1) : .clear)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? .blue : Color.clear, lineWidth: 1)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Card Style ViewModifier
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ThemeSurface.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.05), radius: 2, y: 1)
    }
}

extension View {
    func cardStyle() -> some View {
        self.modifier(CardStyle())
    }
}

struct DragDropButtonStyle: ButtonStyle {
    let isSelected: Bool
    let useDefaultStyle: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        style: StrokeStyle(
                            lineWidth: 2,
                            dash: [5]
                        )
                    )
                    .foregroundColor(isSelected ? .blue : .gray)
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.gray.opacity(0.1) : Color.clear)
            )
    }
}
