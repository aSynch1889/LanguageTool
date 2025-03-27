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
    @Published var showSuccessActions: Bool = false
    @Published var outputFormat: LocalizationFormat = .xcstrings
    @Published var selectedPlatform: PlatformType = .iOS
    @Published var languageChanged = false
    
    enum ExportFormat {
        case csv
        case excel
        
        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .excel: return "xlsx"
            }
        }
        
        var contentType: UTType {
            switch self {
            case .csv: return UTType.commaSeparatedText
            case .excel: return UTType.spreadsheet
            }
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
        Task {
            await MainActor.run {
                isLoading = true
                showResult = false
                showSuccessActions = false
            }
            
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
            
            await MainActor.run {
                conversionResult = result.message
                showSuccessActions = result.success
                isLoading = false
                showResult = true
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
                        self.showAlert(message: "Invalid file type for selected platform".localized, isError: true)
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
            try FileManager.default.removeItem(at: sourceURL)
            try FileManager.default.copyItem(at: outputURL, to: sourceURL)
            showAlert(message: "Sync completed successfully".localized)
        } catch {
            showAlert(message: "Sync failed: \(error.localizedDescription)".localized, isError: true)
        }
    }
    
    func exportToExcel() {
        let alert = NSAlert()
        alert.messageText = "Choose Export Format".localized
        alert.informativeText = "Please select the format you want to export to".localized
        alert.addButton(withTitle: "CSV")
        alert.addButton(withTitle: "Excel")
        alert.addButton(withTitle: "Cancel".localized)
        
        let response = alert.runModal()
        guard response != .alertThirdButtonReturn else { return }
        
        let format: ExportFormat = response == .alertFirstButtonReturn ? .csv : .excel
        
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
                    
                    if format == .csv {
                        // 创建 CSV 内容
                        var csvContent = "Key,"
                        csvContent += Language.supportedLanguages.map { $0.code }.joined(separator: ",")
                        csvContent += "\n"
                        
                        // 添加每一行翻译内容
                        for (key, values) in translations {
                            csvContent += "\(key),"
                            csvContent += Language.supportedLanguages.map { language in
                                let value = values[language.code] ?? ""
                                // 处理 CSV 中的特殊字符
                                return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
                            }.joined(separator: ",")
                            csvContent += "\n"
                        }
                        
                        // 写入文件，使用 UTF-8 BOM 以确保 Excel 正确识别编码
                        let bom = Data([0xEF, 0xBB, 0xBF])
                        try bom.write(to: url)
                        try csvContent.data(using: .utf8)?.write(to: url, options: .atomic)
                    } else {
                        // 如果选择了 Excel 格式，我们仍然创建 CSV 但使用 .xlsx 扩展名
                        // Excel 会自动处理打开这种文件
                        var csvContent = "Key,"
                        csvContent += Language.supportedLanguages.map { $0.code }.joined(separator: ",")
                        csvContent += "\n"
                        
                        for (key, values) in translations {
                            csvContent += "\(key),"
                            csvContent += Language.supportedLanguages.map { language in
                                let value = values[language.code] ?? ""
                                return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
                            }.joined(separator: ",")
                            csvContent += "\n"
                        }
                        
                        let bom = Data([0xEF, 0xBB, 0xBF])
                        try bom.write(to: url)
                        try csvContent.data(using: .utf8)?.write(to: url, options: .atomic)
                    }
                    
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
