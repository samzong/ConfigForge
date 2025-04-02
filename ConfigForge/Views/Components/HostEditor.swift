//
//  HostEditor.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI

struct HostEditor: View {
    @Binding var host: String
    var isEditing: Bool
    @State private var isHostValid: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Host")
                .font(.headline)
            
            if isEditing {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("输入主机标识名", text: $host)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: host) { newValue in
                            validateHost(newValue)
                        }
                    
                    if !isHostValid {
                        Text("主机名不能包含空格或特殊字符")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Text("这是SSH连接时使用的名称，如: ssh your-host-name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(host)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func validateHost(_ value: String) {
        // 检查主机名是否包含空格或特殊字符
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        isHostValid = value.rangeOfCharacter(from: allowedCharacters.inverted) == nil
    }
}

struct HostEditor_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            HostEditor(host: .constant("example-host"), isEditing: true)
            HostEditor(host: .constant("example-host"), isEditing: false)
        }
        .padding()
    }
} 