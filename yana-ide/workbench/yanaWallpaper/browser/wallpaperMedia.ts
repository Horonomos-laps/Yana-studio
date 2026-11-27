/*---------------------------------------------------------------------------------------------
 *  Yana Studio. MIT License.
 *--------------------------------------------------------------------------------------------*/

// Ảnh hoặc video của chính người dùng làm hình nền. File được nạp qua vscode-file://, cùng nguồn với cửa sổ,
// nên không phải nới chính sách bảo mật. Chỉ nhận đúng các đuôi giao thức đó chịu phục vụ.

import { Disposable, toDisposable } from '../../../../base/common/lifecycle.js';
import { FileAccess } from '../../../../base/common/network.js';
import { isAbsolute } from '../../../../base/common/path.js';
import { extname } from '../../../../base/common/resources.js';
import { URI } from '../../../../base/common/uri.js';

export type WallpaperMediaKind = 'image' | 'video';

const IMAGE_EXTENSIONS = new Set(['.png', '.jpg', '.jpeg', '.webp']);
const VIDEO_EXTENSIONS = new Set(['.mp4']);
/** Dài hơn mọi đường dẫn thật; chặn giá trị rác trong cấu hình. */
const MAX_PATH_LENGTH = 4096;

/** Loại hình nền của một đường dẫn, hoặc undefined khi không dùng được. */
export function wallpaperMediaKind(path: string | undefined): WallpaperMediaKind | undefined {
	if (!path || path.length > MAX_PATH_LENGTH || path.includes('\0') || !isAbsolute(path)) {
		return undefined;
	}
	const extension = extname(URI.file(path)).toLowerCase();
	if (IMAGE_EXTENSIONS.has(extension)) {
		return 'image';
	}
	return VIDEO_EXTENSIONS.has(extension) ? 'video' : undefined;
}

/** Phần tử hiển thị, đặt ở đúng lớp của canvas cảnh. */
export class WallpaperMedia extends Disposable {

	readonly element: HTMLImageElement | HTMLVideoElement;

	constructor(readonly path: string, readonly kind: WallpaperMediaKind, container: HTMLElement, onError: () => void) {
		super();
		const targetDocument = container.ownerDocument;
		const element = kind === 'video' ? targetDocument.createElement('video') : targetDocument.createElement('img');
		element.className = 'yana-wallpaper-canvas yana-wallpaper-media';
		element.setAttribute('aria-hidden', 'true');
		if (element.tagName === 'VIDEO') {
			const video = element as HTMLVideoElement;
			video.muted = true;
			video.loop = true;
			video.playsInline = true;
			video.preload = 'auto';
		}
		element.addEventListener('error', onError);
		element.src = FileAccess.uriToBrowserUri(URI.file(path)).toString(true);
		container.prepend(element);
		this.element = element;
		this._register(toDisposable(() => {
			element.removeEventListener('error', onError);
			// Bỏ nguồn để trình giải mã video được giải phóng ngay.
			element.removeAttribute('src');
			if (element.tagName === 'VIDEO') {
				(element as HTMLVideoElement).load();
			}
			element.remove();
		}));
	}

	/** Video chỉ chạy khi cửa sổ đang hiện và người dùng không chọn đứng yên. */
	setPlaying(playing: boolean): void {
		if (this.kind !== 'video') {
			return;
		}
		const video = this.element as HTMLVideoElement;
		if (playing) {
			// Trình duyệt có thể từ chối phát; khi đó còn lại khung hình đầu.
			video.play().catch(() => undefined);
		} else {
			video.pause();
		}
	}
}
