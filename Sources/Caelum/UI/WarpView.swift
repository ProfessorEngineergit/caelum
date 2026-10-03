import AppKit
import MetalKit

/// The hyperspace jump, drawn by one Metal fragment shader over the user's own
/// wallpaper. The WebGL twin lives in desktop/src/renderer/intro/warp-shader.js —
/// keep the two in sync.
///
/// Intro (`time`, from `restart()`):
///   0.2–2.5 s  one smooth wave runs from the centre across the desktop
///   2.1–4.3 s  hyperspace: zoom blur, colour fringes, star streaks
///   4.4 s      the flash (+ shake) — `onFlash` fires, sound and panel land on it
///   after      calm, drifting stars behind the setup
/// Outro (`exitTime`, from `beginExit()`):
///   0.5–5.3 s  the stars accelerate back into streaks
///   5.5 s      the biggest flash — then the landing image washes in from the centre
///   7.6 s      settled on the new desktop — `onExitDone`
///
/// Compiled at runtime from source (no .metal build step in SwiftPM), rendered
/// below native resolution, and the costly image samples are skipped once the
/// desktop is gone.
final class WarpView: MTKView {
    static let flashTime: Float = 4.4
    static let exitFlashTime: Float = 5.5
    static let exitEndTime: Float = 7.6

    /// Once, on the main thread, when the intro flash peaks.
    var onFlash: (() -> Void)?
    /// Every frame: intro time and outro time (negative before the outro).
    var onFrame: ((Float, Float) -> Void)?
    /// Once, when the outro has settled on the landing image.
    var onExitDone: (() -> Void)?

    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let loader: MTKTextureLoader
    private let wallpaper: MTLTexture
    private var landing: MTLTexture
    private var start = CACurrentMediaTime()
    private var exitStart: CFTimeInterval?
    private var flashed = false
    private var exitDone = false
    private let resolutionScale: CGFloat = 0.7

    private struct Uniforms {
        var res: SIMD2<Float>
        var texSize: SIMD2<Float>
        var tex2Size: SIMD2<Float>
        var time: Float
        var exitTime: Float
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
        let loader = MTKTextureLoader(device: device)
        guard let texture = Self.makeTexture(image, loader: loader, device: device) else { return nil }
        self.queue = queue
        self.loader = loader
        self.wallpaper = texture
        self.landing = texture
        super.init(frame: frame, device: device)
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        autoResizeDrawable = false
        preferredFramesPerSecond = 60
        updateDrawableSize()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Restarts the intro timeline — call right before the window appears.
    func restart() {
        start = CACurrentMediaTime()
        exitStart = nil
        flashed = false
        exitDone = false
        isPaused = false
    }

    /// Starts the outro. The landing image can follow later via `setLanding`.
    func beginExit() {
        guard exitStart == nil else { return }
        exitStart = CACurrentMediaTime()
    }

    /// The picture the outro lands on (the wallpaper Caelum just set).
    func setLanding(_ image: CGImage?) {
        guard let device, let texture = Self.makeTexture(image, loader: loader, device: device) else { return }
        landing = texture
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
        let now = CACurrentMediaTime()
        let time = Float(now - start)
        let exitTime = exitStart.map { Float(now - $0) } ?? -1
        if !flashed && time >= Self.flashTime {
            flashed = true
            onFlash?()
        }
        onFrame?(time, exitTime)
        if !exitDone && exitTime >= Self.exitEndTime {
            exitDone = true
            onExitDone?()
        }
        guard let pass = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let commands = queue.makeCommandBuffer(),
              let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }
        let backing = window?.backingScaleFactor ?? 2
        var uniforms = Uniforms(
            res: SIMD2(Float(drawableSize.width), Float(drawableSize.height)),
            texSize: SIMD2(Float(wallpaper.width), Float(wallpaper.height)),
            tex2Size: SIMD2(Float(landing.width), Float(landing.height)),
            time: time,
            exitTime: exitTime,
            scale: Float(backing * resolutionScale))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentTexture(wallpaper, index: 0)
        encoder.setFragmentTexture(landing, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commands.present(drawable)
        commands.commit()
    }

    // MARK: - Textures

    /// The image as a texture; a deep-space pixel when there is none (e.g. a
    /// dynamic wallpaper the image loader doesn't understand).
    private static func makeTexture(_ image: CGImage?, loader: MTKTextureLoader, device: MTLDevice) -> MTLTexture? {
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
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        return image(at: url)
    }

    static func image(at url: URL) -> CGImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    // MARK: - Shader

    private static let shaderSource = #"""
    #include <metal_stdlib>
    using namespace metal;

    struct Uniforms { float2 res; float2 texSize; float2 tex2Size; float time; float exitTime; float scale; };
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
    constant float FLASH = 4.4;
    constant float EXIT_FLASH = 5.5;

    static float hash1(float n) { return fract(sin(n) * 43758.5453123); }

    // Aspect-fill, like "Fill Screen" on the desktop.
    static float2 cover(float2 uv, float2 size, constant Uniforms &u) {
        float sa = u.res.x / u.res.y, ta = size.x / size.y;
        float2 s = sa > ta ? float2(1.0, ta / sa) : float2(sa / ta, 1.0);
        return (uv - 0.5) * s + 0.5;
    }

    static float easeInOut(float x) {
        return x < 0.5 ? 4.0 * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0;
    }

    static float3 backdrop(float2 p, float t) {
        float3 col = float3(0.012, 0.014, 0.03);
        float2 a = float2(0.25 * sin(t * 0.07), -0.12 + 0.08 * cos(t * 0.05));
        float2 b = float2(0.55 + 0.1 * cos(t * 0.06), 0.35 + 0.06 * sin(t * 0.08));
        col += float3(0.33, 0.27, 0.85) * 0.22 * exp(-dot(p - a, p - a) * 3.2);
        col += float3(0.20, 0.65, 0.85) * 0.12 * exp(-dot(p - b, p - b) * 4.0);
        col += float3(0.80, 0.30, 0.70) * 0.06 * exp(-dot(p + b, p + b) * 3.0);
        return col;
    }

    // One expanding wave: radial displacement and a highlight for a glassy sheen.
    static float2 wave(float r, float front, float amp) {
        float d = (r - front) / 0.16;
        float g = exp(-d * d);
        return float2(amp * g * sin(d * 1.6), -amp * g * d * 6.0);
    }

    static float3 stars(float2 p, float t, float speedUp, float streak, float vis, constant Uniforms &u) {
        if (vis < 0.001) return float3(0.0);
        float r = length(p);
        float ang = atan2(p.y, p.x);
        float3 acc = float3(0.0);
        for (int layer = 0; layer < 3; layer++) {
            float L = float(layer);
            float sectors = 160.0 + L * 150.0;
            float a = (ang / TAU + 0.5) * sectors;
            float id = floor(a);
            float h = hash1(id * 7.13 + L * 31.7);
            float speed = (0.25 + h * 0.5) * mix(0.05, 1.0 + 3.5 * speedUp, streak);
            float pos = fract(hash1(id + L * 3.1) + t * speed * 0.25);
            float rr = 0.05 + pos * pos * 1.25;
            float len = rr * mix(0.004, 0.45, speedUp * streak);
            float along = smoothstep(rr - len, rr, r) * (1.0 - smoothstep(rr, rr + 0.003, r));
            float wpx = abs(fract(a) - 0.5) * TAU * r / sectors * u.res.y / u.scale;
            float across = 1.0 - smoothstep(0.4, 1.4, wpx);
            float b = step(0.45, h) * along * across * smoothstep(0.0, 0.35, rr) * (0.5 + 0.5 * h);
            acc += b * mix(float3(0.75, 0.85, 1.0), float3(0.55, 0.7, 1.0), L * 0.5);
        }
        return acc * vis * 1.6;
    }

    fragment float4 warpFragment(VOut in [[stage_in]],
                                 constant Uniforms &u [[buffer(0)]],
                                 texture2d<float> tex [[texture(0)]],
                                 texture2d<float> tex2 [[texture(1)]]) {
        constexpr sampler smp(address::clamp_to_edge, filter::linear);
        float t = u.time;
        float te = u.exitTime;
        float aspect = u.res.x / u.res.y;
        float2 p = (in.uv - 0.5) * float2(aspect, 1.0);

        // Camera shake on both flashes.
        float s1 = t >= FLASH ? max(0.0, 1.0 - abs(t - FLASH - 0.15) / 0.5) : 0.0;
        float s2 = te >= EXIT_FLASH ? max(0.0, 1.0 - (te - EXIT_FLASH) / 0.7) : 0.0;
        float shake = 0.012 * s1 * s1 + 0.02 * s2 * s2;
        p += shake * float2(sin(t * 91.0) + sin(t * 57.0), cos(t * 73.0) + sin(t * 41.0));
        float r = length(p);
        float2 dir = r > 1e-4 ? p / r : float2(0.0);

        // ---- Intro ----
        float morph  = smoothstep(0.2, 2.5, t);
        float warp   = smoothstep(2.1, 4.3, t);
        float imgOut = smoothstep(3.4, 4.35, t);
        float fd     = (t - FLASH) * 6.0;
        float flash  = exp(-fd * fd);
        float calm   = smoothstep(FLASH, 6.4, t);

        float3 col = backdrop(p, t);
        if (imgOut < 1.0) {
            float front = easeInOut(morph) * 1.25;
            float2 w = wave(r, front, 0.05 * (1.0 - warp * 0.6));
            float2 q = p - dir * w.x;
            q *= 1.0 - 0.6 * warp;                                   // pulled into the tunnel
            float2 base = q / float2(aspect, 1.0);
            float blur = 0.5 * warp;
            float fringe = 0.04 * warp;
            int samples = blur < 0.01 ? 1 : 20;
            float3 img = float3(0.0);
            for (int i = 0; i < samples; i++) {
                float k = samples > 1 ? float(i) / float(samples - 1) * blur : 0.0;
                img.r += tex.sample(smp, cover(0.5 + base * (1.0 - k) * (1.0 + fringe), u.texSize, u)).r;
                img.g += tex.sample(smp, cover(0.5 + base * (1.0 - k), u.texSize, u)).g;
                img.b += tex.sample(smp, cover(0.5 + base * (1.0 - k) * (1.0 - fringe), u.texSize, u)).b;
            }
            img /= float(samples);
            img += max(w.y, 0.0) * 0.18 * (1.0 - warp);               // glassy sheen on the wave
            float rd = (r - front) / 0.07;
            img += float3(0.35, 0.5, 1.0) * 0.22 * exp(-rd * rd) * morph * (1.0 - warp);
            img *= 1.0 - 0.35 * warp;
            col = mix(img, col, imgOut);
        }

        // ---- Outro ----
        float speedUp = warp * (1.0 - calm);
        float streak = 1.0 - calm;
        float vis = warp * (1.0 - calm) + calm * 0.75;
        float flash2 = 0.0;
        float reveal = 0.0;
        if (te >= 0.0) {
            float warpE = pow(smoothstep(0.5, 5.3, te), 1.4);
            speedUp = max(speedUp, warpE);
            streak = max(streak, warpE);
            vis = max(vis, 0.75 + 0.6 * warpE);
            col += float3(0.45, 0.4, 1.0) * 0.5 * warpE * exp(-r * 4.0);   // the tunnel's mouth
            float fd2 = (te - EXIT_FLASH) * 4.5;
            flash2 = exp(-fd2 * fd2);
            reveal = smoothstep(EXIT_FLASH, EXIT_FLASH + 1.9, te);
        }
        col += stars(p, te >= 0.0 ? te + 40.0 : t, speedUp, streak, vis, u);

        if (reveal > 0.0) {
            float front = easeInOut(reveal) * 1.45;
            float inside = 1.0 - smoothstep(front - 0.22, front, r);
            float2 w = wave(r, front - 0.08, 0.06 * (1.0 - reveal));
            float2 q = (p - dir * w.x) / float2(aspect, 1.0) + 0.5;
            float3 img2 = tex2.sample(smp, cover(q, u.tex2Size, u)).rgb + max(w.y, 0.0) * 0.15;
            col = mix(col, img2, inside);
        }

        col += float3(0.85, 0.9, 1.0) * flash * (0.7 + 0.6 * exp(-r * 2.5));
        col += float3(0.9, 0.92, 1.0) * flash2 * (0.9 + 0.8 * exp(-r * 2.0));
        return float4(col, 1.0);
    }
    """#
}
