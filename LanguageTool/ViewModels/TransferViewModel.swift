import SwiftUI
import AppKit
import UniformTypeIdentifiers

class TransferViewModel: ObservableObject {
    @Published var inputPath = "No file selected"
    @Published var outputPath = "No save location selected"
    @Published var isInputSelected: Bool = false
    @Published var isOutputSelected: Bool = false
    @Published var conversionResult: String = ""
    @Published var showResult: Bool = false
    @Published var selectedLanguages: Set<Language> = [Language.supportedLanguages[0]]
    @Published var isLoading: Bool = false
    @Published var showSuccessActions: Bool = false
    @Published var outputFormat: LocalizationFormat = .xcstrings
    @Published var selectedPlatform: PlatformType = .iOS
    @Published var languageChanged = false
    
    func selectInputFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        // 根据选择的平台设置允许的文件类型
        switch selectedPlatform {
        case .electron:
            panel.allowedContentTypes = [.json]
            panel.allowsOtherFileTypes = false
            
        case .iOS:
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
                if self.selectedPlatform == .electron {
                    let fileExtension = fileURL.pathExtension.lowercased()
                    guard fileExtension == "json" else {
                        self.showErrorAlert(message: "必须选择 .json 文件")
                        return
                    }
                }
                
                self.inputPath = fileURL.path
                self.isInputSelected = true
                
                // 根据选择的平台设置输出格式
                switch self.selectedPlatform {
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
    
    func selectOutputPath() {
        switch outputFormat {
        case .electron, .arb, .strings:
            selectDirectory()
        case .xcstrings:
            selectXCStringsFile()
        }
    }
    
    private func selectDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select directory for output files".localized
        openPanel.prompt = "Select".localized
        openPanel.title = "Select Save Directory".localized
        
        openPanel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let directoryURL = openPanel.url {
                self.outputPath = directoryURL.path
                self.isOutputSelected = true
            }
        }
    }
    
    private func selectXCStringsFile() {
        let panel = NSSavePanel()
        if let xcstringsType = UTType(filenameExtension: "xcstrings") {
            panel.allowedContentTypes = [xcstringsType]
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        panel.nameFieldStringValue = "Localizable_\(timestamp)"
        panel.canCreateDirectories = true
        panel.title = "Save Localization File".localized
        panel.message = "Select location to save .xcstrings file".localized
        
        panel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let fileURL = panel.url {
                self.outputPath = fileURL.path
                self.isOutputSelected = true
            }
        }
    }
    
    func convertToLocalization() {
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
    
    func handleDroppedFile(_ providers: [NSItemProvider]) -> Bool {
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
                
                switch self.selectedPlatform {
                case .iOS:
                    isValidFile = ["strings", "xcstrings"].contains(fileExtension)
                case .flutter:
                    isValidFile = fileExtension == "arb"
                case .electron:
                    isValidFile = fileExtension == "json"
                }
                
                if !isValidFile {
                    DispatchQueue.main.async {
                        self.showErrorAlert(message: "Invalid file type for selected platform".localized)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.inputPath = url.path
                    self.isInputSelected = true
                    
                    // 根据选择的平台设置输出格式
                    switch self.selectedPlatform {
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
    
    func resetAll() {
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
    
    func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "错误".localized
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定".localized)
        alert.runModal()
    }
    
    func openInFinder() {
        NSWorkspace.shared.selectFile(outputPath, inFileViewerRootedAtPath: "")
    }
} 