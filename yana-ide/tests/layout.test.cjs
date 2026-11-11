// Paths that tie yana-ide, yana-studio and the DMG script to this repository's layout must resolve.
//
// These directories used to sit under tools/ in Yana-AI. A script that still says tools/yana-ide
// only fails when someone runs it (make-dmg-background.swift did), and a vite config that reaches
// into ../../yana-studio only fails when the build runs. This test reads the paths and checks them.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const REPO_ROOT = path.resolve(__dirname, "../..");
const DMG_SCRIPT = path.join(REPO_ROOT, "yana-ide/scripts/make-dmg-background.swift");
const STUDIO_WEB = path.join(REPO_ROOT, "yana-ide/studio-web");
const STALE_PREFIX = "tools/yana-";

const read = file => fs.readFileSync(file, "utf8");

test("the three top-level directories the build scripts rely on exist", () => {
  for (const directory of ["yana-ide", "yana-studio", "yana-app"]) {
    assert.ok(fs.statSync(path.join(REPO_ROOT, directory)).isDirectory(), `${directory} is missing`);
  }
});

test("the DMG script reads the emblem from a file that exists", () => {
  const match = read(DMG_SCRIPT).match(/let svgPath = "([^"]+)"/);
  assert.ok(match, "svgPath not found in make-dmg-background.swift");
  assert.ok(fs.existsSync(path.join(REPO_ROOT, match[1])), `emblem not found at ${match[1]}`);
});

test("the DMG script writes into directories that exist", () => {
  const outputs = [...read(DMG_SCRIPT).matchAll(/\("([^"]+\.(?:png|tiff))",/g)].map(match => match[1]);
  assert.ok(outputs.length >= 5, `expected at least 5 output paths, found ${outputs.length}`);
  for (const output of outputs) {
    const directory = path.dirname(path.join(REPO_ROOT, output));
    assert.ok(fs.existsSync(directory), `output directory missing for ${output}`);
  }
});

test("the DMG script does not mention the old tools/ layout", () => {
  assert.ok(!read(DMG_SCRIPT).includes(STALE_PREFIX), "make-dmg-background.swift still uses tools/yana-*");
});

test("the studio-web vite configs reach yana-studio through a path that exists", () => {
  const configs = fs.readdirSync(STUDIO_WEB).filter(name => /^vite.*\.mjs$/.test(name));
  assert.ok(configs.length >= 2, "expected the vite config files in yana-ide/studio-web");
  for (const name of configs) {
    const text = read(path.join(STUDIO_WEB, name));
    if (!text.includes("../../yana-studio/")) continue;
    assert.ok(
      fs.existsSync(path.resolve(STUDIO_WEB, "../../yana-studio/package.json")),
      `${name} imports from ../../yana-studio but that directory has no package.json`,
    );
  }
});
