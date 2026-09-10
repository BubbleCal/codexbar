import AppKit
import Foundation
import UniformTypeIdentifiers

/// 选择一个 Codex `auth.json` 文件用于导入。
///
/// 面板动作以闭包注入，测试可以在不弹出真实 NSOpenPanel 的情况下覆盖交互流程。
@MainActor
struct OpenAIAuthJSONPanelService {
    typealias AppActivator = @MainActor () -> Void
    typealias ImportURLRequester = @MainActor () -> URL?

    private let activateApp: AppActivator
    private let requestImportURLAction: ImportURLRequester

    init(
        activateApp: @escaping AppActivator = { OpenAIAuthJSONPanelService.activateApp() },
        requestImportURLAction: @escaping ImportURLRequester = {
            OpenAIAuthJSONPanelService.presentImportPanel()
        }
    ) {
        self.activateApp = activateApp
        self.requestImportURLAction = requestImportURLAction
    }

    func requestImportURL() -> URL? {
        // 菜单栏应用必须先抢占焦点，否则模态面板不会出现在最前。
        self.activateApp()
        return self.requestImportURLAction()
    }

    private static func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func presentImportPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.title = L.importOpenAIAuthJSONAction
        panel.prompt = L.openAICSVImportPrompt
        panel.message = L.importOpenAIAuthJSONPanelMessage
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowsOtherFileTypes = false
        panel.allowedContentTypes = [.json]
        // auth.json 位于 ~/.codex，默认是隐藏目录，不展开用户无法定位到它。
        panel.showsHiddenFiles = true
        panel.directoryURL = CodexPaths.codexRoot
        return panel.runModal() == .OK ? panel.url : nil
    }
}
