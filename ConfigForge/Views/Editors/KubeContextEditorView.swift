import SwiftUI

struct KubeContextEditorView: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var context: KubeContext
    @State private var editedName: String = ""
    @State private var editedNamespace: String = ""
    @State private var isNameValid: Bool = true
    @State private var selectedClusterName: String
    @State private var selectedUserName: String
    // 移除@State，这些是计算属性
    private var selectedCluster: KubeCluster? {
        viewModel.kubeClusters.first { $0.name == selectedClusterName }
    }
    private var selectedUser: KubeUser? {
        viewModel.kubeUsers.first { $0.name == selectedUserName }
    }
    
    // 本地编辑状态
    @State private var isEditing: Bool = false
    @State private var editedCluster: String
    @State private var editedUser: String
    
    // 侧滑面板状态控制
    @State private var isShowingClusterPanel: Bool = false
    @State private var isShowingUserPanel: Bool = false
    @State private var panelOffset: CGFloat = 350 // 侧滑面板的宽度
    
    init(viewModel: MainViewModel, context: Binding<KubeContext>) {
        self.viewModel = viewModel
        self._context = context
        
        // 初始化状态变量
        _editedName = State(initialValue: context.wrappedValue.name)
        _selectedClusterName = State(initialValue: context.wrappedValue.context.cluster)
        _selectedUserName = State(initialValue: context.wrappedValue.context.user)
        _editedNamespace = State(initialValue: context.wrappedValue.context.namespace ?? "")
        
        // 初始化编辑状态变量
        _editedCluster = State(initialValue: context.wrappedValue.context.cluster)
        _editedUser = State(initialValue: context.wrappedValue.context.user)
    }

    var body: some View {
        ZStack {
            // 背景
            Color(.windowBackgroundColor).edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading, spacing: 15) {
                // 顶部标题和编辑按钮
                HStack {
                    Text(L10n.Kubernetes.Context.edit(context.name))
                        .font(.title2.bold())
                    Spacer()
                    
                    // 添加编辑/保存按钮
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            // 如果当前有打开的侧滑面板，先关闭它们
                            hideAllPanels()
                            
                            // 如果正在编辑状态，点击保存更改
                            if isEditing {
                                saveChanges()
                            } else {
                                // 进入编辑模式前，更新选择的集群和用户
                                updateSelections()
                            }
                            // 切换编辑状态
                            isEditing.toggle()
                        }
                    }) {
                        Text(isEditing ? L10n.App.save : L10n.App.edit)
                            .frame(minWidth: 80)
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(BorderedButtonStyle())
                    .controlSize(.large)
                }
                Divider()
                
                // context名称区域
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.Kubernetes.Context.name)
                        .font(.headline)
                    
                    TextField(L10n.Kubernetes.Context.name, text: $editedName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(!isEditing)
                        .onChange(of: editedName) { newValue in
                            isNameValid = !newValue.trimmingCharacters(in: .whitespaces).isEmpty
                        }
                }
                .padding()
                
                // 当前context区域
                GroupBox {
                    VStack(alignment: .leading, spacing: 18) {
                        // 集群选择器
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.Kubernetes.Context.cluster)
                                .font(.headline)
                            
                            if isEditing {
                                HStack {
                                    Picker(L10n.Kubernetes.Context.cluster, selection: $editedCluster) {
                                        ForEach(viewModel.kubeClusters, id: \.name) { cluster in
                                            Text(cluster.name).tag(cluster.name)
                                        }
                                    }
                                    .pickerStyle(DefaultPickerStyle())
                                    .labelsHidden()
                                    
                                    // 编辑模式下也提供查看集群详情的按钮
                                    Button(action: {
                                        // 显示集群侧滑面板
                                        hideAllPanels()
                                        withAnimation(.spring()) {
                                            isShowingClusterPanel = true
                                        }
                                    }) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .help(L10n.Kubernetes.Context.View.Cluster.details)
                                }
                            } else {
                                HStack {
                                    Text(context.context.cluster)
                                        .padding(6)
                                        .background(Color(.controlBackgroundColor))
                                        .cornerRadius(4)
                                    
                                    Button(action: {
                                        // 显示集群侧滑面板
                                        hideAllPanels()
                                        withAnimation(.spring()) {
                                            isShowingClusterPanel = true
                                        }
                                    }) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .help(L10n.Kubernetes.Context.View.Cluster.details)
                                }
                            }
                        }
                        
                        // 用户选择器
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.Kubernetes.Context.user)
                                .font(.headline)
                            
                            if isEditing {
                                HStack {
                                    Picker(L10n.Kubernetes.Context.user, selection: $editedUser) {
                                        ForEach(viewModel.kubeUsers, id: \.name) { user in
                                            Text(user.name).tag(user.name)
                                        }
                                    }
                                    .pickerStyle(DefaultPickerStyle())
                                    .labelsHidden()
                                    
                                    // 编辑模式下也提供查看用户详情的按钮
                                    Button(action: {
                                        // 显示用户侧滑面板
                                        hideAllPanels()
                                        withAnimation(.spring()) {
                                            isShowingUserPanel = true
                                        }
                                    }) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .help(L10n.Kubernetes.Context.View.User.details)
                                }
                            } else {
                                HStack {
                                    Text(context.context.user)
                                        .padding(6)
                                        .background(Color(.controlBackgroundColor))
                                        .cornerRadius(4)
                                    
                                    Button(action: {
                                        // 显示用户侧滑面板
                                        hideAllPanels()
                                        withAnimation(.spring()) {
                                            isShowingUserPanel = true
                                        }
                                    }) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .help(L10n.Kubernetes.Context.View.User.details)
                                }
                            }
                        }
                        
                        // Namespace输入框
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.Kubernetes.Context.namespace)
                                .font(.headline)
                            
                            TextField(L10n.Kubernetes.Context.Namespace.optional, text: $editedNamespace)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(!isEditing)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .onChange(of: context) { _ in
                // 当上下文变化时，更新编辑状态中的值
                if !isEditing {
                    editedName = context.name
                    editedNamespace = context.context.namespace ?? ""
                }
            }
            .onAppear {
                // 确保第一次显示时值是正确的
                editedName = context.name
                editedNamespace = context.context.namespace ?? ""
            }
            
            // 侧滑面板 - 集群详情
            if isShowingClusterPanel {
                GeometryReader { geometry in
                    HStack {
                        Spacer()
                        ClusterDetailSidePanelView(
                            viewModel: viewModel,
                            isShowing: $isShowingClusterPanel,
                            clusterId: editedCluster,
                            clusterName: editedCluster,
                            onDismiss: {
                                withAnimation(.spring()) {
                                    isShowingClusterPanel = false
                                }
                            }
                        )
                        .frame(width: 350)
                        .offset(x: isShowingClusterPanel ? 0 : panelOffset)
                    }
                }
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
            
            // 侧滑面板 - 用户详情
            if isShowingUserPanel {
                GeometryReader { geometry in
                    HStack {
                        Spacer()
                        UserDetailSidePanelView(
                            viewModel: viewModel,
                            isShowing: $isShowingUserPanel,
                            userId: editedUser,
                            userName: editedUser,
                            onDismiss: {
                                withAnimation(.spring()) {
                                    isShowingUserPanel = false
                                }
                            }
                        )
                        .frame(width: 350)
                        .offset(x: isShowingUserPanel ? 0 : panelOffset)
                    }
                }
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
        }
        .disabled(isShowingClusterPanel || isShowingUserPanel) // 当显示侧滑面板时禁用主视图的交互
    }
    
    // 保存更改方法
    private func saveChanges() {
        // 验证名称不为空
        if editedName.trimmingCharacters(in: .whitespaces).isEmpty {
            viewModel.postMessage("错误：上下文名称不能为空", type: .error)
            return
        }
        
        // 验证集群和用户不为空
        if editedCluster.isEmpty || editedUser.isEmpty {
            viewModel.postMessage("错误：必须选择有效的集群和用户", type: .error)
            return
        }
        
        // 使用ViewModel的方法来更新上下文
        viewModel.updateKubeContext(
            id: context.id,
            name: editedName,
            cluster: editedCluster,
            user: editedUser,
            namespace: editedNamespace.isEmpty ? nil : editedNamespace
        )
    }
    
    // 隐藏所有侧滑面板
    private func hideAllPanels() {
        // Use DispatchQueue to ensure the animation completes
        withAnimation(.spring()) {
            isShowingClusterPanel = false
            isShowingUserPanel = false
        }
        
        // Add a delay to ensure bindings are updated consistently
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Ensure these are still false after any potential state conflicts
            withAnimation(nil) {
                self.isShowingClusterPanel = false
                self.isShowingUserPanel = false
            }
        }
    }
    
    // 更新选择的集群和用户
    private func updateSelections() {
        // 在编辑时更新选择项以匹配当前上下文的值
        editedCluster = context.context.cluster
        editedUser = context.context.user
    }
}

// MARK: - ClusterDetailSidePanelView

struct ClusterDetailSidePanelView: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var isShowing: Bool
    let clusterId: String
    let clusterName: String
    let onDismiss: () -> Void
    
    private var cluster: KubeCluster? {
        viewModel.kubeClusters.first { $0.id == clusterId }
    }
    
    private var clusterBinding: Binding<KubeCluster>? {
        guard let index = viewModel.kubeClusters.firstIndex(where: { $0.id == clusterId }) else {
            return nil
        }
        return Binding(
            get: { viewModel.kubeClusters[index] },
            set: { viewModel.kubeClusters[index] = $0 }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部栏
            HStack {
                Button(action: {
                    // Explicitly set the binding to false first
                    isShowing = false
                    // Then call the dismiss action
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(L10n.Kubernetes.Panel.Cluster.details)
                    .font(.headline)
                Spacer()
                Color.clear.frame(width: 24, height: 24) // 平衡布局
            }
            .padding()
            .background(Color(.windowBackgroundColor).opacity(0.9))
            
            Divider()
            
            // 内容区域
            if let clusterToEdit = clusterBinding, let _ = cluster {
                KubeClusterEditorView(viewModel: viewModel, cluster: clusterToEdit)
                    .padding(.top)
            } else {
                VStack {
                    Text(L10n.Kubernetes.Panel.Not.Found.cluster)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

// MARK: - UserDetailSidePanelView

struct UserDetailSidePanelView: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var isShowing: Bool
    let userId: String
    let userName: String
    let onDismiss: () -> Void
    
    private var user: KubeUser? {
        viewModel.kubeUsers.first { $0.id == userId }
    }
    
    private var userBinding: Binding<KubeUser>? {
        guard let index = viewModel.kubeUsers.firstIndex(where: { $0.id == userId }) else {
            return nil
        }
        return Binding(
            get: { viewModel.kubeUsers[index] },
            set: { viewModel.kubeUsers[index] = $0 }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部栏
            HStack {
                Button(action: {
                    // Explicitly set the binding to false first
                    isShowing = false
                    // Then call the dismiss action
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(L10n.Kubernetes.Panel.User.details)
                    .font(.headline)
                Spacer()
                Color.clear.frame(width: 24, height: 24) // 平衡布局
            }
            .padding()
            .background(Color(.windowBackgroundColor).opacity(0.9))
            
            Divider()
            
            // 内容区域
            if let userToEdit = userBinding, let _ = user {
                KubeUserEditorView(viewModel: viewModel, user: userToEdit)
                    .padding(.top)
            } else {
                VStack {
                    Text(L10n.Kubernetes.Panel.Not.Found.user)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject var previewViewModel = MainViewModel()
        @State var previewContext = KubeContext(
            name: "dev-context",
            context: ContextDetails(cluster: "dev-cluster", user: "dev-user", namespace: "development")
        )
        
        init() {
            // 添加一些预览数据
            let cluster = KubeCluster(
                name: "dev-cluster",
                cluster: ClusterDetails(
                    server: "https://kubernetes.example.com:6443",
                    certificateAuthorityData: "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURERENDQWZTZ0F3SUJBZ0lJRmVSUG9TREJSb3d3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TVRBM01UQXhNVE0wTXpCYUZ3MHpNVEEzTVRBeE1UTTBNekJhTUJVeApFekFSQmdOVkJBTVRDbXQxWW1WeWJtVjBaWE13Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLCkFvSUJBUUMwVU1KUE5VYStZZDZ3bXpiLzlXenpQZ0lHYnlmMEFxWGluOUc3WUVDTnVsQk1pbTFoc3NoMUxIMVkKNjJ3Q0tvUmFHc3ZqYTdxazZ4aG4xN2dMTXdoVi9PWlZSeDNDQjE2NWVPMFFtendvV0NzTjZRL2pXeDNEYzlpZwphbVRTZEVReHUzQWs2Qmd3djlFUkVrSXN5TTA5SEhSTmNKOUhJbUZPMlFsdjRJN0UxcmFUZ1hJeW5Pem9DNmgyCkFTS0ZFU3I4amdhYTdwcldrTVNLbjlvZ1VKYU5rdHVqQUFpR2pZRDBrNjE5aVBRQ2J0bTdvWEkvMGlMTDI3RmYKcTNISWRKYkxrTnNSUFJlQVN0eDVjb0pzSHJRS3dEQTB1ek83b05LMmJPeWtjcVBXOTRyRUE5V0M5ZnVNRmtHTgpZanJRcEI3aFEydk1kNW5IdnZqOUJjMGptVi9QQWdNQkFBR2pXVEJYTUE0R0ExVWREd0VCL3dRRUF3SUNwREFQCkJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJRcjRmTU5LWTcvdXZPdS9WRElsVktPS25CRThUQVYKQmdOVkhSRUVEakFNZ2dwcmRXSmxjbTVsZEdWek1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQkhQMHBHK1VsUgorWDdKdlZDY3NKRXdwRnlqSW54R0JPbEl6Q2FXekhTL01TdHkrdmZYdnFrQmZXSFI0cTZJbjh5YnVwWTRIT1NPCjQvWE9IWE1BTjFpSDk2QVQrTGsyQ1hwcE1Gd2Z3ZFh4bFB0SXdsMU5XVXg3SHdUWkw3Szlua1hvWjJ1dWFEQi8KelNJWURUaWdBQk5idlZMZVg0MmtpZW9EZ1lWeitrUjNETGw3S09Ib2NwcjlXYUVIa0lTWnZPYjBSRWJCZjZhSAphWFErYjZBdWhiMExqZ0hIWktIWTZWdTFLTmtVMWN2Ni8xYlJ1TGJ1dVl3dDdvU1BRYU9qd2U5Y2FtSldVazJCCmtrd1ZuQms2RlJnbUNrSzh1eU4zTzlsbHluMWdqYXFGUmlKVmZwZ0pZK3ZqSTI3RmdvZTNWcGVoVVlveFJKNWgKTC94ckYwSXpURGlHCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K",
                    insecureSkipTlsVerify: false
                )
            )
            
            let user = KubeUser(
                name: "dev-user",
                user: UserDetails(
                    clientCertificateData: "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNzVENDQVprQ0ZIUmVGMVZzeWpmb0UwL2h2M3AyS0c1MUJkb1lNQTBHQ1NxR1NJYjNEUUVCQ3dVQU1CVXgKRXpBUkJnTlZCQU1UQ210MVltVnlibVYwWlhNd0hoY05Nakl3TmpJME1qRTBOVEF3V2hjTk1qTXdOakkwTWpFMApOVEF3V2pBUE1RMHdDd1lEVlFRREV3UmhjbTFwTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCCkNnS0NBUUVBc0ZHMHBvZ1lFK2FOb2JZWVhXQXlXZE1Iak5sN0xwZm1qQWVHZ0J2ZmlPMkJFZElXSGQ3eWZjQnAKWjJ0VkxoU0hwQml3V0ltV0lVajVOdndqZzhqbm5pWldmYnNyYzZRQmNVbEo5MnZpL0xVRWhXYldaMmNqZjNmTApaY0tHbndtc1prVmpPc2RJNjRqOGlrZGw3VGpvTXpGbERROUhObHNZbVEwU05CenZiZkpZS1l2ZnFZMkVDcG8yCkoxQWFLQm5UbWhHS1hEWXJDbldiOGRTcEZTK0c4MkNXSXlVRDA5SWU0ZEVRZzlNMTlHeVlYdldNOEgxRGFUQkUKWnZUTFdZR1FwQ0I5OXczN3gvNnY2SUdOOUVCYW9LQnhzRUNPYTI4M21yNk5KVFJVR2ZXaEU5UEN0bnIya1NGcAplRWVoMExwQnJvTWdOQ2c0ZGtMcWtKcWFkRDg3SVFJREFRQUJNQTBHQ1NxR1NJYjNEUUVCQ3dVQUE0SUJBUUN4Ck5CVmdnWCtWMHJjck91TSt3aFVBcmZJZERrRW05VWUxTWxLZW9BMUs3OTBUa2FwWFZuUzdSVEdKY1ozUnQwUFoKRjZhS292US9pVE1OVk1RTk5NTWxSOHZpZTMvZU13SEZBYjdWTVA1TThTTDdsUklCS3FyTloxZk8wdklmcEJFVgpvQzRQTWVwWWtnWHF1OGJTVVZUU0YyTE5vS2pQTEtETGtQazRjQ0hCTFgrM1pPaElVb1paZXZZeGlkRHFDSHdYCnI3UG1jWEtBS0JzL0ZjWUpmNlZhL08yaXhiaEZrVWZQMldGdXJhYlYwdStXa1E1OTlOODVzVEZ2MFNVWEY3QTQKL1ZhRnlsR1NqNnMrRDlCS0QyMDVCVUVRbjNXaGhjVjE5SDdQNlRXREc5SWNGalNCcFZ2N3huKzBjb0tLRkg3VwpHbVJFbGlmbFE2cUpsWnV4TmJCdAotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==",
                    clientKeyData: "LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUV2QUlCQURBTkJna3Foa2lHOXcwQkFRRUZBQVNDQktZd2dnU2lBZ0VBQW9JQkFRQ3dVYlNtaUJnVDVvMmgKdGhoZFlESlowa2VNMlhzdWwrYU1CNGFBRzkrSTdZRVIwaFllM3ZKOXdHbG5hMVV1RkllbEdMQllpWlloU1BrMgovQ09EeU9lZUpsWjl1eXR6cEFGeFNVbjNhK0w4dFFTRlp0Wm5aeU4vZDh0bHdvYWZDYXhtUldNNngwanJpUHlLClIyWHRPT2d6TVdVTkQwYzJXeGlaRFJJMEhPOXQ4bGdwaTE",
                    token: nil
                )
            )
            
            // 添加到预览视图模型中
            previewViewModel.kubeClusters = [cluster]
            previewViewModel.kubeUsers = [user]
        }

        var body: some View {
            ZStack {
                KubeContextEditorView(viewModel: previewViewModel, context: $previewContext)
            }
            .frame(width: 700, height: 600)
        }
    }
    return PreviewWrapper()
} 