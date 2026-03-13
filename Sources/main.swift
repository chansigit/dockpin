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

// MARK: - Dock Orientation

func getDockOrientation() -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    task.arguments = ["read", "com.apple.dock", "orientation"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    try? task.run()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return output.isEmpty ? "bottom" : output
}

// MARK: - Dock Window Detection (for status command)

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

        // Skip desktop-sized windows (Dock process also manages desktop icons)
        let displays = getDisplays()
        var isDesktopWindow = false
        for display in displays {
            if rect.width >= display.bounds.width && rect.height >= display.bounds.height {
                isDesktopWindow = true
                break
            }
        }
        if isDesktopWindow { continue }

        var displayID: CGDirectDisplayID = 0
        var count: UInt32 = 0
        CGGetDisplaysWithRect(rect, 1, &displayID, &count)

        if count > 0 {
            return displayID
        }
    }
    return nil
}

// MARK: - Event Tap (core pinning mechanism)

// Instead of polling and trying to move the Dock back (unreliable),
// we intercept mouse events and prevent the cursor from reaching
// the Dock activation zone on non-target displays.
// The Dock simply never activates on the wrong screen.

var gTargetDisplayID: CGDirectDisplayID = 0
var gDockEdge: String = "bottom"
var gEventTap: CFMachPort?

/// How many pixels from the edge to block on non-target displays
let kEdgeBlockZone: CGFloat = 6

func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Re-enable tap if macOS disabled it (happens on processing timeout)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = gEventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    let point = event.location

    // Which display is the mouse on?
    var displayID: CGDirectDisplayID = 0
    var count: UInt32 = 0
    let pointRect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
    CGGetDisplaysWithRect(pointRect, 1, &displayID, &count)

    // If on the target display (or can't determine), pass through unchanged
    guard count > 0, displayID != gTargetDisplayID else {
        return Unmanaged.passUnretained(event)
    }

    // Mouse is on a non-target display — clamp it away from the dock edge
    let db = CGDisplayBounds(displayID)
    var clamped = point
    var needsClamp = false

    switch gDockEdge {
    case "bottom":
        if point.y >= db.maxY - kEdgeBlockZone {
            clamped.y = db.maxY - kEdgeBlockZone - 1
            needsClamp = true
        }
    case "left":
        if point.x <= db.minX + kEdgeBlockZone {
            clamped.x = db.minX + kEdgeBlockZone + 1
            needsClamp = true
        }
    case "right":
        if point.x >= db.maxX - kEdgeBlockZone {
            clamped.x = db.maxX - kEdgeBlockZone - 1
            needsClamp = true
        }
    default:
        // Default to bottom
        if point.y >= db.maxY - kEdgeBlockZone {
            clamped.y = db.maxY - kEdgeBlockZone - 1
            needsClamp = true
        }
    }

    if needsClamp {
        event.location = clamped
    }

    return Unmanaged.passUnretained(event)
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

func showStatus() {
    let displays = getDisplays()
    if let dockDisplay = findDockDisplayID(),
       let info = displays.first(where: { $0.id == dockDisplay }) {
        print("Dock is on display \(info.description)")
    } else {
        print("Could not determine Dock's current display.")
        print("Grant Screen Recording permission to your terminal app:")
        print("  System Settings > Privacy & Security > Screen Recording")
    }
    print("Dock position: \(getDockOrientation())")
}

func pinDock(displayNumber: Int) {
    let displays = getDisplays()
    guard let target = displays.first(where: { $0.index == displayNumber }) else {
        print("Error: Display \(displayNumber) not found.")
        print("Use 'dockpin list' to see available displays.")
        exit(1)
    }

    gTargetDisplayID = target.id
    gDockEdge = getDockOrientation()

    print("Pinning Dock to display \(target.index): \(Int(target.bounds.width))x\(Int(target.bounds.height))")
    print("Dock position: \(gDockEdge)")
    print("Blocking dock activation on all other displays.")
    print("Press Ctrl+C to stop.\n")

    // Create event tap to intercept mouse movements
    let eventMask: CGEventMask =
        (1 << CGEventType.mouseMoved.rawValue)
        | (1 << CGEventType.leftMouseDragged.rawValue)
        | (1 << CGEventType.rightMouseDragged.rawValue)

    guard let tap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: eventTapCallback,
        userInfo: nil
    ) else {
        print("Error: Failed to create event tap.")
        print("")
        print("Grant Accessibility permission to your terminal app:")
        print("  System Settings > Privacy & Security > Accessibility")
        print("")
        print("Then restart your terminal and try again.")
        exit(1)
    }

    gEventTap = tap

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)

    signal(SIGINT) { _ in
        print("\nDock unpinned. Bye!")
        exit(0)
    }

    print("Running... (mouse cannot trigger Dock on other displays)")

    // Run the event loop — blocks here until Ctrl+C
    CFRunLoopRun()
}

// MARK: - Main

func printUsage() {
    print("""
    DockPin — Pin your macOS Dock to one screen

    Usage:
      dockpin list                List available displays
      dockpin pin <display#>      Pin Dock to a display (runs until Ctrl+C)
      dockpin status              Show current Dock display and position

    Example:
      dockpin list
      dockpin pin 2

    Permissions required:
      - Accessibility (for pin command — to intercept mouse events)
      - Screen Recording (for status command — to read window info)
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
    pinDock(displayNumber: num)

case "status":
    showStatus()

case "-h", "--help", "help":
    printUsage()

default:
    print("Unknown command: \(args[1])")
    printUsage()
    exit(1)
}
