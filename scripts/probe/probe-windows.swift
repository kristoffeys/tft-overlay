#!/usr/bin/env swift
// Enumerate on-screen windows via CGWindowListCopyWindowInfo.
//
// Answers: which process OWNS the window TFT renders into, at what bounds,
// on what layer. Bounds/owner/layer need no TCC permission; kCGWindowName
// (the title) requires Screen Recording, so an empty title column is itself
// a signal that this process lacks that permission.
//
// Usage: swift probe-windows.swift [filterSubstring]

import CoreGraphics
import Foundation

let filter = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1].lowercased() : nil

guard let raw = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
) as? [[String: Any]] else {
    FileHandle.standardError.write("CGWindowListCopyWindowInfo returned nil\n".data(using: .utf8)!)
    exit(1)
}

func f(_ d: [String: Any], _ k: String) -> Double {
    (d[k] as? NSNumber)?.doubleValue ?? -1
}

print("windowID\tpid\tlayer\towner\ttitle\tx\ty\tw\th\talpha\tonscreen")
for w in raw {
    let owner = (w[kCGWindowOwnerName as String] as? String) ?? "?"
    let title = (w[kCGWindowName as String] as? String) ?? ""
    if let filter, !owner.lowercased().contains(filter), !title.lowercased().contains(filter) {
        continue
    }
    let b = (w[kCGWindowBounds as String] as? [String: Any]) ?? [:]
    let cols: [String] = [
        String(Int(f(w, kCGWindowNumber as String))),
        String(Int(f(w, kCGWindowOwnerPID as String))),
        String(Int(f(w, kCGWindowLayer as String))),
        owner, title,
        String(Int(f(b, "X"))), String(Int(f(b, "Y"))),
        String(Int(f(b, "Width"))), String(Int(f(b, "Height"))),
        String(format: "%.2f", (w[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? -1),
        String((w[kCGWindowIsOnscreen as String] as? Bool) ?? false),
    ]
    print(cols.joined(separator: "\t"))
}
