// Sets the desktop wallpaper on Windows and the common Linux desktops.
// Every external command runs via execFile (no shell) and gets the path as a
// separate argument or environment variable — never spliced into a command line.
"use strict";

const fs = require("fs");
const path = require("path");
const { execFile } = require("child_process");
const { pathToFileURL } = require("url");

function run(cmd, args, options = {}) {
  return new Promise((resolve, reject) => {
    execFile(cmd, args, { timeout: 20000, windowsHide: true, ...options }, (err, stdout, stderr) => {
      if (err) {
        err.message = `${cmd}: ${(stderr || err.message).toString().trim()}`;
        reject(err);
      } else {
        resolve(stdout.toString());
      }
    });
  });
}

/**
 * Copies the image out of the (pruned) cache into a dedicated folder so the
 * wallpaper survives cache cleanup and reboots. The name changes per image —
 * GNOME and others ignore a "new" wallpaper whose path didn't change.
 */
function stage(file, directory) {
  fs.mkdirSync(directory, { recursive: true });
  const target = path.join(directory, `caelum-${Date.now()}${path.extname(file) || ".jpg"}`);
  fs.copyFileSync(file, target);
  for (const old of fs.readdirSync(directory)) {
    const full = path.join(directory, old);
    if (full !== target && old.startsWith("caelum-")) fs.rmSync(full, { force: true });
  }
  return target;
}

// MARK: - Windows

const WINDOWS_SCRIPT = `
$ErrorActionPreference = 'Stop'
$path = $env:CAELUM_WALLPAPER
Set-ItemProperty -Path 'HKCU:\\Control Panel\\Desktop' -Name WallpaperStyle -Value '10'
Set-ItemProperty -Path 'HKCU:\\Control Panel\\Desktop' -Name TileWallpaper -Value '0'
Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public static class CaelumWallpaper {
  [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern bool SystemParametersInfo(int action, int param, string value, int flags);
}
"@
# SPI_SETDESKWALLPAPER, SPIF_UPDATEINIFILE | SPIF_SENDWININICHANGE
if (-not [CaelumWallpaper]::SystemParametersInfo(20, 0, $path, 3)) { throw "SystemParametersInfo failed" }
`;

async function setWindows(file) {
  await run("powershell.exe",
    ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", WINDOWS_SCRIPT],
    { env: { ...process.env, CAELUM_WALLPAPER: file } });
}

// MARK: - Linux

const KDE_SCRIPT = `
var file = "file://" + %PATH%;
desktops().forEach(function (d) {
  d.wallpaperPlugin = "org.kde.image";
  d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
  d.writeConfig("Image", file);
});`;

async function setLinux(file) {
  const name = process.env.XDG_CURRENT_DESKTOP || process.env.DESKTOP_SESSION || "";
  const desktop = name.toLowerCase();
  const uri = pathToFileURL(file).href;
  const attempts = [];

  if (/kde|plasma/.test(desktop)) {
    attempts.push(() => run("plasma-apply-wallpaperimage", [file]));
    for (const qdbus of ["qdbus6", "qdbus-qt6", "qdbus", "qdbus-qt5"]) {
      attempts.push(() => run(qdbus, ["org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript",
        KDE_SCRIPT.replace("%PATH%", JSON.stringify(file))]));
    }
  }
  if (/xfce/.test(desktop)) {
    attempts.push(async () => {
      const props = (await run("xfconf-query", ["-c", "xfce4-desktop", "-l"]))
        .split("\n").filter((p) => /\/last-image$/.test(p));
      if (!props.length) throw new Error("xfconf-query: no backdrop properties");
      for (const p of props) await run("xfconf-query", ["-c", "xfce4-desktop", "-p", p, "-s", file]);
    });
  }
  if (/cinnamon/.test(desktop)) {
    attempts.push(() => run("gsettings", ["set", "org.cinnamon.desktop.background", "picture-uri", uri]));
  }
  if (/mate/.test(desktop)) {
    attempts.push(() => run("gsettings", ["set", "org.mate.background", "picture-filename", file]));
  }
  if (/lxqt/.test(desktop)) attempts.push(() => run("pcmanfm-qt", ["--set-wallpaper", file, "--wallpaper-mode", "zoom"]));
  if (/lxde/.test(desktop)) attempts.push(() => run("pcmanfm", ["--set-wallpaper", file, "--wallpaper-mode", "crop"]));
  if (/sway/.test(desktop) || process.env.SWAYSOCK) attempts.push(() => run("swaymsg", ["output", "*", "bg", file, "fill"]));

  // GNOME and its relatives (Ubuntu, Pop!_OS, Budgie, Pantheon, Unity, COSMIC's GNOME schema…)
  // — also the default guess for an unknown desktop.
  attempts.push(async () => {
    await run("gsettings", ["set", "org.gnome.desktop.background", "picture-options", "zoom"]);
    await run("gsettings", ["set", "org.gnome.desktop.background", "picture-uri", uri]);
    // Dark style uses its own key since GNOME 42; absent on older versions.
    await run("gsettings", ["set", "org.gnome.desktop.background", "picture-uri-dark", uri]).catch(() => {});
  });
  // Plain X11 window managers.
  attempts.push(() => run("feh", ["--bg-fill", file]));
  attempts.push(() => run("nitrogen", ["--set-zoom-fill", "--save", file]));

  const errors = [];
  for (const attempt of attempts) {
    try {
      await attempt();
      return;
    } catch (err) {
      errors.push(err.message);
    }
  }
  console.error("Caelum: wallpaper attempts failed:", errors);
  throw new Error(`Couldn't set the wallpaper on ${name ? `this ${name} desktop` : "this desktop"}. ` +
    "Supported: GNOME, KDE Plasma, Xfce, Cinnamon, MATE, LXQt/LXDE, Sway, or feh/nitrogen.");
}

// MARK: - macOS (development convenience; the real Mac app is native)

async function setMac(file) {
  await run("osascript", ["-e", 'on run argv\ntell application "System Events" to tell every desktop to set picture to (item 1 of argv)\nend run', file]);
}

/** Sets `file` as the wallpaper; returns the staged copy the desktop now shows. */
async function setWallpaper(file, stagingDirectory) {
  const staged = stage(file, stagingDirectory);
  if (process.platform === "win32") await setWindows(staged);
  else if (process.platform === "darwin") await setMac(staged);
  else await setLinux(staged);
  return staged;
}

module.exports = { setWallpaper };
