// Downloads images to disk (the wallpaper APIs need local files). Deduplicates by
// URL, shares in-flight downloads and prunes to a bounded number of files —
// the port of ImageCache.swift.
"use strict";

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { Readable } = require("stream");
const { pipeline } = require("stream/promises");
const { USER_AGENT } = require("./sources");

const EXTENSIONS = new Set(["jpg", "jpeg", "png", "webp"]);

class ImageCache {
  constructor(directory, maxFiles = 160) {
    this.directory = directory;
    this.maxFiles = maxFiles;
    this.inFlight = new Map();
    fs.mkdirSync(directory, { recursive: true });
  }

  /** Full-resolution file, falling back to the preview if the original fails. */
  async localFile(image) {
    try {
      return await this.download(image.imageURL);
    } catch (err) {
      if (image.thumbURL && image.thumbURL !== image.imageURL) return this.download(image.thumbURL);
      throw err;
    }
  }

  /** A small file quickly — for the panel preview. */
  async previewFile(image) {
    if (!image.thumbURL) return this.localFile(image);
    try {
      return await this.download(image.thumbURL);
    } catch {
      return this.localFile(image);
    }
  }

  cachedFile(url) {
    const file = path.join(this.directory, this.filename(url));
    if (!fs.existsSync(file)) return null;
    const now = new Date();
    try { fs.utimesSync(file, now, now); } catch { /* best effort */ }
    return file;
  }

  isCached(image) {
    return Boolean(this.cachedFile(image.imageURL) || (image.thumbURL && this.cachedFile(image.thumbURL)));
  }

  download(url) {
    const hit = this.cachedFile(url);
    if (hit) return Promise.resolve(hit);
    if (!this.inFlight.has(url)) {
      const task = this.performDownload(url).finally(() => this.inFlight.delete(url));
      this.inFlight.set(url, task);
    }
    return this.inFlight.get(url);
  }

  async performDownload(url) {
    const res = await fetch(url, {
      headers: { "User-Agent": USER_AGENT },
      signal: AbortSignal.timeout(180000),
    });
    if (!res.ok || !res.body) throw new Error(`Image download failed (HTTP ${res.status}).`);
    const type = res.headers.get("content-type") || "";
    if (type && !type.startsWith("image/")) {
      await res.body.cancel();
      throw new Error("The image URL didn't return an image.");
    }
    const file = path.join(this.directory, this.filename(url));
    const partial = `${file}.part`;
    await pipeline(Readable.fromWeb(res.body), fs.createWriteStream(partial));
    if (fs.statSync(partial).size <= 1024) {
      fs.rmSync(partial, { force: true });
      throw new Error("No usable image was found.");
    }
    fs.renameSync(partial, file);
    this.prune();
    return file;
  }

  filename(url) {
    const hash = crypto.createHash("sha256").update(url).digest("hex");
    let ext = "jpg";
    try {
      const m = new URL(url).pathname.toLowerCase().match(/\.([a-z0-9]+)$/);
      if (m && EXTENSIONS.has(m[1])) ext = m[1];
    } catch { /* keep jpg */ }
    return `${hash}.${ext}`;
  }

  prune() {
    let files;
    try {
      files = fs.readdirSync(this.directory)
        .filter((f) => EXTENSIONS.has(path.extname(f).slice(1).toLowerCase()))
        .map((f) => {
          const full = path.join(this.directory, f);
          return { full, mtime: fs.statSync(full).mtimeMs };
        })
        .sort((a, b) => b.mtime - a.mtime);
    } catch {
      return;
    }
    for (const { full } of files.slice(this.maxFiles)) fs.rmSync(full, { force: true });
  }
}

module.exports = { ImageCache };
