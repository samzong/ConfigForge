.PHONY: clean dmg check-arch update-homebrew

# 变量
APP_NAME = ConfigForge
BUILD_DIR = build
X86_64_ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME)-x86_64.xcarchive
ARM64_ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME)-arm64.xcarchive
X86_64_DMG_PATH = $(BUILD_DIR)/$(APP_NAME)-x86_64.dmg
ARM64_DMG_PATH = $(BUILD_DIR)/$(APP_NAME)-arm64.dmg
DMG_VOLUME_NAME = \"$(APP_NAME)\"

# 版本信息
GIT_COMMIT = $(shell git rev-parse --short HEAD)
VERSION ?= $(if $(CI_BUILD),$(shell git describe --tags --always),Dev-$(shell git rev-parse --short HEAD))
CLEAN_VERSION = $(shell echo $(VERSION) | sed 's/^v//')

# Homebrew 相关变量
HOMEBREW_TAP_REPO = homebrew-tap
CASK_FILE = Casks/configforge.rb
BRANCH_NAME = update-configforge-$(CLEAN_VERSION)

# 清理构建产物
clean:
	rm -rf $(BUILD_DIR)
	xcodebuild clean -scheme $(APP_NAME)

# 构建 x86_64 (Intel)
build-x86_64:
	@echo "==> 构建 x86_64 架构的应用..."
	xcodebuild clean archive \
		-project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Release \
		-archivePath $(X86_64_ARCHIVE_PATH) \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="-" \
		DEVELOPMENT_TEAM="" \
		CURRENT_PROJECT_VERSION=$(VERSION) \
		MARKETING_VERSION=$(VERSION) \
		ARCHS="x86_64" \
		OTHER_CODE_SIGN_FLAGS="--options=runtime"

# 构建 arm64 (Apple Silicon)
build-arm64:
	@echo "==> 构建 arm64 架构的应用..."
	xcodebuild clean archive \
		-project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Release \
		-archivePath $(ARM64_ARCHIVE_PATH) \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="-" \
		DEVELOPMENT_TEAM="" \
		CURRENT_PROJECT_VERSION=$(VERSION) \
		MARKETING_VERSION=$(VERSION) \
		ARCHS="arm64" \
		OTHER_CODE_SIGN_FLAGS="--options=runtime"

# 创建 DMG (构建 x86_64 和 arm64 版本)
dmg: build-x86_64 build-arm64
	# 导出 x86_64 归档
	xcodebuild -exportArchive \
		-archivePath $(X86_64_ARCHIVE_PATH) \
		-exportPath $(BUILD_DIR)/x86_64 \
		-exportOptionsPlist exportOptions.plist
	
	# 创建 x86_64 DMG 临时目录
	rm -rf $(BUILD_DIR)/tmp-x86_64
	mkdir -p $(BUILD_DIR)/tmp-x86_64
	
	# 复制应用到临时目录
	cp -r "$(BUILD_DIR)/x86_64/$(APP_NAME).app" "$(BUILD_DIR)/tmp-x86_64/"
	
	# 对 x86_64 应用进行自签名
	@echo "==> 对 x86_64 应用进行自签名..."
	codesign --force --deep --sign - "$(BUILD_DIR)/tmp-x86_64/$(APP_NAME).app"
	
	# 创建指向 Applications 文件夹的符号链接
	ln -s /Applications "$(BUILD_DIR)/tmp-x86_64/Applications"
	
	# 创建 x86_64 DMG
	hdiutil create -volname "$(DMG_VOLUME_NAME) (Intel)" \
		-srcfolder "$(BUILD_DIR)/tmp-x86_64" \
		-ov -format UDZO \
		"$(X86_64_DMG_PATH)"
	
	# 清理
	rm -rf $(BUILD_DIR)/tmp-x86_64 $(BUILD_DIR)/x86_64
	
	# 导出 arm64 归档
	xcodebuild -exportArchive \
		-archivePath $(ARM64_ARCHIVE_PATH) \
		-exportPath $(BUILD_DIR)/arm64 \
		-exportOptionsPlist exportOptions.plist
	
	# 创建 arm64 DMG 临时目录
	rm -rf $(BUILD_DIR)/tmp-arm64
	mkdir -p $(BUILD_DIR)/tmp-arm64
	
	# 复制应用到临时目录
	cp -r "$(BUILD_DIR)/arm64/$(APP_NAME).app" "$(BUILD_DIR)/tmp-arm64/"
	
	# 对 arm64 应用进行自签名
	@echo "==> 对 arm64 应用进行自签名..."
	codesign --force --deep --sign - "$(BUILD_DIR)/tmp-arm64/$(APP_NAME).app"
	
	# 创建指向 Applications 文件夹的符号链接
	ln -s /Applications "$(BUILD_DIR)/tmp-arm64/Applications"
	
	# 创建 arm64 DMG
	hdiutil create -volname "$(DMG_VOLUME_NAME) (Apple Silicon)" \
		-srcfolder "$(BUILD_DIR)/tmp-arm64" \
		-ov -format UDZO \
		"$(ARM64_DMG_PATH)"
	
	# 清理
	rm -rf $(BUILD_DIR)/tmp-arm64 $(BUILD_DIR)/arm64
	
	# 检查架构兼容性
	@make check-arch
	
	@echo "==> 所有 DMG 文件已创建:"
	@echo "    - x86_64 版本: $(X86_64_DMG_PATH)"
	@echo "    - arm64 版本: $(ARM64_DMG_PATH)"
	@echo ""
	@echo "注意: 这些应用使用了自签名，用户首次运行时可能需要在系统偏好设置中手动允许运行。"

# 检查架构兼容性
check-arch:
	@echo "==> 检查应用架构兼容性..."
	@if [ -f "$(X86_64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" ]; then \
		echo "==> 检查 x86_64 版本架构:"; \
		lipo -info "$(X86_64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)"; \
		if lipo -info "$(X86_64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" | grep -q "x86_64"; then \
			echo "✅ x86_64 版本支持 x86_64 架构"; \
		else \
			echo "❌ x86_64 版本不支持 x86_64 架构"; \
			exit 1; \
		fi; \
	fi
	
	@if [ -f "$(ARM64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" ]; then \
		echo "==> 检查 arm64 版本架构:"; \
		lipo -info "$(ARM64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)"; \
		if lipo -info "$(ARM64_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" | grep -q "arm64"; then \
			echo "✅ arm64 版本支持 arm64 架构"; \
		else \
			echo "❌ arm64 版本不支持 arm64 架构"; \
			exit 1; \
		fi; \
	fi

# 显示版本信息
version:
	@echo "版本:     $(VERSION)"
	@echo "Git 提交: $(GIT_COMMIT)"

# 更新 Homebrew Cask
update-homebrew:
	@echo "==> 开始 Homebrew cask 更新流程..."
	@if [ -z "$(GH_PAT)" ]; then \
		echo "❌ 错误: 需要设置 GH_PAT 环境变量"; \
		exit 1; \
	fi

	@echo "==> 当前版本信息:"
	@echo "    - VERSION: $(VERSION)"
	@echo "    - CLEAN_VERSION: $(CLEAN_VERSION)"

	@echo "==> 准备工作目录..."
	@rm -rf tmp && mkdir -p tmp
	
	@echo "==> 下载 DMG 文件..."
	@curl -L -o tmp/$(APP_NAME)-x86_64.dmg "https://github.com/samzong/$(APP_NAME)/releases/download/v$(CLEAN_VERSION)/$(APP_NAME)-x86_64.dmg"
	@curl -L -o tmp/$(APP_NAME)-arm64.dmg "https://github.com/samzong/$(APP_NAME)/releases/download/v$(CLEAN_VERSION)/$(APP_NAME)-arm64.dmg"
	
	@echo "==> 计算 SHA256 校验和..."
	@X86_64_SHA256=$$(shasum -a 256 tmp/$(APP_NAME)-x86_64.dmg | cut -d ' ' -f 1) && echo "    - x86_64 SHA256: $$X86_64_SHA256"
	@ARM64_SHA256=$$(shasum -a 256 tmp/$(APP_NAME)-arm64.dmg | cut -d ' ' -f 1) && echo "    - arm64 SHA256: $$ARM64_SHA256"
	
	@echo "==> 克隆 Homebrew tap 仓库..."
	@cd tmp && git clone https://$(GH_PAT)@github.com/samzong/$(HOMEBREW_TAP_REPO).git
	@cd tmp/$(HOMEBREW_TAP_REPO) && echo "    - 创建新分支: $(BRANCH_NAME)" && git checkout -b $(BRANCH_NAME)

	@echo "==> 更新 cask 文件..."
	@X86_64_SHA256=$$(shasum -a 256 tmp/$(APP_NAME)-x86_64.dmg | cut -d ' ' -f 1) && \
	ARM64_SHA256=$$(shasum -a 256 tmp/$(APP_NAME)-arm64.dmg | cut -d ' ' -f 1) && \
	echo "==> 再次确认SHA256: x86_64=$$X86_64_SHA256, arm64=$$ARM64_SHA256" && \
	cd tmp/$(HOMEBREW_TAP_REPO) && \
	echo "==> 当前目录: $$(pwd)" && \
	echo "==> CASK_FILE路径: $(CASK_FILE)" && \
	if [ -f $(CASK_FILE) ]; then \
		echo "    - 发现现有cask文件，使用sed更新..."; \
		echo "    - cask文件内容 (更新前):"; \
		cat $(CASK_FILE); \
		sed -i '' "s/version \\\".*\\\"/version \\\"$(CLEAN_VERSION)\\\"/g" $(CASK_FILE); \
		echo "    - 更新版本后的cask文件:"; \
		cat $(CASK_FILE); \
		if grep -q "Hardware::CPU.arm" $(CASK_FILE); then \
			echo "    - 更新ARM架构SHA256..."; \
			sed -i '' "/if Hardware::CPU.arm/,/else/ s/sha256 \\\".*\\\"/sha256 \\\"$$ARM64_SHA256\\\"/g" $(CASK_FILE); \
			echo "    - 更新Intel架构SHA256..."; \
			sed -i '' "/else/,/end/ s/sha256 \\\".*\\\"/sha256 \\\"$$X86_64_SHA256\\\"/g" $(CASK_FILE); \
			echo "    - 更新ARM下载URL..."; \
			sed -i '' "s|url \\\".*v#{version}/.*-ARM64.dmg\\\"|url \\\"https://github.com/samzong/$(APP_NAME)/releases/download/v#{version}/$(APP_NAME)-arm64.dmg\\\"|g" $(CASK_FILE); \
			echo "    - 更新Intel下载URL..."; \
			sed -i '' "s|url \\\".*v#{version}/.*-Intel.dmg\\\"|url \\\"https://github.com/samzong/$(APP_NAME)/releases/download/v#{version}/$(APP_NAME)-x86_64.dmg\\\"|g" $(CASK_FILE); \
			echo "    - 最终cask文件内容:"; \
			cat $(CASK_FILE); \
		else \
			echo "❌ 未知的 cask 格式，无法更新 SHA256 值"; \
			exit 1; \
		fi; \
	else \
		echo "    - 未找到cask文件，创建新文件..."; \
		mkdir -p $$(dirname $(CASK_FILE)); \
		echo "    - 使用文本方式创建cask文件..."; \
		echo 'cask "configforge" do' > $(CASK_FILE); \
		echo '  version "$(CLEAN_VERSION)"' >> $(CASK_FILE); \
		echo '' >> $(CASK_FILE); \
		echo '  if Hardware::CPU.arm?' >> $(CASK_FILE); \
		echo '    url "https://github.com/samzong/$(APP_NAME)/releases/download/v#{version}/$(APP_NAME)-arm64.dmg"' >> $(CASK_FILE); \
		echo '    sha256 "'$$ARM64_SHA256'"' >> $(CASK_FILE); \
		echo '  else' >> $(CASK_FILE); \
		echo '    url "https://github.com/samzong/$(APP_NAME)/releases/download/v#{version}/$(APP_NAME)-x86_64.dmg"' >> $(CASK_FILE); \
		echo '    sha256 "'$$X86_64_SHA256'"' >> $(CASK_FILE); \
		echo '  end' >> $(CASK_FILE); \
		echo '' >> $(CASK_FILE); \
		echo '  name "$(APP_NAME)"' >> $(CASK_FILE); \
		echo '  desc "配置文件管理工具"' >> $(CASK_FILE); \
		echo '  homepage "https://github.com/samzong/$(APP_NAME)"' >> $(CASK_FILE); \
		echo '' >> $(CASK_FILE); \
		echo '  app "$(APP_NAME).app"' >> $(CASK_FILE); \
		echo 'end' >> $(CASK_FILE); \
		echo "    - 检查创建的cask文件:"; \
		cat $(CASK_FILE) || echo "❌ 无法读取cask文件"; \
	fi
	
	@echo "==> 检查更改..."
	@cd tmp/$(HOMEBREW_TAP_REPO) && \
	if ! git diff --quiet $(CASK_FILE); then \
		echo "    - 检测到更改，创建 pull request..."; \
		git add $(CASK_FILE); \
		git config user.name "GitHub Actions"; \
		git config user.email "actions@github.com"; \
		git commit -m "chore: update $(APP_NAME) to v$(CLEAN_VERSION)"; \
		git push -u origin $(BRANCH_NAME); \
		echo "    - 准备创建PR数据..."; \
		pr_data=$$(printf '{\"title\":\"chore: update %s to v%s\",\"body\":\"Auto-generated PR\\\\n- Version: %s\\\\n- x86_64 SHA256: %s\\\\n- arm64 SHA256: %s\",\"head\":\"%s\",\"base\":\"main\"}' \
			"$(APP_NAME)" "$(CLEAN_VERSION)" "$(CLEAN_VERSION)" "$$X86_64_SHA256" "$$ARM64_SHA256" "$(BRANCH_NAME)"); \
		echo "    - PR数据: $$pr_data"; \
		curl -X POST \
			-H "Authorization: token $(GH_PAT)" \
			-H "Content-Type: application/json" \
			https://api.github.com/repos/samzong/$(HOMEBREW_TAP_REPO)/pulls \
			-d "$$pr_data"; \
		echo "✅ Pull request 创建成功"; \
	else \
		echo "❌ cask 文件中没有检测到更改"; \
		exit 1; \
	fi

	@echo "==> 清理临时文件..."
	@rm -rf tmp
	@echo "✅ Homebrew cask 更新流程完成"

# 帮助命令
help:
	@echo "可用命令:"
	@echo "  make clean           - 清理构建产物"
	@echo "  make dmg             - 创建 DMG 安装包 (Intel 和 Apple Silicon)"
	@echo "  make version         - 显示版本信息"
	@echo "  make check-arch      - 检查应用架构兼容性"
	@echo "  make update-homebrew - 更新 Homebrew cask (需要 GH_PAT)"

.DEFAULT_GOAL := help 