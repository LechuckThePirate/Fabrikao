// Draws the two small icons of the map and waypoint buttons (Icons/Map.png: a folded map with a pin; Icons/Pointer.png: a navigation
// arrow). No dependencies: shapes are filled with supersampling and written as 64x64 RGBA PNGs.
//   node tools/make_icons.mjs
import { writeFileSync } from "node:fs";
import { deflateSync } from "node:zlib";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const SIZE = 64, SS = 4;
const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, "..", "Icons");

const inside = (pts, x, y) => {
    let c = false;
    for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
        const [xi, yi] = pts[i], [xj, yj] = pts[j];
        if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) c = !c;
    }
    return c;
};
const edgeDistance = (pts, x, y) => {
    let best = Infinity;
    for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
        const [ax, ay] = pts[j], [bx, by] = pts[i];
        const dx = bx - ax, dy = by - ay;
        const t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy || 1)));
        best = Math.min(best, Math.hypot(x - (ax + t * dx), y - (ay + t * dy)));
    }
    return best;
};

// Renders what `draw` paints into the shapes `cv.polygon(points, fill, outline, w)` (a fill is a color or a function of x) and
// `cv.circle(cx, cy, r, fill, outline, w)`; later shapes cover earlier ones. Each pixel is the mean of SS x SS samples.
function render(draw) {
    // 4x4 samples per pixel, each with its own color and coverage
    const samples = new Float64Array(SIZE * SS * SIZE * SS * 4); // r, g, b, set
    const cv = { paint: null };
    const n = SIZE * SS;
    const put = (pts, fill, outline, w) => {
        for (let sy = 0; sy < n; sy++) {
            for (let sx = 0; sx < n; sx++) {
                const x = (sx + 0.5) / SS, y = (sy + 0.5) / SS;
                if (!inside(pts, x, y)) continue;
                const edge = outline && edgeDistance(pts, x, y) < w;
                const c = edge ? outline : (typeof fill === "function" ? fill(x, y) : fill);
                const i = (sy * n + sx) * 4;
                samples[i] = c[0]; samples[i + 1] = c[1]; samples[i + 2] = c[2]; samples[i + 3] = 1;
            }
        }
    };
    cv.polygon = put;
    cv.circle = (cx, cy, r, fill, outline, w) => {
        const pts = [];
        for (let a = 0; a < 48; a++) pts.push([cx + r * Math.cos((a / 48) * Math.PI * 2), cy + r * Math.sin((a / 48) * Math.PI * 2)]);
        put(pts, fill, outline, w);
    };
    draw(cv);
    // down to pixels
    const px = Buffer.alloc(SIZE * SIZE * 4);
    for (let y = 0; y < SIZE; y++) {
        for (let x = 0; x < SIZE; x++) {
            let r = 0, g = 0, b = 0, a = 0;
            for (let sy = 0; sy < SS; sy++) {
                for (let sx = 0; sx < SS; sx++) {
                    const i = ((y * SS + sy) * n + (x * SS + sx)) * 4;
                    if (samples[i + 3]) { r += samples[i]; g += samples[i + 1]; b += samples[i + 2]; a += 1; }
                }
            }
            const o = (y * SIZE + x) * 4;
            if (a > 0) {
                px[o] = Math.round(r / a); px[o + 1] = Math.round(g / a); px[o + 2] = Math.round(b / a);
                px[o + 3] = Math.round((a / (SS * SS)) * 255);
            }
        }
    }
    return px;
}

// ---- PNG -------------------------------------------------------------------------------------------------------------------
const crcTable = new Uint32Array(256).map((_, n) => {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c >>> 0;
});
const crc32 = (buf) => {
    let c = 0xffffffff;
    for (const byte of buf) c = crcTable[(c ^ byte) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
};
const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
    const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body));
    return Buffer.concat([len, body, crc]);
};
function png(pixels) {
    const header = Buffer.alloc(13);
    header.writeUInt32BE(SIZE, 0); header.writeUInt32BE(SIZE, 4);
    header[8] = 8; header[9] = 6; // 8 bits, RGBA
    const rows = Buffer.alloc((SIZE * 4 + 1) * SIZE);
    for (let y = 0; y < SIZE; y++) {
        rows[y * (SIZE * 4 + 1)] = 0; // no filter
        pixels.copy(rows, y * (SIZE * 4 + 1) + 1, y * SIZE * 4, (y + 1) * SIZE * 4);
    }
    return Buffer.concat([
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        chunk("IHDR", header), chunk("IDAT", deflateSync(rows, { level: 9 })), chunk("IEND", Buffer.alloc(0)),
    ]);
}

// ---- the icons ---------------------------------------------------------------------------------------------------------------
const INK = [88, 58, 28];

// a folded map: three panels, and a red pin on the middle one
writeFileSync(join(out, "Map.png"), png(render((cv) => {
    cv.polygon([[5, 17], [22, 11], [22, 53], [5, 59]], [240, 216, 162], INK, 2);
    cv.polygon([[22, 11], [42, 17], [42, 59], [22, 53]], [216, 188, 128], INK, 2);
    cv.polygon([[42, 17], [59, 11], [59, 53], [42, 59]], [242, 220, 168], INK, 2);
    // a road across the panels
    cv.polygon([[7, 44], [20, 40], [24, 43], [8, 49]], [190, 150, 90]);
    cv.polygon([[44, 38], [57, 33], [57, 38], [44, 43]], [190, 150, 90]);
    // the pin: its tail, then its head with a white dot
    cv.polygon([[26, 31], [38, 31], [32, 49]], [214, 52, 40], [110, 20, 14], 1.6);
    cv.circle(32, 28, 10, [226, 66, 48], [110, 20, 14], 1.8);
    cv.circle(32, 28, 3.6, [255, 240, 230]);
})));

// a navigation arrow: its two halves in two golds, as the arrow of a map
writeFileSync(join(out, "Pointer.png"), png(render((cv) => {
    cv.polygon([[32, 4], [55, 59], [32, 46], [9, 59]], (x) => (x < 32 ? [255, 218, 74] : [222, 164, 26]), [66, 42, 0], 2.4);
})));

console.log("Icons/Map.png and Icons/Pointer.png written");
