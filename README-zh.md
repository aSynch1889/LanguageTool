# Language Tool
[English](README-en.md) | [中文](README.md)
Language Tool 是一个 macOS 应用程序，用于自动化生成多平台的多语言本地化文件。支持 iOS、Flutter 和 Electron 项目的本地化文件生成。

## 功能特点

- 📱 支持多个平台：
  - iOS: `.xcstrings` 和 `.strings` 文件
  - Flutter: `.arb` 文件
  - Electron: 本地化 `.json` 文件
- 🌍 支持 50+ 种语言的自动翻译
- 🔄 批量翻译处理
- 💾 按平台生成标准格式的本地化文件
- ⚡️ 简单直观的用户界面
- 🎯 完全适配各平台的本地化工作流
- 🔁 支持同步更新源文件内容
- 📊 支持导出为 Excel 格式便于管理

## 支持的语言

包括但不限于：
- 中文（简体、繁体、香港繁体）
- 英语（美国、英国、澳大利亚等变体）
- 日语
- 韩语
- 欧洲语言（法语、德语、西班牙语等）
- 东南亚语言（泰语、越南语等）
- 中东语言（阿拉伯语等）

## 使用方法

1. 启动应用程序
   ![](https://raw.githubusercontent.com/aSynch1889/image/master/uPic/s0edU520250331001441.png)
2. 在设置中配置 AI 服务的 API Key
   ![](https://raw.githubusercontent.com/aSynch1889/image/master/uPic/7Rp8GC20250331001235.png)
3. 选择目标平台（iOS/Flutter/Electron）
4. 选择源文件：
   - iOS: 选择 `.xcstrings` 或 `.strings` 文件
   - Flutter: 选择 `.arb` 文件
   - Electron: 选择 `.json` 文件
5. 选择目标语言
6. 选择保存位置
7. 点击"开始转换"
8. 等待转换完成
9. 将生成的文件添加到你的项目中：
   - iOS: 添加 `.xcstrings` 或 `.strings` 文件到 Xcode 项目
   - Flutter: 将 `.arb` 文件放入 `lib/l10n` 目录
   - Electron: 将生成的 JSON 文件放入项目的语言资源目录

## 系统要求

- macOS 13.0 或更高版本
- 对于 iOS 开发：Xcode 15.0 或更高版本（用于 .xcstrings 支持）
- 对于 Flutter 开发：Flutter SDK
- 对于 Electron 开发：Node.js 环境

## 安装

由于这是一个开源项目，目前没有经过 Apple 公证，安装时需要一些额外步骤：

1. 从 Releases 页面下载最新的 .zip 文件
2. 解压缩文件
3. 将 .app 文件拖入 Applications 文件夹
4. 首次运行时：
   - 右键点击应用图标
   - 选择"打开"
   - 在弹出的警告对话框中选择"打开"
   

注意：由于应用没有经过 Apple 签名，首次运行时系统会显示安全警告，这是正常的。如果你担心安全问题，可以查看源代码并自行编译。

### 从源码构建

如果你更倾向于自己构建应用：

1. 克隆仓库：
   ```bash
   git clone https://github.com/aSynch1889/LanguageTool.git
   ```
2. 使用 Xcode 打开项目
3. 选择 Product > Build
4. 构建完成后，应用会出现在 Xcode 的 product文件夹中

## 开发环境

- Swift 5.9
- SwiftUI
- Xcode 15.0+

## 注意事项

- 使用前需要配置有效的 DeepSeek AI 或者 Gemini（免费但限制地区） 服务 API Key
- 建议在使用前备份原有的本地化文件
- 翻译结果可能需要人工审核以确保准确性
- 不同平台的本地化文件格式有所不同，请确保选择正确的平台
- deepseek API [申请地址](https://platform.deepseek.com/api_keys)
- Gemini API [申请地址](https://aistudio.google.com/app/apikey?hl=zh-cn)

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 致谢

- DeepSeek AI、Gemini 提供翻译服务
- SwiftUI 框架
- 所有贡献者和用户

## 联系方式

如有问题或建议，请通过 GitHub Issues 与我们联系。

---

Made with ❤️ by [华子]
