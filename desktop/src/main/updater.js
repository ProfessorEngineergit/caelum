// In-app updates from GitHub Releases (the same releases the macOS app reads).
// A new version is always offered in the panel; with "Install updates
// automatically" on, it is downloaded and applied without asking. Mirrors the
// state machine of Updater.swift so both apps behave the same.
//
// electron-updater reads latest.yml (Windows) / latest-linux.yml (AppImage) from
// the release, verifies the download's SHA-512 and runs the installer.
"use strict";

const { app, shell } = require("electron");
const { autoUpdater } = require("electron-updater");

const RELEASES_URL = "https://github.com/ProfessorEngineergit/caelum/releases/latest";
const CHECK_INTERVAL_MS = 6 * 3600 * 1000;

class UpdateManager {
  /**
   * @param {object} opts
   * @param {() => boolean} opts.autoInstall  reads the "install automatically" setting
   * @param {(state: object) => void} opts.onChange  pushes state to the panel
   */
  constructor({ autoInstall, onChange }) {
    this.autoInstall = autoInstall;
    this.onChange = onChange;
    this.state = { status: "idle", currentVersion: app.getVersion(), canSelfInstall: UpdateManager.canSelfInstall() };
    this.dismissedVersion = null;
    this.lastChecked = 0;

    autoUpdater.autoDownload = false;
    autoUpdater.autoInstallOnAppQuit = false;
    autoUpdater.logger = null;

    autoUpdater.on("download-progress", (p) => {
      if (this.state.status === "downloading") this.update({ percent: Math.round(p.percent || 0) });
    });
  }

  /**
   * Windows installs (NSIS) and AppImages can replace themselves. A .deb/.rpm
   * belongs to the package manager and a dev run has nothing to replace — those
   * get "Download" (opens the release page) instead.
   */
  static canSelfInstall() {
    if (!app.isPackaged) return false;
    if (process.platform === "win32") return !process.env.PORTABLE_EXECUTABLE_DIR;
    if (process.platform === "linux") return Boolean(process.env.APPIMAGE);
    return false;
  }

  update(patch) {
    this.state = { ...this.state, ...patch };
    this.onChange(this.publicState());
  }

  publicState() {
    const { status, version } = this.state;
    const offered = ["available", "failed"].includes(status) && version;
    return {
      ...this.state,
      showBanner: offered ? this.dismissedVersion !== version : ["downloading", "installing"].includes(status),
    };
  }

  start() {
    setTimeout(() => this.check(false), 8000);
    setInterval(() => this.check(false), CHECK_INTERVAL_MS);
  }

  /** After sleep: check if a scheduled check was missed. */
  onResume() {
    if (Date.now() - this.lastChecked > CHECK_INTERVAL_MS) this.check(false);
  }

  async check(userInitiated) {
    if (["checking", "downloading", "installing"].includes(this.state.status)) return;
    if (!app.isPackaged) {
      if (userInitiated) this.update({ status: "failed", message: "Update checks only work in the installed Caelum.", version: null });
      return;
    }
    const previous = this.state;
    if (userInitiated) this.update({ status: "checking", message: null });
    try {
      const result = await autoUpdater.checkForUpdates();
      this.lastChecked = Date.now();
      const version = result?.updateInfo?.version;
      if (result?.isUpdateAvailable && version) {
        this.update({ status: "available", version, message: null });
        if (this.autoInstall() && this.state.canSelfInstall) this.install();
      } else {
        this.update({ status: "upToDate", version: null, message: null });
      }
    } catch (err) {
      console.error("Caelum: update check failed:", err);
      if (userInitiated) {
        this.update({ status: "failed", message: `Couldn't check for updates — ${shortError(err)}`, version: null });
      } else {
        this.state = previous;
      }
    }
  }

  dismiss() {
    this.dismissedVersion = this.state.version || null;
    this.onChange(this.publicState());
  }

  /** Called when "install automatically" is switched on: install what's on offer now. */
  installPendingIfAutomatic() {
    if (this.autoInstall() && this.state.canSelfInstall && this.state.status === "available") this.install();
  }

  async install() {
    const { status, version } = this.state;
    if (!["available", "failed"].includes(status) || !version) return;
    if (!this.state.canSelfInstall) {
      shell.openExternal(RELEASES_URL);
      return;
    }
    this.dismissedVersion = null;
    this.update({ status: "downloading", percent: 0, message: null });
    try {
      await autoUpdater.downloadUpdate();
      this.update({ status: "installing" });
      // Give the panel a moment to show "Installing…", then quit, install silently and relaunch.
      setTimeout(() => {
        app.isQuittingForUpdate = true;
        autoUpdater.quitAndInstall(true, true);
      }, 800);
    } catch (err) {
      console.error("Caelum: update install failed:", err);
      this.update({ status: "failed", message: shortError(err) });
    }
  }

  openReleasePage() {
    shell.openExternal(RELEASES_URL);
  }
}

function shortError(err) {
  const text = String(err?.message || err || "unknown error").split("\n")[0];
  return text.length > 140 ? `${text.slice(0, 137)}…` : text;
}

module.exports = { UpdateManager, RELEASES_URL };
