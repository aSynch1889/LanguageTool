import SwiftUI

struct LocalizationMasterView: View {
    @State private var remainingTrials = 4
    @State private var translateSelectedOnly = true
    @StateObject var viewModel: TransferViewModel
    @State private var searchText = ""
    @State private var selection = Set<TranslationItem.ID>()
    
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
                Toggle("仅对勾选了 \"翻译\" 的内容进行翻译。", isOn: $translateSelectedOnly)
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
            
            // 使用 SwiftUI Table 替代手动实现的表格
            Table(filteredTranslations, selection: $selection) {
                // 翻译选择列
                TableColumn("翻译") { (item: TranslationItem) in
                    Toggle("", isOn: bindingForIsSelected(item))
                        .toggleStyle(.checkbox)
                }
                .width(min: 50, ideal: 60, max: 80)
                
                // Key 列
                TableColumn("Key") { (item: TranslationItem) in
                    Text(item.key)
                        .opacity(item.isSelected ? 1.0 : 0.5)
                }
                .width(min: 100, ideal: 200)
                
                // 语言翻译列
                TableColumn("翻译内容") { (item: TranslationItem) in
                    TranslationItemLanguagesView(
                        item: item,
                        availableLanguages: availableLanguages,
                        updateItem: { updatedItem in
                            if let index = viewModel.translationItems.firstIndex(where: { $0.id == item.id }) {
                                viewModel.translationItems[index] = updatedItem
                            }
                        }
                    )
                    .opacity(item.isSelected ? 1.0 : 0.5)
                    .disabled(!item.isSelected)
                }
                .width(min: 300, ideal: 500)
                
                // Comment 列
                TableColumn("Comment") { (item: TranslationItem) in
                    TextField(
                        "Comment",
                        text: bindingForComment(item)
                    )
                    .textFieldStyle(.plain)
                    .opacity(item.isSelected ? 1.0 : 0.5)
                    .disabled(!item.isSelected)
                }
                .width(min: 100, ideal: 150)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            
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
    
    // 为 isSelected 属性创建绑定
    private func bindingForIsSelected(_ item: TranslationItem) -> Binding<Bool> {
        Binding(
            get: { item.isSelected },
            set: { newValue in
                if let index = viewModel.translationItems.firstIndex(where: { $0.id == item.id }) {
                    viewModel.translationItems[index].isSelected = newValue
                }
            }
        )
    }
    
    // 为特定语言的翻译创建绑定
    private func bindingForTranslation(_ item: TranslationItem, languageCode: String) -> Binding<String> {
        Binding(
            get: { item.translations[languageCode] ?? "" },
            set: { newValue in
                if let index = viewModel.translationItems.firstIndex(where: { $0.id == item.id }) {
                    viewModel.translationItems[index].translations[languageCode] = newValue
                }
            }
        )
    }
    
    // 为 comment 属性创建绑定
    private func bindingForComment(_ item: TranslationItem) -> Binding<String> {
        Binding(
            get: { item.comment },
            set: { newValue in
                if let index = viewModel.translationItems.firstIndex(where: { $0.id == item.id }) {
                    viewModel.translationItems[index].comment = newValue
                }
            }
        )
    }

    // 辅助函数：获取语言的显示名称
    private func getLanguageDisplay(for code: String) -> String {
        let languageName = Locale.current.localizedString(forLanguageCode: code) ?? code
        return "\(code) (\(languageName))"
    }
}

struct TranslationItemLanguagesView: View {
    let item: TranslationItem
    let availableLanguages: [String]
    let updateItem: (TranslationItem) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(availableLanguages, id: \.self) { languageCode in
                VStack(alignment: .leading, spacing: 2) {
                    Text(getLanguageDisplay(for: languageCode))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField(
                        getLanguageDisplay(for: languageCode),
                        text: bindingForLanguage(languageCode)
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 120)
                }
            }
        }
    }
    
    private func bindingForLanguage(_ languageCode: String) -> Binding<String> {
        Binding(
            get: { item.translations[languageCode] ?? "" },
            set: { newValue in
                var updatedItem = item
                updatedItem.translations[languageCode] = newValue
                updateItem(updatedItem)
            }
        )
    }
    
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


struct LocalizationMasterView_Previews: PreviewProvider {
    static var previews: some View {
        LocalizationMasterView(viewModel: TransferViewModel())
    }
}
