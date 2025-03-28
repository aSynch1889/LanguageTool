import SwiftUI

struct LocalizationMasterView: View {
    @State private var remainingTrials = 4
    @State private var translateSelectedOnly = true
    @State private var translations: [TranslationItem] = [
        TranslationItem(key: "Select Platform", english: "Select Platform", chineseSimplified: "选择平台", japanese: "プラットフォ...", chineseTraditional: "選擇平台", korean: "플랫폼 선택"),
        TranslationItem(key: "Korean", english: "Korean", chineseSimplified: "韩语", japanese: "韓国語", chineseTraditional: "韓語", korean: "한국어"),
        TranslationItem(key: "Select Output ...", english: "Select Output ...", chineseSimplified: "选择输出位置", japanese: "出力場所を選択", chineseTraditional: "選擇輸出位置", korean: "출력 위치 선택"),
        TranslationItem(key: "Select directo ...", english: "Select directo ...", chineseSimplified: "选择 JSON 文...", japanese: "JSON ファイ...", chineseTraditional: "選擇 JSON 檔...", korean: "JSON 파일 디렉..."),
        TranslationItem(key: "Select locatio ...", english: "Select locatio ...", chineseSimplified: "选择保存 .xcstr...", japanese: ".xcstrings ファ...", chineseTraditional: "選擇儲存 .xcstri....", korean: ".xcstrings 파일 ..."),
        TranslationItem(key: "Other Settings", english: "Other Settings", chineseSimplified: "其他设置", japanese: "その他設定", chineseTraditional: "其他設定", korean: "기타 설정"),
        TranslationItem(key: "Select Target ...", english: "Select Target ...", chineseSimplified: "选择目标语言", japanese: "対象言語を選択", chineseTraditional: "選擇目標語言", korean: "대상 언어 선택"),
        TranslationItem(key: "Translating ...", english: "Translating ...", chineseSimplified: "正在翻译...", japanese: "翻訳中...", chineseTraditional: "翻譯中....", korean: "번역 중 ..."),
        TranslationItem(key: "Successfully ...", english: "Successfully ...", chineseSimplified: "成功为所有语...", japanese: "すべての言語...", chineseTraditional: "成功為所有語...", korean: "모든 언어에 대한 ..."),
        TranslationItem(key: "Select Input F ...", english: "Select Input F ...", chineseSimplified: "选择输入文件", japanese: "入力ファイル...", chineseTraditional: "選擇輸入檔案", korean: "입력 파일 선택"),
        TranslationItem(key: "Please wait , t ...", english: "Please wait , t ...", chineseSimplified: "请稍候, 这可...", japanese: "お待ちくださ...", chineseTraditional: "請稍候 , 這可 ...", korean: "잠시 기다려 주세 ..."),
    ]

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
