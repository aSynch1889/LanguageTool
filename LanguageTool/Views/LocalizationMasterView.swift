import SwiftUI

struct LocalizationMasterView: View {
    @State private var remainingTrials = 4
    @State private var translateSelectedOnly = true
    @StateObject private var transferViewModel = TransferViewModel()
    @State private var translations: [TranslationItem] = []

    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("仅对 勾选 了 “ 翻译 ” 的 内容 进行 翻译 。", isOn: $translateSelectedOnly)
                Spacer()
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("搜索", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                }
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack {
                    headerRow()
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                    Divider()
                    ForEach($translations) { $translation in
                        TranslationRow(translation: $translation, translateSelectedOnly: $translateSelectedOnly)
                            .padding(.horizontal)
                            .padding(.vertical, 3)
                        Divider()
                    }
                }
            }

            Divider()

            HStack {
                Button("新增语言") {
                    // TODO: Implement add language functionality
                }
                Spacer()
                Button("重新加载源文件") {
                    // TODO: Implement reload source file functionality
                }
                Button("同步到源文件") {
                    // TODO: Implement sync to source file functionality
                }
                Button("导出") {
                    // TODO: Implement export functionality
                }
                Button("立即翻译") {
                    // TODO: Implement immediate translation functionality
                }
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 600) // Set a reasonable minimum size for a macOS window
    }

    private func headerRow() -> some View {
        HStack {
            Text("翻译")
                .frame(width: 40)
            Text("Key")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("en (英语)")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("zh - Hans (简体 中...")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("ja (日语)")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("zh - Hant (繁体 中文)")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("ko (韩语)")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Comment")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
        .foregroundColor(.gray)
    }
}

struct TranslationItem: Identifiable {
    let id = UUID()
    var isSelected: Bool = true
    var key: String
    var english: String
    var chineseSimplified: String
    var japanese: String
    var chineseTraditional: String
    var korean: String
    var comment: String = ""
}

struct TranslationRow: View {
    @Binding var translation: TranslationItem
    @Binding var translateSelectedOnly: Bool

    var body: some View {
        HStack {
            Toggle("", isOn: $translation.isSelected)
                .frame(width: 40)
            Text(translation.key)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("English", text: $translation.english)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
            TextField("简体中文", text: $translation.chineseSimplified)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
            TextField("日本語", text: $translation.japanese)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
            TextField("繁體中文", text: $translation.chineseTraditional)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
            TextField("한국어", text: $translation.korean)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
            TextField("Comment", text: $translation.comment)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
        }
    }
}

struct LocalizationMasterView_Previews: PreviewProvider {
    static var previews: some View {
        LocalizationMasterView()
    }
}
