# Language Tool
[English](README.md) | [中文](README-zh.md)
Language Tool is a macOS application designed for the automated generation of multi-platform localization files in multiple languages. It supports the generation of localization files for iOS, Flutter, and Electron projects.

## Features

- 📱 Multi-platform support:
  - iOS: `.xcstrings` and `.strings` files
  - Flutter: `.arb` files
  - Electron: localized `.json` files
- 🌍 Supports automatic translation in 50+ languages
- 🔄 Batch translation processing
- 💾 Generates standardized localization files by platform
- ⚡️ Simple and intuitive user interface
- 🎯 Fully compatible with localization workflows across platforms
- 🔁 Supports synchronization with source file content
- 📊 Export to Excel format for easier management

## Supported Languages

Including but not limited to:
- Chinese (Simplified, Traditional, Hong Kong Traditional)
- English (US, UK, Australian variants, etc.)
- Japanese
- Korean
- European languages (French, German, Spanish, etc.)
- Southeast Asian languages (Thai, Vietnamese, etc.)
- Middle Eastern languages (Arabic, etc.)

## How to Use

1. Launch the application
   ![](https://raw.githubusercontent.com/aSynch1889/image/master/uPic/TvuKkX20250331001509.png)
2. Configure the API Key for the AI service in the settings
   ![](https://raw.githubusercontent.com/aSynch1889/image/master/uPic/RFS8Kk20250331001528.png)
3. Select the target platform (iOS/Flutter/Electron)
4. Choose the source file:
   - iOS: Select `.xcstrings` or `.strings` files
   - Flutter: Select `.arb` files
   - Electron: Select `.json` files
5. Select the target language
6. Choose the save location
7. Click "Start Conversion"
8. Wait for the conversion to complete
9. Add the generated files to your project:
   - iOS: Add `.xcstrings` or `.strings` files to the Xcode project
   - Flutter: Place `.arb` files in the `lib/l10n` directory
   - Electron: Place the generated JSON files in the project's language resource directory

## System Requirements

- macOS 13.0 or later
- For iOS development: Xcode 15.0 or later (for .xcstrings support)
- For Flutter development: Flutter SDK
- For Electron development: Node.js environment

## Installation

As this is an open-source project, it has not been notarized by Apple, and some additional steps are required during installation:

1. Download the latest .zip file from the Releases page
2. Unzip the file
3. Drag the .app file into the Applications folder
4. On the first run:
   - Right-click the application icon
   - Select "Open"
   - In the pop-up warning dialog, select "Open"

**Note**: Since the application has not been signed by Apple, the system will display a security warning on the first run. This is normal. If you are concerned about security, you can review the source code and compile it yourself.

### Building from Source

If you prefer to build the application yourself:

1. Clone the repository:
   ```bash
   git clone https://github.com/aSynch1889/LanguageTool.git
   ```
2. Open the project using Xcode
3. Select Product > Build
4. Once built, the application will appear in the product folder of Xcode

## Development Environment

- Swift 5.9
- SwiftUI
- Xcode 15.0+

## Notes

- You need to configure a valid DeepSeek AI or Gemini service API Key before use
- It is recommended to back up existing localization files before use
- Translation results may require manual review to ensure accuracy
- Different platforms have different localization file formats, please ensure to select the correct platform
- deepseek [application portal](https://platform.deepseek.com/api_keys)
- Gemini api [application portal](https://aistudio.google.com/app/apikey?hl=zh-cn)

## Contribution

Feel free to submit Issues and Pull Requests!

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- DeepSeek AI and Gemini for providing translation services
- SwiftUI framework
- All contributors and users

## Contact

If you have any questions or suggestions, please contact us via GitHub Issues.