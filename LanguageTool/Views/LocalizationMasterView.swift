import SwiftUI

struct LocalizationMasterView: View {
    @State private var remainingTrials = 4
    @State private var translateSelectedOnly = true
    @StateObject var viewModel: TransferViewModel
    @State private var searchText = ""
    
    // 初始化器
    init(viewModel: TransferViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // 添加一个计算属性来获取所有可用的语言
    private var availableLanguages: [String] {
        // 从所有翻译项中收集语言代码
        var languageCodes = Set<String>()
        for translation in viewModel.translationItems {
            languageCodes.formUnion(translation.translations.keys)
        }
        return Array(languageCodes).sorted()
    }
    
    // 添加一个计算属性来过滤和搜索翻译项
    private var filteredTranslations: [TranslationItem] {
        let items = viewModel.translationItems
        if searchText.isEmpty {
            return items
        }
        return items.filter { item in
            // 搜索key
            if item.key.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            // 搜索translations中的值
            if item.translations.values.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) {
                return true
            }
            // 搜索comment
            if item.comment.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("仅对勾选了 “翻译“ 的内容进行翻译。", isOn: $translateSelectedOnly)
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
                    ForEach(filteredTranslations) { translation in
                        TranslationRow(
                            translation: binding(for: translation),
                            translateSelectedOnly: $translateSelectedOnly
                        )
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
                    Task {
                        await viewModel.reloadSourceFile()
                    }
                }
                Button("同步到源文件") {
                    viewModel.syncToSource()
                }
                Button("导出") {
                    viewModel.exportToExcel()
                }
                Button("立即翻译") {
                    // TODO: Implement immediate translation functionality
                }
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // 辅助函数：为特定的翻译项创建绑定
    private func binding(for translation: TranslationItem) -> Binding<TranslationItem> {
        Binding(
            get: {
                translation
            },
            set: { newValue in
                if let index = viewModel.translationItems.firstIndex(where: { $0.id == translation.id }) {
                    viewModel.translationItems[index] = newValue
                }
            }
        )
    }

    private func headerRow() -> some View {
        HStack {
            // 翻译选择框
            Text("翻译")
                .frame(width: 40)
            
            // Key 列
            Text("Key")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 动态语言列
            ForEach(availableLanguages, id: \.self) { languageCode in
                Text(getLanguageDisplay(for: languageCode))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Comment 列
            Text("Comment")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
        .foregroundColor(.gray)
    }

    // 辅助函数：获取语言的显示名称
    private func getLanguageDisplay(for code: String) -> String {
        let languageName = Locale.current.localizedString(forLanguageCode: code) ?? code
        return "\(code) (\(languageName))"
    }
}

struct TranslationItem: Identifiable {
    let id = UUID()
    var isSelected: Bool = true
    var key: String
    var translations: [String: String] // 语言代码到翻译的映射
    var comment: String = ""
    
    // 便利初始化器用于兼容现有代码
    init(isSelected: Bool = true,
         key: String,
         translations: [String: String] = [:],
         comment: String = "") {
        self.isSelected = isSelected
        self.key = key
        self.translations = translations
        self.comment = comment
    }
}

struct TranslationRow: View {
    @Binding var translation: TranslationItem
    @Binding var translateSelectedOnly: Bool

    var body: some View {
        HStack {
            // 翻译选择框
            Toggle("", isOn: $translation.isSelected)
                .frame(width: 40)
            
            // Key
            Text(translation.key)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(translation.isSelected ? 1.0 : 0.5)
                .disabled(!translation.isSelected)
            
            // 动态语言输入框
            ForEach(Array(translation.translations.keys).sorted(), id: \.self) { languageCode in
                TextField(getLanguageDisplay(for: languageCode),
                         text: Binding(
                            get: { translation.translations[languageCode] ?? "" },
                            set: { translation.translations[languageCode] = $0 }
                         ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: .infinity)
                    .opacity(translation.isSelected ? 1.0 : 0.5)
                    .disabled(!translation.isSelected)
            }
            
            // Comment
            TextField("Comment", text: $translation.comment)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
                .opacity(translation.isSelected ? 1.0 : 0.5)
                .disabled(!translation.isSelected)
        }
//        .opacity(translation.isSelected ? 1.0 : 0.5)
//        .disabled(!translation.isSelected)
    }
    
    private func getLanguageDisplay(for code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}

struct LocalizationMasterView_Previews: PreviewProvider {
    static var previews: some View {
        LocalizationMasterView(viewModel: TransferViewModel())
    }
}
