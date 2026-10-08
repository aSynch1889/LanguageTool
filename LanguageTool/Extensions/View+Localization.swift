extension String {
    var localized: String {
        LocalizationManager.shared.localizedString(for: self)
    }

    func localizedFormat(_ arguments: CVarArg...) -> String {
        String(format: localized, locale: nil, arguments: arguments)
    }
}