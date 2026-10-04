// The intro / setup / update screen window — the Windows/Linux twin of
// IntroController.swift. The page (src/renderer/intro) draws the jump; this
// module finds the current desktop picture, the library images that fly past,
// the release notes, and wires the setup to the app.
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFile } = require("child_process");
const { pathToFileURL } = require("url");
const { app, BrowserWindow, ipcMain, screen } = require("electron");
const { USER_AGENT } = require("./sources");

const INTRO_VERSION = 2;          // bump to show the intro again to everyone
const REPO = "ProfessorEngineergit/caelum";

let win = null;
let context = null;               // see show()
let ipcReady = false;

function run(cmd, args, timeout = 4000) {
  return new Promise((resolve) => {
    execFile(cmd, args, { timeout, windowsHide: true }, (err, stdout) => resolve(err ? "" : String(stdout)));
  });
}

const fileURL = (p) => (p ? pathToFileURL(p).href : null);

// MARK: - What's on the desktop right now

async function currentWallpaper(userData) {
  try {
    if (process.platform === "win32") {
      const transcoded = path.join(process.env.APPDATA || "", "Microsoft", "Windows", "Themes", "TranscodedWallpaper");
      if (fs.existsSync(transcoded)) {
        // no extension — copy so Chromium sniffs it as an image
        const copy = path.join(userData, "intro-desktop.jpg");
        fs.copyFileSync(transcoded, copy);
        return copy;
      }
    } else if (process.platform === "linux") {
      const desktop = (process.env.XDG_CURRENT_DESKTOP || "").toLowerCase();
      let uri = "";
      if (/kde|plasma/.test(desktop)) {
        const rc = path.join(os.homedir(), ".config", "plasma-org.kde.plasma.desktop-appletsrc");
        uri = (fs.existsSync(rc) ? fs.readFileSync(rc, "utf8") : "").match(/^Image=(.+)$/m)?.[1] || "";
      } else if (/xfce/.test(desktop)) {
        const props = (await run("xfconf-query", ["-c", "xfce4-desktop", "-l"])).split("\n").filter((p) => /last-image$/.test(p));
        if (props[0]) uri = (await run("xfconf-query", ["-c", "xfce4-desktop", "-p", props[0]])).trim();
      } else {
        const dark = (await run("gsettings", ["get", "org.gnome.desktop.interface", "color-scheme"])).includes("dark");
        uri = (await run("gsettings", ["get", "org.gnome.desktop.background", dark ? "picture-uri-dark" : "picture-uri"])).trim();
        if (!uri || uri === "''") uri = (await run("gsettings", ["get", "org.gnome.desktop.background", "picture-uri"])).trim();
      }
      uri = uri.replace(/^'|'$/g, "");
      const file = uri.startsWith("file://") ? decodeURIComponent(new URL(uri).pathname) : uri;
      if (file && fs.existsSync(file) && /\.(jpe?g|png|webp|bmp)$/i.test(file)) return file;
    }
  } catch { /* fall through */ }
  // Fall back to the last wallpaper Caelum set.
  return latestIn(path.join(userData, "Wallpaper"));
}

function latestIn(dir, count = 1) {
  try {
    return fs.readdirSync(dir)
      .filter((f) => /\.(jpe?g|png|webp)$/i.test(f))
      .map((f) => ({ f: path.join(dir, f), m: fs.statSync(path.join(dir, f)).mtimeMs }))
      .sort((a, b) => b.m - a.m)
      .slice(0, count)
      .map((x) => x.f);
  } catch {
    return [];
  }
}

// MARK: - Windows out of the way (Windows: minimise all, like Arc hides apps)

function minimizeAll() {
  if (process.platform !== "win32") return;
  run("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", "(New-Object -ComObject Shell.Application).MinimizeAll()"]);
}

function restoreAll() {
  if (process.platform !== "win32") return;
  run("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", "(New-Object -ComObject Shell.Application).UndoMinimizeALL()"]);
}

// MARK: - Release notes

/** Commit subjects between two releases, from GitHub — the update screen's lines. */
async function changesBetween(from, to) {
  try {
    const res = await fetch(`https://api.github.com/repos/${REPO}/compare/v${from}...v${to}`, {
      headers: { "User-Agent": USER_AGENT, Accept: "application/vnd.github+json" },
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return [];
    const json = await res.json();
    return (json.commits || [])
      .map((c) => String(c.commit?.message || "").split("\n")[0].trim())
      .filter((m) => m && !/^Merge (pull request|branch)/i.test(m))
      .reverse()
      .slice(0, 6);
  } catch {
    return [];
  }
}

// MARK: - Window

function soundsDir() {
  return app.isPackaged
    ? path.join(process.resourcesPath, "sounds")
    : path.join(__dirname, "..", "..", "..", "Resources", "Sounds");
}

/**
 * @param {object} ctx
 *   settings, sources, state, userData, cacheDir,
 *   selectSource(id), setSetting(key, value), applyWallpaper() → file path,
 *   ensurePreview() → {previewURL, title, sourceName}, onDone()
 * @param {"intro"|"update"} mode
 * @param {{from: string, to: string}} [update]
 */
async function show(ctx, mode = "intro", update = null) {
  if (win) return;
  context = { ...ctx, mode, update };
  registerIPC();
  minimizeAll();

  const display = screen.getPrimaryDisplay();
  win = new BrowserWindow({
    ...display.bounds,
    frame: false,
    show: false,
    resizable: false,
    movable: false,
    minimizable: false,
    maximizable: false,
    skipTaskbar: true,
    alwaysOnTop: true,
    backgroundColor: "#000000",
    title: "Caelum",
    webPreferences: {
      preload: path.join(__dirname, "..", "intro-preload.js"),
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false,
      autoplayPolicy: "no-user-gesture-required",
    },
  });
  win.setAlwaysOnTop(true, "screen-saver");
  win.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  win.webContents.on("will-navigate", (e) => e.preventDefault());
  win.on("closed", () => { win = null; });

  // Look things up while the page loads; the jump waits for nothing.
  const [wallpaper, changes] = await Promise.all([
    currentWallpaper(ctx.userData),
    mode === "update" && update ? changesBetween(update.from, update.to) : Promise.resolve([]),
  ]);
  context.wallpaper = wallpaper;
  context.changes = changes;

  await win.loadFile(path.join(__dirname, "..", "renderer", "intro", "intro.html"));
  win.show();
  if (process.platform === "linux") win.setFullScreen(true);   // above panels and docks
  win.focus();
}

/**
 * Ends the intro. With `fade`, the window lets clicks through at once, fades
 * out (Windows; Linux has no window opacity — the last frame already shows the
 * new desktop) and closes once the outro's music has rung out.
 */
function finish({ fade = false } = {}) {
  const done = context?.onDone;
  if (context?.mode === "intro") context.settings.set("introSeen", INTRO_VERSION);
  context = null;
  restoreAll();
  const closing = win;
  win = null;
  done?.();
  if (!closing || closing.isDestroyed()) return;
  if (!fade) return closing.destroy();
  closing.setIgnoreMouseEvents(true);
  closing.setAlwaysOnTop(false);
  const started = Date.now();
  const tick = setInterval(() => {
    if (closing.isDestroyed()) return clearInterval(tick);
    const k = Math.min(1, (Date.now() - started) / 900);
    closing.setOpacity(1 - k * k * (3 - 2 * k));
    if (k >= 1) clearInterval(tick);
  }, 16);
  setTimeout(() => { if (!closing.isDestroyed()) closing.destroy(); }, 2400);
}

function registerIPC() {
  if (ipcReady) return;
  ipcReady = true;
  const handle = (name, fn) => ipcMain.handle(`caelum-intro:${name}`, (event, ...args) => {
    if (!win || event.sender !== win.webContents || !context) return null;
    return fn(...args);
  });

  handle("getSetup", () => {
    const { settings, sources, state, cacheDir, mode, update, changes, wallpaper } = context;
    return {
      mode,
      version: app.getVersion(),
      platform: process.platform,
      wallpaperURL: fileURL(wallpaper),
      soundsURL: pathToFileURL(soundsDir()).href + "/",
      cardURLs: latestIn(cacheDir, 16).map(fileURL),
      sources,
      activeSourceID: state.activeSourceID,
      settings: settings.publicValues(),
      update: update ? { ...update, changes } : null,
    };
  });
  handle("selectSource", (id) => context.selectSource(id));
  handle("setSetting", (key, value) => context.setSetting(key, value));
  handle("preparePreview", async () => {
    const preview = await context.ensurePreview();
    if (win && preview) win.webContents.send("caelum-intro:preview", preview);
  });
  handle("applyWallpaper", async () => fileURL(await context.applyWallpaper()));
  handle("finish", (options) => finish({ fade: Boolean(options?.fade) }));
}

function needsIntro(settings) {
  return (settings.get("introSeen") || 0) < INTRO_VERSION;
}

module.exports = { show, needsIntro, isShowing: () => Boolean(win) };
