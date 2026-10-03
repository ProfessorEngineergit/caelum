"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const s = require("../src/main/sources");

// Trimmed from a real science.nasa.gov/wp-json/wp/v2/apod-basic response.
const APOD = JSON.stringify([
  {
    date: "2026-10-02",
    title: "The Complete Sharpless Catalog: 313 Nebulas",
    permalink: "https://science.nasa.gov/image-article/apod-2026-october-2-the-complete-sharpless-catalog-313-nebulae/",
    media_type: "image",
    explanation: "<strong>Explanation:</strong> What does it take to image hundreds of nebulas? <a href=\"x\">Today’s image</a> contains 313 objects.<br><br><strong>APOD's email for image submissions has changed.</strong> Please see: <a href=\"y\">APOD Submissions</a><br><strong>Tomorrow's picture: </strong><a href=\"z\">just Curiosity</a>",
    credit: "<a href=\"https://example.com\">Bing Xin</a>",
    copyright: "<a href=\"https://example.com\">Bing Xin</a>",
    url: "https://science.nasa.gov/image-article/apod-2026-october-2-the-complete-sharpless-catalog-313-nebulae/",
    hdurl: "https://assets.science.nasa.gov/dynamicimage/assets/science/cds/apod/apod/2026/october/sharpless_catalog.png?w=4455&h=5592&fit=clip&crop=faces%2Cfocalpoint",
  },
  {
    date: "2026-10-03",
    title: "Selfie at Vera Rubin Ridge",
    media_type: "image",
    explanation: "<strong>Explanation: </strong>On sol 1943 the Curiosity Rover recorded this selfie.",
    credit: "<strong>Image Credit:</strong> <a href=\"http://www.nasa.gov/\">NASA</a>, JPL-Caltech",
    copyright: false,
    url: "https://science.nasa.gov/image-article/apod-2026-october-3-selfie-at-vera-rubin-ridge/",
    hdurl: "https://assets.science.nasa.gov/dynamicimage/assets/science/cds/apod/apod/2026/october/Sol1943CuriosityBodrov.jpg?w=1600&h=800&fit=clip",
  },
  {
    date: "2026-09-13",
    title: "Comet Video",
    media_type: "video",
    explanation: "A video.",
    hdurl: "https://assets.science.nasa.gov/dynamicimage/assets/science/cds/apod/apod/2026/september/Comet_snapshot.png?w=0&h=0",
  },
  { date: "2026-09-12", title: "No image", hdurl: false },
]);

test("APOD: newest first, entries without an image dropped", () => {
  const images = s.parseAPOD(APOD);
  assert.deepEqual(images.map((i) => i.date), ["2026-10-03", "2026-10-02", "2026-09-13"]);
});

test("APOD: wallpaper is the full-resolution original, the CDN copy is the preview", () => {
  const [, sharpless] = s.parseAPOD(APOD);
  assert.equal(sharpless.imageURL,
    "https://assets.science.nasa.gov/content/dam/science/cds/apod/apod/2026/october/sharpless_catalog.png");
  assert.match(sharpless.thumbURL, /\/dynamicimage\/assets\/.*\?w=4455/);
  assert.equal(sharpless.resolution, "4K");
  assert.equal(sharpless.id, "apod-2026-10-02");
});

test("APOD: text is cleaned of HTML, labels and site notices", () => {
  const [selfie, sharpless] = s.parseAPOD(APOD);
  assert.equal(sharpless.explanation, "What does it take to image hundreds of nebulas? Today’s image contains 313 objects.");
  assert.equal(sharpless.credit, "Bing Xin");
  assert.equal(selfie.explanation, "On sol 1943 the Curiosity Rover recorded this selfie.");
  assert.equal(selfie.credit, "NASA, JPL-Caltech");
  assert.equal(selfie.resolution, "SD");    // 1600×800
  assert.equal(selfie.pageURL, "https://science.nasa.gov/image-article/apod-2026-october-3-selfie-at-vera-rubin-ridge/");
});

test("APOD: videos are flagged and never claim 4K", () => {
  const video = s.parseAPOD(APOD).find((i) => i.isVideo);
  assert.equal(video.title, "Comet Video");
  assert.equal(video.resolution, "SD");
});

test("APOD: error bodies and garbage parse to nothing", () => {
  assert.deepEqual(s.parseAPOD('{"code":"apod_basic_not_found","message":"APOD not found.","data":{"status":404}}'), []);
  assert.deepEqual(s.parseAPOD("<html>"), []);
});

test("APOD: original URL only for the resizing CDN", () => {
  assert.equal(s.apodOriginalURL("https://apod.nasa.gov/apod/image/2610/x.jpg"), null);
});

test("RSS: Djangoplicity items with enclosures", () => {
  const xml = `<?xml version="1.0"?><rss><channel><title>Feed</title>
    <item><title>A galaxy &amp; friends</title><link>https://esahubble.org/images/potw2640a/</link>
      <description><![CDATA[<p>Spiral <b>galaxy</b>.</p>]]></description>
      <enclosure url="https://cdn.esahubble.org/archives/images/screen/potw2640a.jpg" type="image/jpeg" length="1"/></item>
    <item><title>Video</title><enclosure url="https://x/v.mp4" type="video/mp4"/></item>
  </channel></rss>`;
  const items = s.parseRSS(xml);
  assert.equal(items.length, 2);
  assert.equal(items[0].title, "A galaxy & friends");
  assert.equal(items[0].link, "https://esahubble.org/images/potw2640a/");
  assert.equal(items[0].imageURL, "https://cdn.esahubble.org/archives/images/screen/potw2640a.jpg");
  assert.equal(s.plainText(items[0].description), "Spiral galaxy.");
  assert.equal(items[1].imageURL, null);
});

test("Registry: same sources and order as the macOS app", () => {
  assert.deepEqual(s.all.map((x) => x.id),
    ["apod", "hubble", "webb", "eso", "deep", "earth", "solar", "stations", "interstellar", "artist-impressions"]);
});

test("Galleries: every image has https URLs", async () => {
  for (const source of s.all.slice(4)) {
    const images = await source.fetchRecent(100);
    assert.ok(images.length >= 7, source.id);
    for (const i of images) {
      assert.match(i.imageURL, /^https:\/\//);
      if (i.thumbURL) assert.match(i.thumbURL, /^https:\/\//);
    }
  }
});

test("Entities and resolution classes", () => {
  assert.equal(s.plainText("Tom&#8217;s &#x2014; A&nbsp;B"), "Tom’s — A B");
  assert.equal(s.classify(3840, 2160), "4K");
  assert.equal(s.classify(1920, 1080), "HD");
  assert.equal(s.classify(1600, 800), "SD");
});
