// Persisted preferences — a small JSON file in the user-data folder (the port of
// Preferences.swift). Writes are atomic so a crash can't leave a torn file.
"use strict";

const fs = require("fs");
const path = require("path");

const DEFAULTS = {
  activeSourceID: "apod",
  autoDailyRefresh: true,       // fetch the newest image every day and set it as wallpaper
  rotateLibrary: false,
  rotateMinutes: 60,
  launchAtLogin: false,
  autoInstallUpdates: false,    // updates are always offered; installing unasked is opt-in
  lastFetchedDate: null,        // "yyyy-MM-dd" (local) of the last applied daily refresh
  lastRunVersion: null,
};

class Settings {
  constructor(directory) {
    this.file = path.join(directory, "settings.json");
    this.values = { ...DEFAULTS };
    try {
      Object.assign(this.values, JSON.parse(fs.readFileSync(this.file, "utf8")));
    } catch { /* first run or unreadable — defaults */ }
  }

  get(key) { return this.values[key]; }

  set(key, value) {
    if (!(key in DEFAULTS)) throw new Error(`Unknown setting ${key}`);
    this.values[key] = value;
    const tmp = `${this.file}.tmp`;
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    fs.writeFileSync(tmp, JSON.stringify(this.values, null, 2));
    fs.renameSync(tmp, this.file);
  }

  /** The settings the panel may show and change. */
  publicValues() {
    const { activeSourceID, autoDailyRefresh, rotateLibrary, rotateMinutes, launchAtLogin, autoInstallUpdates } = this.values;
    return { activeSourceID, autoDailyRefresh, rotateLibrary, rotateMinutes, launchAtLogin, autoInstallUpdates };
  }
}

module.exports = { Settings, DEFAULTS };
