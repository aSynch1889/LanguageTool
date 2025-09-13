import Foundation
import SwiftUI

struct DeepseekDemo: View {
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var responseMessage: String = ""
    @State private var isLoading: Bool = false
    
    func sendMessage() {
        isLoading = true
        messages.append(Message(role: "user", content: inputText))
        
        AIServiceV2.shared.sendMessage(messages: messages) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let response):
                    responseMessage = response
                    messages.append(Message(role: "assistant", content: response))
                case .failure(let error):
                    responseMessage = error.localizedDescription
                }
            }
        }
        
        // 使用示例
//        let messages: [Message] = [
//            Message(role: "system", content: "你是一个中英文翻译专家..."),
//            Message(role: "user", content: "牛顿第一定律...")
//        ]
//
//        AIServiceV2.shared.sendMessage(messages: messages) { result in
//            switch result {
//            case .success(let translation):
//                print("翻译结果：\(translation)")
//            case .failure(let error):
//                print("错误：\(error.localizedDescription)") // 使用 localizedDescription
//            }
//        }
        
    }
    
    var body: some View {
        VStack {
            TextField("输入消息", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("发送") {
                sendMessage()
            }

            if isLoading {
                ProgressView()
            }
        }
    }
}
