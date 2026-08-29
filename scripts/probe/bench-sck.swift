#!/usr/bin/env swift
// Benchmark a ScreenCaptureKit window capture of the Mactician emulator window,
// so it can be compared like-for-like against `adb exec-out screencap`.
//
// Also reports whether Screen Recording (TCC) is granted to the *calling*
// process — that permission is exactly what the adb path would remove from
// the product.
//
// Usage: swift bench-sck.swift <ownerNameSubstring> [seconds]

import AVFoundation
import CoreGraphics
import Foundation
import ScreenCaptureKit

let ownerFilter = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Mactician"
let seconds = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2]) ?? 5.0 : 5.0

final class Collector: NSObject, SCStreamOutput {
    var stamps: [UInt64] = []
    var firstSize: CGSize?
    private let lock = NSLock()
    func stream(_: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sb.isValid else { return }
        guard let att = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]], let st = att.first?[.status] as? Int,
            st == SCFrameStatus.complete.rawValue else { return }
        lock.lock(); defer { lock.unlock() }
        stamps.append(DispatchTime.now().uptimeNanoseconds)
        if firstSize == nil, let px = CMSampleBufferGetImageBuffer(sb) {
            firstSize = CGSize(width: CVPixelBufferGetWidth(px), height: CVPixelBufferGetHeight(px))
        }
    }

    func snapshot() -> ([UInt64], CGSize?) {
        lock.lock(); defer { lock.unlock() }; return (stamps, firstSize)
    }
}

func fail(_ m: String) -> Never {
    FileHandle.standardError.write((m + "\n").data(using: .utf8)!); exit(1)
}

let sem = DispatchSemaphore(value: 0)
Task {
    // CGPreflightScreenCaptureAccess: does THIS process hold Screen Recording?
    print("screen-recording-permission-preflight: \(CGPreflightScreenCaptureAccess())")

    let content: SCShareableContent
    do {
        content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    } catch {
        fail("SCShareableContent failed (usually = Screen Recording denied): \(error)")
    }

    let candidates = content.windows.filter {
        ($0.owningApplication?.applicationName ?? "").localizedCaseInsensitiveContains(ownerFilter)
            || ($0.title ?? "").localizedCaseInsensitiveContains(ownerFilter)
    }
    print("matching windows: \(candidates.count)")
    for w in candidates {
        print("  id=\(w.windowID) owner=\(w.owningApplication?.applicationName ?? "?") "
            + "bundle=\(w.owningApplication?.bundleIdentifier ?? "?") "
            + "title=\(w.title ?? "") frame=\(w.frame) layer=\(w.windowLayer)")
    }
    guard let target = candidates.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })
    else { fail("no window matched \"\(ownerFilter)\"") }
    print("target: id=\(target.windowID) frame=\(target.frame)")

    let cfg = SCStreamConfiguration()
    cfg.pixelFormat = kCVPixelFormatType_32BGRA
    cfg.minimumFrameInterval = CMTime(value: 1, timescale: 120) // ask for up to 120fps
    cfg.queueDepth = 6
    cfg.showsCursor = false
    cfg.scalesToFit = false
    // Capture at the window's backing-store resolution.
    let scale = NSScreen_backingScale()
    cfg.width = Int(target.frame.width * scale)
    cfg.height = Int(target.frame.height * scale)
    print("requested capture size: \(cfg.width)x\(cfg.height) (backingScale \(scale))")

    let filter = SCContentFilter(desktopIndependentWindow: target)
    let collector = Collector()
    let stream = SCStream(filter: filter, configuration: cfg, delegate: nil)
    do {
        try stream.addStreamOutput(
            collector,
            type: .screen,
            sampleHandlerQueue: DispatchQueue(label: "bench.sck")
        )
        try await stream.startCapture()
    } catch { fail("startCapture failed: \(error)") }

    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    try? await stream.stopCapture()

    let (stamps, size) = collector.snapshot()
    guard stamps.count > 2 else { fail("only \(stamps.count) frames — window may be static or occluded") }
    var deltas = zip(stamps.dropFirst(), stamps).map { Double($0 - $1) / 1_000_000.0 }
    deltas.sort()
    let mean = deltas.reduce(0, +) / Double(deltas.count)
    func pct(_ p: Double) -> Double {
        deltas[min(deltas.count - 1, Int(Double(deltas.count) * p))]
    }
    print(String(
        format:
        "frames=%d over %.1fs  delivered_fps=%.1f  interframe_ms min=%.2f p50=%.2f mean=%.2f p95=%.2f max=%.2f",
        stamps.count,
        seconds,
        Double(stamps.count) / seconds,
        deltas.first ?? 0,
        pct(0.5),
        mean,
        pct(0.95),
        deltas.last ?? 0
    ))
    print("delivered pixel buffer: \(size.map { "\(Int($0.width))x\(Int($0.height))" } ?? "n/a")")
    sem.signal()
}

/// Minimal AppKit-free backing-scale probe; ScreenCaptureKit runs headless fine.
func NSScreen_backingScale() -> CGFloat {
    guard let m = CGMainDisplayID() as CGDirectDisplayID?,
          let mode = CGDisplayCopyDisplayMode(m) else { return 2.0 }
    let px = CGFloat(mode.pixelWidth), pt = CGFloat(mode.width)
    return pt > 0 ? px / pt : 2.0
}

sem.wait()
