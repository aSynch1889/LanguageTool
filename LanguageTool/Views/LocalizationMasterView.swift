import SwiftUI
import AppKit

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

    private var addableLanguages: [Language] {
        Language.supportedLanguages.filter { !availableLanguages.contains($0.code) }
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
            
            // 使用 NSTableView 实现真正的动态列
            NSTableViewRepresentable(
                items: filteredTranslations,
                availableLanguages: availableLanguages,
                translateSelectedOnly: $translateSelectedOnly,
                onItemUpdate: { updatedItem in
                    if let index = viewModel.translationItems.firstIndex(where: { $0.id == updatedItem.id }) {
                        viewModel.translationItems[index] = updatedItem
                    }
                }
            )
            
            Divider()
            
            HStack {
                Menu("新增语言") {
                    if addableLanguages.isEmpty {
                        Text("无可新增语言")
                    } else {
                        ForEach(addableLanguages) { language in
                            Button("\(language.localizedName) (\(language.code))") {
                                addLanguage(language.code)
                            }
                        }
                    }
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
                    viewModel.exportToCSV()
                }
                Button("立即翻译") {
                    Task {
                        await viewModel.translateCurrentItems(onlySelected: translateSelectedOnly)
                    }
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

    private func addLanguage(_ languageCode: String) {
        guard !viewModel.translationItems.isEmpty else { return }
        for index in viewModel.translationItems.indices {
            if viewModel.translationItems[index].translations[languageCode] == nil {
                viewModel.translationItems[index].translations[languageCode] = ""
            }
        }
    }
}

struct NSTableViewRepresentable: NSViewRepresentable {
    let items: [TranslationItem]
    let availableLanguages: [String]
    @Binding var translateSelectedOnly: Bool
    let onItemUpdate: (TranslationItem) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()
        
        // 配置 tableView
        tableView.style = .inset
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.headerView = NSTableHeaderView()
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        
        // 创建数据源和代理
        let coordinator = context.coordinator
        tableView.dataSource = coordinator
        tableView.delegate = coordinator
        coordinator.tableView = tableView
        coordinator.onItemUpdate = onItemUpdate
        
        // 配置 scrollView
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tableView = nsView.documentView as? NSTableView else { return }
        let coordinator = context.coordinator
        
        // 更新数据
        coordinator.items = items
        coordinator.availableLanguages = availableLanguages
        coordinator.translateSelectedOnly = translateSelectedOnly
        
        // 重新创建列结构（如果语言发生变化）
        coordinator.setupColumns()
        
        // 重新加载数据
        tableView.reloadData()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var tableView: NSTableView?
        var items: [TranslationItem] = []
        var availableLanguages: [String] = []
        var translateSelectedOnly = false
        var onItemUpdate: ((TranslationItem) -> Void)?
        
        private var currentLanguages: [String] = []
        
        func setupColumns() {
            guard let tableView = tableView else { return }
            
            // 如果语言没有变化，不需要重新设置列
            if currentLanguages == availableLanguages {
                return
            }
            
            // 清除现有列
            tableView.tableColumns.forEach { tableView.removeTableColumn($0) }
            
            // 创建翻译选择列
            let checkboxColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("checkbox"))
            checkboxColumn.title = "翻译"
            checkboxColumn.width = 60
            checkboxColumn.minWidth = 60
            checkboxColumn.maxWidth = 60
            tableView.addTableColumn(checkboxColumn)
            
            // 创建 Key 列
            let keyColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("key"))
            keyColumn.title = "Key"
            keyColumn.width = 200
            keyColumn.minWidth = 100
            tableView.addTableColumn(keyColumn)
            
            // 动态创建语言列
            for languageCode in availableLanguages {
                let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(languageCode))
                let languageName = Locale.current.localizedString(forLanguageCode: languageCode) ?? languageCode
                column.title = "\(languageCode) (\(languageName))"
                column.width = 150
                column.minWidth = 120
                tableView.addTableColumn(column)
            }
            
            // 创建 Comment 列
            let commentColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("comment"))
            commentColumn.title = "Comment"
            commentColumn.width = 150
            commentColumn.minWidth = 100
            tableView.addTableColumn(commentColumn)
            
            currentLanguages = availableLanguages
        }
        
        // MARK: - NSTableViewDataSource
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            return items.count
        }
        
        // MARK: - NSTableViewDelegate
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < items.count else { return nil }
            let item = items[row]
            let identifier = tableColumn?.identifier
            
            if identifier?.rawValue == "checkbox" {
                // 复选框列
                let view = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxChanged(_:)))
                view.state = item.isSelected ? .on : .off
                view.tag = row
                return view
                
            } else if identifier?.rawValue == "key" {
                // Key 列
                let view = NSTextField(labelWithString: item.key)
                view.alphaValue = item.isSelected ? 1.0 : 0.5
                return view
                
            } else if identifier?.rawValue == "comment" {
                // Comment 列
                let view = NSTextField()
                view.stringValue = item.comment
                view.isEditable = item.isSelected
                view.isSelectable = true
                view.alphaValue = item.isSelected ? 1.0 : 0.5
                view.tag = row
                view.target = self
                view.action = #selector(commentChanged(_:))
                return view
                
            } else if let languageCode = identifier?.rawValue, availableLanguages.contains(languageCode) {
                // 语言列
                let view = NSTextField()
                view.stringValue = item.translations[languageCode] ?? ""
                view.isEditable = item.isSelected
                view.isSelectable = true
                view.alphaValue = item.isSelected ? 1.0 : 0.5
                view.tag = row * 1000 + (availableLanguages.firstIndex(of: languageCode) ?? 0)
                view.target = self
                view.action = #selector(languageFieldChanged(_:))
                return view
            }
            
            return nil
        }
        
        @objc func checkboxChanged(_ sender: NSButton) {
            let row = sender.tag
            guard row < items.count else { return }
            
            var updatedItem = items[row]
            updatedItem.isSelected = sender.state == .on
            onItemUpdate?(updatedItem)
        }
        
        @objc func commentChanged(_ sender: NSTextField) {
            let row = sender.tag
            guard row < items.count else { return }
            
            var updatedItem = items[row]
            updatedItem.comment = sender.stringValue
            onItemUpdate?(updatedItem)
        }
        
        @objc func languageFieldChanged(_ sender: NSTextField) {
            let tag = sender.tag
            let row = tag / 1000
            let languageIndex = tag % 1000
            
            guard row < items.count, languageIndex < availableLanguages.count else { return }
            
            let languageCode = availableLanguages[languageIndex]
            var updatedItem = items[row]
            updatedItem.translations[languageCode] = sender.stringValue
            onItemUpdate?(updatedItem)
        }
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
