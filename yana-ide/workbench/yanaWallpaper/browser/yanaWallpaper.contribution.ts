/*---------------------------------------------------------------------------------------------
 *  Yana Studio. MIT License.
 *--------------------------------------------------------------------------------------------*/

// Yana Studio: hình nền động phía sau toàn bộ workbench. Canvas nằm dưới lưới giao diện,
// CSS làm các phần trong suốt một phần để chữ vẫn đọc được.

import './media/yanaWallpaper.css';
import { getWindow } from '../../../../base/browser/dom.js';
import { Emitter } from '../../../../base/common/event.js';
import { Disposable, toDisposable } from '../../../../base/common/lifecycle.js';
import { CommandsRegistry } from '../../../../platform/commands/common/commands.js';
import { localize } from '../../../../nls.js';
import { IAccessibilityService } from '../../../../platform/accessibility/common/accessibility.js';
import { Extensions as ConfigurationExtensions, IConfigurationRegistry } from '../../../../platform/configuration/common/configurationRegistry.js';
import { IConfigurationService } from '../../../../platform/configuration/common/configuration.js';
import { Registry } from '../../../../platform/registry/common/platform.js';
import { IThemeService } from '../../../../platform/theme/common/themeService.js';
import { IWorkbenchContribution, registerWorkbenchContribution2, WorkbenchPhase } from '../../../common/contributions.js';
import { IWorkbenchLayoutService } from '../../../services/layout/browser/layoutService.js';
import { drawAsciiScene } from './scenes.js';
import { resolveWallpaper, wallpaperColors } from './palette.js';
import { IWallpaperTheme, WALLPAPER_THEMES } from './themes.js';

const SECTION = 'yana.wallpaper';
const AUTO = 'auto';
const OFF = 'off';
const DEFAULT_VISIBILITY = 35;
const MIN_VISIBILITY = 10;
const MAX_VISIBILITY = 80;
/** Khoảng 30 khung hình mỗi giây: đủ mượt cho cảnh vẽ bằng ký tự. */
const FRAME_INTERVAL_MS = 33;
/** Giới hạn bước thời gian để cảnh không nhảy sau khi cửa sổ bị treo. */
const MAX_STEP_SECONDS = 0.1;
/** Màn hình Retina không cần vẽ quá 1.5 lần, phần dư chỉ tốn CPU. */
const MAX_PIXEL_RATIO = 1.5;
/** Cảnh tăng nhịp nhanh khi agent bắt đầu và dịu xuống chậm hơn khi xong, để lượt ngắn không giật. */
const ENERGY_RISE = 1.2;
const ENERGY_FALL = 0.6;
const ENERGY_SPEEDUP = 0.8;
/** Gợn sóng khi một lượt xong kéo dài khoảng chừng này giây. */
const PULSE_SECONDS = 1.8;
/** Giá trị lớn hơn là lỗi của bên gọi, không phải số agent thật. */
const MAX_RUNNING_AGENTS = 1000;

// Extension yana-agent báo số lượt đang chạy qua lệnh nội bộ này.
let runningAgents = 0;
const onDidChangeAgents = new Emitter<number>();
CommandsRegistry.registerCommand('_yana.wallpaper.agents', (_accessor, count: unknown) => {
	if (typeof count === 'number' && Number.isInteger(count) && count >= 0 && count <= MAX_RUNNING_AGENTS) {
		const previous = runningAgents;
		runningAgents = count;
		onDidChangeAgents.fire(previous);
	}
});

Registry.as<IConfigurationRegistry>(ConfigurationExtensions.Configuration).registerConfiguration({
	id: 'yanaWallpaper',
	title: localize('yanaWallpaper', "Yana Wallpaper"),
	type: 'object',
	properties: {
		'yana.wallpaper.theme': {
			type: 'string',
			enum: [AUTO, OFF, ...WALLPAPER_THEMES.map(theme => theme.id)],
			default: AUTO,
			description: localize('yanaWallpaper.theme', "Animated wallpaper. 'auto' follows the light or dark colour theme.")
		},
		'yana.wallpaper.visibility': {
			type: 'number',
			minimum: MIN_VISIBILITY,
			maximum: MAX_VISIBILITY,
			default: DEFAULT_VISIBILITY,
			description: localize('yanaWallpaper.visibility', "How much of the wallpaper shows through the interface, in percent.")
		},
		'yana.wallpaper.glyphs': {
			type: 'string',
			enum: ['ascii', 'braille', 'blocks', 'katakana'],
			default: 'ascii',
			description: localize('yanaWallpaper.glyphs', "Character set used to draw the wallpaper.")
		},
		'yana.wallpaper.density': {
			type: 'string',
			enum: ['fine', 'normal', 'chunky'],
			default: 'normal',
			description: localize('yanaWallpaper.density', "Size of the character grid.")
		},
		'yana.wallpaper.recolor': {
			type: 'boolean',
			default: true,
			description: localize('yanaWallpaper.recolor', "Colour the interface to match the scene.")
		},
		'yana.wallpaper.reactive': {
			type: 'boolean',
			default: true,
			description: localize('yanaWallpaper.reactive', "Speed up while Yana agents run and ripple when one finishes.")
		},
		'yana.wallpaper.paused': {
			type: 'boolean',
			default: false,
			description: localize('yanaWallpaper.paused', "Show the wallpaper as a still picture.")
		}
	}
});

class YanaWallpaper extends Disposable implements IWorkbenchContribution {

	static readonly ID = 'workbench.contrib.yanaWallpaper';

	private canvas: HTMLCanvasElement | undefined;
	private theme: IWallpaperTheme | undefined;
	private frame = 0;
	private lastFrameAt = 0;
	private seconds = 0;
	private energy = 0;
	private pulse = 0;
	private recoloured: string[] = [];

	constructor(
		@IWorkbenchLayoutService private readonly layoutService: IWorkbenchLayoutService,
		@IConfigurationService private readonly configurationService: IConfigurationService,
		@IThemeService private readonly themeService: IThemeService,
		@IAccessibilityService private readonly accessibilityService: IAccessibilityService
	) {
		super();
		this._register(configurationService.onDidChangeConfiguration(e => {
			if (e.affectsConfiguration(SECTION)) {
				this.apply();
			}
		}));
		this._register(themeService.onDidColorThemeChange(() => this.apply()));
		this._register(accessibilityService.onDidChangeReducedMotion(() => this.apply()));
		this._register(layoutService.onDidLayoutMainContainer(() => this.resize()));
		this._register(onDidChangeAgents.event(previous => {
			if (runningAgents < previous && this.isReactive()) {
				this.pulse = 1;
			}
		}));

		const targetDocument = layoutService.mainContainer.ownerDocument;
		const onVisibility = () => this.schedule();
		targetDocument.addEventListener('visibilitychange', onVisibility);
		this._register(toDisposable(() => targetDocument.removeEventListener('visibilitychange', onVisibility)));
		this._register(toDisposable(() => this.remove()));
		this.apply();
	}

	private resolveTheme(): IWallpaperTheme | undefined {
		const id = this.configurationService.getValue<string>(`${SECTION}.theme`) ?? AUTO;
		return resolveWallpaper(id, this.themeService.getColorTheme().type);
	}

	private isReactive(): boolean {
		return this.configurationService.getValue<boolean>(`${SECTION}.reactive`) !== false;
	}

	private recolour(theme: IWallpaperTheme | undefined): void {
		const style = this.layoutService.mainContainer.style;
		for (const name of this.recoloured) {
			style.removeProperty(name);
		}
		this.recoloured = [];
		if (!theme || this.configurationService.getValue<boolean>(`${SECTION}.recolor`) === false) {
			return;
		}
		for (const [name, value] of Object.entries(wallpaperColors(theme, this.themeService.getColorTheme().type))) {
			style.setProperty(`--${name}`, value);
			this.recoloured.push(`--${name}`);
		}
	}

	private apply(): void {
		this.theme = this.resolveTheme();
		if (!this.theme) {
			this.remove();
			return;
		}
		const container = this.layoutService.mainContainer;
		const visibility = this.configurationService.getValue<number>(`${SECTION}.visibility`) ?? DEFAULT_VISIBILITY;
		const clamped = Math.min(MAX_VISIBILITY, Math.max(MIN_VISIBILITY, visibility));
		container.style.setProperty('--yana-wallpaper-veil', `${100 - clamped}%`);
		container.classList.add('yana-wallpaper');
		this.recolour(this.theme);
		if (!this.canvas) {
			this.canvas = container.ownerDocument.createElement('canvas');
			this.canvas.className = 'yana-wallpaper-canvas';
			this.canvas.setAttribute('aria-hidden', 'true');
			container.prepend(this.canvas);
		}
		this.resize();
		this.schedule();
	}

	private resize(): void {
		if (!this.canvas) {
			return;
		}
		const { width, height } = this.layoutService.mainContainerDimension;
		const ratio = Math.min(getWindow(this.canvas).devicePixelRatio || 1, MAX_PIXEL_RATIO);
		this.canvas.width = Math.round(width * ratio);
		this.canvas.height = Math.round(height * ratio);
		this.canvas.getContext('2d')?.setTransform(ratio, 0, 0, ratio, 0, 0);
		this.render();
	}

	private render(): void {
		const context = this.canvas?.getContext('2d');
		if (!context || !this.theme) {
			return;
		}
		const { width, height } = this.layoutService.mainContainerDimension;
		// Bộ vẽ mặc định làm mờ phần ba ở giữa. Đặt cột "yên tĩnh" ra ngoài màn hình để cảnh liền khắp
		// giao diện; độ dễ đọc đã do lớp màu mỏng trong CSS lo.
		const noCalmColumn = { l: width * 2, r: width * 2, t: 0 };
		drawAsciiScene(context, width, height, this.theme, this.seconds, 1, noCalmColumn, {
			glyphs: this.configurationService.getValue<string>(`${SECTION}.glyphs`),
			scale: this.configurationService.getValue<string>(`${SECTION}.density`),
			energy: this.energy,
			pulse: this.pulse
		});
	}

	private isStill(): boolean {
		return this.configurationService.getValue<boolean>(`${SECTION}.paused`) === true || this.accessibilityService.isMotionReduced();
	}

	private schedule(): void {
		this.cancel();
		if (!this.canvas || this.canvas.ownerDocument.hidden) {
			return;
		}
		this.render();
		if (this.isStill()) {
			return;
		}
		const targetWindow = getWindow(this.canvas);
		this.lastFrameAt = targetWindow.performance.now();
		const tick = (now: number) => {
			const elapsed = now - this.lastFrameAt;
			if (elapsed >= FRAME_INTERVAL_MS) {
				this.lastFrameAt = now;
				const step = Math.min(elapsed / 1000, MAX_STEP_SECONDS);
				const target = this.isReactive() && runningAgents > 0 ? 1 : 0;
				this.energy += (target - this.energy) * Math.min(1, step * (target ? ENERGY_RISE : ENERGY_FALL));
				this.pulse = Math.max(0, this.pulse - step / PULSE_SECONDS);
				this.seconds += step * (1 + ENERGY_SPEEDUP * this.energy);
				this.render();
			}
			this.frame = targetWindow.requestAnimationFrame(tick);
		};
		this.frame = targetWindow.requestAnimationFrame(tick);
	}

	private cancel(): void {
		if (this.frame && this.canvas) {
			getWindow(this.canvas).cancelAnimationFrame(this.frame);
		}
		this.frame = 0;
	}

	private remove(): void {
		this.cancel();
		this.canvas?.remove();
		this.canvas = undefined;
		this.recolour(undefined);
		this.layoutService.mainContainer.classList.remove('yana-wallpaper');
		this.layoutService.mainContainer.style.removeProperty('--yana-wallpaper-veil');
	}
}

registerWorkbenchContribution2(YanaWallpaper.ID, YanaWallpaper, WorkbenchPhase.AfterRestored);
