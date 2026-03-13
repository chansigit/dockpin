import AppKit
import CoreGraphics
import Foundation

// MARK: - Display Info

struct DisplayInfo {
    let id: CGDirectDisplayID
    let bounds: CGRect
    let isMain: Bool
    let index: Int

    var description: String {
        let main = isMain ? " (main)" : ""
        return "\(index): \(Int(bounds.width))x\(Int(bounds.height))\(main) [ID: \(id)]"
    }
}

func getDisplays() -> [DisplayInfo] {
    var displayCount: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &displayCount)
    var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
    CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount)

    return displayIDs.prefix(Int(displayCount)).enumerated().map { index, id in
        DisplayInfo(
            id: id,
            bounds: CGDisplayBounds(id),
            isMain: CGDisplayIsMain(id) != 0,
            index: index + 1
        )
    }
}

// MARK: - Dock Detection

/// Find the Dock bar window and return which display it's on
func findDockDisplayID() -> CGDirectDisplayID? {
    guard let windowList = CGWindowListCopyWindowInfo(
        [.optionAll], kCGNullWindowID
    ) as? [[String: Any]] else {
        return nil
    }

    let dockLevel = Int(CGWindowLevelForKey(.dockWindow))

    for window in windowList {
        guard
            let ownerName = window[kCGWindowOwnerName as String] as? String,
            ownerName == "Dock",
            let layer = window[kCGWindowLayer as String] as? Int,
            layer == dockLevel,
            let boundsDict = window[kCGWindowBounds as String] as? [String: Any]
        else {
            continue
        }

        let x = (boundsDict["X"] as? NSNumber)?.doubleValue ?? 0
        let y = (boundsDict["Y"] as? NSNumber)?.doubleValue ?? 0
        let w = (boundsDict["Width"] as? NSNumber)?.doubleValue ?? 0
        let h = (boundsDict["Height"] as? NSNumber)?.doubleValue ?? 0
        let rect = CGRect(x: x, y: y, width: w, height: h)

        // Skip desktop-sized windows (Dock also manages desktop icons)
        // The actual dock bar is much smaller than the full screen
        let displays = getDisplays()
        for display in displays {
            if rect.width >= display.bounds.width && rect.height >= display.bounds.height {
                continue  // This is likely a desktop window, skip
            }
        }

        var displayID: CGDirectDisplayID = 0
        var count: UInt32 = 0
        CGGetDisplaysWithRect(rect, 1, &displayID, &count)

        if count > 0 {
            return displayID
        }
    }
    return nil
}

// MARK: - Dock Relocation

func moveDockToDisplay(_ target: DisplayInfo) {
    // Save current mouse position (NSEvent uses bottom-left origin)
    let savedNS = NSEvent.mouseLocation

    // Target: bottom-center of the target display (CoreGraphics uses top-left origin)
    let targetPoint = CGPoint(
        x: target.bounds.midX,
        y: target.bounds.maxY - 1  // Bottom edge in CG coords
    )

    // Warp cursor to target display bottom edge to trigger Dock movement
    CGWarpMouseCursorPosition(targetPoint)

    // Brief pause to let macOS register the Dock move
    usleep(150_000)  // 150ms

    // Convert saved NSEvent coords back to CG coords and restore
    guard let mainScreen = NSScreen.screens.first else { return }
    let mainHeight = mainScreen.frame.height
    let restoredPoint = CGPoint(x: savedNS.x, y: mainHeight - savedNS.y)
    CGWarpMouseCursorPosition(restoredPoint)

    // Re-associate mouse with cursor movement
    CGAssociateMouseAndMouseCursorPosition(1)
}

// MARK: - Commands

func listDisplays() {
    let displays = getDisplays()
    if displays.isEmpty {
        print("No displays found.")
        return
    }
    print("Available displays:")
    for display in displays {
        print("  \(display.description)")
    }
}

func lockDock(displayNumber: Int, interval: UInt32 = 500_000) {
    let displays = getDisplays()
    guard let target = displays.first(where: { $0.index == displayNumber }) else {
        print("Error: Display \(displayNumber) not found.")
        print("Use 'dockpin list' to see available displays.")
        exit(1)
    }

    print("Pinning Dock to display \(target.index): \(Int(target.bounds.width))x\(Int(target.bounds.height))")
    print("Press Ctrl+C to stop.\n")

    // Handle Ctrl+C gracefully
    signal(SIGINT) { _ in
        print("\nDock unpinned. Bye!")
        exit(0)
    }

    // Initial move
    if let currentDisplay = findDockDisplayID(), currentDisplay != target.id {
        print("Moving Dock to target display...")
        moveDockToDisplay(target)
    }

    // Polling loop
    while true {
        usleep(interval)

        guard let currentDisplay = findDockDisplayID() else {
            continue
        }

        if currentDisplay != target.id {
            print("[\(timestamp())] Dock drifted — moving back to display \(target.index)")
            moveDockToDisplay(target)
        }
    }
}

func timestamp() -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "HH:mm:ss"
    return fmt.string(from: Date())
}

// MARK: - Main

func printUsage() {
    print("""
    DockPin — Pin your macOS Dock to one screen

    Usage:
      dockpin list                List available displays
      dockpin pin <display#>      Pin Dock to a display (runs until Ctrl+C)
      dockpin status              Show which display the Dock is currently on

    Example:
      dockpin list
      dockpin pin 2
    """)
}

let args = CommandLine.arguments

guard args.count >= 2 else {
    printUsage()
    exit(0)
}

switch args[1] {
case "list":
    listDisplays()

case "pin":
    guard args.count >= 3, let num = Int(args[2]) else {
        print("Usage: dockpin pin <display#>")
        print("Run 'dockpin list' to see available displays.")
        exit(1)
    }
    lockDock(displayNumber: num)

case "status":
    let displays = getDisplays()
    if let dockDisplay = findDockDisplayID(),
       let info = displays.first(where: { $0.id == dockDisplay }) {
        print("Dock is on display \(info.description)")
    } else {
        print("Could not determine Dock's current display.")
        print("Make sure you have screen recording permission enabled for Terminal.")
    }

case "-h", "--help", "help":
    printUsage()

default:
    print("Unknown command: \(args[1])")
    printUsage()
    exit(1)
}
