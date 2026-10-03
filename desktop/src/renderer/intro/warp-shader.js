window.WARP_SHADER = `
// Caelum's hyperspace jump — the WebGL twin of the Metal shader in
// Sources/Caelum/UI/WarpView.swift. Keep the two in sync.
//
// Intro (time):     a single smooth wave runs from the centre across the desktop,
//                   then hyperspace (zoom blur, colour fringes, star streaks),
//                   flash + shake at 4.4 s, calm drifting stars after.
// Outro (exitTime): stars accelerate back into streaks, the biggest flash at
//                   5.5 s, and the new wallpaper washes in from the centre.
precision highp float;
uniform sampler2D tex;       // desktop wallpaper at launch
uniform sampler2D tex2;      // wallpaper to land on (outro)
uniform vec2 res;
uniform vec2 texSize;
uniform vec2 tex2Size;
uniform float time;
uniform float exitTime;      // < 0 until the outro starts
uniform float scale;         // device pixels per CSS pixel
varying vec2 vUV;

const float TAU = 6.2831853;
const float FLASH = 4.4;
const float EXIT_FLASH = 5.5;

float hash(float n) { return fract(sin(n) * 43758.5453123); }

vec2 cover(vec2 uv, vec2 size) {
  float sa = res.x / res.y, ta = size.x / size.y;
  vec2 s = sa > ta ? vec2(1.0, ta / sa) : vec2(sa / ta, 1.0);
  return (uv - 0.5) * s + 0.5;
}

float easeInOut(float x) { return x < 0.5 ? 4.0 * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0; }

vec3 backdrop(vec2 p, float t) {
  vec3 col = vec3(0.012, 0.014, 0.03);
  vec2 a = vec2(0.25 * sin(t * 0.07), -0.12 + 0.08 * cos(t * 0.05));
  vec2 b = vec2(0.55 + 0.1 * cos(t * 0.06), 0.35 + 0.06 * sin(t * 0.08));
  col += vec3(0.33, 0.27, 0.85) * 0.22 * exp(-dot(p - a, p - a) * 3.2);
  col += vec3(0.20, 0.65, 0.85) * 0.12 * exp(-dot(p - b, p - b) * 4.0);
  col += vec3(0.80, 0.30, 0.70) * 0.06 * exp(-dot(p + b, p + b) * 3.0);
  return col;
}

// One expanding wave: a smooth bulge travelling outwards from the centre.
// Returns the radial displacement and a highlight term for a glassy sheen.
vec2 wave(float r, float front, float amp) {
  float d = (r - front) / 0.16;
  float g = exp(-d * d);
  return vec2(amp * g * sin(d * 1.6), -amp * g * d * 6.0);
}

vec3 stars(vec2 p, float t, float speedUp, float streak, float vis) {
  if (vis < 0.001) return vec3(0.0);
  float r = length(p);
  float ang = atan(p.y, p.x);
  vec3 acc = vec3(0.0);
  for (int layer = 0; layer < 3; layer++) {
    float L = float(layer);
    float sectors = 160.0 + L * 150.0;
    float a = (ang / TAU + 0.5) * sectors;
    float id = floor(a);
    float h = hash(id * 7.13 + L * 31.7);
    float speed = (0.25 + h * 0.5) * mix(0.05, 1.0 + 3.5 * speedUp, streak);
    float pos = fract(hash(id + L * 3.1) + t * speed * 0.25);
    float rr = 0.05 + pos * pos * 1.25;
    float len = rr * mix(0.004, 0.45, speedUp * streak);
    float along = smoothstep(rr - len, rr, r) * (1.0 - smoothstep(rr, rr + 0.003, r));
    float wpx = abs(fract(a) - 0.5) * TAU * r / sectors * res.y / scale;
    float across = 1.0 - smoothstep(0.4, 1.4, wpx);
    float b = step(0.45, h) * along * across * smoothstep(0.0, 0.35, rr) * (0.5 + 0.5 * h);
    acc += b * mix(vec3(0.75, 0.85, 1.0), vec3(0.55, 0.7, 1.0), L * 0.5);
  }
  return acc * vis * 1.6;
}

void main() {
  float t = time;
  float te = exitTime;
  float aspect = res.x / res.y;
  vec2 p = (vUV - 0.5) * vec2(aspect, 1.0);

  // Camera shake on both flashes.
  float s1 = max(0.0, 1.0 - abs(t - FLASH - 0.15) / 0.5) * step(FLASH, t);
  float s2 = te >= EXIT_FLASH ? max(0.0, 1.0 - (te - EXIT_FLASH) / 0.7) : 0.0;
  float shake = 0.012 * s1 * s1 + 0.02 * s2 * s2;
  p += shake * vec2(sin(t * 91.0) + sin(t * 57.0), cos(t * 73.0) + sin(t * 41.0));
  float r = length(p);

  // ---- Intro ----
  float morph  = smoothstep(0.2, 2.5, t);
  float warp   = smoothstep(2.1, 4.3, t);
  float imgOut = smoothstep(3.4, 4.35, t);
  float fd     = (t - FLASH) * 6.0;
  float flash  = exp(-fd * fd);
  float calm   = smoothstep(FLASH, 6.4, t);

  vec3 col = backdrop(p, t);
  if (imgOut < 1.0) {
    float front = easeInOut(morph) * 1.25;
    vec2 w = wave(r, front, 0.05 * (1.0 - warp * 0.6));
    vec2 dir = r > 1e-4 ? p / r : vec2(0.0);
    vec2 q = p - dir * w.x;
    q *= 1.0 - 0.6 * warp;                                // pulled into the tunnel
    vec2 suv = q / vec2(aspect, 1.0) + 0.5;
    float blur = 0.5 * warp;
    float fringe = 0.04 * warp;
    vec3 img = vec3(0.0);
    for (int i = 0; i < 20; i++) {
      float k = float(i) / 19.0 * blur;
      vec2 base = suv - 0.5;
      img.r += texture2D(tex, cover(0.5 + base * (1.0 - k) * (1.0 + fringe), texSize)).r;
      img.g += texture2D(tex, cover(0.5 + base * (1.0 - k), texSize)).g;
      img.b += texture2D(tex, cover(0.5 + base * (1.0 - k) * (1.0 - fringe), texSize)).b;
    }
    img /= 20.0;
    img += max(w.y, 0.0) * 0.18 * (1.0 - warp);           // glassy sheen on the wave
    float rd = (r - front) / 0.07;
    img += vec3(0.35, 0.5, 1.0) * 0.22 * exp(-rd * rd) * morph * (1.0 - warp);
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
    col += vec3(0.45, 0.4, 1.0) * 0.5 * warpE * exp(-r * 4.0);   // the tunnel's mouth
    float fd2 = (te - EXIT_FLASH) * 4.5;
    flash2 = exp(-fd2 * fd2);
    reveal = smoothstep(EXIT_FLASH, EXIT_FLASH + 1.9, te);
  }
  col += stars(p, te >= 0.0 ? te * 1.0 + 40.0 : t, speedUp, streak, vis);

  if (reveal > 0.0) {
    float front = easeInOut(reveal) * 1.45;
    float inside = 1.0 - smoothstep(front - 0.22, front, r);
    vec2 w = wave(r, front - 0.08, 0.06 * (1.0 - reveal));
    vec2 dir = r > 1e-4 ? p / r : vec2(0.0);
    vec2 q = (p - dir * w.x) / vec2(aspect, 1.0) + 0.5;
    vec3 img2 = texture2D(tex2, cover(q, tex2Size)).rgb + max(w.y, 0.0) * 0.15;
    col = mix(col, img2, inside);
  }

  col += vec3(0.85, 0.9, 1.0) * flash * (0.7 + 0.6 * exp(-r * 2.5));
  col += vec3(0.9, 0.92, 1.0) * flash2 * (0.9 + 0.8 * exp(-r * 2.0));
  gl_FragColor = vec4(col, 1.0);
}
`;
