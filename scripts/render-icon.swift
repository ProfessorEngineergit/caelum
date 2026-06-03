#!/usr/bin/env swift
import AppKit
import Foundation

// Renders the Caelum app icon (1024×1024 PNG) — the brand mark on obsidian glass
// with an aurora glow. Run: swift scripts/render-icon.swift <out.png>

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-master.png"
let size: CGFloat = 1024

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF)/255,
            green: CGFloat((hex >> 8) & 0xFF)/255,
            blue: CGFloat(hex & 0xFF)/255, alpha: a)
}

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let full = NSRect(x: 0, y: 0, width: size, height: size)
let corner = size * 0.2237   // macOS squircle-ish radius
let shape = NSBezierPath(roundedRect: full, xRadius: corner, yRadius: corner)
shape.addClip()

// Obsidian base — radial deepening.
if let bg = NSGradient(colors: [color(0x141A37), color(0x06070D)]) {
    bg.draw(in: full, relativeCenterPosition: NSPoint(x: -0.1, y: 0.35))
}
// Aurora glows.
if let cyan = NSGradient(colors: [color(0x5EE7FF, 0.55), color(0x5EE7FF, 0)]) {
    cyan.draw(fromCenter: NSPoint(x: size*0.80, y: size*0.82), radius: 0,
              toCenter: NSPoint(x: size*0.80, y: size*0.82), radius: size*0.62, options: [])
}
if let magenta = NSGradient(colors: [color(0xFF6AD5, 0.32), color(0xFF6AD5, 0)]) {
    magenta.draw(fromCenter: NSPoint(x: size*0.18, y: size*0.16), radius: 0,
                 toCenter: NSPoint(x: size*0.18, y: size*0.16), radius: size*0.5, options: [])
}

// The mark.
let center = NSPoint(x: size/2, y: size/2)
let orbitW = size * 0.74
let orbitH = size * 0.32
let tilt: CGFloat = -24

let orbit = NSBezierPath(ovalIn: NSRect(x: center.x - orbitW/2, y: center.y - orbitH/2,
                                        width: orbitW, height: orbitH))
orbit.lineWidth = size * 0.030
let xform = NSAffineTransform()
xform.translateX(by: center.x, yBy: center.y)
xform.rotate(byDegrees: tilt)
xform.translateX(by: -center.x, yBy: -center.y)
let rotatedOrbit = xform.transform(orbit)

let glow = NSShadow()
glow.shadowColor = color(0x5EE7FF, 0.8)
glow.shadowBlurRadius = size * 0.05
glow.shadowOffset = .zero
glow.set()
color(0xB8AFFF).setStroke()
rotatedOrbit.stroke()

// Planet.
let pr = size * 0.085
let planetRect = NSRect(x: center.x - pr, y: center.y - pr, width: pr*2, height: pr*2)
NSShadow().set()
if let pg = NSGradient(colors: [color(0xFFFFFF), color(0xCBD2FF)]) {
    pg.draw(in: NSBezierPath(ovalIn: planetRect), relativeCenterPosition: NSPoint(x: -0.3, y: 0.3))
}

// Orbiting dot (upper-right).
let t: CGFloat = 0.12 * 2 * .pi
let ex = (orbitW/2) * cos(t), ey = (orbitH/2) * sin(t)
let rad = tilt * .pi / 180
let dot = NSPoint(x: center.x + ex*cos(rad) - ey*sin(rad),
                  y: center.y + ex*sin(rad) + ey*cos(rad))
let dr = size * 0.052
let dotGlow = NSShadow()
dotGlow.shadowColor = color(0x5EE7FF, 0.9)
dotGlow.shadowBlurRadius = size * 0.04
dotGlow.set()
color(0x5EE7FF).setFill()
NSBezierPath(ovalIn: NSRect(x: dot.x - dr, y: dot.y - dr, width: dr*2, height: dr*2)).fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("render-icon: failed to encode PNG\n".utf8))
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("Rendered icon → \(outPath)")
