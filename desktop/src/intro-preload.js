// The intro page's door to the main process — a fixed set of actions.
"use strict";
const { contextBridge, ipcRenderer } = require("electron");

const call = (name) => (...args) => ipcRenderer.invoke(`caelum-intro:${name}`, ...args);

contextBridge.exposeInMainWorld("caelumIntro", {
  getSetup: call("getSetup"),
  selectSource: call("selectSource"),
  setSetting: call("setSetting"),
  preparePreview: call("preparePreview"),
  applyWallpaper: call("applyWallpaper"),
  finish: call("finish"),
  onPreview: (callback) => {
    const listener = (_event, preview) => callback(preview);
    ipcRenderer.on("caelum-intro:preview", listener);
    return () => ipcRenderer.removeListener("caelum-intro:preview", listener);
  },
});
