//
//  EditorControls.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI

struct EditorControls: View {
    @Binding var isEditing: Bool
    
    var body: some View {
        HStack {
            Button(isEditing ? "取消" : "编辑") {
                isEditing.toggle()
            }
            .buttonStyle(.bordered)
            
            if isEditing {
                Button("保存") {
                    // 保存逻辑会在上层处理
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.bottom, 8)
    }
}

struct EditorControls_Previews: PreviewProvider {
    static var previews: some View {
        EditorControls(isEditing: .constant(false))
        EditorControls(isEditing: .constant(true))
    }
} 