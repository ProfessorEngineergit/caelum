import AppKit
import MetalKit

/// The intro's hyperspace jump, drawn by one Metal fragment shader over the
/// user's own wallpaper:
///
///   0.3–2.6 s  the desktop turns liquid — a rippling, softly swirling lens grows
///              out of the centre with a glassy aurora rim
///   2.2–4.3 s  hyperspace — the image is pulled into the centre with a radial
///              zoom blur while star streaks race outwards
///   ~4.4 s     the flash ("BÄFF") — `onFlash` fires so sound and setup land on it
///   4.4 s →    the streaks slow into a calm, drifting starfield behind the setup
///
/// The shader is compiled at runtime from source (no .metal build step in
/// SwiftPM). It renders below native resolution — it's all motion and blur —
/// and skips the costly image samples once the desktop is gone.
final class WarpView: MTKView {
    /// Called once, on the main thread, when the flash peaks.
    var onFlash: (() -> Void)?
    static let flashTime: Float = 4.4

    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let wallpaper: MTLTexture
    private var start = CACurrentMediaTime()
    private var flashed = false
    private let resolutionScale: CGFloat = 0.7

    private struct Uniforms {
        var res: SIMD2<Float>
        var texSize: SIMD2<Float>
        var time: Float
        var scale: Float
    }

    /// `nil` when Metal or the shader is unavailable — the intro then skips the jump.
    init?(frame: CGRect, wallpaper image: CGImage?) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        do {
            let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "warpVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "warpFragment")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            NSLog("Caelum: warp shader unavailable: \(error.localizedDescription)")
            return nil
        }
        guard let texture = Self.makeTexture(image, device: device) else { return nil }
        self.queue = queue
        self.wallpaper = texture
        super.init(frame: frame, device: device)
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        autoResizeDrawable = false
        preferredFramesPerSecond = 60
        updateDrawableSize()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Restarts the timeline — call right before the window appears.
    func restart() {
        start = CACurrentMediaTime()
        flashed = false
        isPaused = false
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateDrawableSize()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSize()
    }

    private func updateDrawableSize() {
        let backing = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let scale = backing * resolutionScale
        drawableSize = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
    }

    override func draw(_ dirtyRect: NSRect) {
        let time = Float(CACurrentMediaTime() - start)
        if !flashed && time >= Self.flashTime {
            flashed = true
            onFlash?()
        }
        guard let pass = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let commands = queue.makeCommandBuffer(),
              let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }
        let backing = window?.backingScaleFactor ?? 2
        var uniforms = Uniforms(
            res: SIMD2(Float(drawableSize.width), Float(drawableSize.height)),
            texSize: SIMD2(Float(wallpaper.width), Float(wallpaper.height)),
            time: time,
            scale: Float(backing * resolutionScale))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentTexture(wallpaper, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commands.present(drawable)
        commands.commit()
    }

    // MARK: - Wallpaper texture

    /// The wallpaper as a texture; a deep-space pixel when it can't be read
    /// (e.g. a dynamic wallpaper the image loader doesn't understand).
    private static func makeTexture(_ image: CGImage?, device: MTLDevice) -> MTLTexture? {
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [.SRGB: false, .textureUsage: MTLTextureUsage.shaderRead.rawValue]
        if let image, let texture = try? loader.newTexture(cgImage: image, options: options) {
            return texture
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        var pixel: [UInt8] = [6, 7, 13, 255]
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &pixel, bytesPerRow: 4)
        return texture
    }

    /// The image currently on the desktop of `screen`, as macOS shows it.
    static func desktopImage(for screen: NSScreen) -> CGImage? {
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let image = NSImage(contentsOf: url) else { return nil }
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    // MARK: - Shader

    private static let shaderSource = #"""
    #include <metal_stdlib>
    using namespace metal;

    struct Uniforms { float2 res; float2 texSize; float time; float scale; };
    struct VOut { float4 position [[position]]; float2 uv; };

    // One oversized triangle covering the screen; uv (0,0) is the top-left.
    vertex VOut warpVertex(uint vid [[vertex_id]]) {
        float2 p = float2((vid << 1) & 2, vid & 2);
        VOut o;
        o.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
        o.uv = float2(p.x, 1.0 - p.y);
        return o;
    }

    constant float TAU = 6.2831853;

    static float hash1(float n) { return fract(sin(n) * 43758.5453123); }

    // Aspect-fill, like "Fill Screen" on the desktop.
    static float2 coverUV(float2 uv, constant Uniforms &u) {
        float sa = u.res.x / u.res.y, ta = u.texSize.x / u.texSize.y;
        float2 s = sa > ta ? float2(1.0, ta / sa) : float2(sa / ta, 1.0);
        return (uv - 0.5) * s + 0.5;
    }

    static float3 spaceBackdrop(float2 p, float t) {
        float3 col = float3(0.012, 0.014, 0.03);
        float2 a = float2(0.25 * sin(t * 0.07), -0.12 + 0.08 * cos(t * 0.05));
        float2 b = float2(0.55 + 0.1 * cos(t * 0.06), 0.35 + 0.06 * sin(t * 0.08));
        col += float3(0.33, 0.27, 0.85) * 0.22 * exp(-dot(p - a, p - a) * 3.2);
        col += float3(0.20, 0.65, 0.85) * 0.12 * exp(-dot(p - b, p - b) * 4.0);
        col += float3(0.80, 0.30, 0.70) * 0.06 * exp(-dot(p + b, p + b) * 3.0);
        return col;
    }

    fragment float4 warpFragment(VOut in [[stage_in]],
                                 constant Uniforms &u [[buffer(0)]],
                                 texture2d<float> tex [[texture(0)]]) {
        constexpr sampler smp(address::clamp_to_edge, filter::linear);
        float t = u.time;
        float aspect = u.res.x / u.res.y;
        float2 p = (in.uv - 0.5) * float2(aspect, 1.0);
        float r = length(p);

        float morph  = smoothstep(0.3, 2.6, t);
        float warp   = smoothstep(2.2, 4.3, t);
        float imgOut = smoothstep(3.4, 4.35, t);
        float fd     = (t - 4.4) * 6.0;
        float flash  = exp(-fd * fd);
        float calm   = smoothstep(4.4, 6.5, t);

        float3 col = spaceBackdrop(p, t);
        if (imgOut < 1.0) {
            // The desktop turns liquid from the centre outwards.
            float front  = morph * 1.35;
            float inside = 1.0 - smoothstep(front - 0.5, front, r);
            float swirl  = inside * (0.22 * morph + 1.3 * warp) * (1.0 - smoothstep(0.0, 1.1, r));
            float s = sin(swirl), c = cos(swirl);
            float2 q = float2(c * p.x - s * p.y, s * p.x + c * p.y);
            q += inside * (0.022 + 0.02 * warp) * float2(
                sin(q.y * 9.0 + t * 2.3) + sin(r * 15.0 - t * 4.2),
                cos(q.x * 8.0 - t * 1.9) + cos(r * 13.0 - t * 3.6));
            q *= 1.0 - 0.6 * warp * inside;              // pulled into the tunnel
            float2 suv = q / float2(aspect, 1.0) + 0.5;

            // Radial zoom blur — a single sample until the jump starts.
            float blur = 0.04 * morph + 0.45 * warp;
            int samples = blur < 0.02 ? 1 : 24;
            float3 img = float3(0.0);
            for (int i = 0; i < samples; i++) {
                float k = samples > 1 ? float(i) / float(samples - 1) : 0.0;
                float2 uv = 0.5 + (suv - 0.5) * (1.0 - blur * k);
                img += tex.sample(smp, coverUV(uv, u)).rgb;
            }
            img /= float(samples);
            float rd = (r - front + 0.08) * 10.0;
            float rim = exp(-rd * rd) * morph * (1.0 - warp);
            img = mix(img, img * 0.6 + float3(0.36, 0.55, 1.0), rim * 0.55);
            img *= 1.0 - 0.35 * warp;
            col = mix(img, col, imgOut);
        }

        // Star streaks in hyperspace, a calm drifting field afterwards.
        float starVis = warp * (1.0 - calm) + calm * 0.75;
        if (starVis > 0.001) {
            float ang = atan2(p.y, p.x);
            float streak = 1.0 - calm;
            float3 stars = float3(0.0);
            for (int layer = 0; layer < 3; layer++) {
                float L = float(layer);
                float sectors = 160.0 + L * 150.0;
                float a = (ang / TAU + 0.5) * sectors;
                float id = floor(a);
                float h = hash1(id * 7.13 + L * 31.7);
                float on = step(0.45, h);
                float speed = (0.25 + h * 0.5) * mix(0.05, 1.0 + 3.5 * warp, streak);
                float pos = fract(hash1(id + L * 3.1) + t * speed * 0.25);
                float rr = 0.05 + pos * pos * 1.25;
                float len = rr * mix(0.004, 0.45, warp * streak);
                float along = smoothstep(rr - len, rr, r) * (1.0 - smoothstep(rr, rr + 0.003, r));
                float wpx = abs(fract(a) - 0.5) * TAU * r / sectors * u.res.y / u.scale;
                float across = 1.0 - smoothstep(0.4, 1.4, wpx);
                float b = on * along * across * smoothstep(0.0, 0.35, rr) * (0.5 + 0.5 * h);
                stars += b * mix(float3(0.75, 0.85, 1.0), float3(0.55, 0.7, 1.0), L * 0.5);
            }
            col += stars * starVis * 1.6;
        }

        col += float3(0.85, 0.9, 1.0) * flash * (0.65 + 0.6 * exp(-r * 2.5));
        return float4(col, 1.0);
    }
    """#
}
