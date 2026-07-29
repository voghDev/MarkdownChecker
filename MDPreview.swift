import Cocoa
import WebKit

// Receives save messages from JavaScript and writes directly to disk
class SaveHandler: NSObject, WKScriptMessageHandler {
    var targetPath = ""

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "save",
              let content = message.body as? String,
              !targetPath.isEmpty else { return }
        do {
            try content.write(toFile: targetPath, atomically: true, encoding: .utf8)
        } catch {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Save failed"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    let saveHandler = SaveHandler()

    func applicationWillFinishLaunching(_ notification: Notification) {
        buildWindow()
        setupMenu()
    }

    func setupMenu() {
        let mainMenu = NSMenu()

        // Application menu (macOS always uses the first menu for the app name)
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit MarkdownPreview",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu

        // File menu
        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        let saveItem = fileMenu.addItem(withTitle: "Save",
                                        action: #selector(saveDocument),
                                        keyEquivalent: "s")
        saveItem.target = self
        fileItem.submenu = fileMenu

        NSApp.mainMenu = mainMenu
    }

    @objc func saveDocument() {
        webView.evaluateJavaScript("manualSave()") { _, _ in }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Support direct CLI invocation: MDPreview /path/to/file.md
        let args = CommandLine.arguments
        if args.count > 1, FileManager.default.fileExists(atPath: args[1]) {
            openMarkdownFile(at: args[1])
        }
    }

    func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Markdown Preview"
        window.isReleasedWhenClosed = false

        let config = WKWebViewConfiguration()
        config.userContentController.add(saveHandler, name: "save")

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        window.contentView!.addSubview(webView)
    }

    // Called by macOS when the app is opened via "Open With"
    func application(_ app: NSApplication, openFile filename: String) -> Bool {
        openMarkdownFile(at: filename)
        return true
    }

    func openMarkdownFile(at path: String) {
        saveHandler.targetPath = path

        let scriptPath = Bundle.main.bundlePath + "/Contents/Resources/preview.sh"
        let task = Process()
        let pipe = Pipe()
        var env = ProcessInfo.processInfo.environment
        env["MDPREVIEW_OUTPUT"] = "path"   // tells preview.sh to print the HTML path instead of opening a browser
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [scriptPath, path]
        task.environment = env
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do { try task.run() } catch { return }
        task.waitUntilExit()

        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let htmlPath = out.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !htmlPath.isEmpty else { return }

        let htmlURL = URL(fileURLWithPath: htmlPath)
        // Allow access to /tmp/ so the HTML file and its temp siblings can be read
        webView.loadFileURL(htmlURL, allowingReadAccessTo: URL(fileURLWithPath: "/tmp/"))

        window.title = URL(fileURLWithPath: path).lastPathComponent
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
