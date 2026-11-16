// Draws every app icon from the palettes in Design/Icon/icons.json.
// Run from the repository root with Node and Playwright installed: node Scripts/render-icons.cjs
//
// For each icon it writes:
//   Design/Icon/<Name>-light.svg and -dark.svg          the vector sources, for reference
//   App/Assets.xcassets/AppIcon[-<Name>].appiconset     light, dark, tinted and macOS sizes
//   QuillKit/Sources/QuillKit/Resources/Icons.xcassets  the previews the icon picker shows
//
// The primary icon's set is named AppIcon. The others are alternate icons, named
// AppIcon-<Name>, which is the name `AppIcon.alternateName` passes to the system.
const { chromium } = require("playwright");
const { readFileSync, writeFileSync, mkdirSync, rmSync } = require("node:fs");

const { icons, tinted } = JSON.parse(readFileSync("Design/Icon/icons.json", "utf8"));
const appAssets = "App/Assets.xcassets";
const kitAssets = "QuillKit/Sources/QuillKit/Resources/Icons.xcassets";
const macSizes = [16, 32, 64, 128, 256, 512, 1024];
const previewSize = 192;

const nib =
  "M0 340 C-20 270 -80 215 -125 150 C-160 100 -195 40 -190 -40 C-188 -110 -170 -160 -120 -200 " +
  "L-120 -290 Q-120 -300 -108 -300 L108 -300 Q120 -300 120 -290 L120 -200 " +
  "C170 -160 188 -110 190 -40 C195 40 160 100 125 150 C80 215 20 270 0 340 Z " +
  "M-6 -26 L-6 292 L6 292 L6 -26 Z M-34 -60 a34 34 0 1 0 68 0 a34 34 0 1 0 -68 0 Z";

// `radius` rounds the corners for macOS, where the icon carries its own shape.
// `flat` leaves out the paper grain and edge highlight, as the tinted icon needs.
function svg({ top, bottom, nib: [nibStart, nibEnd], shadow, shadowOpacity, flat }, radius = 0) {
  const texture = flat
    ? ""
    : `<g clip-path="url(#c)"><rect width="1024" height="1024" filter="url(#n)" opacity="0.1"/>` +
      `<rect width="1024" height="1024" rx="${radius}" fill="none" stroke="#fff" stroke-opacity=".12" stroke-width="6"/></g>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
<defs>
<linearGradient id="t" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${top}"/><stop offset="1" stop-color="${bottom}"/></linearGradient>
<linearGradient id="w" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${nibStart}"/><stop offset="1" stop-color="${nibEnd}"/></linearGradient>
<filter id="n"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" seed="4"/><feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 .9 -.25"/></filter>
<filter id="s" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="18" stdDeviation="16" flood-color="${shadow}" flood-opacity="${shadowOpacity}"/></filter>
<clipPath id="c"><rect width="1024" height="1024" rx="${radius}"/></clipPath>
</defs>
<rect width="1024" height="1024" rx="${radius}" fill="url(#t)"/>
${texture}
<g transform="translate(560 420) rotate(35)" filter="url(#s)"><path fill="url(#w)" fill-rule="evenodd" d="${nib}"/></g>
<circle cx="330" cy="772" r="44" fill="url(#w)" filter="url(#s)"/>
</svg>
`;
}

let browser;

// `inset` leaves the margin macOS icons keep around their shape, on a transparent canvas.
async function render(markup, size, { inset = 0 } = {}) {
  const page = await browser.newPage({ viewport: { width: size, height: size } });
  const inner = size - (inset * 2 * size) / 1024;
  const shadow = inset ? `filter:drop-shadow(0 ${size * 0.01}px ${size * 0.02}px rgba(0,0,0,.3))` : "";
  await page.setContent(
    `<body style="margin:0;background:${inset ? "transparent" : "#000"}">
       <div style="width:${size}px;height:${size}px;display:grid;place-items:center">
         <div style="width:${inner}px;height:${inner}px;${shadow}">${markup}</div>
       </div>
     </body>`
  );
  const png = await page.screenshot({ omitBackground: inset > 0 });
  await page.close();
  return png;
}

function writeJSON(path, value) {
  writeFileSync(path, JSON.stringify(value, null, 2) + "\n");
}

function appearance(value) {
  return [{ appearance: "luminosity", value }];
}

function appIconContents() {
  const ios = { idiom: "universal", platform: "ios", size: "1024x1024" };
  const mac = [16, 32, 128, 256, 512].flatMap((points) => [
    { filename: `mac-${points}.png`, idiom: "mac", scale: "1x", size: `${points}x${points}` },
    { filename: `mac-${points * 2}.png`, idiom: "mac", scale: "2x", size: `${points}x${points}` },
  ]);
  return {
    images: [
      { filename: "icon-light.png", ...ios },
      { appearances: appearance("dark"), filename: "icon-dark.png", ...ios },
      { appearances: appearance("tinted"), filename: "icon-tinted.png", ...ios },
      ...mac,
    ],
    info: { author: "xcode", version: 1 },
  };
}

const previewContents = {
  images: [
    { filename: "light.png", idiom: "universal" },
    { appearances: appearance("dark"), filename: "dark.png", idiom: "universal" },
  ],
  info: { author: "xcode", version: 1 },
};

async function main() {
  browser = await chromium.launch();
  const tintedPNG = await render(svg(tinted), 1024);
  writeFileSync("Design/Icon/tinted.svg", svg(tinted));

  rmSync(kitAssets, { recursive: true, force: true });
  mkdirSync(kitAssets, { recursive: true });
  writeJSON(`${kitAssets}/Contents.json`, { info: { author: "xcode", version: 1 } });

  for (const icon of icons) {
    const set = `${appAssets}/AppIcon${icon.primary ? "" : "-" + icon.name}.appiconset`;
    rmSync(set, { recursive: true, force: true });
    mkdirSync(set, { recursive: true });
    writeJSON(`${set}/Contents.json`, appIconContents());
    writeFileSync(`${set}/icon-light.png`, await render(svg(icon.light), 1024));
    writeFileSync(`${set}/icon-dark.png`, await render(svg(icon.dark), 1024));
    writeFileSync(`${set}/icon-tinted.png`, tintedPNG);
    for (const size of macSizes) {
      writeFileSync(`${set}/mac-${size}.png`, await render(svg(icon.light, 230), size, { inset: 100 }));
    }

    const preview = `${kitAssets}/IconPreview-${icon.name}.imageset`;
    mkdirSync(preview, { recursive: true });
    writeJSON(`${preview}/Contents.json`, previewContents);
    for (const mode of ["light", "dark"]) {
      writeFileSync(`Design/Icon/${icon.name}-${mode}.svg`, svg(icon[mode]));
      writeFileSync(`${preview}/${mode}.png`, await render(svg(icon[mode]), previewSize));
    }
  }
  await browser.close();
}

main();
