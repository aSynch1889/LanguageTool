import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TransferView: View {
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @StateObject private var viewModel = TransferViewModel()
    
    private let columns = [
        GridItem(.adaptive(minimum: 160))
    ]
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    platformSelectionView
                    fileSelectionView
                    languageSelectionView
                    actionButtonsView
                    
                    if viewModel.showResult {
                        resultsView
                    }
                }
                .padding()
                .frame(maxWidth: 600)
            }
            .frame(minHeight: 500)
            .blur(radius: viewModel.isLoading ? 3 : 0)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            
            if viewModel.isLoading {
                loadingView
            }
        }
        .allowsHitTesting(!viewModel.isLoading)
        .id(viewModel.languageChanged)
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            viewModel.languageChanged.toggle()
        }
    }
    
    private var platformSelectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Platform".localized)
                .font(.headline)
            
            Picker("Platform".localized, selection: $viewModel.selectedPlatform) {
                ForEach(PlatformType.allCases, id: \.self) { platform in
                    Text(platform.description)
                        .tag(platform)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedPlatform) { oldValue, newValue in
                viewModel.resetAll()
            }
        }
        .padding(.bottom, 10)
    }
    
    private var fileSelectionView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                DragDropButton(
                    title: "Select Input File".localized,
                    action: viewModel.selectInputFile,
                    isSelected: viewModel.isInputSelected,
                    onDrop: viewModel.handleDroppedFile,
                    useDefaultStyle: false
                )
                
                Text(viewModel.inputPath.localized)
                    .foregroundColor(.gray)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                DragDropButton(
                    title: "Select Output Location".localized + " (Optional)".localized,
                    action: viewModel.selectOutputPath,
                    isSelected: viewModel.isOutputSelected,
                    onDrop: { _ in false },
                    useDefaultStyle: true
                )
                
                if viewModel.isOutputSelected {
                    Text(viewModel.outputPath.localized)
                        .foregroundColor(.gray)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }
    
    private var languageSelectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Select Target Languages".localized)
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    if viewModel.selectedLanguages.count == Language.supportedLanguages.count {
                        viewModel.selectedLanguages = [Language.supportedLanguages[0]]
                    } else {
                        viewModel.selectedLanguages = Set(Language.supportedLanguages)
                    }
                }) {
                    Text(viewModel.selectedLanguages.count == Language.supportedLanguages.count ? "Deselect All".localized : "Select All".localized)
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
            }
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Language.supportedLanguages) { language in
                        LanguageToggle(
                            language: language,
                            isSelected: viewModel.selectedLanguages.contains(language)
                        )
                        .onTapGesture {
                            if viewModel.selectedLanguages.contains(language) {
                                if viewModel.selectedLanguages.count > 1 {
                                    viewModel.selectedLanguages.remove(language)
                                }
                            } else {
                                viewModel.selectedLanguages.insert(language)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 200)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            Button("Start Conversion".localized) {
                viewModel.convertToLocalization()
            }
            .disabled(!viewModel.isInputSelected || !viewModel.isOutputSelected || viewModel.selectedLanguages.isEmpty || viewModel.isLoading)
            .buttonStyle(.borderedProminent)
            
            Button(action: viewModel.resetAll) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset".localized)
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)
        }
    }
    
    private var resultsView: some View {
        VStack(spacing: 12) {
            Text(viewModel.conversionResult)
                .foregroundColor(viewModel.conversionResult.hasPrefix("✅") ? .green : .red)
                .font(.system(.body, design: .rounded))
            
            if viewModel.showSuccessActions {
                VStack(spacing: 8) {
                    Text("Save Path:".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.outputPath)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    
                    HStack(spacing: 16) {
                        Button(action: viewModel.openInFinder) {
                            HStack {
                                Image(systemName: "folder")
                                Text("Show in Finder".localized)
                            }
                        }
                        
                        Button(action: viewModel.syncToSource) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Sync to Source".localized)
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 4)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .padding(.vertical)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Translating...".localized)
                .font(.headline)
            Text("Please wait, this may take a while".localized)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(30)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(radius: 20)
        }
    }
}


// 自定义按钮样式
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

