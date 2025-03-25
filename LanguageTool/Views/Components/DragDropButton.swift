import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DragDropButton: View {
    let title: String
    let action: () -> Void
    let isSelected: Bool
    let onDrop: ([NSItemProvider]) -> Bool
    let useDefaultStyle: Bool
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle()) // 确保整个区域可点击
        }
        .buttonStyle(DragDropButtonStyle(isSelected: isSelected, useDefaultStyle: useDefaultStyle))
        .onDrop(of: [.fileURL], isTargeted: nil, perform: onDrop)
    }
}
