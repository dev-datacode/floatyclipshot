//
//  MainPanelView.swift
//  floatyclipshot
//
//  Main application panel with sidebar navigation (Apple-style)
//

import SwiftUI
import AppKit
import Combine

// MARK: - Navigation Item

enum NavigationItem: String, CaseIterable, Identifiable {
    case capture = "Capture"
    case windows = "Windows"
    case pairings = "Pairings"
    case clipboard = "Clipboard"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .capture: return "camera.fill"
        case .windows: return "macwindow.on.rectangle"
        case .pairings: return "link.circle.fill"
        case .clipboard: return "doc.on.clipboard"
        case .settings: return "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .capture: return .blue
        case .windows: return .purple
        case .pairings: return .orange
        case .clipboard: return .green
        case .settings: return .gray
        }
    }
}

// MARK: - Main Panel State

class MainPanelState: ObservableObject {
    @Published var selectedItem: NavigationItem = .capture
}

// MARK: - Main Panel View

struct MainPanelView: View {
    @ObservedObject var state: MainPanelState
    @ObservedObject private var screenshotManager = ScreenshotManager.shared
    @ObservedObject private var windowManager = WindowManager.shared
    @ObservedObject private var pairingManager = PairingManager.shared
    @ObservedObject private var clipboardManager = ClipboardManager.shared

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(NavigationItem.allCases, selection: $state.selectedItem) { item in
                NavigationLink(value: item) {
                    Label {
                        Text(item.rawValue)
                    } icon: {
                        Image(systemName: item.icon)
                            .foregroundStyle(item.color)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
            .listStyle(.sidebar)
        } detail: {
            // Detail view based on selection with smooth transitions
            Group {
                switch state.selectedItem {
                case .capture:
                    CaptureDetailView()
                case .windows:
                    WindowsDetailView()
                case .pairings:
                    PairingsDetailView()
                case .clipboard:
                    ClipboardDetailView()
                case .settings:
                    SettingsDetailView()
                }
            }
            .frame(minWidth: 450, minHeight: 400)
            .transition(.glassAppear)
            .animation(GlassDesign.Animation.smooth, value: state.selectedItem)
        }
        .frame(minWidth: 650, minHeight: 450)
    }
}

// MARK: - Panel Window Controller

class MainPanelController {
    static let shared = MainPanelController()

    private var window: NSWindow?
    let state = MainPanelState()

    func show(tab: NavigationItem? = nil) {
        if let tab = tab {
            // Use Task to ensure UI update happens on main thread
            Task { @MainActor in
                state.selectedItem = tab
            }
        }

        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panelView = MainPanelView(state: state)
        let hostingController = NSHostingController(rootView: panelView)

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "FloatyClipshot"
        newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        newWindow.setContentSize(NSSize(width: 750, height: 500))
        newWindow.minSize = NSSize(width: 650, height: 450)
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        // Make it a floating panel that stays above other windows
        newWindow.level = .floating
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Toolbar
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.displayMode = .iconOnly
        newWindow.toolbar = toolbar
        newWindow.toolbarStyle = .unified

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }

    func toggle() {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.close()
        } else {
            show()
        }
    }
}

#Preview {
    MainPanelView(state: MainPanelState())
        .frame(width: 750, height: 500)
}