// `npm run smoke` — fetches every source live and checks that its newest image URL
// actually answers. Catches feeds that still return metadata but broken images.
"use strict";
const { all, USER_AGENT } = require("./sources");

(async () => {
  let ok = 0;
  for (const source of all) {
    try {
      const images = await source.fetchRecent(8);
      const image = images.find((i) => !i.isVideo) || images[0];
      const res = await fetch(image.imageURL, { method: "GET", headers: { "User-Agent": USER_AGENT } });
      const type = res.headers.get("content-type") || "";
      await res.body?.cancel();
      if (!res.ok || !type.startsWith("image/")) throw new Error(`image HTTP ${res.status} ${type}`);
      ok++;
      console.log(`✓ ${source.name.padEnd(20)} ${images.length} images · ${image.resolution} · ${image.title}`);
    } catch (err) {
      console.log(`✗ ${source.name.padEnd(20)} ${err.message}`);
    }
  }
  console.log(`\n${ok}/${all.length} sources OK`);
  process.exit(ok === all.length ? 0 : 1);
})();
