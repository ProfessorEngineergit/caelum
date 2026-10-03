// Caelum for Windows & Linux — a tray app that keeps NASA's Astronomy Picture of
// the Day (and nine more sources) on your desktop. The macOS app is native
// Swift (Sources/Caelum); this is its Electron sibling with the same sources,
// daily refresh and in-app updates.
"use strict";

const fs = require("fs");
const path = require("path");
const { pathToFileURL } = require("url");
const { app, BrowserWindow, Tray, Menu, ipcMain, nativeImage, screen, shell, powerMonitor } = require("electron");

const sources = require("./sources");
const { ImageCache } = require("./cache");
const { Settings } = require("./settings");
const { setWallpaper } = require("./wallpaper");
const { UpdateManager } = require("./updater");

if (!app.requestSingleInstanceLock()) {
  app.quit();
  process.exit(0);
}

app.setAppUserModelId("com.professorengineer.caelum");   // Windows notifications & taskbar identity

const ASSETS = path.join(__dirname, "..", "assets");
const BATCH_SIZE = 12;

let tray = null;
let panel = null;
let settings = null;
let cache = null;
let updater = null;
let rotateTimer = null;

/** Everything the panel renders. Sent whole on each change — it's small. */
const state = {
  sources: sources.all.map(({ id, name, subtitle, accent }) => ({ id, name, subtitle, accent })),
  activeSourceID: "apod",
  phase: "loading",         // loading | ready | error
  error: null,
  image: null,              // the CosmicImage on display
  previewURL: null,         // file:// URL of its cached preview
  position: { index: 0, count: 0 },
  wallpaper: "idle",        // idle | applying | applied | failed
  wallpaperError: null,
  appliedID: null,
  settings: {},
  update: null,
  version: app.getVersion(),
  platform: process.platform,
};

let batch = [];
let index = 0;
let loadToken = 0;

function push() {
  state.settings = settings.publicValues();
  state.position = { index, count: batch.length };
  if (panel && !panel.isDestroyed()) panel.webContents.send("state", state);
}

// MARK: - Loading

async function loadLatest({ applyWallpaper = false, silent = false } = {}) {
  const token = ++loadToken;
  const source = sources.byId(state.activeSourceID);
  if (!silent || !state.image) {
    state.phase = "loading";
    state.error = null;
    push();
  }
  try {
    const images = await source.fetchRecent(BATCH_SIZE);
    if (token !== loadToken) return false;
    if (!images.length) throw new Error("The source returned no images.");
    const firstImage = Math.max(0, images.findIndex((i) => !i.isVideo));
    const unchanged = silent && state.image && images[firstImage].id === state.image.id;
    batch = images;
    index = unchanged ? Math.max(0, images.findIndex((i) => i.id === state.image.id)) : firstImage;
    if (!unchanged) await present(token);
    else push();
    if (applyWallpaper) await applyWallpaper_();
    prefetch(images);
    return true;
  } catch (err) {
    if (token !== loadToken) return false;
    console.error(`Caelum: loading ${source.id} failed:`, err);
    if (!silent || !state.image) {
      state.phase = state.image ? "ready" : "error";
      state.error = friendly(err);
      push();
    }
    return false;
  }
}

async function present(token = loadToken) {
  const image = batch[index];
  if (!image) return;
  state.image = image;
  state.error = null;
  if (state.wallpaper !== "applying") state.wallpaper = "idle";
  try {
    const file = await cache.previewFile(image);
    if (token !== loadToken || state.image !== image) return;
    state.previewURL = pathToFileURL(file).toString();
    state.phase = "ready";
  } catch (err) {
    if (token !== loadToken) return;
    state.previewURL = null;
    state.phase = "ready";
    state.error = `Couldn't load this image — ${friendly(err)}`;
  }
  push();
  // Warm the full-resolution file so "Set as wallpaper" is instant.
  if (!image.isVideo) cache.localFile(image).catch(() => {});
}

function step(delta) {
  if (!batch.length) return;
  let next = index;
  for (let hops = 0; hops < batch.length; hops++) {
    next = (next + delta + batch.length) % batch.length;
    if (!batch[next].isVideo) break;
  }
  index = next;
  loadToken++;
  present();
}

function shuffle() {
  const candidates = batch.map((_, i) => i).filter((i) => i !== index && !batch[i].isVideo);
  if (!candidates.length) return;
  index = candidates[Math.floor(Math.random() * candidates.length)];
  loadToken++;
  return present();
}

async function applyWallpaper_() {
  const image = state.image;
  if (!image || image.isVideo || state.wallpaper === "applying") return false;
  state.wallpaper = "applying";
  state.wallpaperError = null;
  push();
  try {
    const file = await cache.localFile(image);
    await setWallpaper(file, path.join(app.getPath("userData"), "Wallpaper"));
    state.wallpaper = "applied";
    state.appliedID = image.id;
    push();
    return true;
  } catch (err) {
    console.error("Caelum: setting the wallpaper failed:", err);
    state.wallpaper = "failed";
    state.wallpaperError = friendly(err);
    push();
    return false;
  }
}

/** Quietly cache the batch's previews so stepping through it is instant. */
function prefetch(images) {
  (async () => {
    for (const image of images.slice(0, 8)) {
      await cache.previewFile(image).catch(() => {});
    }
  })();
}

function friendly(err) {
  const text = String(err?.message || err || "Something went wrong.");
  if (/fetch failed|ENOTFOUND|EAI_AGAIN|ECONNREFUSED|network/i.test(text)) return "You seem to be offline.";
  if (/timeout|aborted/i.test(text)) return "The server took too long to answer.";
  return text;
}

// MARK: - Daily refresh & rotation

const today = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
};

async function dailyCheck(force = false) {
  if (!settings.get("autoDailyRefresh")) return;
  if (!force && settings.get("lastFetchedDate") === today()) return;
  const ok = await loadLatest({ applyWallpaper: true, silent: true });
  if (ok && state.wallpaper === "applied") settings.set("lastFetchedDate", today());
}

function rescheduleRotation() {
  clearInterval(rotateTimer);
  rotateTimer = null;
  if (!settings.get("rotateLibrary")) return;
  const minutes = Math.max(5, Number(settings.get("rotateMinutes")) || 60);
  rotateTimer = setInterval(async () => {
    await shuffle();
    await applyWallpaper_();
  }, minutes * 60000);
}

// MARK: - Launch at login

function setLaunchAtLogin(enabled) {
  if (process.platform === "linux") {
    // XDG autostart — Electron's login-item API doesn't cover Linux.
    const dir = path.join(app.getPath("appData"), "autostart");
    const file = path.join(dir, "caelum.desktop");
    if (!enabled) return fs.rmSync(file, { force: true });
    const exec = process.env.APPIMAGE || process.execPath;
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(file, [
      "[Desktop Entry]", "Type=Application", "Name=Caelum",
      `Exec="${exec.replace(/(["\\`$])/g, "\\$1")}" --hidden`,
      "X-GNOME-Autostart-enabled=true", "",
    ].join("\n"));
  } else {
    app.setLoginItemSettings({ openAtLogin: enabled, args: ["--hidden"] });
  }
}

// MARK: - Window & tray

function createPanel() {
  panel = new BrowserWindow({
    width: 384,
    height: 640,
    show: false,
    frame: false,
    resizable: false,
    maximizable: false,
    fullscreenable: false,
    skipTaskbar: process.platform === "win32",   // Linux: keep a taskbar entry — some desktops hide tray icons
    alwaysOnTop: true,
    backgroundColor: "#07080d",
    title: "Caelum",
    icon: path.join(ASSETS, "icon.png"),
    webPreferences: {
      preload: path.join(__dirname, "..", "preload.js"),
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false,
      spellcheck: false,
    },
  });
  panel.loadFile(path.join(__dirname, "..", "renderer", "index.html"));
  panel.webContents.setWindowOpenHandler(({ url }) => {
    openExternal(url);
    return { action: "deny" };
  });
  panel.webContents.on("will-navigate", (event) => event.preventDefault());
  panel.on("blur", () => {
    if (process.platform === "win32" && !panel.webContents.isDevToolsOpened()) panel.hide();
  });
  panel.on("close", (event) => {
    if (!app.isQuitting && !app.isQuittingForUpdate) {
      event.preventDefault();
      panel.hide();
    }
  });
  panel.webContents.on("did-finish-load", push);
}

function showPanel() {
  positionPanel();
  panel.show();
  panel.focus();
}

function togglePanel() {
  if (panel.isVisible() && panel.isFocused()) panel.hide();
  else showPanel();
}

/** Next to the tray icon when its position is known (Windows), else bottom/top-right. */
function positionPanel() {
  const { width, height } = panel.getBounds();
  const trayBounds = tray?.getBounds?.();
  const known = trayBounds && trayBounds.width > 0;
  const display = known ? screen.getDisplayNearestPoint({ x: trayBounds.x, y: trayBounds.y }) : screen.getPrimaryDisplay();
  const area = display.workArea;
  let x, y;
  if (known) {
    x = Math.round(trayBounds.x + trayBounds.width / 2 - width / 2);
    const below = trayBounds.y < area.y + area.height / 2;
    y = below ? trayBounds.y + trayBounds.height + 6 : trayBounds.y - height - 6;
  } else {
    x = area.x + area.width - width - 12;
    y = process.platform === "win32" ? area.y + area.height - height - 12 : area.y + 12;
  }
  x = Math.min(Math.max(x, area.x + 8), area.x + area.width - width - 8);
  y = Math.min(Math.max(y, area.y + 8), area.y + area.height - height - 8);
  panel.setPosition(x, y, false);
}

function createTray() {
  const icon = nativeImage.createFromPath(path.join(ASSETS, process.platform === "win32" ? "tray.png" : "tray@2x.png"));
  tray = new Tray(process.platform === "linux" ? icon.resize({ width: 22, height: 22 }) : icon);
  tray.setToolTip("Caelum");
  const menu = Menu.buildFromTemplate([
    { label: "Open Caelum", click: showPanel },
    { label: "Next Image", click: () => step(1) },
    { label: "Set as Wallpaper", click: () => applyWallpaper_() },
    { type: "separator" },
    { label: "Check for Updates…", click: () => { updater.check(true); showPanel(); } },
    { type: "separator" },
    { label: "Quit Caelum", click: quit },
  ]);
  if (process.platform === "linux") {
    // Most Linux trays (AppIndicator / StatusNotifier) only support a menu.
    tray.setContextMenu(menu);
  } else {
    tray.on("click", togglePanel);
    tray.on("right-click", () => tray.popUpContextMenu(menu));
  }
}

function quit() {
  app.isQuitting = true;
  app.quit();
}

function openExternal(url) {
  if (/^https?:\/\//i.test(String(url))) shell.openExternal(url);
}

// MARK: - IPC

function registerIPC() {
  const handlers = {
    getState: () => { state.settings = settings.publicValues(); return state; },
    selectSource: (id) => {
      if (!sources.all.some((s) => s.id === id) || id === state.activeSourceID) return;
      state.activeSourceID = id;
      settings.set("activeSourceID", id);
      state.image = null;
      state.previewURL = null;
      loadLatest();
    },
    next: () => step(1),
    previous: () => step(-1),
    shuffle: () => { shuffle(); },
    refresh: () => { loadLatest(); },
    setWallpaper: () => applyWallpaper_(),
    openPage: () => openExternal(state.image?.pageURL),
    openURL: (url) => openExternal(url),
    setSetting: (key, value) => {
      const allowed = { autoDailyRefresh: "boolean", rotateLibrary: "boolean", rotateMinutes: "number",
        launchAtLogin: "boolean", autoInstallUpdates: "boolean" };
      if (allowed[key] !== typeof value) return;
      if (key === "rotateMinutes") value = Math.min(720, Math.max(5, Math.round(value / 5) * 5));
      settings.set(key, value);
      if (key === "launchAtLogin") {
        try { setLaunchAtLogin(value); } catch (err) { console.error("Caelum: autostart failed:", err); }
      }
      if (key === "rotateLibrary" || key === "rotateMinutes") rescheduleRotation();
      if (key === "autoDailyRefresh" && value) dailyCheck();
      if (key === "autoInstallUpdates" && value) updater.installPendingIfAutomatic();
      push();
    },
    checkForUpdates: () => updater.check(true),
    installUpdate: () => updater.install(),
    dismissUpdate: () => updater.dismiss(),
    openReleases: () => updater.openReleasePage(),
    hide: () => panel.hide(),
    quit,
  };
  for (const [name, handler] of Object.entries(handlers)) {
    ipcMain.handle(`caelum:${name}`, (event, ...args) => {
      if (event.senderFrame?.url && !event.senderFrame.url.startsWith("file://")) return null;
      return handler(...args);
    });
  }
}

// MARK: - Lifecycle

app.on("second-instance", () => panel && showPanel());
app.on("window-all-closed", (e) => e.preventDefault());   // tray app: stay alive
app.on("before-quit", () => { app.isQuitting = true; });

app.whenReady().then(() => {
  const userData = app.getPath("userData");
  settings = new Settings(userData);
  // Not "Cache": Chromium keeps its own HTTP cache there.
  cache = new ImageCache(path.join(userData, "Images"));
  state.activeSourceID = sources.byId(settings.get("activeSourceID")).id;

  const firstRun = settings.get("lastRunVersion") === null;
  settings.set("lastRunVersion", app.getVersion());

  updater = new UpdateManager({
    autoInstall: () => settings.get("autoInstallUpdates"),
    onChange: (update) => { state.update = update; push(); },
  });
  state.update = updater.publicState();

  registerIPC();
  createPanel();
  createTray();

  // Initial content, then the daily refresh (applies the wallpaper when due).
  loadLatest().then(() => dailyCheck());
  setInterval(() => dailyCheck(), 5 * 60000);
  powerMonitor.on("resume", () => { dailyCheck(); updater.onResume(); });
  rescheduleRotation();
  updater.start();

  // A tray app is easy to miss on first launch (and GNOME hides tray icons
  // without an extension) — show the panel unless started at login.
  if (firstRun || !process.argv.includes("--hidden")) {
    panel.webContents.once("did-finish-load", showPanel);
  }
});
