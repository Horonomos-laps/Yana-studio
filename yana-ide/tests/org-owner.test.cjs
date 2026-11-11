// The GitHub owner in repository URLs must be the same everywhere and must not be the old account.
//
// The repositories moved from the yanacuti1121 account to the Horonomos-laps organization. The app
// update check, the IDE update check, the settings links and the Yana-AI checkout in the desktop
// workflow each repeat the owner, so one missed copy sends users or CI to the wrong place.
// Only URLs that name one of our own repositories are checked, so links to other projects are fine.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const REPO_ROOT = path.resolve(__dirname, "../..");
const OWNER = "horonomos-laps";
const OLD_OWNER = "yanacuti1121";
const OUR_REPOSITORIES = ["yana-ai", "yana-web", "yana-studio"];
const SKIP_DIRECTORIES = new Set([".git", "node_modules", "target", "dist", "build", "vendor"]);
// The js-tests workflow checks Yana-AI out into ./yana-ai for the parity tests. That is another
// repository's content, so it must not count as this repository's URLs.
const YANA_AI_CHECKOUT = path.join(REPO_ROOT, "yana-ai");
const BINARY_SUFFIXES = new Set([".png", ".jpg", ".jpeg", ".gif", ".ico", ".icns", ".zip", ".woff", ".woff2", ".node", ".lock"]);
const MAX_FILE_BYTES = 2 * 1024 * 1024;
const MIN_FILES = 100; // a Studio checkout holds several hundred files; fewer means REPO_ROOT is wrong

const OWNER_PATTERNS = [
  /github\.com\/([A-Za-z0-9-]+)\/([A-Za-z0-9._-]+)/g,
  /api\.github\.com\/repos\/([A-Za-z0-9-]+)\/([A-Za-z0-9._-]+)/g,
  /repository:\s*([A-Za-z0-9-]+)\/([A-Za-z0-9._-]+)/g,
];

function textFiles(directory, found = []) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (SKIP_DIRECTORIES.has(entry.name)) continue;
    const full = path.join(directory, entry.name);
    if (full === YANA_AI_CHECKOUT) continue;
    if (entry.isDirectory()) {
      textFiles(full, found);
    } else if (
      entry.isFile() &&
      !BINARY_SUFFIXES.has(path.extname(entry.name)) &&
      fs.statSync(full).size <= MAX_FILE_BYTES
    ) {
      found.push(full);
    }
  }
  return found;
}

function ownersOfOurRepositories() {
  const owners = new Map(); // owner -> list of files
  for (const file of textFiles(REPO_ROOT)) {
    const text = fs.readFileSync(file, "utf8");
    for (const pattern of OWNER_PATTERNS) {
      for (const match of text.matchAll(pattern)) {
        const repository = match[2].replace(/\.git$/, "").toLowerCase();
        if (!OUR_REPOSITORIES.includes(repository)) continue;
        const owner = match[1].toLowerCase();
        owners.set(owner, [...(owners.get(owner) || []), path.relative(REPO_ROOT, file)]);
      }
    }
  }
  return owners;
}

test("the checkout is large enough for the scan to mean something", () => {
  assert.ok(textFiles(REPO_ROOT).length > MIN_FILES);
});

test("the old owner does not appear in any URL for our repositories", () => {
  const files = [...new Set(ownersOfOurRepositories().get(OLD_OWNER) || [])];
  assert.deepEqual(files, [], `files still using ${OLD_OWNER}:\n${files.join("\n")}`);
});

test("every URL for our repositories names the same owner", () => {
  const owners = [...ownersOfOurRepositories().keys()];
  assert.deepEqual(owners, [OWNER], `owners found: ${owners.join(", ")}`);
});

test("the desktop workflow checks Yana-AI out from the same owner", () => {
  const workflow = fs.readFileSync(path.join(REPO_ROOT, ".github/workflows/yana-studio-desktop.yml"), "utf8");
  assert.match(workflow, /repository:\s*Horonomos-laps\/Yana-AI/);
});

test("the app update check and its settings link point at the Studio releases", () => {
  const updater = fs.readFileSync(path.join(REPO_ROOT, "yana-app/Sources/YanaApp/AppUpdater.swift"), "utf8");
  const settings = fs.readFileSync(path.join(REPO_ROOT, "yana-app/Sources/YanaApp/SettingsSections.swift"), "utf8");
  assert.match(updater, /api\.github\.com\/repos\/Horonomos-laps\/Yana-studio\/releases/);
  assert.match(settings, /github\.com\/Horonomos-laps\/Yana-studio\/releases/);
});
