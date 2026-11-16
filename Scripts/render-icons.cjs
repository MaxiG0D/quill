// Renders the app icon PNGs in App/Assets.xcassets from the SVG sources in Design/Icon.
// Run from the repository root with Node and Playwright installed: node Scripts/render-icons.cjs
const { chromium } = require("playwright");
const { readFileSync, writeFileSync } = require("node:fs");

const out = "App/Assets.xcassets/AppIcon.appiconset";

async function render(svgPath, size, { inset = 0, opaque = true } = {}) {
  const page = await browser.newPage({ viewport: { width: size, height: size } });
  const svg = readFileSync(svgPath, "utf8");
  // macOS icons sit on a transparent canvas with a margin around the rounded shape.
  const scale = (size - inset * 2 * (size / 1024)) / size;
  await page.setContent(
    `<body style="margin:0;background:${opaque ? "#000" : "transparent"}">
       <div style="width:${size}px;height:${size}px;display:grid;place-items:center">
         <div style="width:${size * scale}px;height:${size * scale}px;${inset ? "filter:drop-shadow(0 " + size * 0.01 + "px " + size * 0.02 + "px rgba(0,0,0,.3))" : ""}">${svg}</div>
       </div>
     </body>`
  );
  const png = await page.screenshot({ omitBackground: !opaque });
  await page.close();
  return png;
}

async function main() {
  writeFileSync(`${out}/icon-light.png`, await render("Design/Icon/icon-light.svg", 1024));
  writeFileSync(`${out}/icon-dark.png`, await render("Design/Icon/icon-dark.svg", 1024));
  writeFileSync(`${out}/icon-tinted.png`, await render("Design/Icon/icon-tinted.svg", 1024));
  for (const size of [16, 32, 64, 128, 256, 512, 1024]) {
    writeFileSync(`${out}/mac-${size}.png`, await render("Design/Icon/icon-mac.svg", size, { inset: 100, opaque: false }));
  }
  await browser.close();
}

let browser;
chromium.launch().then((launched) => {
  browser = launched;
  return main();
});
