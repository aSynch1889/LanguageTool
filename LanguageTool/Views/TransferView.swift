import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TransferView: View {
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false // 添加暗黑模式存储
    @State private var inputPath = "No file selected"
    @State private var outputPath = "No save location selected"
    @State private var isInputSelected: Bool = false
    @State private var isOutputSelected: Bool = false
    @State private var conversionResult: String = ""
    @State private var showResult: Bool = false
    @State private var selectedLanguages: Set<Language> = [Language.supportedLanguages[0]] // 默认选中简体中文
    @State private var isLoading: Bool = false
    @State private var showSuccessActions: Bool = false
    @State private var outputFormat: LocalizationFormat = .xcstrings
    @State private var selectedPlatform: PlatformType = .iOS
    @State private var languageChanged = false  // 添加语言变更状态
    
    private let columns = [
        GridItem(.adaptive(minimum: 160))
    ]
    
    private func selectInputFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        // 根据选择的平台设置允许的文件类型
        switch selectedPlatform {
        case .electron:
            // 对于 Electron 平台，使用 UTType.json
            panel.allowedContentTypes = [.json]
            panel.allowsOtherFileTypes = false
            
        case .iOS:
            // 使用文件扩展名来识别文件类型
            var allowedTypes: [UTType] = []
            if let xcstringsType = UTType(filenameExtension: "xcstrings") {
                allowedTypes.append(xcstringsType)
            }
            if let stringsType = UTType(filenameExtension: "strings") {
                allowedTypes.append(stringsType)
            }
            panel.allowedContentTypes = allowedTypes
            
        case .flutter:
            if let arbType = UTType(filenameExtension: "arb") {
                panel.allowedContentTypes = [arbType]
            }
        }
        
        // 根据平台设置提示信息
        panel.title = "Select Input File".localized
        switch selectedPlatform {
        case .iOS:
            panel.message = "Please select .strings or .xcstrings file".localized
        case .flutter:
            panel.message = "Please select .arb file".localized
        case .electron:
            panel.message = "Please select .json file".localized
        }
        
        panel.begin { response in
            if response == .OK, let fileURL = panel.url {
                // 关键修复 2: 强制二次验证扩展名
                if selectedPlatform == .electron {
                    let fileExtension = fileURL.pathExtension.lowercased()
                    guard fileExtension == "json" else {
                        showErrorAlert(message: "必须选择 .json 文件")
                        return
                    }
                }
                
                self.inputPath = fileURL.path
                self.isInputSelected = true
                
                // 设置默认输出路径：使用输入文件所在目录 + 之前的文件名
                let inputDirectory = fileURL.deletingLastPathComponent().path
                if self.isOutputSelected {
                    // 如果已经有输出路径，保留文件名但更改目录
                    let currentOutputURL = URL(fileURLWithPath: self.outputPath)
                    let fileName = currentOutputURL.lastPathComponent
                    self.outputPath = (inputDirectory as NSString).appendingPathComponent(fileName)
                } else {
                    // 如果还没有输出路径，生成默认文件名
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                    let timestamp = dateFormatter.string(from: Date())
                    let defaultFileName = "Localizable_\(timestamp)"
                    
                    switch outputFormat {
                    case .xcstrings:
                        self.outputPath = (inputDirectory as NSString).appendingPathComponent("\(defaultFileName).xcstrings")
                    case .strings, .arb, .electron:
                        self.outputPath = inputDirectory
                    }
                }
                self.isOutputSelected = true
                
                // 根据选择的平台设置输出格式
                switch selectedPlatform {
                case .iOS:
                    let fileExtension = fileURL.pathExtension.lowercased()
                    self.outputFormat = fileExtension == "strings" ? .strings : .xcstrings
                case .flutter:
                    self.outputFormat = .arb
                case .electron:
                    self.outputFormat = .electron
                }
            }
        }
    }
    
    private func selectOutputPath() {
        switch outputFormat {
        case .electron:
            // 对于 Electron 格式，使用目录选择面板
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.message = "Select directory for JSON files".localized
            openPanel.prompt = "Select".localized
            openPanel.title = "Select Save Directory".localized
            
            openPanel.treatsFilePackagesAsDirectories = true
            
            openPanel.begin { [self] response in
                if response == .OK, let directoryURL = openPanel.url {
                    self.outputPath = directoryURL.path
                    self.isOutputSelected = true
                }
            }
            
        case .arb:
            // 对于 ARB 格式，使用目录选择面板
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.message = "Select directory for ARB files".localized
            openPanel.prompt = "Select".localized
            openPanel.title = "Select Save Directory".localized
            
            openPanel.treatsFilePackagesAsDirectories = true
            
            openPanel.begin { [self] response in
                if response == .OK, let directoryURL = openPanel.url {
                    self.outputPath = directoryURL.path
                    self.isOutputSelected = true
                }
            }
            
        case .strings:
            // 现有的 .strings 格式处理逻辑
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.message = "Select directory for language files".localized
            openPanel.prompt = "Select".localized
            openPanel.title = "Select Save Directory".localized
            
            // 设置可以访问的目录类型
            openPanel.treatsFilePackagesAsDirectories = true
            
            openPanel.begin { [self] response in
                if response == .OK, let directoryURL = openPanel.url {
                    self.outputPath = directoryURL.path
                    self.isOutputSelected = true
                }
            }
            
        case .xcstrings:
            // 现有的 .xcstrings 格式处理逻辑
            let panel = NSSavePanel()
            if let xcstringsType = UTType(filenameExtension: "xcstrings") {
                panel.allowedContentTypes = [xcstringsType]
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            
            let defaultFileName = "Localizable_\(timestamp)"
            panel.nameFieldStringValue = defaultFileName
            
            panel.canCreateDirectories = true
            panel.title = "Save Localization File".localized
            panel.message = "Select location to save .xcstrings file".localized
            
            panel.begin { [self] response in
                if response == .OK, let fileURL = panel.url {
                    self.outputPath = fileURL.path
                    self.isOutputSelected = true
                }
            }
        }
    }
    
    private func convertToLocalization() {
        Task {
            isLoading = true
            showResult = false
            showSuccessActions = false
            
            let fileExtension = (inputPath as NSString).pathExtension.lowercased()
            let result: (message: String, success: Bool)
            
            switch selectedPlatform {
            case .iOS:
                switch fileExtension {
                case "strings":
                    let processResult = await StringsFileParser.processStringsFile(
                        from: inputPath,
                        to: outputPath,
                        format: outputFormat,
                        languages: selectedLanguages
                    )
                    switch processResult {
                    case .success(let message):
                        result = (message: message, success: true)
                    case .failure(let error):
                        result = (message: "❌ 转换失败：\(error.localizedDescription)", success: false)
                    }
                case "xcstrings":
                    let conversionResult = await JsonUtils.convertToLocalizationFile(
                        from: inputPath,
                        to: outputPath,
                        languages: Array(selectedLanguages).map { $0.code }
                    )
                    result = (message: conversionResult.message, success: conversionResult.success)
                default:
                    result = (message: "❌ 不支持的文件格式", success: false)
                }
                
            case .flutter:
                let processResult = await ARBFileHandler.processARBFile(
                    from: inputPath,
                    to: outputPath,
                    languages: Array(selectedLanguages).map { $0.code }
                )
                switch processResult {
                case .success(let message):
                    result = (message: message, success: true)
                case .failure(let error):
                    result = (message: "❌ 转换失败：\(error.localizedDescription)", success: false)
                }
                
            case .electron:
                // 严格校验输入文件类型
                guard fileExtension == "json" else {
                    result = (message: "❌ Electron 平台仅支持 .json 文件", success: false)
                    break
                }
                let processResult = await ElectronLocalizationHandler.processLocalizationFile(
                    from: inputPath,
                    to: outputPath,
                    languages: Array(selectedLanguages).map { $0.code }
                )
                switch processResult {
                case .success(let message):
                    result = (message: message, success: true)
                case .failure(let error):
                    result = (message: "❌ 转换失败：\(error.localizedDescription)", success: false)
                }
            }
            
            DispatchQueue.main.async {
                self.conversionResult = result.message
                self.showSuccessActions = result.success
                self.isLoading = false
                self.showResult = true
            }
        }
    }
    
    private func openInFinder() {
        NSWorkspace.shared.selectFile(outputPath, inFileViewerRootedAtPath: "")
    }
    
    private func resetAll() {
        withAnimation(.smooth(duration: 0.3)) {
            // 重置文件路径
            inputPath = "No file selected".localized
            outputPath = "No save location selected".localized
            isInputSelected = false
            isOutputSelected = false
            
            // 重置语言选择（只保留简体中文）
            selectedLanguages = [Language.supportedLanguages[0]]
            
            // 重置结果显示
            showResult = false
            conversionResult = ""
            showSuccessActions = false
        }
    }
    
    // MARK: - 新增错误提示方法
    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "文件类型错误".localized
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定".localized)
        alert.runModal()
    }
    
    private func handleDroppedFile(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard error == nil,
                      let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                
                // 验证文件类型
                let fileExtension = url.pathExtension.lowercased()
                var isValidFile = false
                
                switch selectedPlatform {
                case .iOS:
                    isValidFile = ["strings", "xcstrings"].contains(fileExtension)
                case .flutter:
                    isValidFile = fileExtension == "arb"
                case .electron:
                    isValidFile = fileExtension == "json"
                }
                
                if !isValidFile {
                    DispatchQueue.main.async {
                        showErrorAlert(message: "Invalid file type for selected platform".localized)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.inputPath = url.path
                    self.isInputSelected = true
                    
                    // 设置默认输出路径：使用输入文件所在目录 + 之前的文件名
                    let inputDirectory = url.deletingLastPathComponent().path
                    if self.isOutputSelected {
                        // 如果已经有输出路径，保留文件名但更改目录
                        let currentOutputURL = URL(fileURLWithPath: self.outputPath)
                        let fileName = currentOutputURL.lastPathComponent
                        self.outputPath = (inputDirectory as NSString).appendingPathComponent(fileName)
                    } else {
                        // 如果还没有输出路径，生成默认文件名
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                        let timestamp = dateFormatter.string(from: Date())
                        let defaultFileName = "Localizable_\(timestamp)"
                        
                        switch self.outputFormat {
                        case .xcstrings:
                            self.outputPath = (inputDirectory as NSString).appendingPathComponent("\(defaultFileName).xcstrings")
                        case .strings, .arb, .electron:
                            self.outputPath = inputDirectory
                        }
                    }
                    self.isOutputSelected = true
                    
                    // 根据选择的平台设置输出格式
                    switch selectedPlatform {
                    case .iOS:
                        self.outputFormat = fileExtension == "strings" ? .strings : .xcstrings
                    case .flutter:
                        self.outputFormat = .arb
                    case .electron:
                        self.outputFormat = .electron
                    }
                }
            }
            return true
        }
        return false
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 添加平台选择部分
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Select Platform".localized)
                            .font(.headline)
                        
                        Picker("Platform".localized, selection: $selectedPlatform) {
                            ForEach(PlatformType.allCases, id: \.self) { platform in
                                Text(platform.description)
                                    .tag(platform)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedPlatform) { oldValue, newValue in
                            // 切换平台时重置状态
                            resetAll()
                        }
                    }
                    .padding(.bottom, 10)
                    
                    // 文件选择部分
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            DragDropButton(
                                title: "Select Input File".localized,
                                action: selectInputFile,
                                isSelected: isInputSelected,
                                onDrop: handleDroppedFile
                            )
                            
                            Text(inputPath.localized)
                                .foregroundColor(.gray)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            DragDropButton(
                                title: "Select Output Location".localized + " (Optional)".localized,
                                action: selectOutputPath,
                                isSelected: isOutputSelected,
                                onDrop: { _ in false }  // 输出位置不支持拖放
                            )
                            
                            if isOutputSelected {
                                Text(outputPath.localized)
                                    .foregroundColor(.gray)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        
                        // 语言选择部分
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Select Target Languages".localized)
                                    .font(.headline)
                                
                                Spacer()
                                
                                // 添加全选按钮
                                Button(action: {
                                    if selectedLanguages.count == Language.supportedLanguages.count {
                                        // 如果已经全选，则只保留第一个语言
                                        selectedLanguages = [Language.supportedLanguages[0]]
                                    } else {
                                        // 否则全选
                                        selectedLanguages = Set(Language.supportedLanguages)
                                    }
                                }) {
                                    Text(selectedLanguages.count == Language.supportedLanguages.count ? "Deselect All".localized : "Select All".localized)
                                        .font(.subheadline)
                                }
                                .buttonStyle(.borderless)
                            }
                            
                            ScrollView {
                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(Language.supportedLanguages) { language in
                                        LanguageToggle(language: language, isSelected: selectedLanguages.contains(language))
                                            .onTapGesture {
                                                if selectedLanguages.contains(language) {
                                                    if selectedLanguages.count > 1 {
                                                        selectedLanguages.remove(language)
                                                    }
                                                } else {
                                                    selectedLanguages.insert(language)
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
                    .frame(maxWidth: .infinity, alignment: .leading) // 使内容靠左对齐
                    
                    HStack(spacing: 12) {
                        Button("Start Conversion".localized) {
                            convertToLocalization()
                        }
                        .disabled(!isInputSelected || !isOutputSelected || selectedLanguages.isEmpty || isLoading)
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: resetAll) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset".localized)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                    }
                    
                    // 结果显示区域
                    if showResult {
                        VStack(spacing: 12) {
                            Text(conversionResult)
                                .foregroundColor(conversionResult.hasPrefix("✅") ? .green : .red)
                                .font(.system(.body, design: .rounded))
                            
                            if showSuccessActions {
                                VStack(spacing: 8) {
                                    Text("Save Path:".localized)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(outputPath)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(6)
                                    
                                    Button(action: openInFinder) {
                                        HStack {
                                            Image(systemName: "folder")
                                            Text("Show in Finder".localized)
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
                }
                .padding()
                .frame(maxWidth: 600)
            }
            .frame(minHeight: 500)
            .blur(radius: isLoading ? 3 : 0)
            .preferredColorScheme(isDarkMode ? .dark : .light) // 根据 isDarkMode 设置颜色方案
            
            // 加载指示器
            if isLoading {
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
        .allowsHitTesting(!isLoading)
        .id(languageChanged)  // 添加 id 以强制视图刷新
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            // 接收到语言变更通知时，触发视图刷新
            languageChanged.toggle()
        }
    }
}

// 语言选择切换组件
struct LanguageToggle: View {
    let language: Language
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
            VStack(alignment: .leading) {
                Text(language.localizedName)
                    .font(.system(.body, design: .rounded))
                Text(language.code)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// 更新按钮和拖放区域的组合视图
struct DragDropButton: View {
    let title: String
    let action: () -> Void
    let isSelected: Bool
    let onDrop: ([NSItemProvider]) -> Bool
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle()) // 确保整个区域可点击
        }
        .buttonStyle(DragDropButtonStyle(isSelected: isSelected))
        .onDrop(of: [.fileURL], isTargeted: nil, perform: onDrop)
    }
}

// 自定义按钮样式
struct DragDropButtonStyle: ButtonStyle {
    let isSelected: Bool
    
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

