// Extracts Caelum's icons from the macOS app's Resources/AppIcon.icns, which embeds
// ready-made PNGs, so all platforms share one icon. Run: npm run icons
"use strict";
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const icns = fs.readFileSync(path.join(root, "..", "Resources", "AppIcon.icns"));

const chunks = {};
for (let i = 8; i < icns.length; ) {
  const type = icns.toString("ascii", i, i + 4);
  const length = icns.readUInt32BE(i + 4);
  chunks[type] = icns.subarray(i + 8, i + length);
  i += length;
}

const outputs = {
  "build/icon.png": "ic10",          // 1024×1024 — installers, .ico, Linux packages
  "src/assets/icon.png": "ic09",     // 512×512 — window / notification icon
  "src/assets/tray.png": "ic11",     // 32×32
  "src/assets/tray@2x.png": "ic12",  // 64×64
};
for (const [file, type] of Object.entries(outputs)) {
  const png = chunks[type];
  if (!png || png.readUInt32BE(0) !== 0x89504e47) throw new Error(`AppIcon.icns has no PNG ${type}`);
  fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
  fs.writeFileSync(path.join(root, file), png);
  console.log(`${file} ← ${type} (${png.length} bytes)`);
}
