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
'use strict';
// Danh sách hình nền cho trang Yana Settings. Test so khớp với workbench/yanaWallpaper/browser/themes.ts.
const WALLPAPERS = Object.freeze([
	{ id: 'clouds', name: 'Cloud Drift', light: true, sky:'#b4d9ee',floor:'#cceaf8',beam:'#62b9f1',chrome:'#b7e1f3',panel:'#f1faff',card:'#f0faff',fg:'#203645',muted:'#476475',border:'#9bbdce',accent:'#367ca6',ink:'#fffef7',glyph:'#648798' },
	{ id: 'aurora', name: 'Aurora', light: false, sky:'#061220',floor:'#0d2233',beam:'#1f6b62',chrome:'#0a1724',panel:'#0b1826',card:'#16283a',fg:'#e9f4f2',muted:'#a9c4c4',border:'#35506a',accent:'#7cf2b4',ink:'#7cf2b4',glyph:'#10202e' },
	{ id: 'lagoon', name: 'Honu Lagoon', light: false, sky:'#286f70',floor:'#084d63',beam:'#45e0d9',chrome:'#1d6666',panel:'#103c45',card:'#225560',fg:'#effaf6',muted:'#bfdfdb',border:'#49868a',accent:'#a2e2c2',ink:'#e3dcaa',glyph:'#375957' },
	{ id: 'koi', name: 'Koi Pond', light: false, sky:'#315c4f',floor:'#1c493e',beam:'#8ce2bd',chrome:'#2d584b',panel:'#193d34',card:'#315b4e',fg:'#f0f7e9',muted:'#c2d8c3',border:'#638c71',accent:'#dfc890',ink:'#ead0a1',glyph:'#475e39' },
	{ id: 'jelly', name: 'Jellyfish', light: false, sky:'#0c2e3e',floor:'#07111f',beam:'#286db0',chrome:'#0b2c3e',panel:'#0b1520',card:'#172b39',fg:'#edf1f7',muted:'#b6c6d6',border:'#42566e',accent:'#e8a7d0',ink:'#bca5d2',glyph:'#2d3148' },
	{ id: 'boats', name: 'Paper Boats', light: true, sky:'#badbd5',floor:'#d4e8df',beam:'#7ebdc1',chrome:'#c4dfd8',panel:'#f2faf5',card:'#f0f8f3',fg:'#263f3b',muted:'#49665e',border:'#a0bdb2',accent:'#3e7a71',ink:'#fffef2',glyph:'#69887c' },
	{ id: 'sakura', name: 'Sakura', light: true, sky:'#f6dfe7',floor:'#fbeef2',beam:'#f3b8cc',chrome:'#f4dbe4',panel:'#fff7fa',card:'#fff4f7',fg:'#4a2d38',muted:'#7a5866',border:'#e2b8c7',accent:'#c2557d',ink:'#ffffff',glyph:'#a1576f' },
	{ id: 'fireflies', name: 'Fireflies', light: false, sky:'#071a17',floor:'#102b21',beam:'#1b493a',chrome:'#0a1c17',panel:'#0b1b15',card:'#172c22',fg:'#f0f2df',muted:'#b9c8ad',border:'#425e48',accent:'#d5e59d',ink:'#d6df9c',glyph:'#374c2c' },
	{ id: 'moon', name: 'Moonlit', light: false, sky:'#090c1a',floor:'#1e2c60',beam:'#263f91',chrome:'#101528',panel:'#0d1224',card:'#1e263c',fg:'#edf0fa',muted:'#bdc6df',border:'#465375',accent:'#ddd8ad',ink:'#8b9bc8',glyph:'#212943' },
	{ id: 'dunes', name: 'Ember Dunes', light: false, sky:'#2b1534',floor:'#8a4a32',beam:'#c86a3e',chrome:'#231228',panel:'#1f1024',card:'#352032',fg:'#fbeadb',muted:'#d8b8a4',border:'#6a4352',accent:'#ffb46b',ink:'#ffd9a8',glyph:'#3a1f22' },
	{ id: 'rain', name: 'Night Rain', light: false, sky:'#0a1120',floor:'#141d31',beam:'#24365a',chrome:'#0c1322',panel:'#0d1424',card:'#1a2438',fg:'#e8eef8',muted:'#aebbd2',border:'#3a4a68',accent:'#ffd27a',ink:'#8fb4e6',glyph:'#0d1526' },
	{ id: 'snow', name: 'Snowfall', light: true, sky:'#c7d9e8',floor:'#eef4f9',beam:'#ffffff',chrome:'#d6e4ef',panel:'#f6fafd',card:'#f3f8fc',fg:'#1f3242',muted:'#4b6275',border:'#a9bfd0',accent:'#3a6f96',ink:'#ffffff',glyph:'#5e7d94' },
	{ id: 'lanterns', name: 'Sky Lanterns', light: false, sky:'#0b1030',floor:'#141a40',beam:'#3a3470',chrome:'#0c1028',panel:'#0d1230',card:'#1b2146',fg:'#f4eee4',muted:'#c2bccf',border:'#3d4170',accent:'#ffb35c',ink:'#ffcf8a',glyph:'#1c1a3a' },
	{ id: 'meadow', name: 'Windy Meadow', light: true, sky:'#cfe9f3',floor:'#dcefd0',beam:'#9fd38a',chrome:'#d4ebde',panel:'#f6fbf2',card:'#f3f9ee',fg:'#213a24',muted:'#4b6a4c',border:'#a9c9a0',accent:'#3f7f3a',ink:'#ffffff',glyph:'#5e8a52' },
	{ id: 'galaxy', name: 'Spiral Galaxy', light: false, sky:'#06051a',floor:'#0e0a26',beam:'#3a2a7a',chrome:'#09071c',panel:'#0a081e',card:'#181436',fg:'#eeeaff',muted:'#b8b0d8',border:'#3c3570',accent:'#b9a3ff',ink:'#cbbcff',glyph:'#141030' },
	{ id: 'bamboo', name: 'Bamboo Grove', light: true, sky:'#dcebdc',floor:'#e8f1e0',beam:'#b5d6a5',chrome:'#dbe9d6',panel:'#f6faf2',card:'#f2f8ee',fg:'#1f3520',muted:'#4d6a4a',border:'#a7c4a0',accent:'#3e7a36',ink:'#f4fbef',glyph:'#5f8754' },
	{ id: 'code', name: 'Digital Rain', light: false, sky:'#020b06',floor:'#04140b',beam:'#0f5a2a',chrome:'#030d07',panel:'#04110a',card:'#0c2214',fg:'#d9ffe4',muted:'#8fc9a2',border:'#1f5a34',accent:'#5dff8a',ink:'#5dff8a',glyph:'#062a12' },
	{ id: 'tide', name: 'Morning Tide', light: true, sky:'#fbe2d0',floor:'#cfe6ea',beam:'#ffd2b0',chrome:'#f5e0d4',panel:'#fffaf6',card:'#fdf6f0',fg:'#2a3440',muted:'#5a6670',border:'#d9c3b5',accent:'#2f7f95',ink:'#ffffff',glyph:'#7a8f99' },
	{ id: 'autumn', name: 'Autumn Leaves', light: true, sky:'#f6e3c8',floor:'#efd3b0',beam:'#f0b070',chrome:'#f2dcc0',panel:'#fff8ef',card:'#fdf3e6',fg:'#3a2416',muted:'#6e5040',border:'#ddb994',accent:'#c0502a',ink:'#fff6e8',glyph:'#9a6040' },
	{ id: 'alpine', name: 'Alpine Dawn', light: true, sky:'#d6cfee',floor:'#f8e2d4',beam:'#f3c9c6',chrome:'#e2d9f0',panel:'#fbf8ff',card:'#f7f3fd',fg:'#2a2545',muted:'#5a5478',border:'#c4b9de',accent:'#6a5aa8',ink:'#ffffff',glyph:'#8a80b4' },
	{ id: 'retro', name: 'Retro Sunset', light: false, sky:'#0d0221',floor:'#1a0630',beam:'#7a1f8a',chrome:'#10032a',panel:'#10042a',card:'#22104a',fg:'#fbeaff',muted:'#d0b4e0',border:'#5a2a7a',accent:'#ff5ad8',ink:'#ff7ad8',glyph:'#2a0a3a' },
	{ id: 'lava', name: 'Lava Lamp', light: false, sky:'#1a0726',floor:'#3a0d22',beam:'#8a2a3a',chrome:'#16061e',panel:'#170620',card:'#2c1230',fg:'#ffeede',muted:'#d8b4b4',border:'#5e2a44',accent:'#ff9a3c',ink:'#ffb070',glyph:'#2a0a18' },
	{ id: 'catnap', name: 'Starry Catnap', light: false, sky:'#070a24',floor:'#1a1a50',beam:'#4b3fb0',chrome:'#0a0c28',panel:'#0b0e2a',card:'#1b1e44',fg:'#f1eeff',muted:'#bfbcdc',border:'#3f4078',accent:'#f0a95e',ink:'#ffc88a',glyph:'#1b1f4a' },
	{ id: 'supercell', name: 'Supercell', light: false, sky:'#262a18',floor:'#3a3820',beam:'#8a8a4a',chrome:'#22261a',panel:'#262a1c',card:'#363a26',fg:'#f6f4dc',muted:'#c8c6a0',border:'#5a5e3a',accent:'#ecd070',ink:'#f4f0b0',glyph:'#383c22' },
	{ id: 'vents', name: 'Black Smokers', light: false, sky:'#040303',floor:'#140a08',beam:'#6a2a14',chrome:'#080505',panel:'#0a0706',card:'#1a1412',fg:'#fff2e6',muted:'#c8b4a8',border:'#3a2a24',accent:'#ff8a3a',ink:'#ffb040',glyph:'#1e1614' },
	{ id: 'candles', name: 'Candlelight', light: false, sky:'#120804',floor:'#2e1a0c',beam:'#6a4018',chrome:'#140a05',panel:'#170c06',card:'#2a1a0e',fg:'#fff4e0',muted:'#d4bc98',border:'#4e3418',accent:'#ffc878',ink:'#ffd474',glyph:'#2a1a0e' },
	{ id: 'neon', name: 'Neon Alley', light: false, sky:'#05030c',floor:'#120a20',beam:'#6a2aa0',chrome:'#08050f',panel:'#0a0614',card:'#1a1230',fg:'#f6eeff',muted:'#c4b4e0',border:'#44306e',accent:'#ff3fbf',ink:'#3ff0ff',glyph:'#150d24' },
	{ id: 'blackhole', name: 'Black Hole', light: false, sky:'#04020a',floor:'#0a0614',beam:'#5a2a4a',chrome:'#06040c',panel:'#080610',card:'#18121e',fg:'#fff4e8',muted:'#cdb8b0',border:'#3e2a3a',accent:'#ffc46a',ink:'#ffc46a',glyph:'#120a12' },
	{ id: 'volcano', name: 'Volcano', light: false, sky:'#0c0610',floor:'#2a0e10',beam:'#8a2a1a',chrome:'#100810',panel:'#120a12',card:'#261418',fg:'#ffeee2',muted:'#d4b4a8',border:'#5a2e2a',accent:'#ffa040',ink:'#ffa040',glyph:'#1e0e10' },
	{ id: 'starry', name: 'Swirling Night', light: false, sky:'#10245e',floor:'#0c1838',beam:'#24458e',chrome:'#0e1e4a',panel:'#10204e',card:'#1c3266',fg:'#f6f4e0',muted:'#bccae8',border:'#3a5aa0',accent:'#ffd84a',ink:'#ffd84a',glyph:'#24458e' },
	{ id: 'radar', name: 'Radar Scope', light: false, sky:'#0c0702',floor:'#160c03',beam:'#6a4612',chrome:'#0e0803',panel:'#110a04',card:'#22160a',fg:'#fff2c4',muted:'#d4b880',border:'#4a3210',accent:'#ffc24a',ink:'#ffc24a',glyph:'#2e1e08' },
	{ id: 'saturn', name: 'Ice Giant', light: false, sky:'#020a12',floor:'#05182a',beam:'#145a7a',chrome:'#030c16',panel:'#04101c',card:'#0e2030',fg:'#effdff',muted:'#a8d4e2',border:'#1e4a62',accent:'#6cd0e6',ink:'#b4f0fa',glyph:'#0e2a3e' },
	{ id: 'kelp', name: 'Kelp Forest', light: false, sky:'#2a6e9e',floor:'#061c3a',beam:'#14385a',chrome:'#0a2440',panel:'#0c2846',card:'#163a5c',fg:'#eef6ff',muted:'#a8c4dc',border:'#2e5478',accent:'#f0cc64',ink:'#d4a83c',glyph:'#14385a' },
	{ id: 'glitch', name: 'Signal Glitch', light: false, sky:'#050508',floor:'#0a0a12',beam:'#34344a',chrome:'#07070c',panel:'#09090e',card:'#18181f',fg:'#ffffff',muted:'#b4b4c8',border:'#34344a',accent:'#ff2a6a',ink:'#2af0ff',glyph:'#20202e' },
	{ id: 'peacock', name: 'Peacock Feathers', light: false, sky:'#04100e',floor:'#081e1c',beam:'#14806e',chrome:'#06120f',panel:'#071613',card:'#102a26',fg:'#eefff6',muted:'#a4d4c4',border:'#1e5048',accent:'#f4d860',ink:'#38d0bc',glyph:'#0e3430' },
	{ id: 'blueprint', name: 'Blueprint', light: false, sky:'#0f3c8c',floor:'#0a2c6c',beam:'#5a86d0',chrome:'#0d3478',panel:'#0e387e',card:'#1a4892',fg:'#ffffff',muted:'#cfe2ff',border:'#5a86d0',accent:'#ffd84a',ink:'#cfe2ff',glyph:'#2a5aa8' },
	{ id: 'stainedglass', name: 'Stained Glass', light: false, sky:'#1e1814',floor:'#2a221c',beam:'#5a4c44',chrome:'#1a1511',panel:'#1e1814',card:'#2e2620',fg:'#fff4d0',muted:'#d4c4a8',border:'#4a3e34',accent:'#f0b02a',ink:'#f0b02a',glyph:'#3a302c' },
	{ id: 'inkwash', name: 'Ink Wash', light: true, sky:'#f3eee2',floor:'#e9e2d2',beam:'#d8d2c4',chrome:'#ece6d8',panel:'#faf8f2',card:'#f3efe4',fg:'#1e1e1e',muted:'#5a5a58',border:'#cfc8b8',accent:'#c4302a',ink:'#ffffff',glyph:'#8e8e8e' },
	{ id: 'glacier', name: 'Ice Cave', light: true, sky:'#d8ecf8',floor:'#cfe6f0',beam:'#aee0f6',chrome:'#d4eaf4',panel:'#f4fbff',card:'#eaf6fc',fg:'#123a54',muted:'#3e6680',border:'#9ccbe2',accent:'#1e88c8',ink:'#ffffff',glyph:'#5a8aa8' },
	{ id: 'balloons', name: 'Hot Air Balloons', light: true, sky:'#f2c4dc',floor:'#eef4dc',beam:'#ffe2ee',chrome:'#f2dce6',panel:'#fffaf8',card:'#fdf2f4',fg:'#3a2a32',muted:'#6e5a64',border:'#e0c4d0',accent:'#e0508a',ink:'#ffffff',glyph:'#a07888' },
	{ id: 'reef', name: 'Coral Reef', light: true, sky:'#6ad4e6',floor:'#c4eeee',beam:'#a8f0f4',chrome:'#bfe8ee',panel:'#f2fcfc',card:'#eaf8f8',fg:'#1e3a44',muted:'#486a74',border:'#9ccad2',accent:'#e0506a',ink:'#ffffff',glyph:'#5a8a94' },
	{ id: 'popart', name: 'Pop Art', light: true, sky:'#fff4d4',floor:'#ffeec4',beam:'#ffe02a',chrome:'#fff0c8',panel:'#fffbec',card:'#fff6dc',fg:'#111111',muted:'#4a4a4a',border:'#111111',accent:'#ff2a2a',ink:'#ffffff',glyph:'#2a64ff' },
	{ id: 'cranes', name: 'Paper Cranes', light: true, sky:'#e6ddf0',floor:'#fbf3e6',beam:'#f4c8d4',chrome:'#ece4ee',panel:'#fdfaff',card:'#f8f2f8',fg:'#3a2e3e',muted:'#6a5a6e',border:'#d4c4d8',accent:'#c8506e',ink:'#ffffff',glyph:'#8a7a8e' },
	{ id: 'tea', name: 'Matcha', light: true, sky:'#f4f0e2',floor:'#e6dcc4',beam:'#c4dc84',chrome:'#ece6d4',panel:'#fbf9f0',card:'#f4efe0',fg:'#24201c',muted:'#5e5446',border:'#d4c8a8',accent:'#6e9a2e',ink:'#ffffff',glyph:'#8a7a5a' },
	{ id: 'oasis', name: 'Desert Oasis', light: true, sky:'#f6d8a0',floor:'#f0d8a0',beam:'#ffe6b0',chrome:'#f2e0bc',panel:'#fffaee',card:'#fcf2de',fg:'#3a2c1a',muted:'#6e5a3e',border:'#dcc49a',accent:'#2e8a6a',ink:'#ffffff',glyph:'#9a8058' },
	{ id: 'lavender', name: 'Lavender Fields', light: true, sky:'#ffd8c4',floor:'#e8cce8',beam:'#e4c4f0',chrome:'#f0dce6',panel:'#fdf8fc',card:'#f8eef6',fg:'#36283e',muted:'#685874',border:'#d6bed8',accent:'#8a5ac8',ink:'#ffffff',glyph:'#8a7a96' },
	{ id: 'windmills', name: 'Windmills', light: true, sky:'#aeb4bf',floor:'#eeede6',beam:'#d9dce2',chrome:'#dcdee2',panel:'#f8f8f6',card:'#f0f0ec',fg:'#22262c',muted:'#50565e',border:'#b8bcc4',accent:'#e04a5a',ink:'#ffffff',glyph:'#6a707a' },
	{ id: 'island', name: 'Island Palms', light: true, sky:'#7ccaf0',floor:'#2aa0c0',beam:'#a8e8f0',chrome:'#c4e6f2',panel:'#f2fbfe',card:'#eaf6fa',fg:'#16323e',muted:'#40606c',border:'#94c4d4',accent:'#1a8ab0',ink:'#ffffff',glyph:'#4e7a88' },
	{ id: 'opart', name: 'Moire', light: true, sky:'#f7f7f3',floor:'#efefea',beam:'#dcdcd6',chrome:'#efefea',panel:'#fbfbf8',card:'#f2f2ee',fg:'#121212',muted:'#555555',border:'#cfcfc8',accent:'#e23a3a',ink:'#ffffff',glyph:'#444444' },
	{ id: 'zen', name: 'Zen Garden', light: true, sky:'#f4ece0',floor:'#ece2d2',beam:'#e8dcc8',chrome:'#ece4d8',panel:'#fbf8f2',card:'#f6f0e6',fg:'#2e2a22',muted:'#625a4c',border:'#d4c8b4',accent:'#5a8a4a',ink:'#ffffff',glyph:'#8a8270' },
]);

module.exports = { WALLPAPERS };
