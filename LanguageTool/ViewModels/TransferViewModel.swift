import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Foundation

@MainActor
class TransferViewModel: ObservableObject {
    @Published var inputPath = "No file selected"
    @Published var outputPath = "No save location selected"
    @Published var isInputSelected: Bool = false
    @Published var isOutputSelected: Bool = false
    @Published var conversionResult: String = ""
    @Published var showResult: Bool = false
    @Published var selectedLanguages: Set<Language> = [Language.supportedLanguages[0]]
    @Published var isLoading: Bool = false
    @Published var lastConversionSucceeded: Bool = false
    @Published var showSuccessActions: Bool = false
    @Published var outputFormat: LocalizationFormat = .xcstrings
    @Published var selectedPlatform: PlatformType = .iOS
    @Published var languageChanged = false
    @Published var translationItems: [TranslationItem] = []
    @Published var skipExistingTranslations: Bool = true

    private var conversionTask: Task<Void, Never>?

    // 通知管理器
    private let notificationManager = NotificationManager.shared
    
    enum ExportFormat {
        case csv
        
        var fileExtension: String {
            "csv"
        }
        
        var contentType: UTType {
            UTType.commaSeparatedText
        }
    }
    
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
                        self.showAlert(message: "Must select .json file".localized, isError: true)
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
        conversionTask?.cancel()
        conversionTask = Task {
            isLoading = true
            showResult = false
            showSuccessActions = false
            lastConversionSucceeded = false
            translationItems = []

            let inputPath = self.inputPath
            let outputPath = self.outputPath
            let selectedPlatform = self.selectedPlatform
            let outputFormat = self.outputFormat
            let languageCodes = self.selectedLanguages.map(\.code)
            let skipExistingTranslations = self.skipExistingTranslations

            let executionResult = await Task.detached(priority: .userInitiated) {
                await LocalizationConversionService.execute(
                    inputPath: inputPath,
                    outputPath: outputPath,
                    selectedPlatform: selectedPlatform,
                    outputFormat: outputFormat,
                    languageCodes: languageCodes,
                    skipExistingTranslations: skipExistingTranslations
                )
            }.value

            if Task.isCancelled {
                conversionResult = "Conversion cancelled"
                lastConversionSucceeded = false
                showSuccessActions = false
                isLoading = false
                showResult = true
                return
            }

            conversionResult = executionResult.message
            lastConversionSucceeded = executionResult.success
            showSuccessActions = executionResult.success
            translationItems = executionResult.translationItems
            isLoading = false
            showResult = true

            if notificationManager.areNotificationsEnabled {
                if executionResult.success {
                    notificationManager.sendTranslationCompleteNotification(languageCount: selectedLanguages.count)
                } else {
                    notificationManager.sendTranslationFailedNotification(errorMessage: executionResult.message)
                }
            }
        }
    }

    func cancelConversion() {
        conversionTask?.cancel()
        conversionTask = nil
        isLoading = false
        lastConversionSucceeded = false
        showSuccessActions = false
        conversionResult = "Conversion cancelled"
        showResult = true
    }
    
    func handleDroppedFile(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        let selectedPlatform = self.selectedPlatform
        
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
                        self.showAlert(message: "Invalid file type for selected platform".localized, isError: true)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.inputPath = url.path
                    self.isInputSelected = true
                    
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
    
    /// Change platform and clear file/language selection for the new target.
    /// Call from a deferred turn (not inside a Picker/`onChange` view update).
    func selectPlatform(_ platform: PlatformType) {
        if selectedPlatform != platform {
            selectedPlatform = platform
        }
        resetAll()
    }

    func resetAll() {
        let emptyInput = "No file selected".localized
        let emptyOutput = "No save location selected".localized
        if inputPath != emptyInput { inputPath = emptyInput }
        if outputPath != emptyOutput { outputPath = emptyOutput }
        if isInputSelected { isInputSelected = false }
        if isOutputSelected { isOutputSelected = false }

        let defaultLanguages: Set<Language> = [Language.supportedLanguages[0]]
        if selectedLanguages != defaultLanguages {
            selectedLanguages = defaultLanguages
        }

        if showResult { showResult = false }
        if !conversionResult.isEmpty { conversionResult = "" }
        if showSuccessActions { showSuccessActions = false }
        if lastConversionSucceeded { lastConversionSucceeded = false }
        if !skipExistingTranslations { skipExistingTranslations = true }
    }
    
    func showAlert(message: String, isError: Bool = false) {
        let alert = NSAlert()
        alert.messageText = (isError ? "Error" : "Success").localized
        alert.informativeText = message
        alert.alertStyle = isError ? .warning : .informational
        alert.addButton(withTitle: "OK".localized)
        alert.runModal()
    }
    
    func openInFinder() {
        NSWorkspace.shared.selectFile(outputPath, inFileViewerRootedAtPath: "")
    }
    
    func syncToSource() {
        let sourceURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        
        do {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: outputURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                showAlert(message: "Sync failed: output file is invalid".localized, isError: true)
                return
            }

            let tempURL = sourceURL.deletingLastPathComponent().appendingPathComponent("\(sourceURL.lastPathComponent).tmp.\(UUID().uuidString)")
            try FileManager.default.copyItem(at: outputURL, to: tempURL)

            if FileManager.default.fileExists(atPath: sourceURL.path) {
                _ = try FileManager.default.replaceItemAt(
                    sourceURL,
                    withItemAt: tempURL,
                    backupItemName: nil,
                    options: [.usingNewMetadataOnly]
                )
            } else {
                try FileManager.default.moveItem(at: tempURL, to: sourceURL)
            }
            showAlert(message: "Sync completed successfully".localized)
        } catch {
            showAlert(message: "Sync failed: \(error.localizedDescription)".localized, isError: true)
        }
    }
    
    /// Builds a review request for the app shell (input or conversion output).
    func makeReviewRequest(preferOutput: Bool) -> AppShellViewModel.ReviewRequest? {
        let languageCodes = selectedLanguages.map(\.code)
        let path: String?
        if preferOutput, isOutputSelected, isRegularFile(at: outputPath) {
            path = outputPath
        } else if isInputSelected, !inputPath.isEmpty, inputPath != "No file selected" {
            path = inputPath
        } else {
            path = nil
        }

        guard let path else {
            showAlert(message: "Select a localization file first".localized, isError: true)
            return nil
        }

        return AppShellViewModel.ReviewRequest(
            path: path,
            platform: selectedPlatform,
            languageCodes: languageCodes,
            skipExisting: skipExistingTranslations
        )
    }

    private func isRegularFile(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        return !isDirectory.boolValue
    }
    
    func exportToCSV() {
        let format: ExportFormat = .csv
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "translations.\(format.fileExtension)"
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    // 读取本地化文件
                    let jsonData = try Data(contentsOf: URL(fileURLWithPath: self.outputPath))
                    let decoder = JSONDecoder()
                    
                    // 根据文件类型选择不同的解析方式
                    let fileExtension = (self.outputPath as NSString).pathExtension.lowercased()
                    var translations: [String: [String: String]] = [:]
                    
                    if fileExtension == "xcstrings" {
                        // 解析 xcstrings 格式
                        struct XCStringsContainer: Codable {
                            struct StringEntry: Codable {
                                struct LocalizationEntry: Codable {
                                    let stringUnit: StringUnit
                                }
                                let localizations: [String: LocalizationEntry]
                            }
                            struct StringUnit: Codable {
                                let value: String
                            }
                            let strings: [String: StringEntry]
                        }
                        
                        let xcstrings = try decoder.decode(XCStringsContainer.self, from: jsonData)
                        
                        // 转换格式
                        for (key, entry) in xcstrings.strings {
                            var languageValues: [String: String] = [:]
                            for (languageCode, localization) in entry.localizations {
                                languageValues[languageCode] = localization.stringUnit.value
                            }
                            translations[key] = languageValues
                        }
                    } else {
                        // 其他格式直接解析
                        translations = try decoder.decode([String: [String: String]].self, from: jsonData)
                    }
                    
                    // 收集所有有翻译的语言代码
                    var usedLanguageCodes = Set<String>()
                    for (_, values) in translations {
                        for (code, value) in values {
                            if !value.isEmpty {
                                usedLanguageCodes.insert(code)
                            }
                        }
                    }
                    
                    // 将语言代码转换为Language对象，并按照supportedLanguages的顺序排序
                    let usedLanguages = Language.supportedLanguages.filter { usedLanguageCodes.contains($0.code) }
                    
                    var csvContent = "Key,"
                    csvContent += usedLanguages.map { $0.code }.joined(separator: ",")
                    csvContent += "\n"
                    
                    // 添加每一行翻译内容
                    for (key, values) in translations {
                        csvContent += "\(key),"
                        csvContent += usedLanguages.map { language in
                            let value = values[language.code] ?? ""
                            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
                        }.joined(separator: ",")
                        csvContent += "\n"
                    }
                    
                    // 写入文件，使用 UTF-8 BOM 以确保 Excel 正确识别编码
                    let bom = Data([0xEF, 0xBB, 0xBF])
                    let body = Data(csvContent.utf8)
                    try (bom + body).write(to: url, options: .atomic)
                    
                    DispatchQueue.main.async {
                        NSWorkspace.shared.open(url)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.showAlert(message: "Export failed: \(error.localizedDescription)", isError: true)
                    }
                }
            }
        }
    }
    
}
