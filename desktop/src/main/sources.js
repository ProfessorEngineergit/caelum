// Image sources — the Windows/Linux port of Sources/Caelum/Core/Sources/*.swift.
// Plain Node (global fetch), no Electron imports, so it can be unit-tested and
// smoke-tested with `node`. Every source returns CosmicImage objects:
//   { id, title, credit, explanation, date ("yyyy-MM-dd" | null), sourceID,
//     pageURL, imageURL, thumbURL, isVideo, resolution ("4K" | "HD" | "SD") }
"use strict";

const galleries = require("./galleries.json");

const USER_AGENT = "Caelum/1.0 (Windows/Linux; +https://github.com/ProfessorEngineergit/caelum)";

class SourceError extends Error {}

// MARK: - HTTP

async function fetchText(url, { attempts = 2, timeoutMs = 15000 } = {}) {
  for (let attempt = 1; ; attempt++) {
    try {
      const res = await fetch(url, {
        headers: { "User-Agent": USER_AGENT, Accept: "application/json, application/rss+xml, */*" },
        signal: AbortSignal.timeout(timeoutMs),
      });
      if ((res.status >= 500 || res.status === 429) && attempt < attempts) {
        await sleep(600 * attempt);
        continue;
      }
      if (!res.ok) throw new SourceError(`Network error (HTTP ${res.status}).`);
      return await res.text();
    } catch (err) {
      const transient = err && err.name !== "TimeoutError" && !(err instanceof SourceError);
      if (transient && attempt < attempts) {
        await sleep(600 * attempt);
        continue;
      }
      throw err;
    }
  }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// MARK: - Text helpers

const ENTITIES = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ", mdash: "—", ndash: "–", hellip: "…" };

function decodeEntities(s) {
  return s.replace(/&(#x[0-9a-f]+|#[0-9]+|[a-z]+);/gi, (whole, code) => {
    if (code[0] === "#") {
      const n = code[1] === "x" || code[1] === "X" ? parseInt(code.slice(2), 16) : parseInt(code.slice(1), 10);
      try { return String.fromCodePoint(n); } catch { return whole; }
    }
    return ENTITIES[code.toLowerCase()] ?? whole;
  });
}

/** HTML fragment → single-line plain text. */
function plainText(html) {
  if (!html) return "";
  return decodeEntities(
    String(html)
      .replace(/<(?:br|\/p|\/div|\/li)[^>]*>/gi, " ")
      .replace(/<[^>]+>/g, "")
  )
    .replace(/\s+/g, " ")
    .trim();
}

function classify(width, height) {
  const longest = Math.max(width, height);
  if (longest >= 3840) return "4K";
  if (longest >= 1920) return "HD";
  return "SD";
}

const isHTTP = (s) => typeof s === "string" && /^https?:\/\//i.test(s.trim());

// MARK: - APOD

/**
 * NASA's Astronomy Picture of the Day via the keyless route that replaced the
 * retired api.nasa.gov/planetary/apod (which now returns a NASA logo for every
 * date). See APODSource.swift for the full list of differences; in short:
 * `hdurl` is the image (poster frame for videos) on NASA's resizing CDN, capped
 * at ~1280 px — the original lives at the same path under /content/dam/.
 */
const APOD_ENDPOINT = "https://science.nasa.gov/wp-json/wp/v2/apod-basic";
const APOD_FIELDS = "date,title,explanation,credit,copyright,media_type,url,hdurl,permalink";

const apod = {
  id: "apod",
  name: "NASA APOD",
  subtitle: "Astronomy Picture of the Day",
  accent: "#5EE7FF",

  async fetchRecent(limit = 12) {
    const count = Math.min(Math.max(limit, 1), 25);
    try {
      const images = parseAPOD(await fetchText(`${APOD_ENDPOINT}?per_page=${count}&_fields=${APOD_FIELDS}`));
      if (images.length) return images;
    } catch {
      // fall through to the per-day route
    }
    const days = [...Array(Math.min(count, 8)).keys()].map((n) => yyMMdd(new Date(Date.now() - n * 86400000)));
    const batches = await Promise.all(
      days.map((d) => fetchText(`${APOD_ENDPOINT}/${d}?_fields=${APOD_FIELDS}`).then(parseAPOD, () => []))
    );
    const images = batches.flat().sort(byDateDesc);
    if (!images.length) throw new SourceError("The source returned no images.");
    return images;
  },
};

function parseAPOD(body) {
  let json;
  try { json = JSON.parse(body); } catch { return []; }
  const entries = Array.isArray(json) ? json : [json];
  return entries.map(mapAPOD).filter(Boolean).sort(byDateDesc);
}

function mapAPOD(e) {
  if (!e || typeof e !== "object") return null;
  const str = (v) => (typeof v === "string" ? v : null);   // WordPress sends false/null for empty
  const hd = str(e.hdurl)?.trim();
  if (!isHTTP(hd)) return null;

  const isImage = (str(e.media_type) || "image").toLowerCase() === "image";
  const date = /^\d{4}-\d{2}-\d{2}/.test(str(e.date) || "") ? e.date.slice(0, 10) : null;
  const size = apodOriginalSize(hd);
  const title = plainText(str(e.title));
  const page = [str(e.permalink), str(e.url)].find(isHTTP);

  return {
    id: `apod-${date || Math.random().toString(36).slice(2)}`,
    title: title || "Astronomy Picture of the Day",
    credit: cleanCredit(str(e.copyright)) || cleanCredit(str(e.credit)) || "NASA APOD",
    explanation: cleanExplanation(str(e.explanation)),
    date,
    sourceID: "apod",
    pageURL: page ? page.trim() : "https://science.nasa.gov/apod/",
    imageURL: apodOriginalURL(hd) || hd,
    thumbURL: hd,
    isVideo: !isImage,
    resolution: !isImage ? "SD" : size ? classify(size.width, size.height) : "HD",
  };
}

/** …/dynamicimage/assets/science/…/x.jpg?w=… → …/content/dam/science/…/x.jpg */
function apodOriginalURL(hd) {
  try {
    const u = new URL(hd);
    const marker = "/dynamicimage/assets/";
    if (!u.pathname.startsWith(marker)) return null;
    u.pathname = "/content/dam/" + u.pathname.slice(marker.length);
    u.search = "";
    return u.toString();
  } catch {
    return null;
  }
}

/** The original's size from the CDN URL's w/h (NASA writes 0 when unknown). */
function apodOriginalSize(hd) {
  try {
    const q = new URL(hd).searchParams;
    const width = parseInt(q.get("w"), 10), height = parseInt(q.get("h"), 10);
    return width > 0 && height > 0 ? { width, height } : null;
  } catch {
    return null;
  }
}

const NOTICE_TEASERS = ["APOD's email", "APOD’s email", "APOD's main NASA site", "APOD’s main NASA site",
  "Tomorrow's picture", "Tomorrow’s picture", "Tomorrow's Picture", "Tomorrow’s Picture"];

/** Explanation without the "Explanation:" label and the site notices after it. */
function cleanExplanation(html) {
  if (!html) return null;
  // Notices follow as bold lines after a break: "…end.<br><br><strong>APOD's email…"
  const cut = html.search(/<br[^>]*>\s*(?:<br[^>]*>\s*)*<(?:strong|b)\b/i);
  let text = plainText(cut >= 0 ? html.slice(0, cut) : html);
  for (const teaser of NOTICE_TEASERS) {
    const i = text.indexOf(teaser);
    if (i >= 0) text = text.slice(0, i);
  }
  text = text.trim().replace(/^explanation:\s*/i, "").trim();
  return text || null;
}

function cleanCredit(html) {
  let text = plainText(html);
  if (!text) return null;
  text = text.replace(/^(?:image\s+)?(?:credit\s*(?:&|and)\s*copyright|credit|copyright)\s*:\s*/i, "").trim();
  return text || null;
}

function yyMMdd(date) {
  const p = (n) => String(n).padStart(2, "0");
  return `${p(date.getUTCFullYear() % 100)}${p(date.getUTCMonth() + 1)}${p(date.getUTCDate())}`;
}

const byDateDesc = (a, b) => (b.date || "").localeCompare(a.date || "");

// MARK: - Djangoplicity (ESA/Hubble, ESA/Webb, ESO)

function djangoplicity({ id, name, subtitle, accent, feedURL, credit }) {
  return {
    id, name, subtitle, accent,
    async fetchRecent(limit = 12) {
      const items = parseRSS(await fetchText(feedURL));
      const images = items
        .filter((it) => it.imageURL && /\.(jpe?g|png)/i.test(it.imageURL))
        .map((it) => ({
          id: `${id}-${it.imageURL}`,
          title: it.title || name,
          credit,
          explanation: plainText(it.description) || null,
          date: null,
          sourceID: id,
          pageURL: it.link || null,
          // The feed links the "screen" size; "large" is the crisp wallpaper.
          imageURL: it.imageURL.replace("/screen/", "/large/").replace("/thumb/", "/large/"),
          thumbURL: it.imageURL,
          isVideo: false,
          resolution: "4K",
        }));
      if (!images.length) throw new SourceError("The source returned no images.");
      return images.slice(0, limit);
    },
  };
}

/** Minimal RSS/Atom reader: title, link, description and the first image enclosure. */
function parseRSS(xml) {
  const items = [];
  for (const [, body] of xml.matchAll(/<(?:item|entry)\b[^>]*>([\s\S]*?)<\/(?:item|entry)>/gi)) {
    const tag = (name) => {
      const m = body.match(new RegExp(`<${name}\\b[^>]*>([\\s\\S]*?)<\\/${name}>`, "i"));
      if (!m) return null;
      return m[1].replace(/^\s*<!\[CDATA\[([\s\S]*?)\]\]>\s*$/, "$1").trim();
    };
    let imageURL = null;
    for (const [el] of body.matchAll(/<(?:enclosure|media:content|media:thumbnail)\b[^>]*>/gi)) {
      const url = el.match(/\burl="([^"]+)"/i)?.[1];
      const type = el.match(/\btype="([^"]+)"/i)?.[1] || "";
      if (url && (type.startsWith("image") || /\.(jpe?g|png)/i.test(url))) { imageURL = decodeEntities(url); break; }
    }
    let link = tag("link");
    if (!link) link = body.match(/<link\b[^>]*href="([^"]+)"/i)?.[1] || null;
    items.push({
      title: plainText(tag("title")),
      link: link ? decodeEntities(link) : null,
      description: tag("description") || tag("summary"),
      imageURL,
    });
  }
  return items;
}

// MARK: - Curated galleries (generated from StaticGallerySource.swift)

function gallery(g) {
  return {
    id: g.id, name: g.name, subtitle: g.subtitle, accent: g.accent,
    async fetchRecent(limit = 12) {
      // Rotates daily for variety, deterministic within a day.
      const offset = Math.floor(Date.now() / 86400000) % g.assets.length;
      const rotated = [...g.assets.slice(offset), ...g.assets.slice(0, offset)];
      return rotated.slice(0, Math.max(limit, 1)).map((a) => ({
        id: `${g.id}-${a.identifier}`,
        title: a.title,
        credit: a.credit,
        explanation: a.explanation,
        date: a.date || null,
        sourceID: g.id,
        pageURL: a.pageURL || null,
        imageURL: a.imageURL,
        thumbURL: a.thumbURL || null,
        isVideo: false,
        resolution: a.resolution || "4K",
      }));
    },
  };
}

// MARK: - Registry (same order as SourceRegistry.swift)

const all = [
  apod,
  djangoplicity({ id: "hubble", name: "ESA/Hubble", subtitle: "Picture of the Week", accent: "#8B7CFF",
    feedURL: "https://esahubble.org/images/potw/feed/", credit: "ESA/Hubble & NASA" }),
  djangoplicity({ id: "webb", name: "James Webb", subtitle: "ESA/Webb Images", accent: "#FFB45E",
    feedURL: "https://esawebb.org/images/feed/", credit: "ESA/Webb, NASA & CSA" }),
  djangoplicity({ id: "eso", name: "ESO", subtitle: "Picture of the Week", accent: "#5EF2B0",
    feedURL: "https://www.eso.org/public/images/potw/feed/", credit: "ESO" }),
  ...galleries.map(gallery),
];

const byId = (id) => all.find((s) => s.id === id) || all[0];

module.exports = {
  all, byId, SourceError, USER_AGENT,
  // exported for tests
  parseAPOD, parseRSS, cleanExplanation, cleanCredit, plainText, apodOriginalURL, classify,
};
