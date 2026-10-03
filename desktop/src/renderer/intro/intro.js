// The intro and setup — hyperspace jump in, four calm steps, a bigger jump out.
// Timings match the macOS app (IntroController / WarpView) and the sound files.
"use strict";

(() => {
  const api = window.caelumIntro;
  const $ = (id) => document.getElementById(id);

  const FLASH = 4.4;           // intro flash (intro.m4a hits here)
  const EXIT_FLASH = 5.5;      // outro flash (outro.m4a hits here)
  const EXIT_END = 7.6;        // the new wallpaper has settled — close
  const LAST_STEP = 3;

  // A virtual clock, so the whole sequence can be rendered frame by frame.
  const debug = new URLSearchParams(location.search).has("render");
  let virtualNow = 0;
  const now = () => (debug ? virtualNow : performance.now() / 1000);

  let setup = null;
  let step = 0;
  let landedAt = 0;
  const schedule = [];        // [{at, run}] relative to the landing, driven by frame()
  const isUpdate = () => setup?.mode === "update";
  let introStart = now();
  let exitStart = -1;
  let leaving = false;

  // MARK: - Sound

  const sounds = {};
  let audioCtx = null;
  let bed = null;

  function sound(name) {
    if (!setup?.soundsURL || debug) return null;
    if (!sounds[name]) {
      const a = new Audio(setup.soundsURL + name + ".m4a");
      a.preload = "auto";
      sounds[name] = a;
    }
    return sounds[name];
  }

  function play(name, volume = 1) {
    const a = sound(name);
    if (!a) return;
    a.currentTime = 0;
    a.volume = volume;
    a.play().catch(() => {});
  }

  /** The ambient bed loops sample-accurately through Web Audio (no gap at the seam). */
  async function startBed() {
    if (!setup?.soundsURL || debug || bed) return;
    try {
      audioCtx = audioCtx || new AudioContext();
      const data = await (await fetchFile(setup.soundsURL + "bed.m4a")).arrayBuffer();
      const buffer = await audioCtx.decodeAudioData(data);
      const ch = buffer.getChannelData(0);
      let first = 0;                                   // skip the encoder's priming silence
      while (first < ch.length && Math.abs(ch[first]) < 1e-5) first++;
      const source = audioCtx.createBufferSource();
      source.buffer = buffer;
      source.loop = true;
      source.loopStart = first / buffer.sampleRate;
      source.loopEnd = Math.min(buffer.duration, source.loopStart + 32);
      const gain = audioCtx.createGain();
      gain.gain.setValueAtTime(0, audioCtx.currentTime);
      gain.gain.linearRampToValueAtTime(0.9, audioCtx.currentTime + 3);
      source.connect(gain).connect(audioCtx.destination);
      source.start(0, source.loopStart);
      bed = { source, gain };
    } catch (err) {
      console.warn("Caelum: ambient bed unavailable", err);
    }
  }

  function stopBed(seconds = 0.8) {
    if (!bed || !audioCtx) return;
    const t = audioCtx.currentTime;
    bed.gain.gain.cancelScheduledValues(t);
    bed.gain.gain.setValueAtTime(bed.gain.gain.value, t);
    bed.gain.gain.linearRampToValueAtTime(0, t + seconds);
    bed.source.stop(t + seconds + 0.05);
    bed = null;
  }

  // file:// fetch isn't allowed; XHR on a file URL is.
  function fetchFile(url) {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open("GET", url);
      xhr.responseType = "arraybuffer";
      xhr.onload = () => resolve({ arrayBuffer: async () => xhr.response });
      xhr.onerror = reject;
      xhr.send();
    });
  }

  // MARK: - Warp (WebGL)

  const canvas = $("warp");
  const gl = canvas.getContext("webgl", { antialias: false, premultipliedAlpha: false });
  let program = null;
  const uniforms = {};
  const textures = { tex: null, tex2: null, size: [1, 1], size2: [1, 1] };

  function compile(type, src) {
    const s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
    return s;
  }

  function initGL() {
    if (!gl) return false;
    const vs = "attribute vec2 pos; varying vec2 vUV; void main(){ vUV = vec2(pos.x * 0.5 + 0.5, 0.5 - pos.y * 0.5); gl_Position = vec4(pos, 0.0, 1.0); }";
    program = gl.createProgram();
    gl.attachShader(program, compile(gl.VERTEX_SHADER, vs));
    gl.attachShader(program, compile(gl.FRAGMENT_SHADER, window.WARP_SHADER));
    gl.linkProgram(program);
    gl.useProgram(program);
    const buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    const loc = gl.getAttribLocation(program, "pos");
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
    for (const name of ["tex", "tex2", "res", "texSize", "tex2Size", "time", "exitTime", "scale"]) {
      uniforms[name] = gl.getUniformLocation(program, name);
    }
    textures.tex = blankTexture([6, 7, 13]);
    textures.tex2 = textures.tex;
    return true;
  }

  function blankTexture(rgb) {
    const t = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, t);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([...rgb, 255]));
    return t;
  }

  function loadTexture(url) {
    return new Promise((resolve) => {
      if (!url) return resolve(null);
      const img = new Image();
      img.onload = () => {
        const t = gl.createTexture();
        gl.bindTexture(gl.TEXTURE_2D, t);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, img);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        resolve({ texture: t, size: [img.naturalWidth, img.naturalHeight] });
      };
      img.onerror = () => resolve(null);
      img.src = url;
    });
  }

  function resize() {
    // Below native resolution: it's all motion and blur, and the GPU stays cool.
    const scale = Math.min(window.devicePixelRatio || 1, 2) * 0.7;
    canvas.width = Math.round(innerWidth * scale);
    canvas.height = Math.round(innerHeight * scale);
    gl && gl.viewport(0, 0, canvas.width, canvas.height);
    return scale;
  }
  let pixelScale = 1;

  function drawWarp(t, te) {
    if (!program) return;
    gl.uniform2f(uniforms.res, canvas.width, canvas.height);
    gl.uniform2f(uniforms.texSize, ...textures.size);
    gl.uniform2f(uniforms.tex2Size, ...textures.size2);
    gl.uniform1f(uniforms.time, t);
    gl.uniform1f(uniforms.exitTime, te);
    gl.uniform1f(uniforms.scale, pixelScale);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, textures.tex);
    gl.uniform1i(uniforms.tex, 0);
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, textures.tex2);
    gl.uniform1i(uniforms.tex2, 1);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }

  // MARK: - Outro cards (the library flying past)

  const cardLayer = $("cards");
  let cards = [];

  function buildCards(urls) {
    const list = urls.slice(0, 16);
    cards = list.map((url, i) => {
      const el = document.createElement("div");
      el.className = "card";
      const img = document.createElement("img");
      img.src = url;
      el.append(img);
      cardLayer.append(el);
      const angle = (i * 2.399963) % (Math.PI * 2);          // golden-angle spread around the tunnel
      const radius = 420 + ((i * 97) % 5) * 90;
      // spawn times 1.0 → 4.2 s (gone before the flash), each crossing faster
      const spawn = 1.0 + (i / Math.max(1, list.length - 1)) * 3.2;
      const life = 1.7 - (spawn - 1.0) * 0.22;
      return { el, angle, radius, spawn, life, tilt: (i % 2 ? 1 : -1) * (6 + (i % 4) * 3) };
    });
  }

  function drawCards(te) {
    for (const c of cards) {
      const k = (te - c.spawn) / c.life;
      if (te < 0 || k < 0 || k > 1) { c.el.style.opacity = "0"; continue; }
      const z = -3200 + 4300 * Math.pow(k, 1.7);             // from deep in the tunnel past the camera
      const x = Math.cos(c.angle) * c.radius * (0.6 + 0.4 * k);
      const y = Math.sin(c.angle) * c.radius * 0.62 * (0.6 + 0.4 * k);
      const fadeIn = Math.min(1, k / 0.2);
      const fadeOut = Math.min(1, (1 - k) / 0.12);
      c.el.style.opacity = String(Math.min(fadeIn, fadeOut) * 0.95);
      c.el.style.transform = `translate3d(${x}px, ${y}px, ${z}px) rotateY(${c.tilt * (x > 0 ? -1 : 1)}deg) rotateZ(${c.tilt * 0.3}deg)`;
    }
  }

  // MARK: - Panel & steps

  function splitForReveal(root) {
    for (const el of root.querySelectorAll(".reveal-letters, .reveal-words")) {
      if (el.dataset.split) continue;
      const text = el.textContent;
      const parts = el.classList.contains("reveal-letters") ? [...text] : text.split(/(\s+)/);
      el.textContent = "";
      let i = 0;
      for (const part of parts) {
        if (/^\s+$/.test(part)) { el.append(document.createTextNode(part)); continue; }
        const span = document.createElement("span");
        span.textContent = part;
        span.style.setProperty("--i", String(i++));
        el.append(span);
      }
      el.dataset.split = "1";
    }
  }

  function showStep(target, sound = true) {
    step = target;
    for (const section of document.querySelectorAll(".step")) {
      const on = Number(section.dataset.step) === step;
      section.hidden = !on;
      section.classList.remove("enter", "revealed");
      if (on) {
        splitForReveal(section);
        void section.offsetWidth;                            // restart animations
        section.classList.add("enter", "revealed");
      }
    }
    $("dots").replaceChildren(...Array.from({ length: LAST_STEP + 1 }, (_, i) => {
      const d = document.createElement("i");
      if (i === step) d.className = "on";
      return d;
    }));
    $("back").classList.toggle("invisible", step === 0);
    $("next").textContent = step === 0 ? "Begin" : step === LAST_STEP ? "Enter Caelum" : "Continue";
    if (sound && step > 0) play("step", 0.8);
    if (step === LAST_STEP) api?.preparePreview?.();
  }

  const SOURCE_SOUND = { "artist-impressions": "artist" };

  function renderSources() {
    const list = $("sources");
    list.replaceChildren(...setup.sources.map((s) => {
      const tile = document.createElement("button");
      tile.className = "tile" + (s.id === setup.activeSourceID ? " selected" : "");
      tile.style.setProperty("--c", s.accent);
      const dot = document.createElement("span"); dot.className = "dot";
      const text = document.createElement("span");
      const b = document.createElement("b"); b.textContent = s.name;
      const small = document.createElement("small"); small.textContent = s.subtitle;
      text.append(b, small);
      tile.append(dot, text);
      tile.addEventListener("click", () => {
        play("source-" + (SOURCE_SOUND[s.id] || s.id));     // also on a repeat tap
        if (s.id !== setup.activeSourceID) {
          setup.activeSourceID = s.id;
          api?.selectSource(s.id);
          for (const t of list.children) t.classList.toggle("selected", t === tile);
        }
      });
      return tile;
    }));
  }

  function renderSettings() {
    for (const input of document.querySelectorAll("[data-setting]")) {
      input.checked = Boolean(setup.settings[input.dataset.setting]);
      input.addEventListener("change", () => api?.setSetting(input.dataset.setting, input.checked));
    }
  }

  function land() {
    landedAt = now();
    $("panel").classList.add("in");
    if (isUpdate()) showUpdate();
    else showStep(0, false);
    startBed();
  }

  // MARK: - Update screen

  const STOP = new Set("the and for with from into that this when then than your you are was were have has had not but all any its it's also just only more less over under after before about their there here they them what which while will would should could into onto upon each every very much many some such like make made makes add adds added fix fixes fixed use uses used now new".split(" "));

  function showUpdate() {
    const u = setup.update || {};
    for (const section of document.querySelectorAll(".step")) section.hidden = section.dataset.step !== "update";
    const section = document.querySelector('[data-step="update"]');
    section.classList.add("enter", "revealed");
    $("old-version").textContent = u.from ? `v${u.from}` : "";
    $("new-version").textContent = `v${u.to || setup.version}`;
    $("dots").replaceChildren();
    $("back").classList.add("invisible");
    $("next").textContent = "Continue";
    $("close").hidden = true;

    const changes = (u.changes && u.changes.length ? u.changes : ["Under-the-hood improvements."]).slice(0, 6);
    const list = $("changes");
    list.replaceChildren(...changes.map((text) => {
      const li = document.createElement("li");
      li.textContent = text;
      return li;
    }));
    [...list.children].forEach((li, i) => {
      schedule.push({ at: 1.7 + i * 0.95, run: () => {
        for (const other of list.children) other.classList.remove("current");
        li.classList.add("shown", "current");
        play("line", 0.9);
      } });
    });
    buildWords(changes);
  }

  let words = [];
  function buildWords(changes) {
    const seen = new Set();
    const picked = [];
    for (const text of changes) {
      for (const w of text.split(/[^\p{L}\p{N}'-]+/u)) {
        const k = w.toLowerCase();
        if (w.length < 4 || STOP.has(k) || seen.has(k)) continue;
        seen.add(k);
        picked.push(w);
      }
    }
    const layer = $("words");
    words = picked.slice(0, 18).map((w, i) => {
      const el = document.createElement("span");
      el.textContent = w;
      const size = 34 + ((i * 53) % 90);
      el.style.fontSize = size + "px";
      layer.append(el);
      return {
        el,
        y: 0.08 + ((i * 0.618) % 0.84),                       // spread over the height
        x0: (i * 0.37) % 1,
        speed: (10 + (i * 7) % 26) * (i % 2 ? 1 : -1),        // px/s, alternating lanes
        size,
      };
    });
  }

  function drawWords(t) {
    if (!words.length) return;
    const W = innerWidth, H = innerHeight;
    const appear = Math.min(1, Math.max(0, (t - 0.6) / 1.2));
    const focus = Math.floor(Math.max(0, t - 1.2) / 1.7) % words.length;
    words.forEach((w, i) => {
      const width = w.el.offsetWidth || w.size * 4;
      const span = W + width;
      let x = (w.x0 * span + w.speed * t) % span;
      if (x < 0) x += span;
      w.el.style.transform = `translate3d(${x - width}px, ${w.y * H - w.size / 2}px, 0)`;
      w.el.style.opacity = String(appear);
      w.el.classList.toggle("focus", i === focus && t > 1.2);
    });
  }

  // MARK: - Leaving

  async function enter() {
    if (leaving) return;
    leaving = true;
    stopBed(0.6);
    play("outro");
    exitStart = now();
    $("panel").classList.remove("in");
    $("panel").classList.add("out");
    $("spark").animate([{ opacity: 0, transform: "scale(0.2)" }, { opacity: 1, transform: "scale(1.6)", offset: 0.4 }, { opacity: 0, transform: "scale(0.6)" }],
      { duration: 1100, delay: 200, easing: "ease-out" });
    for (const w of words) w.el.style.transition = "opacity .5s", w.el.style.opacity = "0";
    words = [];
    // Set the wallpaper now; the jump lands on it. After an update we simply
    // land back on the desktop as it is.
    const landing = isUpdate() ? setup.wallpaperURL : api ? await api.applyWallpaper() : setup.landingURL;
    const loaded = await loadTexture(landing || setup.wallpaperURL);
    if (loaded) { textures.tex2 = loaded.texture; textures.size2 = loaded.size; }
  }

  function quit() {
    if (leaving) return;
    leaving = true;
    stopBed(0.4);
    $("panel").classList.remove("in");
    $("panel").classList.add("out");
    document.body.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 700, delay: 250, fill: "forwards" })
      .finished.then(() => api?.finish());
  }

  $("next").addEventListener("click", () => (isUpdate() || step >= LAST_STEP ? enter() : showStep(step + 1)));
  $("back").addEventListener("click", () => step > 0 && showStep(step - 1));
  $("close").addEventListener("click", quit);
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") quit();
    if (e.key === "Enter" && !leaving && $("panel").classList.contains("in")) $("next").click();
  });

  // MARK: - Main loop

  let landed = false;
  let finished = false;

  function frame() {
    const t = now() - introStart;
    const te = exitStart >= 0 ? now() - exitStart : -1;
    if (!landed && t >= FLASH) { landed = true; land(); }
    if (landed) {
      const tl = now() - landedAt;
      while (schedule.length && schedule[0].at <= tl) schedule.shift().run();
      if (!leaving) drawWords(tl);
    }
    drawWarp(t, te);
    drawCards(te);
    if (te >= EXIT_END && !finished) {
      finished = true;
      if (!debug) api?.finish();
    }
    if (!debug) requestAnimationFrame(frame);
  }

  async function start() {
    setup = api ? await api.getSetup() : window.__demoSetup;
    pixelScale = resize();
    window.addEventListener("resize", () => { pixelScale = resize(); });
    initGL();
    const loaded = await loadTexture(setup.wallpaperURL);
    if (loaded) { textures.tex = loaded.texture; textures.size = loaded.size; }
    renderSources();
    renderSettings();
    buildCards(setup.cardURLs || []);
    api?.onPreview?.((p) => {
      const img = $("preview-img");
      img.classList.remove("loaded");
      img.onload = () => img.classList.add("loaded");
      if (p.previewURL) img.src = p.previewURL;
      $("preview-title").textContent = p.title || "";
      $("preview-source").textContent = p.sourceName || "";
    });
    introStart = now();
    play(isUpdate() ? "update" : "intro");
    if (!debug) requestAnimationFrame(frame);
  }

  // Frame-by-frame rendering for previews (`?render`): advance the virtual clock
  // and pin every CSS animation to it.
  window.__introRender = {
    start,
    seek(seconds) {
      virtualNow = seconds;
      frame();
      for (const a of document.getAnimations()) {
        if (a.__v0 === undefined) a.__v0 = virtualNow;
        a.pause();
        a.currentTime = (virtualNow - a.__v0) * 1000;
      }
    },
    enter, showStep,
  };

  if (!debug) start();
})();
