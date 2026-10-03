// Panel UI — renders the state pushed by the main process and forwards clicks.
"use strict";

(() => {
  const api = window.caelum;
  const $ = (id) => document.getElementById(id);
  let state = null;
  let shownPreview = null;

  // MARK: - Rendering

  function render(next) {
    state = next;
    const source = state.sources.find((s) => s.id === state.activeSourceID) || state.sources[0];
    document.documentElement.style.setProperty("--accent", source.accent);

    renderHero(source);
    renderDeck();
    renderSources();
    renderUpdate();
    renderSettings();
  }

  function renderHero(source) {
    const image = state.image;
    $("source-name").textContent = source.name;
    $("hero-title").textContent = image ? image.title : state.phase === "error" ? "Couldn't load this source" : "Loading the cosmos…";
    $("hero-credit").textContent = image?.credit ? `© ${image.credit}` : "";
    $("hero-date").textContent = image?.date ? formatDate(image.date) : "";
    $("hero-res").textContent = image ? (image.isVideo ? "Video" : image.resolution) : "";
    $("hero-explanation").textContent = image?.explanation || "No description for this image.";
    $("open-page").hidden = !image?.pageURL;
    $("about-image").hidden = !image;

    const img = $("hero-img");
    if (state.previewURL !== shownPreview) {
      shownPreview = state.previewURL;
      img.classList.remove("shown");
      if (shownPreview) {
        const loader = new Image();
        loader.onload = () => { if (shownPreview === loader.src) { img.src = loader.src; img.classList.add("shown"); } };
        loader.src = shownPreview;
      }
    }
    $("hero-loading").hidden = !(state.phase === "loading" || (image && !state.previewURL && !state.error));
    $("prev").hidden = $("next").hidden = state.position.count < 2;

    const error = state.error || (state.wallpaper === "failed" ? state.wallpaperError : null);
    $("error").hidden = !error;
    $("error").textContent = error || "";
  }

  function renderDeck() {
    const apply = $("apply");
    const image = state.image;
    const applied = image && state.appliedID === image.id && state.wallpaper !== "applying";
    apply.classList.toggle("applied", Boolean(applied));
    apply.disabled = !image || image.isVideo || state.wallpaper === "applying";
    apply.textContent = !image ? "Set as wallpaper"
      : image.isVideo ? "Video — can't be a wallpaper"
      : state.wallpaper === "applying" ? "Setting wallpaper…"
      : applied ? "✓ On your desktop"
      : "Set as wallpaper";
    $("shuffle").disabled = state.position.count < 2;
  }

  function renderSources() {
    const list = $("sources");
    if (list.childElementCount !== state.sources.length) {
      list.replaceChildren(...state.sources.map((s) => {
        const chip = document.createElement("button");
        chip.className = "chip";
        chip.dataset.id = s.id;
        chip.style.setProperty("--chip", s.accent);
        chip.title = `${s.name} — ${s.subtitle}`;
        const dot = document.createElement("span"); dot.className = "dot";
        const text = document.createElement("span"); text.className = "text";
        const name = document.createElement("div"); name.className = "name"; name.textContent = s.name;
        const sub = document.createElement("div"); sub.className = "sub"; sub.textContent = s.subtitle;
        text.append(name, sub);
        chip.append(dot, text);
        chip.addEventListener("click", () => api.selectSource(s.id));
        return chip;
      }));
    }
    for (const chip of list.children) chip.classList.toggle("active", chip.dataset.id === state.activeSourceID);
  }

  function renderUpdate() {
    const u = state.update || { status: "idle" };
    const banner = $("update-banner");
    banner.hidden = !u.showBanner;
    banner.className = `banner${u.status === "failed" ? " failed" : ""}`;
    if (u.showBanner) {
      const parts = [];
      if (u.status === "downloading") {
        parts.push(el("div", "grow", [text(`Downloading Caelum ${u.version}… ${u.percent || 0}%`),
          el("div", "progress", [el("div", "", [], { width: `${u.percent || 0}%` })])]));
      } else if (u.status === "installing") {
        parts.push(el("div", "grow", [text("Installing — Caelum restarts in a moment…")]));
      } else if (u.status === "failed") {
        parts.push(el("div", "grow", [text(`Update failed — ${u.message || ""}`)]));
        parts.push(button("pill", "Download", () => api.openReleases()));
        parts.push(button("close", "✕", () => api.dismissUpdate(), "Later"));
      } else {
        parts.push(el("div", "grow", [text(`Caelum ${u.version} is available`)]));
        parts.push(button("pill", u.canSelfInstall ? "Update" : "Download", () => api.installUpdate()));
        parts.push(button("close", "✕", () => api.dismissUpdate(), "Later"));
      }
      banner.replaceChildren(...parts);
    }

    // Settings → Updates
    $("update-version").textContent = `Caelum ${u.currentVersion || state.version}`;
    const status = {
      idle: "Not checked yet",
      checking: "Checking…",
      upToDate: "You're up to date",
      available: `Version ${u.version} is available`,
      downloading: `Downloading ${u.version}… ${u.percent || 0}%`,
      installing: "Installing…",
      failed: u.message || "Update failed",
    }[u.status] || "";
    $("update-status").textContent = status;
    $("update-status").classList.toggle("warning", u.status === "failed");

    const action = $("update-action");
    let label = null, run = null;
    if (u.status === "idle" || u.status === "upToDate") { label = "Check for updates"; run = api.checkForUpdates; }
    else if (u.status === "available") { label = u.canSelfInstall ? `Install ${u.version} & restart` : `Download ${u.version}`; run = api.installUpdate; }
    else if (u.status === "failed") { label = u.version ? "Try again" : "Check again"; run = u.version ? api.installUpdate : api.checkForUpdates; }
    action.hidden = !label;
    action.textContent = label || "";
    action.onclick = run ? () => run() : null;
  }

  function renderSettings() {
    for (const input of document.querySelectorAll("[data-setting]")) {
      const value = state.settings[input.dataset.setting];
      if (input.type === "checkbox") input.checked = Boolean(value);
      else if (document.activeElement !== input) input.value = String(value);
    }
    $("rotate-row").hidden = !state.settings.rotateLibrary;
    $("about-version").textContent = `Version ${state.version} · MIT License`;
  }

  // MARK: - Helpers

  function el(tag, className, children = [], style = {}) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    Object.assign(node.style, style);
    node.append(...children);
    return node;
  }
  const text = (s) => document.createTextNode(s);
  function button(className, label, onClick, title) {
    const b = el("button", className, [text(label)]);
    if (title) b.title = title;
    b.addEventListener("click", onClick);
    return b;
  }

  function formatDate(ymd) {
    const [y, m, d] = ymd.split("-").map(Number);
    return new Date(Date.UTC(y, m - 1, d)).toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric", timeZone: "UTC" });
  }

  // MARK: - Wiring

  $("prev").addEventListener("click", () => api.previous());
  $("next").addEventListener("click", () => api.next());
  $("shuffle").addEventListener("click", () => api.shuffle());
  $("refresh").addEventListener("click", () => api.refresh());
  $("apply").addEventListener("click", () => api.setWallpaper());
  $("open-page").addEventListener("click", () => api.openPage());
  $("quit").addEventListener("click", () => api.quit());
  $("open-settings").addEventListener("click", () => { $("settings").hidden = false; });
  $("close-settings").addEventListener("click", () => { $("settings").hidden = true; });
  for (const link of document.querySelectorAll("[data-url]")) {
    link.addEventListener("click", () => api.openURL(link.dataset.url));
  }
  for (const input of document.querySelectorAll("[data-setting]")) {
    input.addEventListener("change", () => {
      const value = input.type === "checkbox" ? input.checked : Number(input.value);
      api.setSetting(input.dataset.setting, value);
    });
  }
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      if (!$("settings").hidden) $("settings").hidden = true;
      else api.hide();
    } else if (e.key === "ArrowRight") api.next();
    else if (e.key === "ArrowLeft") api.previous();
  });

  api.onState(render);
  api.getState().then(render);
})();
