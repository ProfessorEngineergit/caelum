// The panel's only door to the main process: a fixed list of actions plus the
// state stream. No Node APIs reach the page.
"use strict";
const { contextBridge, ipcRenderer } = require("electron");

const actions = ["getState", "selectSource", "next", "previous", "shuffle", "refresh", "setWallpaper",
  "openPage", "openURL", "setSetting", "checkForUpdates", "installUpdate", "dismissUpdate",
  "openReleases", "hide", "quit"];

const api = {};
for (const name of actions) api[name] = (...args) => ipcRenderer.invoke(`caelum:${name}`, ...args);
api.onState = (callback) => {
  const listener = (_event, state) => callback(state);
  ipcRenderer.on("state", listener);
  return () => ipcRenderer.removeListener("state", listener);
};

api.onShown = (callback) => {
  const listener = () => callback();
  ipcRenderer.on("shown", listener);
  return () => ipcRenderer.removeListener("shown", listener);
};

api.onOpenSettings = (callback) => {
  const listener = () => callback();
  ipcRenderer.on("open-settings", listener);
  return () => ipcRenderer.removeListener("open-settings", listener);
};

contextBridge.exposeInMainWorld("caelum", api);
