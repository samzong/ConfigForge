//
//  PropertiesEditor.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct PropertiesEditor: View {
    @Binding var properties: [String: String]
    var isEditing: Bool
    
    @State private var showingFilePicker = false
    @State private var currentEditingKey = ""
    
    // 基本属性和身份认证属性 - 确保包含HostName和IdentityFile
    private let basicProperties = ["HostName", "User", "Port"]
    private let identityProperties = ["IdentityFile"]
    
    // 获取所有属性键的有序数组
    private var orderedPropertyKeys: [String] {
        var keys = [String]()
        
        // 确保添加基本属性，尤其是HostName
        for key in basicProperties {
            // 即使不存在也添加这些基本属性
            keys.append(key)
            
            // 如果属性不存在且在编辑模式，添加空值
            if !properties.keys.contains(key) && isEditing {
                properties[key] = ""
            }
        }
        
        // 确保添加身份认证属性
        if !properties.keys.contains("IdentityFile") {
            keys.append("IdentityFile")
            if isEditing {
                properties["IdentityFile"] = ""
            }
        } else {
            // 如果已存在，确保加入keys列表
            keys.append("IdentityFile")
        }
        
        return keys
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 显示所有属性
                ForEach(orderedPropertyKeys, id: \.self) { key in
                    PropertyRowEditor(
                        key: key,
                        value: Binding(
                            get: { properties[key] ?? "" },
                            set: { properties[key] = $0 }
                        ),
                        isEditing: isEditing,
                        onDelete: nil, // 不允许删除任何属性
                        onBrowse: isEditing && key == "IdentityFile" ? {
                            currentEditingKey = key
                            showingFilePicker = true
                        } : nil
                    )
                }
            }
            .padding()
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // 使用文件路径
                    properties[currentEditingKey] = url.path
                }
            case .failure:
                // 处理错误情况
                break
            }
        }
    }
}

struct PropertyRowEditor: View {
    let key: String
    @Binding var value: String
    let isEditing: Bool
    let onDelete: (() -> Void)?
    let onBrowse: (() -> Void)?
    
    // 获取适合显示的键名
    private var displayKey: String {
        switch key {
        case "HostName": return "主机地址"
        case "User": return "用户名"
        case "Port": return "端口"
        case "IdentityFile": return "密钥文件"
        default: return key
        }
    }
    
    var body: some View {
        // 改为水平布局
        HStack {
            // 属性名称
            Text(displayKey)
                .font(.headline)
                .frame(width: 120, alignment: .leading)
            
            // 属性值
            if isEditing {
                HStack {
                    TextField(key, text: $value)
                        .textFieldStyle(.roundedBorder)
                    
                    if key == "Port" {
                        Stepper("", value: Binding(
                            get: { Int(value) ?? 22 },
                            set: { value = "\($0)" }
                        ), in: 1...65535)
                        .labelsHidden()
                    }
                    
                    // 显示浏览按钮
                    if let onBrowse = onBrowse {
                        Button(action: onBrowse) {
                            Image(systemName: "folder")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.borderless)
                        .padding(.horizontal, 8)
                    }
                }
            } else {
                Text(value)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PropertiesEditor_Previews: PreviewProvider {
    static var previews: some View {
        PropertiesEditor(
            properties: .constant([
                "HostName": "example.com",
                "User": "admin",
                "Port": "22"
            ]),
            isEditing: true
        )
        .padding()
    }
} 