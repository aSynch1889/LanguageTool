import Foundation

struct ConversionExecutionResult: Sendable {
    let translationItems: [TranslationItem]
    let message: String
    let success: Bool
}

enum LocalizationConversionService {
    static func execute(
        inputPath: String,
        outputPath: String,
        selectedPlatform: PlatformType,
        outputFormat: LocalizationFormat,
        languageCodes: [String],
        skipExistingTranslations: Bool
    ) async -> ConversionExecutionResult {
        let parsedItems = await TranslationManager.shared.parseInputFile(at: inputPath, platform: selectedPlatform)
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
                    languages: Set(languageCodes.compactMap { code in
                        Language.supportedLanguages.first(where: { $0.code == code })
                    }),
                    skipExistingTranslations: skipExistingTranslations
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
                    languages: languageCodes,
                    skipExistingTranslations: skipExistingTranslations
                )
                result = (message: conversionResult.message, success: conversionResult.success)
            default:
                result = (message: "❌ 不支持的文件格式", success: false)
            }
        case .flutter:
            let processResult = await ARBFileHandler.processARBFile(
                from: inputPath,
                to: outputPath,
                languages: languageCodes,
                skipExistingTranslations: skipExistingTranslations
            )
            switch processResult {
            case .success(let message):
                result = (message: message, success: true)
            case .failure(let error):
                result = (message: "❌ 转换失败：\(error.localizedDescription)", success: false)
            }
        case .electron:
            guard fileExtension == "json" else {
                result = (message: "❌ Electron 平台仅支持 .json 文件", success: false)
                return ConversionExecutionResult(translationItems: parsedItems, message: result.message, success: result.success)
            }
            let processResult = await ElectronLocalizationHandler.processLocalizationFile(
                from: inputPath,
                to: outputPath,
                languages: languageCodes,
                skipExistingTranslations: skipExistingTranslations
            )
            switch processResult {
            case .success(let message):
                result = (message: message, success: true)
            case .failure(let error):
                result = (message: "❌ 转换失败：\(error.localizedDescription)", success: false)
            }
        }

        return ConversionExecutionResult(translationItems: parsedItems, message: result.message, success: result.success)
    }
}
