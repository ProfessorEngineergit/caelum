// The top-bar icon on Linux. KDE, Xfce, Cinnamon and friends host tray icons
// themselves; GNOME (Fedora Workstation, …) only shows them through the
// AppIndicator extension. The Fedora package pulls that extension in — this
// switches it on for the user and says what's still needed when it can't.
"use strict";

const { execFile } = require("child_process");

const EXTENSION = "appindicatorsupport@rgcjonas.gmail.com";

function run(cmd, args) {
  return new Promise((resolve) => {
    execFile(cmd, args, { timeout: 5000 }, (err, stdout) => resolve(err ? null : String(stdout)));
  });
}

/** Is something on the session bus hosting StatusNotifier (tray) icons? */
async function hasTrayHost() {
  const out = await run("gdbus", ["call", "--session", "--dest", "org.freedesktop.DBus",
    "--object-path", "/org/freedesktop/DBus", "--method", "org.freedesktop.DBus.NameHasOwner",
    "org.kde.StatusNotifierWatcher"]);
  return out === null ? true : out.includes("true");      // can't tell → don't nag
}

/**
 * Makes sure the tray icon can show; returns a one-line hint for the panel when
 * the user still has to do something, or null.
 */
async function ensureTrayHost() {
  if (process.platform !== "linux" || await hasTrayHost()) return null;
  if (!/gnome/i.test(process.env.XDG_CURRENT_DESKTOP || "")) return null;

  const installed = (await run("gnome-extensions", ["info", EXTENSION])) !== null;
  if (!installed) {
    return "To see Caelum in the top bar, install the AppIndicator extension: sudo dnf install gnome-shell-extension-appindicator — then log out and back in.";
  }
  await run("gnome-extensions", ["enable", EXTENSION]);
  await new Promise((r) => setTimeout(r, 1500));
  if (await hasTrayHost()) return null;
  // A freshly installed extension only loads with a new GNOME session.
  return "Caelum's top-bar icon appears after you log out and back in once.";
}

module.exports = { ensureTrayHost };
