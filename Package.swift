// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LanguageToolLogic",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LanguageToolLogic", targets: ["LanguageToolLogic"])
    ],
    targets: [
        .target(
            name: "LanguageToolLogic",
            path: "LanguageTool/Utilities",
            exclude: [
                "ARBFileHandler.swift",
                "ElectronLocalizationHandler.swift",
                "KeychainService.swift",
                "LanguagePrompt.swift",
                "LocalizationJSONGenerator.swift",
                "NotificationManager.swift",
                "LocalizationManager.swift",
                "JsonUtils.swift",
                "LocalizationConversionService.swift",
                "StringsFileParser.swift"
            ],
            sources: [
                "BatchTranslationParser.swift",
                "XCStringsParser.swift",
                "GlossaryStore.swift"
            ]
        ),
        .testTarget(
            name: "LanguageToolLogicTests",
            dependencies: ["LanguageToolLogic"],
            path: "Tests/LanguageToolLogicTests"
        )
    ]
)
