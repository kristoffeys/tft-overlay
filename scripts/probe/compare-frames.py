#!/usr/bin/env python3
"""Diff a ScreenCaptureKit window frame against an adb guest framebuffer frame.

The SCK frame includes the macOS title bar, so the guest content is the bottom
`guest_h` rows. Reports geometry, per-channel mean/max absolute difference and
the fraction of pixels that differ at all — i.e. whether the host capture is a
faithful copy of the guest framebuffer or a resampled/colour-managed version.

Usage: compare-frames.py <sck.png> <adb.png>
"""
import subprocess, sys, tempfile, os

def load(path):
    """Decode PNG to raw RGBA via sips, avoiding a numpy/Pillow dependency."""
    import struct
    d = open(path, 'rb').read()
    w, h = struct.unpack('>II', d[16:24])
    tmp = tempfile.mktemp(suffix='.tiff')
    subprocess.run(['sips', '-s', 'format', 'tiff', path, '--out', tmp],
                   capture_output=True, check=True)
    return w, h, tmp

try:
    import numpy as np
    from PIL import Image
except ImportError:
    print("needs numpy+Pillow: python3 -m pip install --user numpy pillow")
    sys.exit(2)

sck = np.array(Image.open(sys.argv[1]).convert('RGB'), dtype=np.int16)
adb = np.array(Image.open(sys.argv[2]).convert('RGB'), dtype=np.int16)
print(f"sck  {sck.shape[1]}x{sck.shape[0]}")
print(f"adb  {adb.shape[1]}x{adb.shape[0]}  (guest framebuffer)")

gh, gw = adb.shape[0], adb.shape[1]
if sck.shape[1] != gw:
    print(f"WIDTH MISMATCH: host window content is {sck.shape[1]}px wide vs guest {gw}px "
          f"-> host capture is RESAMPLED by {sck.shape[1]/gw:.4f}x; not 1:1.")
    sys.exit(0)

chrome = sck.shape[0] - gh
print(f"title-bar / chrome rows in SCK frame: {chrome}px")
crop = sck[chrome:chrome + gh, :, :]
diff = np.abs(crop - adb)
print(f"mean|diff| per channel R/G/B: {diff[:,:,0].mean():.2f} "
      f"{diff[:,:,1].mean():.2f} {diff[:,:,2].mean():.2f}")
print(f"max|diff|: {diff.max()}")
exact = (diff.max(axis=2) == 0).mean()
near = (diff.max(axis=2) <= 2).mean()
print(f"pixels exactly equal: {exact*100:.2f}%   within +/-2: {near*100:.2f}%")
