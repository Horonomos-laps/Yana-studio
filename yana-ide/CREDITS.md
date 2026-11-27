# Mã bên thứ ba trong yana-ide

## Hình nền động (`workbench/yanaWallpaper/browser/scenes.ts`, `themes.ts`)

Chuyển thể từ [antigravity-ascii-wallpapers](https://github.com/erlttt0/antigravity-ascii-wallpapers),
commit `9c81e00`. `extensions/yana-agent/host/wallpaper-catalog.cjs` lấy tên và màu từ cùng nguồn.

Thay đổi so với bản gốc: export bộ vẽ cho workbench, thêm `@ts-nocheck`, chuyển bảng theme sang TypeScript.
Phần cài đặt bằng cách vá `app.asar`, phần quota và phần lấy CSRF token không được đưa vào.

Giấy phép MIT:

```
MIT License

Copyright (c) 2026 Mix4o445

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
