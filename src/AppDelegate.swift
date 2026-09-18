import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var popoverContent: PopoverController!
    let bluetooth = BluetoothManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPopover()
        setupStatusItem()
        
        bluetooth.onStateUpdate = { [weak self] state in
            DispatchQueue.main.async {
                self?.popoverContent.syncUI(with: state)
            }
        }
        
        bluetooth.connect()
    }
    
    func setupPopover() {
        popoverContent = PopoverController()
        popoverContent.loadViewIfNeeded()
        popover.contentSize = NSSize(width: 310, height: 480)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = popoverContent
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
                if let image = ImageLoader.image(named: "wf_sp800n_color_00_01_sca", size: NSSize(width: 20, height: 20)) {
                button.image = image
            } else {
                button.title = "🎧"
            }
            button.toolTip = L10n.text("controlPanel")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if !bluetooth.state.isConnected {
                bluetooth.refreshStatus()
            }
            popoverContent.syncUI(with: bluetooth.state)
            
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
