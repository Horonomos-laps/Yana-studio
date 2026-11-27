// Mỗi tên theme mà Settings ghi vào workbench.colorTheme phải là id của một theme có thật.
// VS Code chọn theme theo id, nên ghi nhãn hiển thị (khác id) thì nút bấm không có tác dụng.
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const ide = path.join(__dirname, '..');
const read = relative => fs.readFileSync(path.join(ide, relative), 'utf8');
const ids = new Set(JSON.parse(read('extensions/yana-theme/package.json')).contributes.themes.map(theme => theme.id));

const settings = read('extensions/yana-agent/features/settings.js');
const written = [...settings.matchAll(/update\('colorTheme', '([^']+)'/g)].map(match => match[1]);
assert.ok(written.length >= 3, 'expected the theme buttons in features/settings.js');
for (const name of written) assert.ok(ids.has(name), `settings.js writes '${name}', which is not a theme id`);
console.log('PASS every theme button writes an existing theme id');

const page = read('extensions/yana-agent/media/settings-tabs.js');
const listed = page.match(/const YANA_THEMES = \[([^\]]+)\]/)[1].match(/'[^']+'/g).map(name => name.slice(1, -1));
const compared = [...page.matchAll(/data\.colorTheme === '([^']+)'/g)].map(match => match[1]);
assert.ok(compared.length >= 3, 'expected the active-state checks in settings-tabs.js');
for (const name of [...listed, ...compared]) assert.ok(ids.has(name), `settings-tabs.js compares '${name}', which is not a theme id`);
console.log('PASS the appearance tab marks the active theme by id');
assert.ok(!ids.has('Yana Web') && !`${settings}${page}`.includes('Yana Web'), 'the Yana Web theme was removed');
console.log('PASS the removed web theme is gone from settings and the theme pack');
console.log('theme-names: 3 PASS');
