#!/usr/bin/env swift
// Grab ONE ScreenCaptureKit frame of a window and write it as PNG, so it can
// be diffed pixel-for-pixel against `adb exec-out screencap -p`.
// Usage: swift grab-sck-frame.swift <ownerSubstring> <out.png>

import CoreGraphics
import CoreImage
import Foundation
import ScreenCaptureKit

let ownerFilter = CommandLine.arguments[1]
let outPath = CommandLine.arguments[2]

final class Grabber: NSObject, SCStreamOutput {
    var image: CGImage?
    let sem = DispatchSemaphore(value: 0)
    private var done = false
    func stream(_: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of t: SCStreamOutputType) {
        guard !done, t == .screen, let px = CMSampleBufferGetImageBuffer(sb) else { return }
        guard let att = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]], let st = att.first?[.status] as? Int,
            st == SCFrameStatus.complete.rawValue else { return }
        let ci = CIImage(cvPixelBuffer: px)
        image = CIContext().createCGImage(ci, from: ci.extent)
        done = true
        sem.signal()
    }
}

let outer = DispatchSemaphore(value: 0)
Task {
    let content = try! await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    let w = content.windows
        .filter { ($0.owningApplication?.applicationName ?? "").localizedCaseInsensitiveContains(ownerFilter) }
        .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }!
    let scale = { () -> CGFloat in
        guard let m = CGDisplayCopyDisplayMode(CGMainDisplayID()) else { return 2 }
        return CGFloat(m.pixelWidth) / CGFloat(m.width)
    }()
    let cfg = SCStreamConfiguration()
    cfg.pixelFormat = kCVPixelFormatType_32BGRA
    cfg.width = Int(w.frame.width * scale)
    cfg.height = Int(w.frame.height * scale)
    cfg.showsCursor = false
    cfg.scalesToFit = false
    cfg.captureResolution = .best
    let g = Grabber()
    let stream = SCStream(filter: SCContentFilter(desktopIndependentWindow: w), configuration: cfg, delegate: nil)
    try! stream.addStreamOutput(g, type: .screen, sampleHandlerQueue: .global())
    try! await stream.startCapture()
    _ = g.sem.wait(timeout: .now() + 5)
    try? await stream.stopCapture()
    guard let img = g.image else { FileHandle.standardError.write("no frame\n".data(using: .utf8)!); exit(1) }
    let url = URL(fileURLWithPath: outPath) as CFURL
    let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(outPath) \(img.width)x\(img.height) window=\(w.frame) scale=\(scale)")
    outer.signal()
}

outer.wait()
