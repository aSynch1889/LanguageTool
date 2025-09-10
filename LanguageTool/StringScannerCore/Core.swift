import Foundation
import SwiftSyntax
import SwiftParser
import SwiftOperators

public struct FileHandleOutputStream: TextOutputStream {
    let fileHandle: FileHandle
    
    public init(fileHandle: FileHandle) {
        self.fileHandle = fileHandle
    }
    
    public mutating func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        fileHandle.write(data)
    }
}

public var stderr = FileHandleOutputStream(fileHandle: .standardError)

public struct StringLocation: Codable, Hashable {
    public let file: String
    public let line: Int
    public let column: Int
    public let content: String
    public let isLocalized: Bool
    
    public init(file: String, line: Int, column: Int, content: String, isLocalized: Bool) {
        self.file = file
        self.line = line
        self.column = column
        self.content = content
        self.isLocalized = isLocalized
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(file)
        hasher.combine(line)
        hasher.combine(column)
        hasher.combine(content)
        hasher.combine(isLocalized)
    }
    
    public static func == (lhs: StringLocation, rhs: StringLocation) -> Bool {
        return lhs.file == rhs.file &&
               lhs.line == rhs.line &&
               lhs.column == rhs.column &&
               lhs.content == rhs.content &&
               lhs.isLocalized == rhs.isLocalized
    }
}

public class ProjectScanner {
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "result.queue", attributes: .concurrent)
    private var allStrings: [StringLocation] = []
    
    public init() {}
    
    public func scanProject(at path: String) {
        print("Scanning project at: \(path)", to: &stderr)
        
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            print("Error: Cannot enumerate directory contents", to: &stderr)
            return
        }
        
        let files = enumerator.compactMap { $0 as? URL }
            .filter { isValidFile($0) }
        
        DispatchQueue.concurrentPerform(iterations: files.count) { index in
            let file = files[index]
            do {
                try scanFile(at: file)
            } catch {
                print("Error scanning \(file.path): \(error)", to: &stderr)
            }
        }
        
        outputResults()
    }
    
    public func getScanResults() -> [StringLocation] {
        return allStrings.sorted {
            $0.file == $1.file ?
                ($0.line == $1.line ? $0.column < $1.column : $0.line < $1.line) :
                $0.file < $1.file
        }
    }
    
    private func isValidFile(_ url: URL) -> Bool {
        let validExtensions = ["swift", "m", "h"]
        guard validExtensions.contains(url.pathExtension) else { return false }
        
        let excludedPaths = [
            "/Pods/", "/Carthage/", "/.swiftpm/",
            "/Tests/", "/Test/", "/Specs/",
            "/DerivedData/", "/build/"
        ]
        
        let path = url.path
        return !excludedPaths.contains { path.contains($0) }
    }
    
    private func scanFile(at url: URL) throws {
        let source = try String(contentsOf: url)
        let sourceFile = try Parser.parse(source: source)
        
        let operatorTable = OperatorTable.standardOperators
        let foldedFile = try operatorTable.foldAll(sourceFile)
        
        let locationConverter = SourceLocationConverter(
            fileName: url.path,
            tree: foldedFile
        )
        
        let visitor = StringVisitor(
            filePath: url.path,
            locationConverter: locationConverter
        )
        
        visitor.walk(foldedFile)
        
        queue.async(flags: .barrier) {
            self.allStrings.append(contentsOf: visitor.strings)
        }
    }
    
    private func outputResults() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let jsonData = try encoder.encode(getScanResults())
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } catch {
            print("JSON encoding error: \(error)", to: &stderr)
        }
    }
}

public class StringVisitor: SyntaxVisitor {
    let filePath: String
    let locationConverter: SourceLocationConverter
    public var strings: [StringLocation] = []
    
    public init(filePath: String, locationConverter: SourceLocationConverter) {
        self.filePath = filePath
        self.locationConverter = locationConverter
        super.init(viewMode: .sourceAccurate)
    }
    
    public override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        let location = node.startLocation(converter: locationConverter)
        let content = node.segments
            .compactMap { $0.as(StringSegmentSyntax.self)?.content.text }
            .joined()
        
        guard !content.isEmpty else { return .skipChildren }
        
        let isLocalized = isInLocalizationContext(node)
        
        strings.append(StringLocation(
            file: filePath,
            line: location.line,
            column: location.column,
            content: content,
            isLocalized: isLocalized
        ))
        
        return .skipChildren
    }
    
    private func isInLocalizationContext(_ node: StringLiteralExprSyntax) -> Bool {
        if let functionCall = node.parent?.as(FunctionCallExprSyntax.self),
           let calledExpression = functionCall.calledExpression.as(DeclReferenceExprSyntax.self),
           calledExpression.baseName.text == "NSLocalizedString" {
            return true
        }
        return false
    }
    
    public override func visit(_ node: RegexLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        let location = node.startLocation(converter: locationConverter)
        strings.append(StringLocation(
            file: filePath,
            line: location.line,
            column: location.column,
            content: node.regex.text,
            isLocalized: false
        ))
        return .skipChildren
    }
} 