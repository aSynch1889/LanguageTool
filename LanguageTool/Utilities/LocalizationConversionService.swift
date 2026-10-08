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
        let parsedItems = await TranslationManager.shared.parseInputFileOrEmpty(at: inputPath, platform: selectedPlatform)
        let fileExtension = (inputPath as NSString).pathExtension.lowercased()
        let result: (message: String, success: Bool)

        do {
            try Task.checkCancellation()
        } catch {
            return ConversionExecutionResult(
                translationItems: parsedItems,
                message: "Conversion cancelled",
                success: false
            )
        }

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
                    if error is CancellationError {
                        result = (message: "Conversion cancelled", success: false)
                    } else {
                        result = (message: "Conversion failed: \(error.localizedDescription)", success: false)
                    }
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
                result = (message: "Unsupported file format", success: false)
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
                result = (message: "Conversion failed: \(error.localizedDescription)", success: false)
            }
        case .electron:
            guard fileExtension == "json" else {
                return ConversionExecutionResult(
                    translationItems: parsedItems,
                    message: "Electron platform only supports .json files",
                    success: false
                )
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
                result = (message: "Conversion failed: \(error.localizedDescription)", success: false)
            }
        }

        return ConversionExecutionResult(translationItems: parsedItems, message: result.message, success: result.success)
    }
}
