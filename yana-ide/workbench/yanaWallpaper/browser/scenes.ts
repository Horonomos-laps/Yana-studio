// @ts-nocheck
/*
 * Adapted from antigravity-ascii-wallpapers (commit 9c81e00), MIT.
 * MIT License
 * 
 * Copyright (c) 2026 Mix4o445
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
/* Character-field scenes. Every cell of one fixed glyph grid samples a procedural scene, so shading, depth and
   motion all come from characters and tiles, as in the reference video. Wrapped so nothing leaks into preload scope. */
export const drawAsciiScene: any = (() => {
  'use strict';
  // 0..11 is a density ramp; 12+ are special glyphs scenes pick directly.
  const SPECIAL = 'v^~o|/\\@\',zZ';
  const GLYPHS = {
    ascii: ' .:-=+*tx%S#' + SPECIAL,
    braille: ' ⠁⠃⠇⠏⠟⠿⡿⣿▊▉█' + SPECIAL,
    blocks: ' ·∙░▒▓█▀▄▌▐█' + SPECIAL,
    katakana: ' ｡･ｰ+=*ﾅﾓﾐｼ#' + SPECIAL
  };
  const CH = GLYPHS.ascii, SCALES = { fine: 11, normal: 14, chunky: 18 };
  const hash = (x, y) => { let h = Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263); h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
  const noise = (x, y) => {
    const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi, u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
    const a = hash(xi, yi), b = hash(xi + 1, yi), c = hash(xi, yi + 1), d = hash(xi + 1, yi + 1);
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
  };
  const fbm = (x, y) => noise(x, y) * .57 + noise(x * 2.03 + 17.1, y * 2.03 + 9.7) * .29 + noise(x * 4.07 + 3.3, y * 4.07 + 41.9) * .14;
  const tri = x => 1 - Math.abs(2 * (x - Math.floor(x)) - 1);
  const sat = v => v < 0 ? 0 : v > 1 ? 1 : v;
  const sm = (a, b, v) => { v = sat((v - a) / (b - a)); return v * v * (3 - 2 * v); };
  const wrap = (v, m) => ((v % m) + m) % m;
  const grad = (g, w, h, stops) => { const s = g.createLinearGradient(0, 0, 0, h); stops.forEach(([p, c]) => s.addColorStop(p, c)); g.fillStyle = s; g.fillRect(0, 0, w, h); };
  const glow = (g, x, y, r, color) => { const s = g.createRadialGradient(x, y, 0, x, y, r); s.addColorStop(0, color); s.addColorStop(1, color.slice(0, 7) + '00'); g.fillStyle = s; g.fillRect(0, 0, g.canvas.width, g.canvas.height); };

  // Layouts: x values are fractions of the scene width; y and sizes are fractions of its height.
  const KOI = [[.83, .3, .1, .09, .11, 0, .3, 0], [.86, .72, .08, .07, -.09, 2, .24, 1], [.13, .5, .06, .16, .08, 4, .27, 2]];
  const KOIP = [[1, 3], [2, 1], [4, 2]];
  const LILY = [[.05, .16, .1, 1, 0], [.95, .1, .085, 4, 1], [.93, .9, .11, 2, 0], [.08, .87, .09, 5, 1], [.035, .52, .06, .5, 0], [.97, .52, .055, 3, 0]];
  const JELLY = [[.12, .25, .3, 0], [.87, .6, .26, 2], [.2, 1.05, .2, 1], [.8, 1.3, .18, 0]];
  const BOATS = [[.08, .2, .24, .008, -.5], [.88, .16, .2, .006, .4], [.82, .64, .23, .007, -.3], [.1, .7, .26, .009, .55], [.45, .4, .14, .005, .15]];
  const FTREES = [[.02, -.05, .24], [.98, 0, .22], [.13, .2, .15], [.88, .28, .13]];
  const PINES = [[.06, .95, .5], [.33, .97, .26], [-.07, .94, .56], [-.22, .98, .36], [-.01, .9, .28]];
  // Dune layers near→far: base y, crest height, frequency, phase, silhouette colour. Crests are sharp with a short slip face.
  const DUNES = [[.94, .13, .42, .3, '#7a3a34', '#c46a40'], [.8, .11, .62, .75, '#5e2e3e', '#9a4c44'], [.69, .09, .95, .1, '#442240', '#743448']];
  let DP = 0;
  function duneY(x, L) {
    const D = DUNES[L], q = x * D[2] + D[3], p = q - Math.floor(q); DP = p;
    return D[0] - D[1] * (p < .72 ? Math.pow(p / .72, 1.6) : Math.pow((1 - p) / .28, .9)) - .012 * noise(x * 4 + L * 5, L);
  }
  // Height of the sunlit slip face below the crest: a crescent that thins out at both ends.
  const slip = (p, L) => { const q = (p - .72) / .28; return q > 0 ? DUNES[L][1] * 2.2 * Math.sqrt(q) * (1 - q) : 0; };
  const meadowY = (x, L) => L ? .76 - .06 * Math.sin(x * 2.6 + 1) - .03 * noise(x * 3, 7) : .88 - .06 * Math.sin(x * 1.6 - .4) - .02 * noise(x * 4, 3);
  // Bamboo stalks, near first: x (negative = from the right edge), depth, half-width.
  const STALKS = [[.05, 1, .022], [-.06, 1, .024], [.2, .85, .018], [-.21, .9, .019], [.12, .62, .014], [-.13, .7, .016], [.3, .42, .01], [-.31, .45, .011], [.4, .28, .008], [-.42, .3, .008]];
  const MAPLES = [[.14, .5, .26], [-.13, .46, .29], [.36, .66, .1]];
  // Mountain ranges far→near: base y, height, frequency, phase, colour.
  const ALPS = [[.62, .2, 2.1, .3, '#e3d6ee'], [.7, .22, 1.5, .8, '#cdbfe4'], [.8, .2, 1.1, .1, '#b3a5d6'], [.9, .14, .8, .55, '#9a8dc8']];
  const alpY = (x, L) => { const D = ALPS[L]; return D[0] - D[1] * (Math.pow(tri(x * D[2] + D[3]), 1.8) * .75 + .25 * tri(x * D[2] * 2.7 + D[3] * 3)) - .015 * fbm(x * 9, L); };
  const retroY = (x, A) => .6 - (.05 + .13 * tri(x * 2.3 + .2) ** 2 + .02 * noise(x * 8, 4)) * sm(A * .12, A * .38, Math.abs(x - A / 2));
  const AUR = [[-.05, .62, .4, 1], [.42, .66, .32, .95], [.2, .6, .22, .7]];
  const CLOUDS = [[.04, .16, .15, .02], [.3, .1, .09, .03], [.62, .2, .1, .025], [.9, .14, .17, .018], [.16, .45, .12, .022], [.82, .48, .13, .02], [.47, .36, .07, .035], [.06, .78, .13, .02], [.93, .82, .15, .017], [.62, .7, .08, .03]];
  const BUMPS = [[-.55, -.18, .34], [-.15, -.4, .44], [.3, -.32, .38], [.66, -.14, .26]];
  // A flat-bottomed cloud: a base lozenge plus four bumps whose sizes vary per cloud.
  function cumulus(u, v, k) {
    if (v > 0) return false;
    if ((u / 1) ** 2 + (v / .3) ** 2 < 1) return true;
    for (let b = 0; b < 4; b++) { const B = BUMPS[b], r = B[2] * (.8 + .4 * hash(k, b)), du = u - B[0], dv = v - B[1] * (.85 + .3 * hash(b, k)); if (du * du + dv * dv < r * r) return true; }
    return false;
  }
  const NEON_SC = [0, 1, 2, 5];
  const bhDisk = (dx, dy, rd, t, o, back) => { if (rd < .09 || rd > .34) return false; const a = Math.atan2(dy * 3.4, dx), I = (noise(a * 3 - t * .5 / rd, rd * 24) * .6 + .4) * (1 - (rd - .09) / .25) * (1.1 - .5 * dx / rd); if (I < .12) return false; o.v = Math.min(1, I * (back ? .7 : 1.2)); o.c = I > .75 ? 0 : I > .5 ? 1 : I > .3 ? 2 : 3; if (I > .85 && !back) o.t = 1; return true; };
  const radarWave = (x, q) => .5 + .13 * Math.sin(x * 16 - q * 3) * Math.sin(x * 2.4 + q * .7);
  const SATURN_MOONS = [[.48, .06, 0, .016], [.6, .04, 2, .012], [.72, .025, 4, .02]];
  const REEF_CORALS = [[.06, .3, .07, 1], [.18, .18, .06, 2], [.3, .12, .05, 3], [-.07, .34, .08, 3], [-.2, .2, .06, 1], [-.32, .14, .05, 2]];
  const OASIS_PALMS = [[.06, .84, .34, .25, 0], [.3, .83, .26, -.3, 1], [.18, .8, .2, .15, 2]];
  const WINDMILL_TOWERS = [[.17, .74, .28, .5], [-.15, .72, .22, -.4], [-.34, .7, .12, .6]];
  const TULIP_BANDS = [4, 7, 5, 8, 6, 7];
  const ISLAND_PALMS_L = [[-.06, .3, .25, 0], [.06, .22, -.3, 1]];
  const ISLAND_PALMS_R = [[0, .22, -.2, 2]];
  const ZEN_STONES = [[.16, .32, .1], [.32, .74, .07], [-.17, .52, .12], [-.33, .2, .06], [.07, .86, .05]];
  // Per-frame particle positions, filled by each scene's pre() so cells only compare numbers.
  const PX = new Float64Array(64), PY = new Float64Array(64), PZ = new Float64Array(64);

  function turtle(x, y, cx, cy, ang, s, t, seed, o) {
    const dx = x - cx, dy = y - cy; if (dx * dx + dy * dy > s * s * .75) return false;
    const ca = Math.cos(ang), sa = Math.sin(ang), u = (dx * ca + dy * sa) / s, v = (-dx * sa + dy * ca) / s;
    const e = (u / .55) ** 2 + (v / .42) ** 2;
    if (e < 1) { o.t = 1; o.c = e > .72 ? 2 : Math.sin(u * 13) + Math.sin(v * 13 + u * 6) > .9 ? 2 : e < .25 && u > -.1 ? 8 : 1; return true; }
    if (((u - .68) / .17) ** 2 + (v / .12) ** 2 < 1) { o.t = 1; o.c = 3; return true; }
    const flap = Math.sin(t * 1.5 + seed) * .45;
    for (let k = -1; k <= 1; k += 2) for (let f = 0; f < 2; f++) {
      const pu = f ? -.38 : .22, pv = k * (f ? .28 : .34), th = k * (f ? 2.6 + flap * .3 : 2.1 + flap), len = f ? .24 : .5, wd = f ? .08 : .12;
      const a = (u - pu) * Math.cos(th) + (v - pv) * Math.sin(th), p = -(u - pu) * Math.sin(th) + (v - pv) * Math.cos(th);
      if (a > 0 && a < len && Math.abs(p) < wd * (1 - a / len * .8)) { o.t = 1; o.c = 3; return true; }
    }
    return false;
  }
  const branchY = (b, span, right) => .02 + (right ? .3 : .22) * Math.pow(Math.max(0, b) / span, 1.5);
  const buildBranchFlowers = right => {
    const span = right ? .85 : .55, out = [];
    for (let k = 0; k < 26; k++) {
      const bs = span * (.04 + .037 * k); if (bs > span) break;
      const seed = k + (right ? 0 : 40), r = .026 + .016 * hash(seed, 9);
      out.push([bs + (hash(seed, 8) - .5) * .05, branchY(bs, span, right) + (hash(seed, 7) - .5) * .11, r, seed, k]);
    }
    return out;
  };
  const BRANCH_FLOWERS_R = buildBranchFlowers(true), BRANCH_FLOWERS_L = buildBranchFlowers(false);
  function branch(x, y, t, A, o, right) {
    const s = right ? A - x : x, span = right ? .85 : .55; if (s < -.04 || s > span + .06 || y > (right ? .44 : .36)) return false;
    const sway = .006 * Math.sin(t * .6 + s * 3), flowers = right ? BRANCH_FLOWERS_R : BRANCH_FLOWERS_L;
    // Individual five-petal flowers clustered along the branch, each with a deep pink centre.
    for (let k = 0; k < flowers.length; k++) {
      const fl = flowers[k], r = fl[2], ds = s - fl[0], dy = y - fl[1] - sway;
      if (ds > r || ds < -r || dy > r || dy < -r) continue;
      const d = Math.hypot(ds, dy);
      if (d > r) continue;
      const a = Math.atan2(dy, ds) + fl[3] + Math.sin(t * .4 + fl[4]) * .2, petal = r * (.62 + .38 * Math.abs(Math.cos(a * 2.5)));
      if (d < petal) { o.t = 1; o.c = d < r * .24 ? 2 : d > petal * .75 ? 1 : 0; return true; }
    }
    if (s >= 0 && s <= span && Math.abs(y - branchY(s, span, right) - sway) < .02 * (1 - s / span) + .005) { o.t = 1; o.c = 3; return true; }
    // A twig off the main branch
    if (s > span * .3 && s < span * .62) { const q = (s - span * .3) / (span * .32); if (Math.abs(y - branchY(span * .3, span, right) - q * .12 - sway) < .008 + .006 * (1 - q)) { o.t = 1; o.c = 3; return true; } }
    return false;
  }

  // Starry Catnap: the near hill the cat sleeps on, and the curled cat in units of its own size (v grows downward).
  let NAPN = 0; const NAPF = new Float64Array(64), NAPC = new Float64Array(64);
  const napF = (x, A) => .8 + .03 * Math.sin(x * 3.1 + 2) + .018 * noise(x * 6, 3);
  const napY = (x, A) => .845 + .018 * Math.sin(x * 2.6 + 1) + .05 * ((x - A + .36) / .8) ** 2;
  function napCat(u, v, t, o, i, j) {
    if (u < -1.35 || u > 1.3 || v < -.75 || v > .8) return false;
    const yb = (v - .58) / (1 + .04 * Math.sin(t * 1.15)) + .58; // the back rises and falls from the ground up
    const hx = u + .78, hy = v - .22 - .012 * Math.sin(t * 1.15), hd = Math.hypot(hx, hy * 1.08);
    if (hy < -.14) for (const e of [-.26, .2]) {
      const twitch = e > 0 && o.e ? o.e * .045 * Math.sin(t * 7) : 0;
      const w = .19 * (hy + .63) / .49, dx = Math.abs(hx - e - twitch);
      if (hy > -.63 && dx < w) { o.t = 1; o.c = dx < w * .42 && hy > -.5 ? 7 : 4; return true; }
    }
    if (hd < .4) {
      o.t = 1; o.c = 4;
      if (Math.abs(hy + .03) < .055 && (Math.abs(hx + .2) < .075 || Math.abs(hx - .2) < .075)) { o.c = 8; o.g = 3; }
      else if (Math.abs(hx) < .07 && Math.abs(hy - .11) < .05) o.c = 7;
      else if (hy > .08) o.c = 6;
      else if (hy < -.2 && Math.abs(Math.sin(hx * 14)) > .75) o.c = 5;
      return true;
    }
    if (hd < .47) { o.t = 1; o.c = 8; return true; }
    const tv = .47 + .09 * Math.sin(u * 1.5 + .4 + (o.e || 0) * Math.sin(t * 3.2) * .7), td = Math.abs(v - tv);
    if (u > -.42 && u < 1.08 && td < .13) { o.t = 1; o.c = u < -.2 ? 6 : Math.sin(u * 9) > .35 ? 5 : 4; return true; }
    if (u > -.42 && u < 1.08 && td < .2 && v < tv) { o.t = 1; o.c = 8; return true; }
    const q = (u - .1) ** 2 + (yb / .6) ** 2;
    if (q < 1) { o.t = 1; o.c = Math.sin(u * 7 + yb * 2.4) > .42 ? 5 : q > .78 && yb > .2 ? 5 : 4; return true; }
    return false;
  }

  // A palm: curved trunk rising from (cx, base) plus six drooping fronds. 0 = miss, 1 = trunk, 2/3 = frond shade/light.
  const FRONDS = [-2.9, -2.35, -1.85, -1.3, -.8, -.25];
  function palm(x, y, cx, base, h, lean, t, k) {
    const s = (base - y) / h;
    if (s > 0 && s < 1 && Math.abs(x - cx - lean * s * s * h) < h * (.045 - .02 * s)) return 1;
    const dx = x - cx - lean * h, dy = y - base + h, r = Math.hypot(dx, dy), L = h * .55;
    if (r > L) return 0;
    const ang = Math.atan2(dy, dx), q = r / L;
    for (let f = 0; f < 6; f++) {
      const th = FRONDS[f] + .06 * Math.sin(t * .8 + f + k * 2) + (FRONDS[f] < -Math.PI / 2 ? -1 : 1) * q * q * 1.1;
      const d = Math.atan2(Math.sin(ang - th), Math.cos(ang - th));
      if (Math.abs(d) < .03 + .14 * (1 - q) * Math.min(1, q * 4)) return d > 0 ? 3 : 2;
    }
    return 0;
  }
  // Points on a rotating ring of blades: true when (dx, dy) lies on one of n blades of length L.
  const onBlade = (dx, dy, a, n, L, w) => { const r = Math.hypot(dx, dy); if (r > L) return false; const ang = Math.atan2(dy, dx); for (let b = 0; b < n; b++) { if (Math.cos(ang - a - b * 2 * Math.PI / n) > 0 && Math.abs(Math.sin(ang - a - b * 2 * Math.PI / n)) * r < w * (.4 + .6 * r / L)) return true; } return false; };
  const stars = (o, i, j, t, c, y, top = .6) => { const h = hash(i, j); if (y < top && h > .987) { o.v = (h > .997 ? .9 : .35) * (.6 + .4 * Math.sin(t * 1.7 + h * 80)); o.c = c; o.g = h > .997 ? 6 : 1; return true; } return false; };

  // Jittered-grid Voronoi: returns the distance to the nearest cell border and leaves the cell's random id in VID.
  let VID = 0;
  function voronoi(x, y, s) {
    x /= s; y /= s; const xi = Math.floor(x), yi = Math.floor(y); let d1 = 9, d2 = 9, id = 0;
    for (let a = -1; a <= 1; a++) for (let b = -1; b <= 1; b++) { const cx = xi + a, cy = yi + b, dx = x - cx - hash(cx, cy), dy = y - cy - hash(cy + 17, cx + 5), d = dx * dx + dy * dy; if (d < d1) { d2 = d1; d1 = d; id = hash(cx * 7 + 3, cy * 13 + 1); } else if (d < d2) d2 = d; }
    VID = id; return (Math.sqrt(d2) - Math.sqrt(d1)) * s * .5;
  }
  // Ben-Day halftone: true inside a dot of the staggered grid (spacing s, fill f in 0..1).
  const dotFill = (x, y, s, f) => { const gy = y / s, row = Math.floor(gy), gx = x / s + (row % 2) * .5; return Math.hypot(gx - Math.floor(gx) - .5, gy - row - .5) < f * .5; };
  const VENTS = [[.1, .4, .045], [.24, .6, .035], [.87, .34, .05]];
  const CANDLES = [[.08, .44, .035], [.17, .27, .03], [.26, .36, .025], [-.09, .52, .04], [-.19, .3, .03], [-.28, .2, .024]];
  const STARRY = [[.1, .12, .05], [.24, .4, .04], [.42, .1, .035], [-.3, .1, .05], [-.16, .44, .04], [.36, .52, .03]], SWIRLS = [[.3, .3, .12], [.56, .2, .09], [.8, .36, .11]];
  const GEARS = [[.16, .42, .13, 14, .3], [.36, .557, .09, 10, -.42], [.112, .626, .06, 7, -.6], [-.22, .4, .15, 16, .25], [-.398, .563, .07, 8, -.54]];
  // Glitch subject: rotating concentric squares on the left, a wireframe globe on the right.
  function glitchShape(x, y, t, A) {
    { const dx = x - A * .18, dy = y - .5, c = Math.cos(t * .2), s = Math.sin(t * .2), m = Math.max(Math.abs(dx * c - dy * s), Math.abs(dx * s + dy * c)); if (m < .24 && wrap(m - t * .02, .06) < .016) return true; }
    { const dx = x - (A - .2), dy = y - .48, r = .2, d = Math.hypot(dx, dy); if (d < r) { if (d > r - .01) return true; const lat = Math.asin(dy / r), lon = Math.asin(Math.max(-1, Math.min(1, dx / (r * Math.cos(lat))))); return Math.abs(Math.sin(lat * 5)) < .12 || Math.abs(Math.sin(lon * 3 + t * .6)) < .08; } }
    return false;
  }

  const SCENES = {
    clouds: { pal: ['#ffffff', '#f4f9fd', '#cfe1ee', '#ffffff', '#4b7592', '#ecf8ff'], ink: '#8aa8bd', inkA: .42,
      bg(g, w, h) { grad(g, w, h, [[0, '#5aaee6'], [.6, '#a6d6f3'], [1, '#d3eefb']]); glow(g, w * .86, h * .04, h * .8, '#fff6dcd0'); },
      pre(t, A) {
        for (let b = 0; b < 6; b++) { PX[b] = wrap(t * .035 + b * .045 + (b % 2) * .02, A + .6) - .3; PY[b] = .3 + .025 * Math.sin(b * 2.3) + .006 * Math.sin(t * 2 + b); PZ[b] = Math.sin(t * 6 + b * 1.7) > 0 ? 12 : 13; }
        for (let k = 0; k < CLOUDS.length; k++) { const C = CLOUDS[k]; PX[10 + k] = wrap(A * C[0] + t * C[3], A + .8) - .4; PY[10 + k] = C[1] + .006 * Math.sin(t * .3 + k); }
      },
      f(x, y, t, A, o, i, j) {
        for (let b = 0; b < 6; b++) if (Math.abs(x - PX[b]) < o.cw * .5 && Math.abs(y - PY[b]) < o.ch * .5) { o.g = PZ[b]; o.c = 4; o.v = 1; return; }
        // Flat-bottomed cumulus built from bumps; top rim white, underside shaded, like the reference.
        for (let k = 0; k < CLOUDS.length; k++) {
          const s = CLOUDS[k][2], u = (x - PX[10 + k]) / s, v = (y - PY[10 + k]) / s; if (u < -1.15 || u > 1.15 || v < -1 || v > .05) continue;
          if (cumulus(u, v, k)) { o.t = 1; o.c = v > -.12 ? 2 : !cumulus(u, v - .1, k) ? 0 : 1; return; }
          if (cumulus(u * .94, v * .9 - .02, k) && hash(i, j) > .55) { o.v = .55; o.c = 3; o.g = 1; return; }
        }
        const h = hash(i, j); if (h > .986) { o.v = .3 + .15 * Math.sin(t * 1.5 + h * 40); o.c = 5; o.g = 1; }
      } },
    aurora: { pal: ['#c9ffe4', '#62f0aa', '#2fc0a8', '#a27cff', '#ff86cc', '#1c3450', '#0d1a29', '#d3e3f3', '#e8f0ff', '#2a6f72'], ink: '#0a1622',
      bg(g, w, h) { grad(g, w, h, [[0, '#030915'], [.55, '#0a1d2e'], [.8, '#10354a'], [1, '#081828']]); glow(g, w * .5, h * .45, h * .9, '#22c49a24'); },
      f(x, y, t, A, o, i, j) {
        const far = .66 - .15 * tri(x * 1.3 + .2) - .06 * tri(x * 3.1 + .6) - .02 * noise(x * 9, 1), near = .79 - .07 * tri(x * 2.2 + .5) - .03 * noise(x * 12, 2), lake = .87;
        let yy = y, refl = 1;
        if (y > lake) { yy = 2 * lake - y + .01 * Math.sin(y * 160 + t * 2); refl = .38; }
        else if (y > near) { o.t = 1; o.c = 6; return; }
        else if (y > far) { o.t = 1; o.c = y < far + .03 && noise(x * 36, y * 36) > .35 ? 7 : 5; return; }
        // Curtains: a bright, sharply defined lower hem that folds across the sky, with soft rays rising from it.
        let v = 0, c = 1;
        for (let L = 0; L < 3; L++) {
          const C = AUR[L], s = (x - A * C[0]) / (A * C[1]); if (s < 0 || s > 1) continue;
          const env = sm(0, .18, s) * sm(0, .18, 1 - s);
          const hem = C[2] + .07 * Math.sin(s * 5.2 + t * .09 + L * 2) + .035 * Math.sin(s * 13 - t * .15 + L), d = hem - yy;
          if (d < -.02) continue;
          const rise = d < 0 ? 1 + d * 50 : Math.exp(-d * (2.6 + L * .8)), ray = .45 + .55 * noise(s * 60 + L * 9, t * .18 + L);
          const pulse = .7 + .3 * Math.sin(s * 7 - t * .35 + L * 1.7), I = env * rise * ray * pulse * C[3] * (1 + .35 * (o.e || 0));
          if (I > v) { v = I; c = d < .025 ? 0 : d < .08 ? 1 : d < .17 ? 2 : L === 1 ? 4 : 3; }
        }
        v *= refl;
        if (v > .08) { o.v = Math.min(1, v); o.c = c; if (v > .78 && refl === 1 && c === 0) o.t = 1; else if (refl < 1) o.g = v > .25 ? 14 : -1; return; }
        if (y > lake) { if (noise(x * 14, y * 60 + t * .4) > .74) { o.v = .25; o.c = 9; o.g = 14; } return; }
        const h = hash(i, j); if (h > .985) { o.v = (h > .997 ? .9 : .35) * (.6 + .4 * Math.sin(t * 2 + h * 90)); o.c = 8; o.g = h > .997 ? 6 : 1; }
      } },
    lagoon: { pal: ['#b4f5ec', '#cdb75a', '#7f8c3c', '#e0cb72', '#43a693', '#e9fffb', '#e2617f', '#f3e7c9', '#e7d58a', '#d9c99a'], ink: '#2f4a3a',
      bg(g, w, h) { grad(g, w, h, [[0, '#3a9290'], [.45, '#196a73'], [1, '#063f55']]); for (let k = 0; k < 4; k++) { const x = w * (.1 + k * .27), s = g.createLinearGradient(x, 0, x + w * .12, h); s.addColorStop(0, '#9ff5ea30'); s.addColorStop(1, '#9ff5ea00'); g.fillStyle = s; g.beginPath(); g.moveTo(x, 0); g.lineTo(x + w * .06, 0); g.lineTo(x + w * .2, h); g.lineTo(x + w * .08, h); g.fill(); } },
      pre(t, A) { for (let k = 0; k < 9; k++) { PX[k] = hash(k, 1) * A + .012 * Math.sin(t * 1.3 + k); PY[k] = 1.05 - wrap(t * .05 * (1 + hash(k, 2)) + hash(k, 4), 1.3); } },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 9; k++) if (Math.abs(x - PX[k]) < o.cw * .5 && Math.abs(y - PY[k]) < o.ch * .5) { o.g = 15; o.c = 5; o.v = .85; return; }
        if (turtle(x, y, A * .8 + .09 * Math.sin(t * .06), .3 + .08 * Math.sin(t * .09), Math.atan2(.0072 * Math.cos(t * .09), .0054 * Math.cos(t * .06)), .27, t, 0, o)) return;
        if (turtle(x, y, A * .15 + .07 * Math.cos(t * .05), .62 + .06 * Math.sin(t * .07), Math.atan2(.0042 * Math.cos(t * .07), -.0035 * Math.sin(t * .05)), .19, t, 2, o)) return;
        { const dx = x - A * .92, dy = y - .95; if ((dx / .13) ** 2 + (dy / .17) ** 2 < 1 && noise(x * 20, y * 20) > .4) { o.t = 1; o.c = 6; return; } }
        { const dx = x - A * .06, dy = y - .9, r = Math.hypot(dx, dy), a = Math.atan2(dy, dx) + t * .05; if (r < .055 * (.45 + .55 * Math.abs(Math.cos(a * 2.5)))) { o.t = 1; o.c = 7; return; } }
        if (y > .62) for (let k = 0; k < 11; k++) {
          const sx = hash(k, 7) * A, h = .14 + .22 * hash(k, 3); if (y < 1 - h) continue;
          const q = (1 - y) / h, ph = q * 5 - t * 1.1 + k, sway = Math.sin(ph) * .03 * q;
          if (Math.abs(x - sx - sway) < o.cw * .7) { const s = Math.cos(ph); o.g = s > .35 ? 17 : s < -.35 ? 18 : 16; o.c = 4; o.v = .9; return; }
        }
        if (y > .955 + .02 * Math.sin(x * 5)) { o.t = 1; o.c = 9; return; }
        const n1 = noise(x * 6 + t * .13, y * 6 - t * .09), n2 = noise(x * 6 - t * .1 + 9.3, y * 6 + t * .07 + 4.1), w = 1 - Math.abs(n1 - n2) * 7;
        if (w > .45) { o.v = (w - .45) * 1.6 * (1.1 - y * .6); o.c = 0; }
      } },
    koi: { pal: ['#8fe3c0', '#f6f3e8', '#ef7d3a', '#cf3d2e', '#1b2621', '#78b858', '#4a8a3c', '#f7b9cd', '#5aa489'], ink: '#2a3b2f',
      bg(g, w, h) { grad(g, w, h, [[0, '#3c6f5f'], [.5, '#27594b'], [1, '#183f35']]); glow(g, w * .5, h * .5, h * .9, '#000c0820'); },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 3; k++) {
          const F = KOI[k], a = t * F[4] + F[5], cx = A * F[0] + F[2] * Math.cos(a), cy = F[1] + F[3] * Math.sin(a), dx = x - cx, dy = y - cy, L = F[6];
          if (dx * dx + dy * dy > L * L * .36) continue;
          const ang = Math.atan2(F[3] * Math.cos(a) * F[4], -F[2] * Math.sin(a) * F[4]), ca = Math.cos(ang), sa = Math.sin(ang);
          const u = (dx * ca + dy * sa) / (L * .5); let v = (-dx * sa + dy * ca) / (L * .5);
          v -= Math.sin(u * 2.4 + t * (4.2 + 2.5 * (o.e || 0)) + k) * (.065 + .025 * (o.e || 0)) * (1 - u);
          if (u > -.72 && u < 1) {
            const q = (u - .18) / .86, w = .32 * Math.pow(Math.max(0, 1 - q * q), .6);
            if (Math.abs(v) < w) { o.t = 1; o.c = KOIP[F[7]][noise(u * 2.6 + k * 9, v * 5 + k * 3) > .56 ? 1 : 0]; return; }
            if (u > .2 && u < .5 && Math.abs(v) < w + .12) { o.v = .6; o.c = KOIP[F[7]][0]; return; }
          }
          if (u <= -.6 && u > -1.2 && Math.abs(v) < .04 + (-.6 - u) * .6) { o.v = .8; o.c = KOIP[F[7]][0]; return; }
          if (Math.abs(v) < .5 && u < 1.1) { o.v = .12; o.c = 8; }
        }
        for (let k = 0; k < LILY.length; k++) {
          const P = LILY[k], dx = x - A * P[0], dy = y - P[1] - .004 * Math.sin(t * .5 + k), r = P[2], d = Math.hypot(dx, dy); if (d > r) continue;
          const aa = wrap(Math.atan2(dy, dx) - P[3], Math.PI * 2); if (aa < .5 && d > r * .15) continue;
          if (P[4] && d < r * .34) { o.t = 1; o.c = 7; return; }
          o.t = 1; o.c = d > r * .82 || Math.abs(Math.sin(aa * 4)) < .08 ? 6 : 5; return;
        }
        for (let k = 0; k < 4; k++) {
          const cyc = t * .16 + k * .27, p = wrap(cyc, 1), n = Math.floor(cyc), d = Math.hypot(x - A * hash(k, n + 11), (y - .15 - .7 * hash(k, n + 12)) * 1.8);
          if (Math.abs(d - p * .2) < .008) { o.v = (1 - p) * .9; o.c = 0; return; }
        }
        const wn = noise(x * 2.6 + t * .04, y * 5.5 - t * .02) * 7, wl = Math.abs(wn - Math.round(wn));
        if (wl < .04 && hash(i, j >> 1) > .5) { o.g = 14; o.c = 8; o.v = .45; }
      } },
    jelly: { pal: ['#f5a8d9', '#c79ff5', '#f8c8a4', '#fff0fa', '#a5c8f2', '#5a7fc4', '#8e6bd0'], ink: '#3a2346',
      bg(g, w, h) { grad(g, w, h, [[0, '#14466a'], [.4, '#0b2741'], [1, '#040b18']]); glow(g, w * .5, 0, h * .9, '#4fa0e030'); },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 4; k++) {
          const J = JELLY[k], s = J[2], cx = A * J[0] + .03 * Math.sin(t * .17 + k * 2), cy = wrap(J[1] - t * .011 * (1 + k * .15), 1.6) - .25;
          const dx = x - cx; if (Math.abs(dx) > s * .75) continue; const dy = y - cy; if (dy < -s * .6 || dy > s * 1.9) continue;
          const u = dx / s, v = dy / s, p = .5 + .5 * Math.sin(t * 1.7 + k * 2.3), rx = .48 * (1 + .1 * p), ry = .52 * (1 - .12 * p);
          if (v < .06) {
            const e = (u / rx) ** 2 + ((v - .06) / ry) ** 2;
            if (e < 1) { o.t = 1; o.c = e < .28 ? 3 : J[3]; return; }
            if (e < 1.7) { o.v = (1.7 - e) * .7; o.c = J[3]; return; }
            continue;
          }
          if (v < .14 && Math.abs(u) < rx * (1 - (v - .06) * 2)) { o.v = .9; o.c = J[3]; o.g = 12; return; }
          const arm = Math.sin(v * 6 - t * 1.6 + k) * .05; if (v < .85 && Math.abs(u - arm) < .07 * (1 - v) + o.cw / s * .4) { o.v = .9 - .5 * v; o.c = 3; return; }
          for (let n = 0; n < 6; n++) {
            const u0 = -.4 + n * .16, len = 1.2 + .5 * hash(k, n); if (v > len) continue;
            const w = Math.sin(v * 8 - t * 2.1 + n * 1.3 + k) * .08 * v;
            if (Math.abs(u - u0 - w) < o.cw / s * .55) { o.v = (1 - v / len) * .85 + .15; o.c = J[3]; o.g = hash(n, j) > .55 ? 16 : -1; return; }
          }
        }
        const jj = j - Math.floor(t * (.8 + hash(i, 0) * 1.4) + hash(i, 1) * 40);
        if (hash(i, jj) > .98) { o.v = .35; o.c = 4; o.g = 1; } else if (hash(i, j) > .994) { o.v = .2; o.c = 5; }
      } },
    boats: { pal: ['#ffffff', '#e3eeeb', '#5f9c94', '#ffffff', '#7fb0a8', '#e8a85a', '#bcd6d0'], ink: '#86a49c', inkA: .36,
      bg(g, w, h) { grad(g, w, h, [[0, '#8fc9c1'], [.5, '#b0dbd3'], [1, '#cfe9e1']]); },
      f(x, y, t, A, o, i, j) {
        // Side-view paper boats: folded hull, centre sail split into lit and shaded faces, rippled reflection below.
        for (let k = 0; k < 5; k++) {
          const B = BOATS[k], s = B[2] * 1.15, cx = wrap(A * B[0] + t * B[3], A + .6) - .3, cy = B[1] + .01 * Math.sin(t * .9 + k * 2);
          const dx = x - cx, dy = y - cy; if (dx < -s * .75 || dx > s * .75 || dy < -s * .65 || dy > s * .6) continue;
          const tilt = .06 * Math.sin(t * .8 + k * 1.3), u = (dx - dy * tilt) / s, v = (dy + dx * tilt) / s, au = Math.abs(u);
          if (v >= 0 && v < .2 && au < .62 - v * 1.15) { o.t = 1; o.c = v < .07 ? 0 : au > .5 - v * 1.15 ? 6 : 1; return; }
          if (v < 0 && v > -.55 && au < .3 * (1 + v / .55)) { o.t = 1; o.c = u < 0 ? 0 : 6; return; }
          if (v > .24 && v < .5) { const m = .5 - (v - .24) * .8; if (au < m && hash(i, j + Math.floor(t * 3)) > .45) { o.g = 14; o.c = 4; o.v = .75 - (v - .24) * 1.6; return; } }
        }
        // Water as drifting contour lines of a slow noise field, broken up so it never reads as ruled paper.
        const wn = noise(x * 3.2 + t * .05, y * 7 - t * .03) * 8 + noise(x * 9 - t * .04, y * 16) * .8, wl = Math.abs(wn - Math.round(wn));
        if (wl < .06 && hash(i >> 1, j) > .3) { o.g = 14; o.c = 2; o.v = .7; return; }
        const h = hash(i, j); if (h > .988) { o.v = .45 * (.5 + .5 * Math.sin(t * 2 + h * 70)); o.c = 3; o.g = 1; }
      } },
    sakura: { pal: ['#f59cbc', '#fdd3e2', '#c9446f', '#5a3a40', '#ec8fb0', '#f4d4df', '#ffffff', '#ecbccd'], ink: '#a65a74', inkA: .34,
      bg(g, w, h) { grad(g, w, h, [[0, '#f7c9d8'], [.6, '#fbe3eb'], [1, '#fdf1f5']]); glow(g, w * .5, h * .78, h * .5, '#fff4e6c0'); },
      pre(t, A) { for (let k = 0; k < 44; k++) { PX[k] = wrap(hash(k, 1) * (A + .4) + t * .035 * (.6 + hash(k, 2)), A + .4) - .2 + .02 * Math.sin(t * 1.2 + k); PY[k] = wrap(hash(k, 3) * 1.1 + t * .045 * (.6 + hash(k, 4)), 1.1) - .05; PZ[k] = hash(k, 5) > .55 ? -1 : Math.sin(t * 3 + k) > 0 ? 6 : 15; } },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 44; k++) if (Math.abs(x - PX[k]) < o.cw * .5 && Math.abs(y - PY[k]) < o.ch * .5) { if (PZ[k] < 0) { o.t = 1; o.c = 1; } else { o.g = PZ[k]; o.c = 4; o.v = 1; } return; }
        if (branch(x, y, t, A, o, true) || branch(x, y, t, A, o, false)) return;
        const near = .87 + .04 * Math.sin(x * 3.4 + 2) + .02 * noise(x * 6, 4), far = .78 + .06 * Math.sin(x * 2.1 + 1) + .04 * noise(x * 4, 3);
        if (y > near) { o.t = 1; o.c = 7; return; }
        if (y > far) { o.t = 1; o.c = 5; return; }
        if (hash(i, j) > .992) { o.v = .4; o.c = 6; o.g = 1; }
      } },
    fireflies: { pal: ['#fbffb8', '#d8ef6f', '#7f9e3c', '#04100b', '#0a1d15', '#4f8a55', '#123224'], ink: '#020906',
      bg(g, w, h) { grad(g, w, h, [[0, '#0b2a26'], [.6, '#16392f'], [1, '#1e4433']]); glow(g, w * .5, h * .7, h * .8, '#9cd07a22'); },
      pre(t, A, o) { const exp = 3 - 1.6 * (o?.e || 0); for (let k = 0; k < 30; k++) { PX[k] = hash(k, 1) * A + .06 * Math.sin(t * .27 * (1 + hash(k, 3)) + k); PY[k] = .1 + .74 * hash(k, 2) + .05 * Math.cos(t * .23 * (1 + hash(k, 5)) + k * 1.7); PZ[k] = Math.pow(.5 + .5 * Math.sin(t * (.7 + hash(k, 4) * .8) + k * 3), exp); } },
      f(x, y, t, A, o, i, j) {
        let best = 0;
        for (let k = 0; k < 30; k++) {
          const dx = x - PX[k]; if (dx > .08 || dx < -.08) continue; const dy = y - PY[k]; if (dy > .08 || dy < -.08) continue;
          const gl = PZ[k]; if (gl < .04) continue; const d = Math.hypot(dx, dy);
          if (d < o.ch * .5) { o.t = gl > .3 ? 1 : 0; o.c = 0; o.v = gl; o.g = o.t ? -1 : 19; return; }
          if (d < .075) best = Math.max(best, gl * (1 - d / .075) ** 2);
        }
        if (best > .05) { o.v = Math.min(.55, best * 1.2); o.c = best > .3 ? 1 : 2; o.g = best > .3 ? -1 : hash(i, j) > .5 ? 1 : 2; return; }
        for (let k = 0; k < FTREES.length; k++) {
          const T = FTREES[k], dx = x - A * T[0], r = T[2]; if (Math.abs(dx) > r * 1.1) continue;
          if (Math.abs(dx) < r * .1 && y > T[1] + r) { o.t = 1; o.c = 3; return; }
          const e = (dx / r) ** 2 + ((y - T[1] - r * .6) / (r * 1.7)) ** 2; if (e < 1 && fbm(x * 8 + k, y * 8) > .3 + e * .25) { o.t = 1; o.c = e > .6 ? 4 : 3; return; }
        }
        const hill = .82 - .08 * fbm(x * 3.5, 2.3);
        if (y > hill) {
          if (y < hill + .035) { const h = hash(i, j), lean = Math.sin(t * .8 + x * 6); if (h < .35) return; o.v = .75; o.c = 5; o.g = h > .8 ? 20 : lean > .3 ? 17 : lean < -.3 ? 18 : 16; return; }
          o.t = 1; o.c = y > .93 ? 3 : 4; return;
        }
        if (y > .45 && noise(x * 3 + t * .03, y * 4) > .7) { o.v = .2; o.c = 6; }
      } },
    moon: { pal: ['#f6f0cf', '#d6cfa6', '#e2e9ff', '#8a9be0', '#5b6fb4', '#a9b8ea', '#fff6d8', '#34478e', '#f6f0cf'], ink: '#6a6650',
      bg(g, w, h) { grad(g, w, h, [[0, '#060a1a'], [.6, '#16225a'], [.86, '#25387a'], [1, '#0d1638']]); glow(g, w * .8, h * .2, h * .5, '#a3b2f048'); },
      f(x, y, t, A, o, i, j) {
        const sea = .86;
        if (y > sea) {
          const col = Math.abs(x - A * .8) < .05 + (y - sea) * .5 && noise(x * 30, y * 70 + t * .6) > .42;
          if (col) { o.v = .85 - (y - sea) * 3; o.c = 8; o.g = 14; return; }
          if (Math.sin(y * 120 + noise(x * 3 + t * .1, y * 9) * 6 + x * 2 - t * .8) > .7) { o.v = .45; o.c = 7; o.g = 14; }
          return;
        }
        const c = fbm(x * 1.6 - t * .014, y * 7 + 2) + .32 * Math.sin(y * 12.5 - 4.05) - .68;
        if (c > .03) { o.t = 1; o.c = c > .1 ? 3 : 4; return; } if (c > -.01) { o.v = .5; o.c = 4; return; }
        const dx = x - A * .8, dy = y - .2, r = .11, d = Math.hypot(dx, dy);
        if (d < r) { o.t = 1; o.c = noise(dx * 22 + 3, dy * 22 + 7) > .62 || dx + dy * .3 < -r * .7 ? 1 : 0; return; }
        if (d < r * 2.4 && hash(i, j) > .3) { const h = 1 - (d - r) / (r * 1.4); if (h > 0) { o.v = h * h * .7; o.c = 5; return; } }
        const cyc = t % 11;
        if (cyc < 1.1) {
          const p = cyc / 1.1, px = x - A * (.18 + .3 * p), py = y - .06 - .16 * p, along = -(px * .88 + py * .47);
          if (along > 0 && along < .16 && Math.abs(px * .47 - py * .88) < o.ch * .4) { o.v = (1 - along / .16) * (1 - p * .3); o.c = 6; o.g = 18; return; }
        }
        const h = hash(i, j); if (h > .986) { o.v = (h > .997 ? .9 : .35) * (.55 + .45 * Math.sin(t * 1.7 + h * 100)); o.c = 2; o.g = h > .997 ? 6 : 1; }
      } },
    dunes: { pal: ['#ffe7b0', '#ff9d5c', '#ffd08c', '#e98f58', '#a4523f', '#5e2e4c', '#f6dcc0', '#2c1428', '#ffb070', '#ffc98a', '#8a4150'], ink: '#6a3424', inkA: .3,
      bg(g, w, h) {
        grad(g, w, h, [[0, '#140a24'], [.38, '#4a1d42'], [.64, '#d4643c'], [.75, '#f08a4a'], [1, '#5a2a2a']]); glow(g, w - h * .36, h * .6, h * .75, '#ffb36080');
        // The dunes never move, so their silhouettes live in the cached background and the glyph field only adds light and ripples.
        for (let L = 2; L >= 0; L--) {
          const D = DUNES[L]; g.fillStyle = D[4]; g.beginPath(); g.moveTo(0, h);
          for (let px = 0; px <= w + 4; px += 4) g.lineTo(px, duneY(px / h, L) * h);
          g.lineTo(w, h); g.fill(); g.fillStyle = D[5];
          for (let px = 0; px <= w; px += 2) { const y = duneY(px / h, L) * h; g.fillRect(px, y, 2, h * slip(DP, L)); }
        }
      },
      f(x, y, t, A, o, i, j) {
        const nY = duneY(x, 0), nP = DP, mY = duneY(x, 1), mP = DP, fY = duneY(x, 2), fP = DP;
        const L = y > nY ? 0 : y > mY ? 1 : y > fY ? 2 : -1;
        if (L >= 0) {
          const top = L === 0 ? nY : L === 1 ? mY : fY, p = L === 0 ? nP : L === 1 ? mP : fP, depth = y - top;
          const lit = depth < slip(p, L), k = L === 0 ? 1 : L === 1 ? .75 : .5;
          if (depth < o.ch * .9) { o.g = 3; o.c = lit ? 0 : L === 2 ? 10 : 2; o.v = k; return; }
          if (L === 0 && hash(i + Math.floor(t * 7), j) > .99) { o.g = 1; o.c = 2; o.v = .9; return; }
          // Wind ripples: thin wavy bands that follow the slope, brighter on the sunlit slip face.
          const rip = Math.sin(x * 38 + depth * (lit ? 120 : 160) + 2 * noise(x * 6, y * 6 + L));
          if (rip > .55) { o.g = 14; o.c = lit ? 2 : 3; o.v = (lit ? .7 : .4) * k * (rip - .4); }
          return;
        }
        const dx = x - (A - .36), dy = y - .6, r = .2, d = Math.hypot(dx, dy);
        if (d < r) { o.t = 1; o.c = dy < -.1 ? 0 : dy < .03 ? 9 : 1; return; }
        if (d < r * 1.9 && hash(i, j) > .25) { const hh = 1 - (d - r) / (r * .9); o.v = hh * hh * .75; o.c = 8; return; }
        const h = hash(i, j); if (y < .4 && h > .986) { o.v = (h > .997 ? .9 : .4) * (1 - y * 1.6) * (.6 + .4 * Math.sin(t * 1.5 + h * 60)); o.c = 6; o.g = h > .997 ? 6 : 1; }
      } },
    rain: { pal: ['#8fb0e6', '#1c2742', '#26345a', '#ffd27a', '#ff9f5a', '#5d7cb5', '#cfe0ff', '#9fd0ff', '#ff5fa2'], ink: '#0b1220',
      bg(g, w, h) { grad(g, w, h, [[0, '#070c18'], [.6, '#101a30'], [.9, '#1a2848'], [1, '#0b1222']]); glow(g, w * .5, h * .92, h * .6, '#ff9f5a1c'); },
      f(x, y, t, A, o, i, j) {
        if (hash(i, 9) > .42) for (let k = 0; k < 2; k++) {
          const d = wrap(t * (.9 + .5 * hash(i, k + 2)) + hash(i, k + 4) * 3, 1.35) - .15 - y;
          if (d > 0 && d < .08) { o.v = .3 + .55 * (1 - d / .08); o.c = 0; o.g = d < .025 ? 16 : -1; return; }
        }
        if (y > .9) {
          for (let k = 0; k < 4; k++) {
            const cyc = t * .7 + k * .25, p = wrap(cyc, 1), d = Math.hypot(x - A * hash(k, Math.floor(cyc)), (y - .95) * 4);
            if (Math.abs(d - p * .09) < .009) { o.v = (1 - p) * .85; o.c = 5; o.g = 14; return; }
          }
          const b = Math.floor(x / .085); if (hash(b, 3) > .45 && noise(x * 30, y * 20 + t) > .58) { o.v = .45; o.c = hash(b, 4) > .5 ? 3 : 4; o.g = 16; }
          return;
        }
        const b = Math.floor(x / .085), top = .9 - (.14 + .46 * hash(b, 1)) * (.3 + .7 * Math.min(1, Math.abs(x - A / 2) / (A * .5)));
        if (y > top) {
          o.t = 1; o.c = b % 2 ? 1 : 2;
          // Neon sign on one tall building per side
          if (hash(b, 5) > .82 && y > top + .05 && y < top + .2 && Math.abs((x / .085 - b) - .5) < .22) { o.c = Math.sin(t * 9) > -.8 ? 8 : 2; return; }
          if (i % 3 === 1 && j % 2 === 0 && y > top + .03 && hash(i, j) > .45) o.c = hash(i, j + Math.floor(t * .15)) > .93 ? 2 : hash(i, 7) > .66 ? 7 : hash(i, 7) > .33 ? 3 : 4;
          return;
        }
        if (hash(i, j) > .993) { o.v = .25; o.c = 6; o.g = 1; }
      } },
    snow: { pal: ['#ffffff', '#20443a', '#2e5e4d', '#f7fbff', '#ffffff', '#dbe7f0', '#b3c8da', '#6b4b36', '#ffd27a', '#f4f8fc'], ink: '#6f8ba1', inkA: .36,
      bg(g, w, h) { grad(g, w, h, [[0, '#9fbbd6'], [.55, '#c4d7e8'], [1, '#e9f1f8']]); },
      pre(t, A) { for (let k = 0; k < 64; k++) { const z = hash(k, 9); PX[k] = hash(k, 1) * A + .03 * Math.sin(t * (.5 + z) + k); PY[k] = wrap(hash(k, 2) + t * (.025 + .05 * z), 1.1) - .05; PZ[k] = z; } },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 64; k++) if (Math.abs(x - PX[k]) < o.cw * .55 && Math.abs(y - PY[k]) < o.ch * .5) { const z = PZ[k]; if (z > .62) { o.t = 1; o.c = 0; } else { o.g = z > .4 ? 6 : 1; o.c = 0; o.v = 1; } return; }
        for (let k = 0; k < PINES.length; k++) {
          const P = PINES[k], h = P[2], q = (y - P[1] + h) / h; if (q < 0 || q > 1) continue;
          const dx = x - (P[0] < 0 ? A + P[0] : P[0]);
          if (q > .86) { if (Math.abs(dx) < h * .045) { o.t = 1; o.c = 7; return; } continue; }
          const tier = (q * 4.2) % 1, hw = h * .36 * (q * .75 + .25) * (.62 + .38 * tier);
          if (Math.abs(dx) < hw) { o.t = 1; o.c = tier < .2 || Math.abs(dx) > hw - .01 && tier < .4 ? 3 : dx < 0 ? 2 : 1; return; }
        }
        // Cabin with a warm window
        { const cx = .21, dx = x - cx, base = .935; if (Math.abs(dx) < .07 && y < base && y > base - .1) { const ry = base - .065 - (.07 - Math.abs(dx)) * .5; if (y < ry) { if (y > ry - .03) { o.t = 1; o.c = 3; return; } } else { o.t = 1; o.c = Math.abs(dx - .025) < .012 && y > base - .055 && y < base - .025 ? 8 : 7; return; } } }
        if (y > .93 + .015 * Math.sin(x * 3)) { o.t = 1; o.c = noise(x * 20, y * 20) > .6 ? 5 : 4; return; }
        const m = .7 - .2 * tri(x * 1.1 + .35) - .08 * tri(x * 2.9 + .1) - .02 * fbm(x * 8, 1);
        if (y > m) { o.t = 1; o.c = y < m + .05 + .03 * noise(x * 20, 3) ? 9 : 6; return; }
      } },
    lanterns: { pal: ['#ffe2a0', '#d9532f', '#ff9a4e', '#ffb46a', '#191736', '#4a5ca0', '#c9d2ff', '#ff8a45'], ink: '#5a1f14', inkA: .3,
      bg(g, w, h) { grad(g, w, h, [[0, '#070b22'], [.5, '#171c48'], [.67, '#3d2c5a'], [.69, '#121838'], [1, '#060918']]); glow(g, w * .5, h * .68, h * .7, '#ff9a5a26');
        g.fillStyle = '#16142f'; g.beginPath(); g.moveTo(0, h * .68); for (let px = 0; px <= w + 4; px += 4) { const x = px / h; g.lineTo(px, (.678 - (.02 + .06 * fbm(x * 3, 1.3)) * sm(w / h * .2, w / h * .45, Math.abs(x - w / h / 2))) * h); } g.lineTo(w, h * .68); g.fill(); },
      pre(t, A) { for (let k = 0; k < 26; k++) { const z = hash(k, 9); PZ[k] = z; PX[k] = hash(k, 1) * A + .025 * Math.sin(t * .3 + k); PY[k] = .66 - wrap(hash(k, 2) * .8 + t * (.006 + .012 * z), .8); } },
      f(x, y, t, A, o, i, j) {
        const H = .68; let best = 0;
        for (let k = 0; k < 26; k++) {
          const z = PZ[k], s = .01 + .028 * z, dx = x - PX[k]; if (dx > s * 3 || dx < -s * 3) continue;
          const dy = y - PY[k];
          if (z > .4 ? Math.abs(dx) < s * .7 && Math.abs(dy) < s : Math.abs(dx) < o.cw * .5 && Math.abs(dy) < o.ch * .5) { if (z > .4) { o.t = 1; o.c = dy < -s * .55 ? 1 : Math.abs(dx) < s * .35 ? 0 : 2; } else { o.g = 19; o.c = 0; o.v = .85 + .15 * Math.sin(t * 7 + k * 3); } return; }
          const d = Math.hypot(dx, dy) / s; if (d < 3) best = Math.max(best, (1 - d / 3) ** 2 * (.4 + .6 * z));
          // Each lantern leaves a broken, shimmering reflection on the lake.
          if (y > H && Math.abs(y - (2 * H - PY[k])) < s * 1.6 && Math.abs(dx) < s * .7) { const sh = Math.sin(y * 300 + t * 3 + k); if (sh > -.2) { o.g = 3; o.c = 7; o.v = .35 + .4 * z * (sh + .2); return; } }
        }
        if (best > .08) { o.v = best * .6; o.c = 3; o.g = hash(i, j) > .5 ? 1 : 2; return; }
        if (y > H) { if (hash(i, j) > .8 && Math.sin(x * 40 + y * 200 - t * .8) > .6) { o.g = 3; o.c = 5; o.v = .3 + .3 * (y - H) / (1 - H); } return; }
        const h = hash(i, j); if (y < .5 && h > .988) { o.v = .5 * (.6 + .4 * Math.sin(t * 1.3 + h * 50)); o.c = 6; o.g = 1; }
      } },
    meadow: { pal: ['#ffffff', '#8cbc6a', '#4f8a3e', '#7cb653', '#f2c94c', '#e8698a', '#f08a3c', '#5a7fd8', '#3f7a3a', '#74b04e', '#6b4a2e'], ink: '#2f5a2a', inkA: .3,
      bg(g, w, h) {
        grad(g, w, h, [[0, '#a9d6f0'], [.55, '#def0f2'], [1, '#e9f4e2']]); glow(g, w * .2, h * .1, h * .5, '#fff8d880');
        for (let L = 1; L >= 0; L--) { g.fillStyle = L ? '#b7d79c' : '#9ccb7c'; g.beginPath(); g.moveTo(0, h); for (let px = 0; px <= w + 4; px += 4) g.lineTo(px, meadowY(px / h, L) * h); g.lineTo(w, h); g.fill(); }
      },
      pre(t, A) { for (let k = 0; k < 6; k++) { PX[k] = wrap(hash(k, 1) * A + t * .015 + .05 * Math.sin(t * .6 + k), A + .2) - .1; PY[k] = .5 + .25 * hash(k, 2) + .04 * Math.sin(t * 1.1 + k * 2); } },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 6; k++) if (Math.abs(x - PX[k]) < o.cw * .6 && Math.abs(y - PY[k]) < o.ch * .5) { o.g = Math.sin(t * 14 + k) > 0 ? 8 : 16; o.c = k % 2 ? 7 : 6; o.v = 1; return; }
        const n = meadowY(x, 0), f = meadowY(x, 1), dx = x - (A - .3);
        // A lone oak on the far hill
        if (Math.abs(dx) < .2 && y < f + .01) {
          if (Math.abs(dx) < .012 + Math.max(0, y - .6) * .06 && y > .5) { o.t = 1; o.c = 10; return; }
          const e = (dx / .19) ** 2 + ((y - .44) / .17) ** 2;
          if (e < 1 && fbm(x * 9, y * 9 + .3 * Math.sin(t * .8)) > .28 + e * .3) { o.t = 1; o.c = fbm(x * 5 + 3, y * 5) - (y - .44) * 1.5 > .5 ? 9 : 8; return; }
        }
        // Gusts roll across the grass as a travelling wave of leaning blades.
        const gust = Math.sin(t * 1.4 - x * 4 + noise(x * 2, t * .2) * 2), blade = gust > .3 ? 17 : gust < -.5 ? 18 : 16;
        if (y > n) {
          const d = y - n, h = hash(i, j);
          if (d < .05) { if (h < .3) return; o.g = blade; o.c = gust > .3 ? 3 : 2; o.v = .85; return; }
          if (h > .965) { o.g = 6; o.c = h > .983 ? 4 : 5; o.v = 1; return; }
          if (h > .55) { o.g = gust > .3 ? 20 : 21; o.c = 2; o.v = .55; }
          return;
        }
        if (y > f) { const h = hash(i, j); if (y - f < .03 && h > .4) { o.g = blade; o.c = 1; o.v = .6; return; } if (h > .97) { o.g = 6; o.c = 4; o.v = .6; } return; }
      } },
    galaxy: { pal: ['#fff4dc', '#f4a6d8', '#8fb8ff', '#b8a8ff', '#c45ab0', '#3fb8c0', '#e8ecff', '#ffe9a8'], ink: '#0a0718',
      bg(g, w, h) { grad(g, w, h, [[0, '#04030e'], [.6, '#0a0820'], [1, '#110a26']]); glow(g, w - h * .42, h * .42, h * .6, '#6a4ab030'); glow(g, h * .3, h * .8, h * .6, '#2a8a9a1c'); },
      f(x, y, t, A, o, i, j) {
        // A shooting star every seven seconds
        const cyc = Math.floor(t / 7), p = (t / 7 - cyc) * 2.5;
        if (p < 1) { const sx = hash(cyc, 1) * A * .8, sy = .05 + .2 * hash(cyc, 2), hx = sx + p * .6, back = hx - x;
          if (x > sx && back > 0 && back < .18 && Math.abs(y - sy - (x - sx) * .5) < o.ch * .5) { o.v = 1 - back / .18; o.c = 6; o.g = back < o.cw ? 5 : 18; return; } }
        // Spiral seen at a tilt: rotate into the galaxy plane, then undo the foreshortening.
        const dx = x - (A - .36), dy = y - .42, rx = dx * .94 + dy * .34, ry = (dy * .94 - dx * .34) * 2.6, r = Math.hypot(rx, ry);
        if (r < .5) {
          const arm = .5 + .5 * Math.cos(2 * (Math.atan2(ry, rx) - Math.log(r + .01) * 2.6 - t * .04)), core = Math.exp(-r / .05);
          if (core > .5) { o.t = 1; o.c = 0; return; }
          const v = core * 1.6 + arm ** 2.5 * Math.exp(-r / .26) * (.9 + 1.2 * fbm(x * 14, y * 14));
          if (v > .1) { o.v = Math.min(1, v); o.c = core > .15 ? 7 : r < .12 || hash(i, j) > .8 ? 1 : 2; return; }
        }
        { const m = fbm(x * 2.4 + t * .006, y * 2.4) - .36 - .3 * Math.hypot(x / (A * .4), (1 - y) / .6); if (m > 0) { o.v = Math.min(.4, m * 2); o.c = noise(x * 3, y * 3) > .5 ? 4 : 5; o.g = m > .12 ? 2 : 1; return; } }
        const fd = Math.hypot((x - .25) / .06, (y - .2) / .02); if (fd < 1) { o.v = (1 - fd) * .6; o.c = 3; return; }
        const h = hash(i, j); if (h > .985) { o.v = h > .997 ? .9 : .3 + .2 * Math.sin(t * (1 + h * 3) + h * 90) + .2; o.c = h > .993 ? 7 : 6; o.g = h > .997 ? 5 : 1; }
      } },
    bamboo: { pal: ['#4f8a3c', '#8cc66a', '#b4d3a8', '#5d9c45', '#c9d46a', '#ffffff', '#7a9a5a', '#2f5a26', '#9fc28e'], ink: '#2c4f24', inkA: .28,
      bg(g, w, h) { grad(g, w, h, [[0, '#d8ead6'], [.6, '#eef5e6'], [1, '#d4e4c8']]); glow(g, w * .5, h * .2, h * .8, '#ffffffa0'); },
      pre(t, A) { for (let k = 0; k < 14; k++) { PX[k] = wrap(hash(k, 1) * A - t * .02 + .04 * Math.sin(t * .8 + k), A + .1) - .05; PY[k] = wrap(hash(k, 2) + t * (.03 + .03 * hash(k, 3)), 1.1) - .05; PZ[k] = Math.floor(t * 3 + k) % 4; } },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 14; k++) if (Math.abs(x - PX[k]) < o.cw * .55 && Math.abs(y - PY[k]) < o.ch * .5) { o.g = [17, 3, 18, 16][PZ[k]]; o.c = k % 3 ? 3 : 4; o.v = 1; return; }
        for (let s = 0; s < STALKS.length; s++) {
          const S = STALKS[s], z = S[1], w = S[2], dx = x - (S[0] < 0 ? A + S[0] : S[0]) - .02 * z * (1 - y) ** 2 * Math.sin(t * .5 + s * 1.7);
          if (Math.abs(dx) < w && y < .95) { o.t = 1; o.c = z < .5 ? 2 : wrap(y + hash(s, 1), .14) < .012 ? 7 : dx < -w * .3 ? 1 : 0; return; }
          // Leaves droop outward from a few nodes
          for (let l = 0; l < 3; l++) {
            const side = hash(s, l + 7) > .5 ? 1 : -1, L = .05 + .07 * z, u = (dx * side - w) / L; if (u < 0 || u > 1) continue;
            const py = .1 + .55 * hash(s, l + 3) + .05 * u * u + .006 * Math.sin(t * 1.3 + s + l), th = (.004 + .01 * z) * (1 - (2 * u - 1) ** 2) + o.ch * .3;
            if (Math.abs(y - py) < th) { o.g = side > 0 ? 18 : 17; o.c = z < .5 ? 8 : 3; o.v = 1; return; }
          }
        }
        if (y > .93) { const h = hash(i, j); if (h > .4) { o.g = h > .8 ? 20 : 21; o.c = 6; o.v = .7; } return; }
        if (y > .55) { const m = noise(x * 2 + t * .02, y * 4); if (m > .62) { o.v = (m - .62) * 2.5; o.c = 5; o.g = 3; } }
      } },
    code: { pal: ['#eaffef', '#5dff8a', '#22c25e', '#0f5a2c'], ink: '#001a08',
      bg(g, w, h) { grad(g, w, h, [[0, '#010805'], [1, '#03140a']]); glow(g, w * .5, h * .5, h * .9, '#0a4a2030'); },
      f(x, y, t, A, o, i, j) {
        if (hash(i, 9) > .3 - .22 * (o.e || 0)) for (let k = 0; k < ((o.e || 0) > .35 ? 3 : 2); k++) {
          const len = .25 + .35 * hash(i, k + 5), d = wrap(t * (.12 + .22 * hash(i, k + 2)) + hash(i, k + 4) * 3, 1.6) - .3 - y;
          if (d > 0 && d < len) { const q = d / len; o.v = 1 - q * .85; o.c = d < o.ch ? 0 : q < .3 ? 1 : 2; o.g = 3 + Math.floor(hash(i, j + Math.floor(t * (2 + 6 * hash(j, i)))) * 19); return; }
        }
        if (hash(i, j) > .975) { o.v = .2; o.c = 3; o.g = 3 + Math.floor(hash(j, i) * 19); }
      } },
    tide: { pal: ['#fff3c4', '#ffc58a', '#ffffff', '#ffffff', '#f2dcb6', '#dcc092', '#4a5a6e', '#fffaf2', '#5aa4b8', '#ffe2a8'], ink: '#a88a60', inkA: .3,
      bg(g, w, h) { grad(g, w, h, [[0, '#f9d6c4'], [.47, '#ffe7cf'], [.48, '#bfe0e6'], [.75, '#9ccfdb'], [1, '#86c2d0']]); glow(g, w - h * .45, h * .46, h * .5, '#fff3c890'); },
      f(x, y, t, A, o, i, j) {
        const H = .48, sx = A - .3;
        for (let b = 0; b < 3; b++) { const bx = wrap(t * .02 + b * .09 + .3, A + .3) - .15, by = .18 + .05 * b + .01 * Math.sin(t * .7 + b); if (Math.abs(x - bx) < o.cw * .5 && Math.abs(y - by) < o.ch * .5) { o.g = Math.sin(t * 4 + b * 2) > 0 ? 12 : 13; o.c = 6; o.v = .9; return; } }
        if (y < H) {
          const d = Math.hypot(x - sx, y - H);
          if (d < .1) { o.t = 1; o.c = d < .075 ? 0 : 1; return; }
          if (d < .16 && hash(i, j) > .4) { o.v = (1 - (d - .1) / .06) * .6; o.c = 9; o.g = 1; return; }
          if (y < .4 && noise(x * 1.4 - t * .006, y * 14) > .7) { o.v = .55; o.c = 7; o.g = 3; }
          return;
        }
        const shore = .9 + .025 * Math.sin(t * .5) + .015 * Math.sin(x * 3.1 + t * .3);
        if (y > shore) { o.t = 1; o.c = y < shore + .012 ? 3 : y < shore + .04 ? 5 : 4; return; }
        const z = (y - H) / (1 - H);
        if (Math.abs(x - sx) < .03 + z * .25 && hash(i, j + Math.floor(t * 4)) > .6 - z * .2) { o.g = 3; o.c = 9; o.v = .8 - z * .5; return; }
        // Swell lines in perspective, rolling toward the shore
        const band = wrap(1.2 / (z + .08) + t * .18 + .15 * Math.sin(x * 3 + z * 4), 1);
        if (band < .1 + z * .1) { o.g = 14; o.c = band < .04 ? 2 : 8; o.v = .4 + .5 * z; }
      } },
    autumn: { pal: ['#d9482f', '#ee8a2e', '#f4c04a', '#b8532a', '#a8361f', '#6a4530', '#d9a066'], ink: '#7a3a1a', inkA: .3,
      bg(g, w, h) { grad(g, w, h, [[0, '#f7e2c4'], [.7, '#f4dcbc'], [1, '#ecc8a0']]); glow(g, w * .5, h * .35, h * .7, '#fff2d880'); },
      pre(t, A) { for (let k = 0; k < 40; k++) { const z = hash(k, 9); PX[k] = wrap(hash(k, 1) * A + t * (.015 + .02 * z) + .05 * Math.sin(t * (.6 + z) + k), A + .1) - .05; PY[k] = wrap(hash(k, 2) + t * (.025 + .035 * z), 1.1) - .05; PZ[k] = z; } },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 40; k++) if (Math.abs(x - PX[k]) < o.cw * .55 && Math.abs(y - PY[k]) < o.ch * .5) { const z = PZ[k]; if (z > .8) { o.t = 1; o.c = k % 3; } else { o.g = [17, 3, 18, 16][Math.floor(t * (2 + 3 * z) + k) % 4]; o.c = k % 4; o.v = 1; } return; }
        for (let k = 0; k < MAPLES.length; k++) {
          const T = MAPLES[k], r = T[2], dx = x - (T[0] < 0 ? A + T[0] : T[0]); if (Math.abs(dx) > r * 1.15) continue;
          if (y > T[1] + r * .5 && y < .92 && Math.abs(dx) < r * .09 + Math.max(0, y - .82) * .15) { o.t = 1; o.c = 5; return; }
          const e = (dx / r) ** 2 + ((y - T[1]) / (r * .8)) ** 2;
          if (e < 1 && fbm(x * 7 + k * 3, y * 7 + .2 * Math.sin(t * .7)) > .3 + e * .28) { const n = fbm(x * 4 + 9, y * 4); o.t = 1; o.c = e > .75 && y > T[1] ? 4 : n > .58 ? 0 : n > .44 ? 1 : 2; return; }
        }
        if (y > .92 + .01 * Math.sin(x * 4)) { const h = hash(i, j); o.t = 1; o.c = h > .8 ? 1 : h > .6 ? 0 : h > .4 ? 2 : 6; }
      } },
    alpine: { pal: ['#ffffff', '#fff7f4', '#fff6e0', '#4a4670', '#6e6aa0', '#efe6f6', '#c9bce2', '#ffbf8a', '#857ab8'], ink: '#8a80b4', inkA: .34,
      bg(g, w, h) {
        grad(g, w, h, [[0, '#c7c3ea'], [.35, '#efd2dc'], [.6, '#ffe2c8'], [1, '#f6dccb']]); glow(g, w - h * .6, h * .5, h * .5, '#fff1d0a0');
        for (let L = 0; L < 4; L++) { g.fillStyle = ALPS[L][4]; g.beginPath(); g.moveTo(0, h); for (let px = 0; px <= w + 4; px += 4) g.lineTo(px, alpY(px / h, L) * h); g.lineTo(w, h); g.fill(); }
      },
      f(x, y, t, A, o, i, j) {
        // A V of geese crossing slowly
        for (let b = 0; b < 5; b++) { const s = b - 2, bx = wrap(t * .018, A + .5) - .25 - Math.abs(s) * .03, by = .22 + s * .018 + .005 * Math.sin(t * 2 + b); if (Math.abs(x - bx) < o.cw * .5 && Math.abs(y - by) < o.ch * .5) { o.g = Math.sin(t * 5 + b) > 0 ? 12 : 13; o.c = 3; o.v = .9; return; } }
        for (let L = 3; L >= 0; L--) {
          const top = alpY(x, L); if (y < top) continue;
          const d = y - top, lit = alpY(x + .01, L) > top;
          if (L >= 1 && d < .07 && y < .56 + .02 * noise(x * 12, L)) { o.t = 1; o.c = d < o.ch ? 0 : 5; return; }
          if (d < o.ch * .8) { o.g = 3; o.c = lit ? 1 : 6; o.v = .6 + .1 * L; return; }
          if (L < 3) { const m = fbm(x * 1.6 - t * .012, y * 6 + L) - .55; if (m > 0 && d > .02) { o.v = Math.min(.7, m * 4); o.c = 1; o.g = m > .08 ? 4 : 3; return; } }
          if (L < 3 && hash(i, j) > .7 + .08 * L && Math.sin((x * 30 + d * 60) * (lit ? 1 : -1)) > .4) { o.g = lit ? 18 : 17; o.c = lit ? 5 : 8; o.v = .3 + .1 * L; }
          return;
        }
        const d = Math.hypot(x - (A - .32), y - .36);
        if (d < .07) { o.t = 1; o.c = 2; return; }
        if (d < .15 && hash(i, j) > .3) { o.v = (1 - (d - .07) / .08) * .9; o.c = 7; o.g = d < .1 ? 2 : 1; }
      } },
    retro: { pal: ['#ffe066', '#ff8a3d', '#ff2d8a', '#24093f', '#ff5ad8', '#ff4fd8', '#6ad8ff', '#f2e6ff'], ink: '#3a0820', inkA: .3,
      bg(g, w, h) { grad(g, w, h, [[0, '#0b021d'], [.4, '#25093f'], [.6, '#6a1b5a'], [.601, '#12042a'], [1, '#1c0638']]); glow(g, w - h * .5, h * .5, h * .6, '#ff3d8a38'); },
      f(x, y, t, A, o, i, j) {
        if (y > .6) {
          // Neon floor grid running to a vanishing point on the horizon
          const z = (y - .6) / .4, vp = A / 2, n = Math.round((x - vp) / (z + .03) * 1.5);
          if (Math.abs(x - vp - n / 1.5 * (z + .03)) < o.cw * .55) { o.g = n < 0 ? 17 : n > 0 ? 18 : 16; o.c = 6; o.v = .25 + .6 * z; return; }
          const dz = o.ch / .8; if (z > .04 && Math.floor(4 / (z - dz + .12) + t * .6) !== Math.floor(4 / (z + dz + .12) + t * .6)) { o.g = 3; o.c = 5; o.v = .15 + .85 * z; }
          return;
        }
        const ridge = retroY(x, A);
        if (y > ridge) { if (y - ridge < o.ch) { const s = retroY(x + .01, A) - ridge; o.g = Math.abs(s) < .002 ? 3 : s < 0 ? 17 : 18; o.c = 4; o.v = 1; } else { o.t = 1; o.c = 3; } return; }
        const d = Math.hypot(x - (A - .3), y - .44);
        if (d < .16) { const q = (y - .28) / .32; if (!(q > .45 && Math.sin(y * 120 + t * 1.5) > 1.4 - q * 2)) { o.t = 1; o.c = q < .35 ? 0 : q < .65 ? 1 : 2; return; } }
        const h = hash(i, j); if (y < .45 && h > .988) { o.v = .5 + .3 * Math.sin(t * 1.7 + h * 40); o.c = 7; o.g = 1; }
      } },
    lava: { pal: ['#ffe27a', '#ff9a3c', '#ff4a5a', '#ff7a4a', '#ffb0d0'], ink: '#6a1020', inkA: .32,
      bg(g, w, h) { grad(g, w, h, [[0, '#14051f'], [.6, '#250929'], [1, '#3a0d22']]); glow(g, w * .5, h * 1.05, h * .7, '#ff6a2a40'); },
      pre(t, A) { for (let k = 0; k < 9; k++) { PX[k] = A / 2 + (k % 2 ? 1 : -1) * A * (.3 + .17 * hash(k, 1)) + .04 * Math.sin(t * .13 + k); PY[k] = .5 + .42 * Math.sin(t * (.05 + .05 * hash(k, 2)) + k * 2.1); PZ[k] = (.035 + .045 * hash(k, 3)) ** 2; } },
      f(x, y, t, A, o, i, j) {
        // Metaballs: blobs merge and split where their summed field crosses 1.
        let F = y > .95 + .015 * Math.sin(x * 5 + t * .4) ? 1.6 : 0;
        for (let k = 0; k < 9; k++) { const dx = x - PX[k], dy = (y - PY[k]) * .8; F += PZ[k] * (1 + .28 * (o.e || 0)) / (dx * dx + dy * dy + 1e-4); }
        if (F > 1) { o.t = 1; o.c = F > 2.6 ? 0 : F > 1.5 ? 1 : 2; return; }
        if (F > .7) { o.v = (F - .7) * 1.4; o.c = 3; o.g = hash(i, j) > .5 ? 1 : 2; return; }
        if (hash(i, 5) > .93 && Math.abs(y - 1 + wrap(t * .05 * (1 + hash(i, 2)) + hash(i, 3), 1.1)) < o.ch * .5) { o.g = 15; o.c = 4; o.v = .6; }
      } },
    catnap: { pal: ['#ffffff', '#9fe8ff', '#b79cff', '#ff9fd6', '#f0a95e', '#c8743a', '#fff0dc', '#ffa9a0', '#2a1c2e', '#141d3c', '#22325a', '#e9efff', '#fff0b8'], ink: '#5a3218', inkA: .34,
      bg(g, w, h) { grad(g, w, h, [[0, '#04061a'], [.5, '#0d1140'], [.8, '#211c5e'], [1, '#0b0f2a']]); glow(g, w * .55, h * .28, h * .9, '#5b4bd034');
        const A = w / h;
        for (const [fn, c] of [[napF, '#141d3c'], [napY, '#22325a']]) { g.fillStyle = c; g.beginPath(); g.moveTo(0, h); for (let px = 0; px <= w + 4; px += 4) g.lineTo(px, fn(px / h, A) * h); g.lineTo(w, h); g.fill(); } },
      pre(t, A, o) {
        // A meteor spends a third of its cycle crossing the sky; agent activity or completion triggers a fuller shower.
        NAPN = 0;
        const duty = Math.min(.88, .34 + .28 * (o?.e || 0) + .35 * (o?.p || 0));
        for (let k = 0; k < 120 && NAPN < 64; k++) {
          const q = wrap(t / (5 + 9 * hash(k, 7)) + hash(k, 8), 1) / duty; if (q >= 1) continue;
          const d = q * (.9 + .5 * hash(k, 4));
          PX[NAPN] = hash(k, 1) * (A + .75) - d * .6; PY[NAPN] = hash(k, 2) * .6 - .3 + d * .8; PZ[NAPN] = .14 + .3 * hash(k, 3); NAPF[NAPN] = Math.sin(q * Math.PI); NAPC[NAPN++] = hash(k, 5) * 3;
        }
      },
      f(x, y, t, A, o, i, j) {
        const cx = A - .36, s = .15, cy = napY(cx, A) - s * .56;
        if (napCat((x - cx) / s, (y - cy) / s, t, o, i, j)) return;
        for (let k = 0; k < 3; k++) {
          const q = wrap(t * .11 + k / 3, 1), zx = cx - s * 1.05 + .07 * q + .012 * Math.sin(t + k * 2), zy = cy - s * .55 - q * .24;
          if (Math.abs(x - zx) < o.cw * .5 && Math.abs(y - zy) < o.ch * .5) { o.g = q < .45 ? 22 : 23; o.c = 12; o.v = 1 - q * .62; return; }
        }
        const near = napY(x, A), far = napF(x, A);
        if (y > near) {
          if (y - near < o.ch && hash(i, 9) > .35) { o.g = hash(i, 4) > .5 ? 17 : 18; o.c = 10; o.v = .8; return; }
          if (noise(x * 22, y * 44) > .62) { o.v = .34; o.c = 11; o.g = hash(i, j) > .5 ? 1 : 2; } return;
        }
        if (y > far) { if (noise(x * 18 + 5, y * 36) > .7) { o.v = .28; o.c = 2; o.g = 1; } return; }
        for (let k = 0; k < NAPN; k++) {
          if (y > PY[k] + o.ch || y < PY[k] - PZ[k]) continue;
          const rx = x - PX[k], ry = y - PY[k], back = rx * .6 - ry * .8, side = Math.abs(rx * .8 + ry * .6);
          if (back < -o.ch * .5 || back > PZ[k] || side > o.cw * .95) continue;
          if (back < o.ch * .8 && side < o.cw * .55) { o.t = 1; o.g = 6; o.c = 0; return; }
          const f = 1 - back / PZ[k]; o.g = side < o.cw * .5 ? 17 : 1; o.v = NAPF[k] * (f * .85 + .25); o.c = f > .68 ? 1 + (NAPC[k] | 0) : f > .3 ? 1 : 2; return;
        }
        const h = hash(i, j), band = noise(x * 1.5 + 4, y * 2.4 - x * .9);
        if (h > .985 - band * .05) { o.v = (h > .996 ? .9 : .32) * (.62 + .38 * Math.sin(t * 1.6 + h * 70)); o.c = 11; o.g = h > .996 ? 5 : 1; }
      } },
    supercell: { pal: ['#f4f0b0', '#c8c878', '#8a8a4a', '#5a5e34', '#383c22', '#ecd070', '#b8962e', '#e8eeff', '#7a8a5a'], ink: '#1e2012',
      bg(g, w, h) { grad(g, w, h, [[0, '#262a18'], [.45, '#4a5030'], [.63, '#b8b070'], [.69, '#5a5a34'], [1, '#3a3820']]); glow(g, w * .5, h * .64, h * .5, '#f4e8a040'); },
      f(x, y, t, A, o, i, j) {
        const cx = A * .74, cy = .3, flash = (o.p || 0) > .5 || wrap(t, 9) < .12;
        // Funnel: a narrowing, wavering rope from the wall cloud down to the ground, kicking up dust.
        if (y > .4 && y < .69) { const q = (y - .4) / .29, fx = cx + .05 + .04 * Math.sin(y * 9 + t * .9) * q, w = .05 * (1 - q) ** 1.4 + .006; if (Math.abs(x - fx) < w) { o.t = 1; o.c = x < fx ? 3 : 4; return; } if (q > .85 && Math.abs(x - fx) < .07 && noise(x * 30 + t * 2, y * 30) > .55) { o.v = .6; o.c = 6; o.g = 2; return; } }
        // Mesocyclone: stacked striations turning slowly around the updraft.
        const dx = (x - cx) / (A * .55), dy = (y - cy) / .16, r = Math.hypot(dx, dy);
        if (r < 1 + .15 * noise(x * 3, 1) && y < .44) { const band = Math.sin(Math.atan2(dy, dx) * 2 + r * 9 - t * .35 + 1.5 * noise(x * 4, y * 6)); o.t = 1; o.c = flash ? 1 : band > .5 ? 2 : band > -.2 ? 3 : 4; if (r < .25 && band > .3) o.c = flash ? 0 : 2; return; }
        if (y < .38 && fbm(x * 2 - t * .02, y * 5) > .52 + y) { o.t = 1; o.c = flash ? 2 : 4; return; }
        if (x < A * .3 && y > .3 && y < .66 && hash(i, j + Math.floor(t * 8)) > .55) { o.v = .35; o.c = 8; o.g = 16; return; }
        // Wheat bending in waves of wind
        if (y > .69) { const wave = Math.sin(x * 7 - t * 2.2 + y * 18 + noise(x * 2, y * 4) * 2), z = (y - .69) / .31; if (z > .5 && wave > .2) { o.t = 1; o.c = wave > .7 ? 5 : 6; return; } o.g = wave > .4 ? 17 : wave < -.4 ? 18 : 16; o.c = wave > 0 ? 5 : 6; o.v = .5 + .4 * z; }
      } },
    vents: { pal: ['#fff2d0', '#ffb040', '#e04a1a', '#161212', '#2e2624', '#f4f2ec', '#d8203a', '#6a605c', '#a0948e'], ink: '#050303',
      bg(g, w, h) { grad(g, w, h, [[0, '#040303'], [1, '#140a08']]); glow(g, w * .1, h * .4, h * .22, '#ff6a2030'); glow(g, w * .24, h * .6, h * .18, '#ff6a2028'); glow(g, w * .87, h * .34, h * .22, '#ff6a2030'); },
      f(x, y, t, A, o, i, j) {
        for (const [xf, top, w] of VENTS) {
          const cx = A * xf + .015 * Math.sin(y * 13 + xf * 9), dx = x - cx, ww = w * (.8 + .4 * noise(y * 14, xf * 20)) * (1 + (y - top) * .6);
          if (y > top && Math.abs(dx) < ww) { if (Math.abs(noise(x * 22, y * 16) - .5) < .04) { o.t = 1; o.c = Math.sin(t * 3 + y * 40) > 0 ? 1 : 2; return; } o.t = 1; o.c = y < top + .015 ? 0 : dx > ww * .3 ? 4 : 3; return; }
          // Black smoke boils up and spreads out from each mouth.
          if (y < top) { const s = top - y, drift = .06 * Math.sin(s * 5 + t * .3); if (Math.abs(dx - drift) < .02 + s * .35) { const m = fbm(x * 9 - t * .1, y * 7 + t * .5); if (m > .42 + s * .4) { o.v = .55 + (m - .42) * 1.5; o.c = s < .04 ? 2 : m > .6 ? 8 : 7; return; } } }
          // Tube worms crowd the base: white tubes, red plumes.
          if (Math.abs(dx) < w * 3.2 && Math.abs(dx) > ww && y > .8) { const col = Math.floor(x / .012), hh = .03 + .08 * hash(col, 3), tip = .93 - hh; if (hash(col, 1) > .45 && y > tip) { o.t = 1; o.c = y < tip + .02 ? 6 : 5; return; } }
        }
        if (y > .93 - .02 * fbm(x * 6, 4)) { o.t = 1; o.c = Math.abs(noise(x * 14, y * 8) - .5) < .03 ? 2 : 3; return; }
        if (hash(i, j - Math.floor(t * 1.5)) > .993) { o.v = .25; o.c = 8; o.g = 1; }
      } },
    candles: { pal: ['#fffbe8', '#ffd474', '#ff9a30', '#f4e8d0', '#d4bf98', '#3e2616', '#64401f', '#ffc878', '#1e120a'], ink: '#2a1a0a', inkA: .35,
      bg(g, w, h) { grad(g, w, h, [[0, '#120804'], [.6, '#22140a'], [.86, '#2e1a0c'], [1, '#1a0e06']]); for (const C of CANDLES) glow(g, C[0] < 0 ? w + C[0] * h : C[0] * h, h * (.82 - C[1]), h * .3, '#ffb05a26'); },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < CANDLES.length; k++) {
          const C = CANDLES[k], cx = C[0] < 0 ? A + C[0] : C[0], w = C[2], top = .86 - C[1], dx = x - cx;
          const fx = cx + .004 * Math.sin(t * 7 + k) + .008 * (noise(t * 2, k) - .5), fy = top - .06, u = (x - fx) / (w * .85), v = (y - fy) / .06;
          // Teardrop flame: white core, gold body, orange rim.
          if (v > -1.3 && v < 1 && Math.abs(u) < (v < 0 ? (1 + v / 1.3) ** 1.5 : Math.sqrt(1 - v * v))) { const r = Math.hypot(u, v * .7); o.t = 1; o.c = r < .35 ? 0 : r < .7 ? 1 : 2; return; }
          if (Math.abs(dx) < .004 && y > top - .012 && y <= top) { o.t = 1; o.c = 8; return; }
          if (y > top && y < .86 && Math.abs(dx) < w) { o.t = 1; o.c = y < top + .012 ? 7 : dx > w * .35 ? 4 : 3; return; }
          const d = Math.hypot(x - fx, (y - fy) * 1.2); if (d < .16 && hash(i, j) > .55) { const g = (1 - d / .16) ** 2 * (.8 + .2 * Math.sin(t * 6 + k)); if (g > .06) { o.v = g * .6; o.c = 7; o.g = 1; return; } }
          if (y > .87 && Math.abs(dx) < w * .8 && hash(i, j + Math.floor(t * 4)) > .5) { o.v = .35 * (1 - (y - .87) / .13); o.c = 7; o.g = 16; return; }
        }
        if (y > .86) { o.t = 1; o.c = Math.sin(x * 4 + 3 * noise(x * 2, y * 25)) > .5 ? 6 : 5; return; }
        if (hash(i, Math.floor(j + t * .6)) > .996) { o.v = .3; o.c = 7; o.g = 1; }
      } },
    neon: { pal: ['#ff3fbf', '#3ff0ff', '#ffe14a', '#0a0714', '#150d24', '#9a5cff', '#ffffff', '#ff5a3a', '#1a1230'], ink: '#05030a',
      bg(g, w, h) { grad(g, w, h, [[0, '#05030c'], [.45, '#1a0c2c'], [.46, '#0a0614'], [1, '#120a20']]); },
      f(x, y, t, A, o, i, j) {
        const vx = A / 2, vy = .45, ax = x - vx, ay = y - vy, hw = .06 + Math.abs(ay) * 1.4;
        if (Math.abs(ax) > hw) {
          // A wall seen in one-point perspective: u is depth toward the vanishing point, hgt is height on the wall.
          const u = 1 / Math.abs(ax), hgt = ay / Math.abs(ax), side = ax < 0 ? 0 : 1, k = Math.floor(u * 1.2 + side * .5), f = wrap(u * 1.2 + side * .5, 1), col = NEON_SC[Math.floor(hash(k, side + 7) * 4)];
          if (hgt > -.55 && hgt < -.12 && f > .25 && f < .55 && hash(k, side + 3) > .25) { const on = Math.sin(t * (3 + 5 * hash(k, side)) + k) > -.85; o.t = 1; o.c = on ? col : 4; if (on && Math.abs(hgt + .335) < .06 && hash(Math.floor(f * 30), k) > .5) o.c = 6; return; }
          if (hgt > -.6 && hgt < -.07 && f > .2 && f < .6 && hash(k, side + 3) > .25) { o.v = .4; o.c = col; return; }
          o.t = 1; o.c = (Math.floor(u * 4) + side) % 2 ? 3 : 4;
          if (hgt < -.7 && wrap(u * 4, 1) < .5 && wrap(hgt * 4, 1) < .5 && hash(Math.floor(u * 4) + side, Math.floor(hgt * 4)) > .55) o.c = hash(Math.floor(u * 4) + side, 9) > .5 ? 2 : 5;
          return;
        }
        if (ay > 0) {
          // Wet asphalt: each sign smears into a vertical streak of reflection near the wall it hangs on.
          const k = Math.floor(1 / hw * 1.2), side = ax < 0 ? 0 : 1;
          if (Math.abs(Math.abs(ax) - hw) < hw * .45 && hash(i, j + Math.floor(t * 3)) > .5) { o.v = .25 + .25 * Math.sin(t * 2 + i); o.c = NEON_SC[Math.floor(hash(k, side + 7) * 4)]; o.g = 16; return; }
          if (Math.abs(ax) < .006 + ay * .02 && wrap(.3 / (ay + .02) - t * .5, 1) < .4) { o.v = .5; o.c = 2; o.g = 16; return; }
          if (noise(x * 20, y * 6 - t * .4) > .72) { o.v = .25; o.c = 6; o.g = 2; return; }
          o.t = 1; o.c = 8; return;
        }
        if (Math.abs(y - (vy - hw * .9)) < .004) { o.v = .4; o.c = 5; o.g = 3; return; }
        if (hash(i, j + Math.floor(t * 2)) > .992) { o.v = .3; o.c = 6; o.g = 1; }
      } },
    blackhole: { pal: ['#fff8e8', '#ffc46a', '#ff7a3a', '#b03a6a', '#000000', '#cfd8ff', '#9a7cff'], ink: '#000000',
      bg(g, w, h) { grad(g, w, h, [[0, '#04020a'], [1, '#0a0614']]); glow(g, w - h * .5, h * .48, h * .8, '#ffb04a22'); },
      f(x, y, t, A, o, i, j) {
        const dx = (x - (A - .5)) / 2.2, dy = (y - .48) / 2.2, d = Math.hypot(dx, dy), rd = Math.hypot(dx, dy * 3.4);
        if (dy > 0 && bhDisk(dx, dy, rd, t, o, false)) return;
        if (d < .075) { o.t = 1; o.c = 4; return; }
        if (d < .09) { o.v = .9; o.c = 6; return; }
        if (dy <= 0 && bhDisk(dx, dy, rd, t, o, true)) return;
        // The far side of the disk, bent up over the shadow by the hole's gravity.
        if (dy < .02 && d > .09 && d < .14) { const I = (1 - (d - .09) / .05) * (.6 + .4 * noise(Math.atan2(dy, dx) * 5 + t * .4, 3)); if (I > .2) { o.v = I * .8; o.c = I > .5 ? 1 : 2; return; } }
        if (d > .2) stars(o, i, j, t, 5, y, 1.1);
      } },
    volcano: { pal: ['#fff2a8', '#ffa040', '#ff5020', '#a02a1a', '#1a1012', '#2e1c1a', '#4a3e42', '#7a6a6a', '#ffd0a0'], ink: '#0a0406',
      bg(g, w, h) { grad(g, w, h, [[0, '#0c0610'], [.5, '#1e0c14'], [1, '#2a0e10']]); glow(g, h * .36, h * .42, h * .45, '#ff5a2030'); },
      pre(t, A) { const cx = A * .2; for (let k = 0; k < 24; k++) { const q = wrap(t * (.35 + .2 * hash(k, 1)) + hash(k, 2), 1), vx = (hash(k, 3) - .5) * .5; PX[k] = cx + vx * q; PY[k] = .42 - (.5 + .3 * hash(k, 4)) * q + .75 * q * q; PZ[k] = q; } },
      f(x, y, t, A, o, i, j) {
        const cx = A * .2, peak = .42;
        for (let k = 0; k < 24; k++) if (PY[k] < peak + .02 && Math.abs(x - PX[k]) < o.cw * .5 && Math.abs(y - PY[k]) < o.ch * .5) { o.g = 6; o.c = PZ[k] < .5 ? 8 : 1; o.v = 1 - PZ[k] * .6; return; }
        const dx = x - cx, hw = (y - peak) / .53 * .34 + .035;
        if (y > peak && Math.abs(dx) < hw) {
          for (let s = -1; s <= 1; s += 2) { const px = cx + s * (y - peak) * .32 + .015 * Math.sin(y * 22 + s); if (Math.abs(x - px) < .008 + (y - peak) * .015) { const fl = .55 + .45 * Math.sin(y * 45 - t * 2.5); o.t = fl > .5 ? 1 : 0; o.c = fl > .85 ? 0 : fl > .5 ? 1 : 2; o.v = fl; return; } }
          if (y < peak + .02) { o.t = 1; o.c = 1; return; }
          o.t = 1; o.c = dx < -hw * .2 ? 5 : 4; return;
        }
        if (y < peak) {
          const s = peak - y, drift = s * .35, w = .04 + s * .45, m = fbm(x * 3.2 - t * .05, y * 3 + t * .08);
          if (Math.abs(dx - drift) < w * (m + .3)) { o.v = Math.min(.8, .3 + m * .6); o.c = s < .06 ? 2 : m > .6 ? 7 : 6; o.g = m > .55 ? 3 : 2; return; }
        }
        { const r = .88 - .12 * tri(x * 1.2 + .4) - .03 * noise(x * 8, 2); if (x > A * .55 && y > r) { o.t = 1; o.c = 4; return; } }
        stars(o, i, j, t, 8, y, .45);
      } },
    starry: { pal: ['#fff8c0', '#ffd84a', '#e8a820', '#7aa8ec', '#4a74c8', '#24458e', '#0c1a34', '#141c28', '#ffcf5a'], ink: '#081430',
      bg(g, w, h) { grad(g, w, h, [[0, '#10245e'], [.6, '#1c3c84'], [1, '#0c1838']]); },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < STARRY.length; k++) { const S = STARRY[k], d = Math.hypot(x - (S[0] < 0 ? A + S[0] : S[0]), y - S[1]); if (d < S[2] * .3) { o.t = 1; o.c = 0; return; } if (d < S[2]) { const ring = Math.sin(d / S[2] * 14 - t * 1.5 + k); if (ring > .2) { o.v = .9; o.c = ring > .7 ? 1 : 2; return; } } }
        { const d = Math.hypot(x - (A - .12), y - .14); if (d < .06 && Math.hypot(x - (A - .1), y - .125) > .05) { o.t = 1; o.c = 1; return; } }
        // A flame-shaped cypress licking up the left side
        { const q = (.98 - y) / .86, dx = x - A * .09, w = q > 0 && q < 1 ? .06 * (1 - q) ** .6 * (1 + .25 * Math.sin(y * 30 + t * .8)) : 0; if (Math.abs(dx) < w) { o.t = 1; o.c = Math.sin(y * 50 + dx * 80) > .4 ? 7 : 6; return; } }
        // Village roofs with lit windows
        if (y > .86) { const col = Math.floor(x / .05), hh = .03 + .05 * hash(col, 1); if (y > .95 - hh) { o.t = 1; o.c = hash(i, j) > .86 && y > .96 - hh + .015 ? 8 : 7; return; } }
        // Everything else is brushwork: each cell is a stroke laid along a swirling flow field.
        let ang = (noise(x * 1.3 + t * .015, y * 1.6) - .5) * 3;
        let band = 0;
        for (const [sx, sy, r] of SWIRLS) { const dx = x - sx * A, dy = y - sy, d = Math.hypot(dx, dy), wgt = Math.exp(-d / (r * 1.6)); ang = ang * (1 - wgt) + (Math.atan2(dy, dx) + Math.PI / 2) * wgt; if (wgt > .45) band = Math.sin(d / r * 9 - Math.atan2(dy, dx) * .5 - t * .4); }
        const a = wrap(ang, Math.PI), n = noise(x * 5, y * 5 + t * .05);
        o.g = a < .39 || a > 2.75 ? 3 : a < 1.18 ? 18 : a < 1.96 ? 16 : 17; o.v = .5 + .4 * n;
        // Inside a swirl, strokes alternate pale and deep blue in rings so the eddy reads from across the room.
        if (band > .35) { o.c = 3; o.v = .95; if (band > .85) { o.t = 1; o.c = 4; } } else o.c = y > .78 ? 5 : n > .62 ? 3 : n > .4 ? 4 : 5;
      } },
    radar: { pal: ['#fff2c4', '#ffc24a', '#c8861c', '#6a4612', '#2e1e08', '#ff7a3a'], ink: '#0a0602',
      bg(g, w, h) { grad(g, w, h, [[0, '#0c0702'], [1, '#160c03']]); glow(g, w - h * .42, h * .5, h * .45, '#ffb04a14'); },
      pre(t, A) { for (let k = 0; k < 7; k++) { const a = hash(k, 1) * 6.283 + t * .02 * (hash(k, 2) - .5), r = .08 + .3 * hash(k, 3); PX[k] = A - .42 + r * Math.cos(a); PY[k] = .5 + r * Math.sin(a); PZ[k] = a; } },
      f(x, y, t, A, o, i, j) {
        const scan = j % 2 ? .75 : 1, cx = A - .42, dx = x - cx, dy = y - .5, r = Math.hypot(dx, dy), sw = wrap(t * 1.1, 6.283);
        if (r < .4) {
          const lag = wrap(sw - wrap(Math.atan2(dy, dx), 6.283), 6.283);
          // Contacts flare when the beam passes and fade until the next sweep.
          for (let k = 0; k < 7; k++) if (Math.abs(x - PX[k]) < o.cw * .6 && Math.abs(y - PY[k]) < o.ch * .5) { const age = wrap(sw - wrap(PZ[k], 6.283), 6.283); o.v = Math.max(.15, 1 - age / 3.5); o.c = age < .4 ? 0 : 1; o.t = age < .25 ? 1 : 0; o.g = 19; return; }
          if (lag < .03) { o.t = 1; o.c = 0; return; }
          if (lag < 1.3) { const v = (1 - lag / 1.3) ** 2; if (v > .05) { o.v = v * .8 * scan; o.c = v > .5 ? 1 : 2; return; } }
          if (Math.abs(r - Math.round(r / .1) * .1) < .004 || Math.abs(dx) < o.cw * .3 || Math.abs(dy) < o.ch * .3) { o.v = .4 * scan; o.c = 3; o.g = 1; }
          return;
        }
        if (Math.abs(r - .41) < .006) { o.v = .7; o.c = 2; return; }
        // Oscilloscope on the left, with a phosphor ghost of the previous trace.
        const L = .04, R = A * .32, inX = x > L && x < R, inY = y > .25 && y < .75;
        if (inX && inY) {
          if (Math.abs(y - radarWave(x, t)) < o.ch * .6) { o.t = 1; o.c = 0; return; }
          if (Math.abs(y - radarWave(x, t - .12)) < o.ch * .6) { o.v = .55; o.c = 2; return; }
          if (wrap(x - L, .08) < o.cw * .5 || wrap(y - .25, .05) < o.ch * .5) { o.v = .3 * scan; o.c = 3; o.g = 1; }
          return;
        }
        if (inY && (Math.abs(x - L) < o.cw * .5 || Math.abs(x - R) < o.cw * .5)) { o.v = .6; o.c = 2; o.g = 16; return; }
        if (inX && (Math.abs(y - .25) < o.ch * .5 || Math.abs(y - .75) < o.ch * .5)) { o.v = .6; o.c = 2; o.g = 3; return; }
        if (inX && y > .8 && y < .9) { const h = hash(i, j + Math.floor(t * 3)); if (h > .45) { o.v = .6 * scan; o.c = h > .9 ? 5 : 1; o.g = 3 + Math.floor(h * 8); } }
      } },
    saturn: { pal: ['#effdff', '#b4f0fa', '#6cd0e6', '#2e92b4', '#145a7a', '#d4ecff', '#7a9cbc', '#dce8ff', '#9ae8c8'], ink: '#020a12',
      bg(g, w, h) { grad(g, w, h, [[0, '#020a12'], [1, '#05182a']]); glow(g, w - h * .4, h * .5, h * .5, '#4ad0e81c'); },
      f(x, y, t, A, o, i, j) {
        const cx = A - .4, cy = .5, r = .2, dx = x - cx, dy = y - cy, d = Math.hypot(dx, dy);
        const ry = (dy + dx * .5) * 2.2, rr = Math.hypot(dx, ry), rw = Math.max(.006, o.ch * .45), ring = Math.abs(rr - .3) < rw || Math.abs(rr - .34) < rw * .7 || Math.abs(rr - .37) < rw * .5;
        if (ring && (ry > 0 || d > r)) { o.v = .7; o.c = rr < .32 ? 5 : 6; o.g = 3; return; }
        if (d < r) {
          const z = Math.sqrt(1 - (d / r) ** 2), lit = (-dx * .7 - dy * .35) / r + z * .55, sx = wrap(t * .02, 1) * 2 - 1;
          if (dy < -r * .82 && Math.sin(t * 2 + dx * 40) > -.2) { o.t = 1; o.c = 8; return; }
          const spot = Math.abs(sx) < .9 && ((dx / r - sx) / .16) ** 2 + ((dy / r - .2) / .07) ** 2 < 1;
          o.t = 1; o.c = spot ? 4 : lit > .95 ? 0 : lit > .6 ? 1 : lit > .25 ? 2 : lit > -.1 ? 3 : 4;
          if (!spot && o.c < 3 && Math.sin(dy / r * 18 + noise(x * 6, y * 30) * 2) > .85) o.c++;
          return;
        }
        for (let m = 0; m < SATURN_MOONS.length; m++) { const M = SATURN_MOONS[m], a = t * M[1] + M[2], mx = cx + M[0] * Math.cos(a), my = cy - M[0] * .2 * Math.cos(a) + M[0] * .25 * Math.sin(a); if (Math.sin(a) < 0 && Math.hypot(mx - cx, my - cy) < r) continue; if (Math.hypot(x - mx, y - my) < M[3]) { o.t = 1; o.c = x < mx ? 1 : 3; return; } }
        stars(o, i, j, t, 7, y, 1.1);
      } },
    kelp: { pal: ['#eef6ff', '#9ab8d4', '#d4a83c', '#8a661c', '#f0cc64', '#0a2440', '#14385a', '#c4e2ff', '#4e6c8c'], ink: '#030c18',
      bg(g, w, h) { grad(g, w, h, [[0, '#2a6e9e'], [.5, '#103e6a'], [1, '#061c3a']]); for (let k = 0; k < 4; k++) { const x = w * (.05 + k * .3), s = g.createLinearGradient(x, 0, x + w * .1, h); s.addColorStop(0, '#c4e2ff22'); s.addColorStop(1, '#c4e2ff00'); g.fillStyle = s; g.beginPath(); g.moveTo(x, 0); g.lineTo(x + w * .05, 0); g.lineTo(x + w * .16, h); g.lineTo(x + w * .07, h); g.fill(); } },
      pre(t, A) { const cx = A * .78 + .05 * Math.sin(t * .2), cy = .4 + .05 * Math.sin(t * .27), R = .13; for (let k = 0; k < 60; k++) { const lat = (hash(k, 1) - .5) * 2.6, a = hash(k, 2) * 6.283 + t * (.5 + .2 * hash(k, 3)); PX[k] = cx + R * Math.cos(lat) * Math.cos(a); PY[k] = cy + R * .8 * Math.sin(lat); PZ[k] = Math.cos(lat) * Math.sin(a); } },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 60; k++) if (Math.abs(x - PX[k]) < o.cw * .5 && Math.abs(y - PY[k]) < o.ch * .5) { if (PZ[k] > 0) { o.t = 1; o.c = 0; } else { o.v = .55; o.c = 8; o.g = 3; } return; }
        for (let s = 0; s < 7; s++) {
          const X = s < 4 ? A * (.03 + s * .07) : A * (.96 - (s - 4) * .07), h = .5 + .4 * hash(s, 1);
          if (y < .95 - h) continue; const q = (.95 - y) / h, dx = x - X - .05 * q * q * Math.sin(t * .5 + s * 1.3);
          if (Math.abs(dx) < .007) { o.t = 1; o.c = 3; return; }
          // Broad blades with a gas float at each base
          const seg = wrap(y * 9 + s * .37, 1), side = Math.floor(y * 9 + s * .37) % 2 ? 1 : -1, u = dx * side;
          if (u > .007 && u < .06 && Math.abs(seg - .5 - (u - .007) * 3) < .22 * (1 - (u - .007) / .053)) { o.t = 1; o.c = u < .02 ? 2 : 4; if (u < .016 && Math.abs(seg - .5) < .1) { o.t = 0; o.g = 15; o.v = 1; } return; }
        }
        if (y > .93 - .025 * fbm(x * 5, 1)) { o.t = 1; o.c = noise(x * 20, y * 20) > .55 ? 6 : 5; return; }
        if (hash(i, 7) > .95) { const d = wrap(t * .1 * (1 + hash(i, 2)) + hash(i, 3), 1.1); if (Math.abs(y - 1 + d) < o.ch * .5) { o.g = 15; o.c = 7; o.v = .7; } }
      } },
    glitch: { pal: ['#ffffff', '#ff2a6a', '#2af0ff', '#20202e', '#f4f02a', '#7a7a96', '#34344a'], ink: '#040408',
      bg(g, w, h) { grad(g, w, h, [[0, '#050508'], [1, '#0a0a12']]); },
      f(x, y, t, A, o, i, j) {
        const band = Math.floor(y * 24), tick = Math.floor(t * 5), jolt = hash(band, tick) > .86 ? (hash(tick, band) - .5) * .25 : 0;
        // A tracking bar rolls down the screen like a worn tape.
        const roll = wrap(t * .13, 1.2) - .1; if (Math.abs(y - roll) < .02) { if (hash(i, j + Math.floor(t * 30)) > .4) { o.v = .5; o.c = 5; o.g = 3 + Math.floor(hash(j, i + tick) * 9); } return; }
        // Red and cyan copies drift apart; where they overlap the image is white.
        const X = x + jolt, sep = .012 + (jolt ? .02 : 0) + .01 * (o.e || 0), r = glitchShape(X - sep, y, t, A), c = glitchShape(X + sep, y, t, A);
        if (r && c) { o.t = 1; o.c = jolt ? 4 : 0; return; } if (r) { o.t = 1; o.c = 1; return; } if (c) { o.t = 1; o.c = 2; return; }
        if (jolt && hash(i, band) > .7) { o.v = .4; o.c = 6; o.g = 3; return; }
        if (hash(i, j + Math.floor(t * 24)) > .992) { o.v = .5; o.c = 5; o.g = 3 + Math.floor(hash(i, j) * 9); }
      } },
    peacock: { pal: ['#f4d860', '#14806e', '#2a58d0', '#0a1650', '#5ab84a', '#8a3ab0', '#d4f0a0', '#06121a', '#38d0bc'], ink: '#020a0e',
      bg(g, w, h) { grad(g, w, h, [[0, '#04100e'], [1, '#081e1c']]); },
      f(x, y, t, A, o, i, j) {
        // Eyes on a staggered lattice; their rings shimmer between blue/purple and teal as the light moves.
        const sx = .3, sy = .26, row = Math.floor(y / sy + .5), off = row % 2 ? sx / 2 : 0, col = Math.floor((x - off) / sx + .5), ex = x - off - col * sx - .008 * Math.sin(t * .5 + y * 4), ey = y - row * sy;
        const d = Math.hypot(ex / .12, ey / .155), shimmer = Math.sin(t * .7 + col * 1.3 + row * 2.1) > .3;
        if (d < 1) { o.t = 1; o.c = d < .28 ? 3 : d < .45 ? (shimmer ? 5 : 2) : d < .62 ? (shimmer ? 8 : 1) : d < .78 ? 0 : 4; if (d < .14 && ex < 0) o.c = 6; return; }
        // Barbs: fine strokes fanning out from below the screen.
        const a = Math.atan2(y - 1.4, x - A / 2);
        if (Math.sin(a * 140 + noise(x * 3, y * 3) * 4) > .35) { o.v = .35 + .25 * noise(x * 6, y * 6); o.c = noise(x * 2 + t * .05, y * 2) > .5 ? 8 : 1; o.g = Math.abs(a + Math.PI / 2) < .35 ? 16 : a < -Math.PI / 2 ? 18 : 17; }
      } },
    blueprint: { pal: ['#ffffff', '#cfe2ff', '#8ab2ee', '#5a86d0', '#ffd84a', '#2a5aa8'], ink: '#0a2a6a',
      bg(g, w, h) { grad(g, w, h, [[0, '#0f3c8c'], [1, '#0a2c6c']]); },
      f(x, y, t, A, o, i, j) {
        for (let n = 0; n < GEARS.length; n++) {
          const G = GEARS[n], cx = G[0] < 0 ? A + G[0] : G[0], dx = x - cx, dy = y - G[1], R = G[2];
          if (Math.abs(dx) >= R + .06 || Math.abs(dy) >= R + .06 + o.ch * .5) continue;
          if (Math.abs(dx) < R + .035 && Math.abs(dy) < R + .035) {
            const r = Math.hypot(dx, dy);
            if (r < R + .035) {
              const a = Math.atan2(dy, dx) - t * G[4], p = wrap(a * G[3] / 6.283, 1);
              // Outline of the teeth (rim plus flanks), the inner rim, five spokes and the bore.
              if ((p < .5 ? Math.abs(r - R - .022) : Math.abs(r - R)) < .004 || ((p < .04 || Math.abs(p - .5) < .04) && r > R && r < R + .022)) { o.t = 1; o.c = 0; return; }
              if (Math.abs(r - R * .78) < .004 || Math.abs(r - R * .25) < .004 || Math.abs(r - R * .1) < .004) { o.v = .9; o.c = 1; return; }
              if (r > R * .25 && r < R * .78) for (let s = 0; s < 5; s++) if (Math.abs(Math.sin(a - s * 1.2566)) * r < .005 && Math.cos(a - s * 1.2566) > 0) { o.v = .9; o.c = 1; return; }
            }
          }
          // Dashed centre lines and, on the big gears, a yellow dimension line.
          if ((Math.abs(dy) < o.ch * .3 && Math.abs(dx) < R + .06 || Math.abs(dx) < o.cw * .3 && Math.abs(dy) < R + .06) && wrap(dx + dy, .03) < .018) { o.v = .5; o.c = 3; o.g = Math.abs(dy) < o.ch * .3 ? 3 : 16; return; }
          if (R > .12 && Math.abs(y - (G[1] - R - .06)) < o.ch * .5 && Math.abs(dx) < R) { o.v = .9; o.c = 4; o.g = Math.abs(Math.abs(dx) - R) < o.cw ? 16 : 3; return; }
        }
        if (wrap(x, .25) < o.cw * .5 || wrap(y, .25) < o.ch * .5) { o.v = .35; o.c = 3; o.g = 1; return; }
        if (wrap(x, .05) < o.cw * .5 && wrap(y, .05) < o.ch * .5) { o.v = .3; o.c = 5; o.g = 1; }
      } },
    stainedglass: { pal: ['#141016', '#d8283a', '#2a54d0', '#f0b02a', '#249a58', '#8a34b0', '#4ac4e0', '#fff4d0', '#3a302c', '#5a4c44'], ink: '#0a0806', inkA: .35,
      bg(g, w, h) { grad(g, w, h, [[0, '#1e1814'], [1, '#2a221c']]); },
      f(x, y, t, A, o, i, j) {
        for (let side = 0; side < 2; side++) {
          const cxF = side ? -.17 : .17, w = .13, cx = cxF < 0 ? A + cxF : cxF, dx = x - cx, archY = .14 + w;
          const inside = Math.abs(dx) < w && y < .78 && (y > archY || Math.hypot(dx, y - archY) < w);
          if (inside) {
            const edge = voronoi(x, y, .06); if (edge < .005 || Math.abs(dx) < .004 || Math.abs(y - archY - .2) < .004) { o.t = 1; o.c = 0; return; }
            // A shaft of sun slides across the glass, turning lit panes pale gold.
            o.t = 1; o.c = wrap(x * .7 + y * .5 - t * .04, .6) < .08 && VID > .5 ? 7 : 1 + Math.floor(VID * 6); return;
          }
          if (Math.abs(dx) < w + .02 && y < .8 && (y > archY || Math.hypot(dx, y - archY) < w + .02)) { o.t = 1; o.c = 0; return; }
          if (y > .86 && Math.abs(dx - (y - .86) * .6) < w * 1.2 && hash(i, j) > .5) { voronoi(dx - (y - .86) * .6 + cx, .3 + (y - .86) * 3, .06); o.v = .35; o.c = 1 + Math.floor(VID * 6); o.g = 1; return; }
        }
        if (y > .86) { o.t = 1; o.c = 8; return; }
        // Stone courses around the windows
        const row = Math.floor(y / .06); if (wrap(y, .06) < o.ch * .45 || wrap(x / .14 + (row % 2) * .5, 1) < o.cw / .14 * .45) { o.v = .3; o.c = 9; o.g = 3; }
      } },
    inkwash: { pal: ['#141414', '#383838', '#626262', '#8e8e8e', '#b8b6b0', '#c4302a', '#f6f2e8'], ink: '#f6f2e8', inkA: .25,
      bg(g, w, h) { grad(g, w, h, [[0, '#f3eee2'], [1, '#e9e2d2']]); },
      f(x, y, t, A, o, i, j) {
        if (Math.abs(x - (A - .07)) < .025 && Math.abs(y - .88) < .03) { o.t = 1; o.c = Math.abs(x - (A - .07)) < .012 && Math.abs(y - .88) < .015 && hash(i, j) > .5 ? 6 : 5; return; }
        for (let k = 0; k < 3; k++) { const bx = wrap(t * .012 + k * .05, A + .4) - .2, by = .18 + k * .025 + .01 * Math.sin(t + k); if (Math.abs(x - bx) < o.cw * .5 && Math.abs(y - by) < o.ch * .5) { o.g = Math.sin(t * 4 + k) > 0 ? 12 : 13; o.c = 1; o.v = 1; return; } }
        // A pine branch reaching in from the top-left corner
        { const q = x / .45, by = .05 + .12 * q * q; if (q < 1 && Math.abs(y - by) < .008 + .006 * (1 - q)) { o.t = 1; o.c = 0; return; } if (q < 1 && q > .2 && Math.abs(y - by) < .05 && hash(i, j) > .35) { o.g = y < by ? 18 : 17; o.c = 1; o.v = .9; return; } }
        // Karst towers in washes: ink pools on each ridge and bleeds downward into the mist.
        for (let L = 0; L < 4; L++) {
          let peak = 0; for (let p = 0; p < 5; p++) { const s = .05 + .06 * hash(p, L + 5); peak = Math.max(peak, Math.exp(-(((x - hash(p, L + 1) * A) / s) ** 2)) * (.12 + .18 * hash(p, L + 9))); }
          // Between peaks the layer dissolves into mist instead of drawing a flat ridge.
          if (peak < .03) continue;
          const top = .5 + L * .12 - peak - .02 * fbm(x * 6, L), depth = .08 + peak * .9;
          if (y > top && y < top + depth) { const q = (y - top) / depth, v = (1 - q) ** 1.5 * (.6 + .4 * fbm(x * 12, y * 12 + L)); if (q < .06 || v > .62) { o.t = 1; o.c = q < .06 ? Math.max(0, 3 - L) : 4 - L; return; } if (v > .12) { o.v = v + .15; o.c = 4 - L; return; } }
        }
        // A sampan on still water
        { const dx = x - A * .2, sy = .86; if (Math.abs(dx) < .07 && y > sy && y < sy + .02 - Math.abs(dx) * .15) { o.t = 1; o.c = 0; return; } if (Math.abs(dx - .01) < .008 && y > sy - .035 && y <= sy) { o.t = 1; o.c = 0; return; } if (Math.abs(dx - .01) < .02 && Math.abs(y - sy + .04) < .006) { o.g = 13; o.c = 0; o.v = 1; return; } if (y > sy + .03 && y < sy + .05 && Math.abs(dx) < .1 && Math.sin(x * 60 + t * .5) > .6) { o.g = 14; o.c = 3; o.v = .6; } }
      } },
    glacier: { pal: ['#ffffff', '#dcf4ff', '#aee0f6', '#78c4ea', '#3a92c8', '#1e6496', '#f4fbff', '#8ad0e6'], ink: '#5a8aa8', inkA: .3,
      bg(g, w, h) { grad(g, w, h, [[0, '#d8ecf8'], [.55, '#f4fafe'], [.7, '#e6f2f8'], [1, '#cfe6f0']]); },
      pre(t, A) { for (let k = 0; k < 20; k++) { PX[k] = A * (.3 + .4 * hash(k, 1)) + .02 * Math.sin(t * .5 + k); PY[k] = wrap(hash(k, 2) + t * (.015 + .015 * hash(k, 3)), 1); } for (let k = 20; k < 30; k++) { PX[k] = A * (.17 + .66 * hash(k, 1)); PZ[k] = wrap(t * .3 + hash(k, 4) * 4, 1.6); } },
      f(x, y, t, A, o, i, j) {
        const ex = (x - A / 2) / (A * .36), ey = (y - .5) / .46, e = ex * ex + ey * ey;
        if (e > 1 || y < .08) {
          // Cave ice: faceted cells that get darker and bluer deeper into the wall.
          const edge = voronoi(x, y, .09), depth = Math.min(1, (Math.sqrt(e) - 1) * 2.2 + (y < .08 ? .5 : 0));
          o.t = 1; o.c = edge < .006 ? (depth > .6 ? 3 : 0) : Math.min(5, 1 + Math.floor(depth * 3 + VID * 2)); return;
        }
        // Icicles hang from the lip of the opening, each letting go of a drop now and then.
        for (let k = 20; k < 30; k++) {
          const ix = PX[k], lip = .5 - .46 * Math.sqrt(Math.max(0, 1 - ((ix - A / 2) / (A * .36)) ** 2)), len = .04 + .08 * hash(k, 6);
          if (y > lip && y < lip + len && Math.abs(x - ix) < .012 * (1 - (y - lip) / len) + o.cw * .3) { o.t = 1; o.c = 2; return; }
          if (PZ[k] < 1 && Math.abs(x - ix) < o.cw * .5 && Math.abs(y - lip - len - PZ[k] * .5) < o.ch * .5) { o.g = 16; o.c = 4; o.v = .9; return; }
        }
        for (let k = 0; k < 20; k++) if (Math.abs(x - PX[k]) < o.cw * .5 && Math.abs(y - PY[k]) < o.ch * .5) { o.g = 6; o.c = 3; o.v = .9; return; }
        if (y > .8) { if (Math.sin(x * 40 + y * 200 - t) > .7) { o.v = .5; o.c = 7; o.g = 14; } else { o.t = 1; o.c = 1; } return; }
        const m = .7 - .12 * tri(x * 2.2 + .3) - .04 * noise(x * 8, 2); if (y > m) { o.t = 1; o.c = y < m + .02 ? 0 : 2; return; }
        if (wrap(x * .8 - y * .6 + t * .02, .25) < .05) { o.v = .3; o.c = 6; o.g = 1; }
      } },
    balloons: { pal: ['#ff7aa8', '#ffe07a', '#7ad0f0', '#8ae0b0', '#ffffff', '#a8745a', '#c8a0f8', '#cfeec0', '#f4ecb0', '#b8e0a8'], ink: '#6a4a3a', inkA: .3,
      bg(g, w, h) { grad(g, w, h, [[0, '#f2c4dc'], [.5, '#ffe2ee'], [.75, '#fff2e6'], [1, '#eef4dc']]); glow(g, w * .5, h * .74, h * .5, '#fff8e8a0'); },
      pre(t, A) { const X = [.08, .22, .34, -.08, -.22, -.34], C = [[0, 1], [2, 4], [3, 1], [6, 4], [0, 4], [2, 1]]; for (let k = 0; k < 6; k++) { const z = .6 + .4 * hash(k, 5); PX[k] = (X[k] < 0 ? A + X[k] : X[k]) + .02 * Math.sin(t * .2 + k); PY[k] = .65 - wrap(hash(k, 2) + t * (.006 + .006 * z), .8) * .75; PZ[k] = z; NAPC[k] = C[k][0]; NAPF[k] = C[k][1]; } },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 6; k++) {
          const r = .05 * PZ[k] + .015, dx = x - PX[k], dy = y - PY[k]; if (Math.abs(dx) > r * 1.2 || dy < -r * 1.3 || dy > r * 1.6) continue;
          const rx = dy > 0 ? r * Math.max(.15, 1 - dy / (r * 1.25)) : r;
          if ((dx / rx) ** 2 + (Math.min(0, dy) / (r * 1.15)) ** 2 < 1 && dy < r * 1.1) { o.t = 1; o.c = Math.floor((dx / rx + 1) * 2.5) % 2 ? NAPF[k] : NAPC[k]; return; }
          if (dy > r * 1.32 && dy < r * 1.55 && Math.abs(dx) < r * .2) { o.t = 1; o.c = 5; return; }
          if (dy > r * 1.1 && dy < r * 1.32 && Math.abs(Math.abs(dx) - r * .16) < o.cw * .5) { o.g = 16; o.c = 5; o.v = .8; return; }
        }
        if (y > .75) { const z = (y - .75) / .25, u = (x - A / 2) / (z + .25), row = Math.floor(1 / (z + .12)), col = Math.floor(u * 2.2); if (Math.abs(wrap(u * 2.2, 1) - .5) > .47) { o.g = 16; o.c = 9; o.v = .5; return; } o.t = 1; o.c = 7 + Math.floor(hash(col, row) * 3); return; }
        const m = noise(x * 1.5 - t * .01, y * 6); if (y < .5 && m > .7) { o.v = .5; o.c = 4; o.g = 3; }
      } },
    reef: { pal: ['#ffffff', '#ff7a8a', '#ffb04a', '#a87aff', '#ffe060', '#3a8ad0', '#f6e8c4', '#e0cc9a', '#3ab8b0'], ink: '#4a6a7a', inkA: .3,
      bg(g, w, h) { grad(g, w, h, [[0, '#6ad4e6'], [.5, '#9ae2ee'], [1, '#c4eeee']]); },
      pre(t, A) { for (let k = 0; k < 12; k++) { const dir = k % 2 ? 1 : -1; PX[k] = wrap(dir * t * (.03 + .03 * hash(k, 1)) + hash(k, 2) * 3, A + .3) - .15; PY[k] = .2 + .55 * hash(k, 3) + .015 * Math.sin(t + k); PZ[k] = dir; } },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 12; k++) { const dx = (x - PX[k]) * PZ[k], dy = y - PY[k]; if (Math.abs(dy) < .014 && dx > -.04 && dx < .025) { if (dx > -.012 && (dx / .025) ** 2 + (dy / .012) ** 2 < 1) { o.t = 1; o.c = k % 3 ? 4 : 5; return; } if (dx <= -.012 && Math.abs(dy) < (-.012 - dx) * .5) { o.t = 1; o.c = k % 3 ? 2 : 5; return; } } }
        for (let c = 0; c < REEF_CORALS.length; c++) {
          const rc = REEF_CORALS[c], cx = rc[0], X = cx < 0 ? A + cx : cx, q = (.9 - y) / rc[1]; if (q < 0 || q > 1) continue;
          if (Math.abs(x - X) < rc[2] * (1 - q * .6) && fbm(x * 16 + cx * 9, y * 16) > .38 + q * .12) { o.t = 1; o.c = rc[3]; if (q > .85) o.c = 0; return; }
        }
        if (y > .88 + .01 * Math.sin(x * 5)) { o.t = 1; o.c = Math.sin(x * 40 + y * 120) > .6 ? 7 : 6; return; }
        const q = Math.abs(noise(x * 5 + t * .15, y * 5) - noise(x * 5 + 4, y * 5 - t * .12)); if (q < .035) { o.v = .45; o.c = 0; o.g = 14; return; }
        if (hash(i, 7) > .96) { const d = wrap(t * .08 * (1 + hash(i, 2)) + hash(i, 3), 1.1); if (Math.abs(y - 1 + d) < o.ch * .5) { o.g = 15; o.c = 0; o.v = .7; } }
      } },
    popart: { pal: ['#ff2a2a', '#ffe02a', '#2a64ff', '#111111', '#ffffff', '#ff8ac8', '#22c4a0'], ink: '#111111', inkA: .2,
      bg(g, w, h) { grad(g, w, h, [[0, '#fff4d4'], [1, '#ffeec4']]); },
      f(x, y, t, A, o, i, j) {
        // Comic starburst with a heavy black outline and halftone shading
        { const dx = x - A * .2, dy = y - .45, r = Math.hypot(dx, dy), a = Math.atan2(dy, dx) + t * .05, R = .2 + .08 * tri(a * 12 / 6.283), R2 = .11 + .04 * tri(a * 8 / 6.283 + .5);
          if (Math.abs(r - R) < .01 || Math.abs(r - R2) < .008) { o.t = 1; o.c = 3; return; }
          if (r < R) { o.t = 1; o.c = r < R2 || dotFill(x, y, .035, .35 + .4 * (r - R2) / (R - R2)) ? 0 : 1; return; } }
        // Speech balloon: white fill, black outline, three bold dots and a black tail
        { const cx = A - .26, cy = .34, u = (x - cx) / .2, v = (y - cy) / .13, e = Math.hypot(u, v);
          const ty = (y - cy - .1) / .16, tail = ty > 0 && ty < 1 && x > cx - .05 - ty * .1 - (1 - ty) * 0 && x < cx + .03 - ty * .17;
          if (Math.abs(e - 1) < .06) { o.t = 1; o.c = 3; return; }
          if (e < 1) { o.t = 1; o.c = e < .5 && Math.abs(v) < .25 && (Math.abs(u + .35) < .09 || Math.abs(u) < .09 || Math.abs(u - .35) < .09) ? 3 : 4; return; }
          if (tail) { o.t = 1; o.c = 3; return; } }
        // Ben-Day dots everywhere else, growing toward the bottom
        if (dotFill(x, y, .045, .15 + .6 * y)) { o.t = 1; o.c = hash(i, j) < sat((x - A * .3) / (A * .4)) ? 5 : 2; }
      } },
    cranes: { pal: ['#ffffff', '#f4a6b8', '#d8708e', '#8ac8e0', '#4a8ab0', '#f0d890', '#c8a860', '#d8d0e4', '#c4b4d0', '#f8e4ea', '#e2eef8', '#f6eedc'], ink: '#7a6a7a', inkA: .3,
      bg(g, w, h) { grad(g, w, h, [[0, '#e6ddf0'], [.6, '#f8ecea'], [1, '#fbf3e6']]); for (let L = 0; L < 2; L++) { g.fillStyle = L ? '#ddd0e4' : '#e8dde8'; g.beginPath(); g.moveTo(0, h); for (let px = 0; px <= w + 4; px += 4) { const x = px / h; g.lineTo(px, (.78 + L * .06 - (.14 - L * .05) * tri(x * (1.3 + L) + L * .4) ** 1.6) * h); } g.lineTo(w, h); g.fill(); } },
      pre(t, A) { for (let k = 0; k < 10; k++) { PX[k] = wrap(hash(k, 1) * (A + .4) + t * (.02 + .015 * hash(k, 2)), A + .4) - .2; PY[k] = .1 + .55 * hash(k, 3) - .02 * Math.sin(t * .3 + k); PZ[k] = Math.sin(t * (2 + hash(k, 4)) + k * 3); } },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 10; k++) {
          const s = 1.5 + 1 * hash(k, 5), du = (x - PX[k]) / s, dv = (y - PY[k]) / s, blue = k % 3 === 0; if (Math.abs(du) > .06 || Math.abs(dv) > .06) continue;
          if (Math.abs(du) / .03 + Math.abs(dv) / .01 < 1) { o.t = 1; o.c = blue ? 3 : 1; return; }
          const f = PZ[k], wh = .045 * f; if (Math.abs(wh) > .004 && dv * Math.sign(-wh) > 0 && Math.abs(dv) < Math.abs(wh) && Math.abs(du + .004) < .022 * (1 - Math.abs(dv / wh))) { o.t = 1; o.c = blue ? (du > 0 ? 4 : 3) : (du > 0 ? 2 : 1); return; }
          if (du > .025 && du < .045 && Math.abs(dv + (du - .025) * .9) < .005) { o.g = 17; o.c = blue ? 4 : 2; o.v = .9; return; }
        }
        if (y > .7 && noise(x * 2 + t * .02, y * 9) > .62) { o.v = .45; o.c = 7; o.g = 14; return; }
        const u = x / .22, v = y / .19, fu = u - Math.floor(u), fv = v - Math.floor(v); if (fu < .03 || fv < .035 || Math.abs(fu + fv - 1) < .03) { o.v = .4; o.c = 8; o.g = fu < .03 ? 16 : fv < .035 ? 3 : 17; return; } const fh = hash(Math.floor(u) * 2 + (fu + fv > 1), Math.floor(v)); if (fh > .55) { o.t = 1; o.c = 9 + Math.floor((fh - .55) / .15); }
      } },
    tea: { pal: ['#98a286', '#24201c', '#4a4038', '#6e9a2e', '#c4dc84', '#ece2c8', '#cdbc94', '#e2d2a8', '#a8946a', '#f4bccb', '#e494ac'], ink: '#6a5a40', inkA: .3,
      bg(g, w, h) { grad(g, w, h, [[0, '#f4f0e2'], [1, '#e6dcc4']]); glow(g, w * .5, h * .3, h * .7, '#fffaf090'); },
      f(x, y, t, A, o, i, j) {
        const cx = A * .22, rim = .6, bot = .82, dx = x - cx;
        if (y > rim && y < bot) { const q = (y - rim) / (bot - rim), w = .15 * Math.sqrt(1 - q * q * .7); if (Math.abs(dx) < w) { o.t = 1; o.c = dx > w * .4 || q > .92 ? 2 : 1; return; } }
        if (Math.abs(y - rim) < .014 && Math.abs(dx) < .15) { o.t = 1; o.c = Math.abs(dx) < .135 ? (noise(x * 40, y * 40 + t * .2) > .55 ? 4 : 3) : 2; return; }
        if (y < rim) { const s = rim - y, xs = cx + .03 * Math.sin(s * 12 - t * 1.4) + .02 * Math.sin(s * 5 + t * .6); if (Math.abs(x - xs) < .015 + s * .1 && s < .5) { const n = noise(x * 18, y * 16 + t * 1.1); if (n > .4 + s * .35) { o.v = .95 * (1 - s / .5); o.c = 0; o.g = n > .6 ? 14 : -1; return; } } }
        // Chasen: a bamboo whisk standing beside the bowl
        { const wdx = x - A * .05; if (y > .55 && y < .7 && Math.abs(wdx) < .013) { o.t = 1; o.c = 7; return; } if (y >= .7 && y < .82) { const q = (y - .7) / .12, ww = .013 + .04 * Math.sin(q * 2.2); if (Math.abs(wdx) < ww) { if (q > .85) { o.t = 1; o.c = 8; } else { o.g = 16; o.c = Math.abs(wdx) > ww * .7 ? 8 : 7; o.v = 1; } return; } } }
        // Mochi on a small plate
        { const px = A - .2, pdx = x - px; for (let m = 0; m < 3; m++) { const mx = px + (m - 1) * .06, my = .76 - (m === 1 ? .03 : 0); if (((x - mx) / .035) ** 2 + ((y - my) / .028) ** 2 < 1) { o.t = 1; o.c = y < my - .01 ? 9 : 10; return; } } if ((pdx / .14) ** 2 + ((y - .8) / .02) ** 2 < 1) { o.t = 1; o.c = 5; return; } }
        if (y > .82) { o.t = 1; o.c = wrap(x, .06) < .006 ? 8 : y > .9 ? 6 : 5; return; }
      } },
    oasis: { pal: ['#fff8dc', '#f6d898', '#e6b866', '#c89040', '#2e7a4e', '#5ab070', '#7a5030', '#3ab8c8', '#a8e8f0', '#8a6040'], ink: '#8a6a40', inkA: .3,
      bg(g, w, h) { grad(g, w, h, [[0, '#f6d8a0'], [.5, '#fff0d4'], [1, '#f0d8a0']]); glow(g, w - h * .3, h * .2, h * .35, '#fffbe8d0'); },
      f(x, y, t, A, o, i, j) {
        if (y > .55 && y < .72) x += .004 * Math.sin(y * 90 + t * 4);
        for (let q = 0; q < OASIS_PALMS.length; q++) { const P = OASIS_PALMS[q], p = palm(x, y, P[0], P[1], P[2], P[3], t, P[4]); if (p) { o.t = 1; o.c = p === 1 ? 6 : p === 2 ? 4 : 5; return; } }
        if ((x - A * .18) ** 2 / .05 + (y - .85) ** 2 / .0012 < 1) { o.t = 1; o.c = Math.sin(x * 50 + t * 1.5) > .5 ? 8 : 7; return; }
        // A small caravan walking the far ridge
        for (let k = 0; k < 3; k++) { const cx = wrap(A - .1 - t * .006 - k * .07, A + .4) - .2, cy = .66, dx = x - cx, dy = y - cy; if ((dx / .022) ** 2 + (dy / .01) ** 2 < 1 || (Math.abs(dx) < .008 && dy < -.004 && dy > -.017) || (Math.abs(dx + .026) < .005 && dy < 0 && dy > -.022) || (Math.abs(dy - .016) < .008 && (Math.abs(dx - .012 + .004 * Math.sin(t * 3 + k)) < .003 || Math.abs(dx + .012 - .004 * Math.sin(t * 3 + k)) < .003))) { o.t = 1; o.c = 9; return; } }
        const far = .68 - .04 * Math.sin(x * 1.6 + 1) - .02 * noise(x * 4, 3), near = .88 - .05 * Math.sin(x * 2.4 + .3);
        if (y > near) { o.t = 1; o.c = Math.sin(x * 30 + y * 90) > .7 ? 3 : 2; return; }
        if (y > far) { o.t = 1; o.c = 1; return; }
        if (Math.hypot(x - (A - .3), y - .2) < .06) { o.t = 1; o.c = 0; return; }
      } },
    lavender: { pal: ['#b48ae0', '#8a5ac8', '#dcc4f2', '#6a9a4a', '#ffd86a', '#ffe9b0', '#f0c040', '#3a3a2a', '#5a4a7a'], ink: '#5a4a6a', inkA: .3,
      bg(g, w, h) { grad(g, w, h, [[0, '#ffd8c4'], [.45, '#ffe4d4'], [.56, '#f6d4e6'], [1, '#e8cce8']]); glow(g, w - h * .3, h * .52, h * .4, '#ffe9b0c0'); },
      pre(t, A) { for (let k = 0; k < 6; k++) { PX[k] = (k < 3 ? A * .15 : A * .85) + .08 * Math.sin(t * (.7 + .3 * k) + k); PY[k] = .66 + .1 * hash(k, 1) + .03 * Math.sin(t * (1.3 + .2 * k) + k * 2); } },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 6; k++) if (Math.abs(x - PX[k]) < o.cw * .6 && Math.abs(y - PY[k]) < o.ch * .5) { o.g = 15; o.c = Math.sin(t * 20 + k) > 0 ? 6 : 7; o.v = 1; return; }
        const H = .55;
        if (y > H) {
          const z = (y - H) / (1 - H), u = (x - A / 2) / (z + .02), f = wrap(u * 3, 1), sway = .04 * Math.sin(t * 1.2 + y * 12);
          if (Math.abs(f - .5 + sway) < .3) { if (z > .45 && hash(i, j) > .55) { o.g = hash(i, j) > .8 ? 20 : 16; o.c = 2; o.v = 1; return; } o.t = 1; o.c = noise(x * 20, y * 30) > .55 ? 1 : 0; return; }
          o.t = 1; o.c = 3; return;
        }
        { const tx = A * .18, dx = x - tx; if (y > H - .1 && y < H && Math.abs(dx) < .006) { o.t = 1; o.c = 8; return; } if ((dx / .06) ** 2 + ((y - H + .13) / .05) ** 2 < 1 && fbm(x * 18, y * 18) > .35) { o.t = 1; o.c = 8; return; } }
        if (Math.hypot(x - (A - .3), y - H) < .08) { o.t = 1; o.c = y > H - .03 ? 5 : 4; return; }
      } },
    windmills: { pal: ['#f6f6f4', '#ece4d4', '#c8b8a0', '#a85a3a', '#ff5a6a', '#ffd04a', '#ff8ad0', '#6ab04a', '#4a8a3a', '#8ab8e0'], ink: '#6a5a4a', inkA: .3,
      bg(g, w, h) { grad(g, w, h, [[0, '#aeb4bf'], [.55, '#d9dce2'], [1, '#eeede6']]); },
      f(x, y, t, A, o, i, j) {
        for (let w = 0; w < WINDMILL_TOWERS.length; w++) {
          const W = WINDMILL_TOWERS[w], px = W[0], base = W[1], h = W[2], cx = px < 0 ? A + px : px, top = base - h, dx = x - cx, hub = top - .015;
          if (onBlade(dx, y - hub, t * W[3], 4, h * .75, .018)) { const r = Math.hypot(dx, y - hub); o.t = wrap(r * 45, 1) > .35 ? 1 : 0; o.c = 0; o.v = .9; o.g = 4; return; }
          if (y > top && y < base) { const wd = h * (.12 + .1 * (y - top) / h); if (Math.abs(dx) < wd) { o.t = 1; o.c = dx > wd * .4 ? 2 : 1; if (Math.abs(dx) < wd * .25 && y > base - h * .2) o.c = 3; return; } }
          if (y > top - h * .1 && y <= top && Math.abs(dx) < h * .14 - (top - y) * 1.2) { o.t = 1; o.c = 3; return; }
        }
        if (y > .74) { const z = (y - .74) / .26, row = Math.floor(1 / (z + .1) * 2); if (Math.abs(y - .82 - .01 * Math.sin(x * 4)) < .008) { o.t = 1; o.c = 9; return; } o.t = 1; o.c = TULIP_BANDS[row % 6]; if (o.c !== 7 && o.c !== 8 && hash(i, j) > .7) { o.t = 0; o.g = 15; o.v = 1; } return; }
        if (y > .7 - .03 * Math.sin(x * 1.8)) { o.t = 1; o.c = 8; return; }
        for (let k = 0; k < 4; k++) { const s = .06 + .03 * hash(k, 3), cx = wrap(hash(k, 1) * A + t * .012, A + .4) - .2, cy = .1 + .3 * hash(k, 2); if (cumulus((x - cx) / s, (y - cy) / s, k + 3)) { o.t = 1; o.c = 0; return; } }
      } },
    island: { pal: ['#ffffff', '#3ac0d0', '#1a8ab0', '#f6e2a8', '#2a8a4a', '#5ab060', '#8a5a30', '#fff0a0', '#5a6a7a', '#7ad8e0'], ink: '#4a6a7a', inkA: .3,
      bg(g, w, h) { grad(g, w, h, [[0, '#7ccaf0'], [.57, '#c8ecf8'], [.58, '#5ad0dc'], [1, '#2aa0c0']]); glow(g, w - h * .3, h * .18, h * .3, '#fffbe0c0'); },
      pre(t, A) { for (let k = 0; k < 5; k++) { PX[k] = wrap(hash(k, 1) * A + t * (.02 + .02 * hash(k, 2)), A + .2) - .1; PY[k] = .15 + .25 * hash(k, 3) + .02 * Math.sin(t + k); PZ[k] = Math.sin(t * 5 + k * 2) > 0 ? 12 : 13; } },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 5; k++) if (Math.abs(x - PX[k]) < o.cw * .6 && Math.abs(y - PY[k]) < o.ch * .5) { o.g = PZ[k]; o.c = 8; o.v = 1; return; }
        for (let isl = 0; isl < 2; isl++) {
          const cx = isl ? A - .14 : A * .16, cy = isl ? .63 : .66, rx = isl ? .12 : .22, palms = cx < A / 2 ? ISLAND_PALMS_L : ISLAND_PALMS_R;
          for (let q = 0; q < palms.length; q++) { const P = palms[q], p = palm(x, y, cx + P[0], cy - .01, P[1], P[2], t, P[3]); if (p) { o.t = 1; o.c = p === 1 ? 6 : p === 2 ? 4 : 5; return; } }
          const u = (x - cx) / rx, v = (y - cy) / .04; if (u * u + v * v < 1 && v > -1) { o.t = 1; o.c = 3; return; }
          if (u * u + v * v < 1.6 && y > cy) { o.v = .6 + .3 * Math.sin(t * 2 + x * 30); o.c = 0; o.g = 14; return; }
        }
        if (y > .58) { const z = (y - .58) / .42; if (Math.sin(x * (20 / (z + .2)) + t * .8 + y * 60) > .85 - z * .1) { o.v = .4 + .4 * z; o.c = z > .5 ? 9 : 0; o.g = 14; } return; }
        if (Math.hypot(x - (A - .3), y - .18) < .05) { o.t = 1; o.c = 7; return; }
        { const m = noise(x * 1.6 - t * .01, y * 7); if (y < .45 && m > .72) { o.v = .55; o.c = 0; o.g = 3; } }
      } },
    opart: { pal: ['#121212', '#444444', '#e23a3a'], ink: '#f6f6f2', inkA: .15,
      bg(g, w, h) { grad(g, w, h, [[0, '#f7f7f3'], [1, '#efefea']]); },
      f(x, y, t, A, o, i, j) {
        // Two sets of rings slide past each other; their interference makes the moire.
        const d1 = Math.hypot(x - A * (.22 + .03 * Math.sin(t * .1)), y - .5), d2 = Math.hypot(x - A * (.78 - .03 * Math.sin(t * .1)), y - .5);
        if (d1 < .015 || d2 < .015) { o.t = 1; o.c = 2; return; }
        const s = Math.sin(d1 * 70 - t * .6) + Math.sin(d2 * 70 + t * .6);
        if (s > .9) { o.t = 1; o.c = 0; return; } if (s > .3) { o.v = .7; o.c = 1; }
      } },
    zen: { pal: ['#f6efe4', '#d8ccb8', '#8a8478', '#625c50', '#5a8a4a', '#7aa860', '#e8a0b0', '#c4b8a2'], ink: '#6a6050', inkA: .3,
      bg(g, w, h) { grad(g, w, h, [[0, '#f4ece0'], [1, '#ece2d2']]); },
      pre(t, A) { for (let k = 0; k < 12; k++) { PX[k] = wrap(hash(k, 1) * A + t * .012 + .03 * Math.sin(t * .6 + k), A + .1) - .05; PY[k] = wrap(hash(k, 2) + t * (.012 + .01 * hash(k, 3)), 1.1) - .05; PZ[k] = Math.floor(t * 1.5 + k) % 4; } },
      f(x, y, t, A, o, i, j) {
        for (let k = 0; k < 12; k++) if (Math.abs(x - PX[k]) < o.cw * .55 && Math.abs(y - PY[k]) < o.ch * .5) { o.g = [20, 21, 17, 18][PZ[k]]; o.c = 6; o.v = 1; return; }
        let dmin = 9;
        for (let z = 0; z < ZEN_STONES.length; z++) {
          const S = ZEN_STONES[z], cx = S[0], cy = S[1], r = S[2], X = cx < 0 ? A + cx : cx, d = Math.hypot(x - X, (y - cy) * 1.4) - r;
          if (d < 0) { o.t = 1; o.c = fbm(x * 14, y * 14) > .55 + (y - cy) * 4 ? (noise(x * 30, y * 30) > .5 ? 5 : 4) : (x - X > r * .2 ? 3 : 2); return; }
          dmin = Math.min(dmin, d);
        }
        // Raked sand: rings around each stone, straight furrows everywhere else.
        const s = dmin < .16 ? Math.sin(dmin * 80) : Math.sin(y * 95 + .5 * Math.sin(x * 2));
        if (s > .55) { o.v = .55; o.c = s > .85 ? 7 : 1; o.g = dmin < .16 ? 14 : 3; }
      } }
  };

  const cache = new WeakMap(), atlases = new Map(), MAX_ATLASES = 32, o = { v: 0, c: 0, t: 0, g: -1, cw: 0, ch: 0, e: 0, p: 0 }, ALPHA = [.45, .65, .85, 1], DIM = [.22, .5, .66, 1], TG = [2, 2, 7, 7, 9, 10, 1, 8];
  function atlasFor(id, sc, theme, aw, ah, glyphs = 'ascii') {
    const ch = GLYPHS[glyphs] || CH, key = id + '|' + glyphs + '|' + aw + '|' + ah;
    let a = atlases.get(key);
    if (a) { atlases.delete(key); atlases.set(key, a); return a; }
    if (atlases.size >= MAX_ATLASES) atlases.delete(atlases.keys().next().value);
    a = document.createElement('canvas'); a.width = ch.length * aw; a.height = (sc.pal.length + 1) * ah;
    const g = a.getContext('2d'); g.font = `${Math.max(4, Math.round(ah * .74))}px "SF Mono", Menlo, Monaco, Consolas, "Cascadia Mono", monospace`; g.textAlign = 'center'; g.textBaseline = 'middle';
    [...sc.pal, sc.ink || theme.glyph].forEach((color, r) => { g.fillStyle = color; for (let c = 1; c < ch.length; c++) g.fillText(ch[c], c * aw + aw / 2, r * ah + ah * .54); });
    atlases.set(key, a); return a;
  }
  function background(w, h, theme, sc, k, cw, ch) {
    const c = document.createElement('canvas'); c.width = Math.ceil(w * k); c.height = Math.ceil(h * k);
    const g = c.getContext('2d'); g.scale(k, k);
    if (sc.bg) sc.bg(g, w, h, theme); else grad(g, w, h, [[0, theme.sky], [1, theme.floor]]);
    // Side light bands from the reference, then its faint character grid, stronger toward the edges.
    const beam = (x, bw, a) => { const b = g.createLinearGradient(x, 0, x + bw, 0), hex = Math.round(a * 255).toString(16).padStart(2, '0'); b.addColorStop(0, theme.beam + '00'); b.addColorStop(.4, theme.beam + hex); b.addColorStop(.6, theme.beam + hex); b.addColorStop(1, theme.beam + '00'); g.fillStyle = b; g.fillRect(x, 0, bw, h); };
    const a = theme.light ? .3 : .16; beam(-w * .1, w * .28, a); beam(w * .82, w * .28, a);
    if (ch >= 8) {
      g.strokeStyle = theme.light ? '#ffffff' : theme.beam; g.lineWidth = 1 / k;
      for (let x = 0; x < w; x += cw) { g.globalAlpha = .025 + .06 * Math.min(1, Math.abs(x - w / 2) / (w / 2)) ** 2; g.beginPath(); g.moveTo(x, 0); g.lineTo(x, h); g.stroke(); }
      g.globalAlpha = .022; for (let y = 0; y < h; y += ch) { g.beginPath(); g.moveTo(0, y); g.lineTo(w, y); g.stroke(); }
    }
    return c;
  }
  // Cells are whole device pixels and live on a persistent layer; only cells whose glyph, colour or tile changed are repainted.
  // calm: optional {l, r} in CSS px, the live conversation column; without it the centre third is kept calm.
  // fx: optional {energy, pulse} in 0..1. energy brightens the character field while agents run; pulse drives a
  // ripple that spreads out from the composer when an agent finishes.
  return function draw(ctx, width, height, theme, seconds, strength = 1, calm, fx) {
    if (!(width > 0 && height > 0)) return;
    const glyphs = fx?.glyphs && GLYPHS[fx.glyphs] ? fx.glyphs : 'ascii';
    const sc = SCENES[theme.id] || SCENES.clouds, k = ctx.getTransform().a || 1, base = height > 220 ? (SCALES[fx?.scale] || 14) : Math.max(3.5, height / 24);
    const ah = Math.max(3, Math.round(base * k)), aw = Math.max(2, Math.round(base * .66 * k)), cw = aw / k, ch = ah / k;
    const cols = Math.ceil(width / cw), rows = Math.ceil(height / ch), n = cols * rows, A = width / height, half = A / 2, gap = aw >= 6 ? 1 : 0;
    let st = cache.get(ctx); if (!st) { st = {}; cache.set(ctx, st); }
    const key = width + '|' + height + '|' + theme.id + '|' + k + '|' + glyphs + '|' + base;
    if (st.key !== key) {
      st.key = key; st.frameKey = ''; st.bg = background(width, height, theme, sc, k, cw, ch); st.K = new Int32Array(n).fill(-1); st.V = new Float32Array(n); st.C = new Uint8Array(n); st.T = new Uint8Array(n); st.G = new Int8Array(n);
      st.layer = st.layer || document.createElement('canvas'); st.layer.width = cols * aw; st.layer.height = rows * ah; st.lg = st.layer.getContext('2d'); st.atlas = atlasFor(theme.id, sc, theme, aw, ah, glyphs);
    }
    const frameKey = seconds + '|' + (calm ? calm.l + ',' + calm.r + ',' + (calm.t ?? '') : '') + '|' + (fx?.energy || 0) + '|' + (fx?.pulse || 0);
    if (st.frameKey !== frameKey) {
      st.frameKey = frameKey;
      const K = st.K, lg = st.lg, atlas = st.atlas, pal = sc.pal, inkRow = pal.length, phase = Math.floor(seconds * 2.2);
      o.cw = cw / height; o.ch = ch / height; o.e = fx?.energy || 0; o.p = fx?.pulse || 0; sc.pre?.(seconds, A, o);
      const cl = calm ? calm.l / height : -1, cr = calm ? calm.r / height : -1;
      const topH = calm?.t != null ? (calm.t / height) : (height > 220 ? 38 / height : 0);
      const glowUp = 1 + .35 * (fx?.energy || 0), fp = fx?.pulse || 0, rx = cl >= 0 && cr > cl ? (cl + cr) / 2 : half, ry = .92;
      const rr = (1 - fp * fp) * Math.hypot(Math.max(rx, A - rx), ry) * 1.05, band = .07, amp = .45 + .75 * fp;
      const V = st.V, C = st.C, T = st.T, G = st.G;
      // Pass 1: ask the scene for every cell, so pass 2 can compare neighbours.
      for (let j = 0, p = 0; j < rows; j++) {
        const y = (j + .5) * ch / height;
        for (let i = 0; i < cols; i++, p++) {
          const x = (i + .5) * cw / height;
          o.v = 0; o.c = 0; o.t = 0; o.g = -1; sc.f(x, y, seconds, A, o, i, j);
          // Finish ripple: a bright ring with a fainter echo behind it, drawn over everything except solid subjects.
          if (fp > 0 && !o.t) {
            const d = Math.hypot(x - rx, y - ry), q = Math.max(1 - Math.abs(d - rr) / band, .55 * (1 - Math.abs(d - rr * .72) / band));
            if (q > 0) { const rv = q * amp; if (rv > o.v) { if (o.v < .06) o.c = 0; o.v = rv; o.g = -1; } }
          }
          V[p] = o.v; C[p] = o.c; T[p] = o.t ? 1 : 0; G[p] = o.g;
        }
      }
      // What a cell shows, for outline purposes: a solid colour, a bright glyph colour, or nothing.
      const cls = q => T[q] ? C[q] : V[q] * glowUp > .3 ? 32 + C[q] : -1;
      // Pass 2: outside the chat column draw normally; behind it the scene becomes a line sketch of the same shapes.
      for (let j = 0, p = 0; j < rows; j++) {
        const y = (j + .5) * ch / height;
        const ey = topH > 0 ? sm(0, .035, y - topH) : 1;
        for (let i = 0; i < cols; i++, p++) {
          const x = (i + .5) * cw / height;
          const ex = cl < 0 ? sm(A * .17, A * .33, Math.abs(x - half)) : sm(-.01, .1, Math.max(cl - x, x - cr));
          // Dithered handover, so the picture breaks up into the sketch rather than ending at a line.
          const sketch = ex < 1 && hash(i * 7 + 3, j * 11 + 5) >= ex;
          let tile = T[p], c = C[p], g = 0, b = 3, dl = 3;
          if (sketch) {
            tile = 0; const me = cls(p);
            if (me >= 0) {
              const up = j > 0 && cls(p - cols) !== me, dn = j < rows - 1 && cls(p + cols) !== me, lf = i > 0 && cls(p - 1) !== me, rt = i < cols - 1 && cls(p + 1) !== me;
              c = me & 31;
              const sides = up + dn + lf + rt;
              // Cells exposed on three or four sides are specks too small to outline: keep them as a dot.
              if (sides > 2) { g = 1; dl = 1; }
              else if (sides) { g = (up && lf) || (dn && rt) ? 17 : (up && rt) || (dn && lf) ? 18 : up || dn ? 3 : 16; dl = 1; }
              // Insides of solid shapes get a sparse stipple so fills still read.
              else if (me < 32 && (i + 2 * j) % 4 === 0) { g = 1; b = 2; dl = 0; }
            }
            if (ey < 1 && hash(i, j * 3) > ey) g = 0;
          } else {
            // Solid subjects thin out into a dither where they dissolve into the titlebar.
            if (tile && hash(i * 3 + 1, j * 5 + 2) > ey * 1.8) { tile = 0; V[p] = .5; G[p] = hash(i, j) > .45 ? 2 : 1; }
            if (tile) g = G[p] >= 0 ? G[p] : TG[Math.floor(hash(i + (hash(i, j + phase * 31) > .88 ? phase : 0), j) * TG.length)];
            else { const v = V[p] * glowUp * ey; g = v < .06 ? 0 : G[p] >= 0 ? (v > .12 ? G[p] : 0) : Math.min(11, 1 + Math.floor(v * 11)); b = v > .7 ? 3 : v > .45 ? 2 : v > .25 ? 1 : 0; }
          }
          if (ey <= 0) { g = 0; tile = 0; }
          const shade = tile && ((p * 2654435761) >>> 0) % 3 === 0 ? 1 : 0;
          const kk = g ? g | c << 5 | tile << 9 | b << 10 | shade << 12 | dl << 13 : 0;
          if (kk === K[p]) continue; K[p] = kk;
          const X = i * aw, Y = j * ah, D = DIM[dl]; lg.clearRect(X, Y, aw, ah); if (!g) continue;
          if (tile) { lg.globalAlpha = shade ? .78 : .94; lg.fillStyle = pal[c]; lg.fillRect(X + gap, Y + gap, aw - gap, ah - gap); lg.globalAlpha = sc.inkA || .5; lg.drawImage(atlas, g * aw, inkRow * ah, aw, ah, X, Y, aw, ah); }
          else { lg.globalAlpha = ALPHA[b] * D; lg.drawImage(atlas, g * aw, c * ah, aw, ah, X, Y, aw, ah); }
        }
      }
    }
    ctx.save(); ctx.globalAlpha = 1; ctx.drawImage(st.bg, 0, 0, width, height);
    ctx.globalAlpha = strength; ctx.drawImage(st.layer, 0, 0, cols * cw, rows * ch); ctx.restore();
  };
})();
