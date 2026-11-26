/*---------------------------------------------------------------------------------------------
 *  Yana Studio. MIT License.
 *--------------------------------------------------------------------------------------------*/

// Chọn cảnh và màu giao diện đi theo cảnh. Dùng chung cho workbench và cho webview (themeing.ts).

import { ColorScheme, isDark, isHighContrast } from '../../../../platform/theme/common/theme.js';
import { IWallpaperTheme, WALLPAPER_THEMES } from './themes.js';

const AUTO_DARK = 'moon';
const AUTO_LIGHT = 'clouds';

export function resolveWallpaper(id: string, scheme: ColorScheme): IWallpaperTheme | undefined {
	if (id === 'off' || isHighContrast(scheme)) {
		return undefined;
	}
	const wanted = id === 'auto' ? (isDark(scheme) ? AUTO_DARK : AUTO_LIGHT) : id;
	return WALLPAPER_THEMES.find(theme => theme.id === wanted);
}

/** Chữ đen hay trắng đọc rõ hơn trên một màu nền #rrggbb. */
function textOn(background: string): string {
	const channel = (start: number) => {
		const value = parseInt(background.slice(start, start + 2), 16) / 255;
		return value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
	};
	const luminance = 0.2126 * channel(1) + 0.7152 * channel(3) + 0.0722 * channel(5);
	// Điểm cân bằng tương phản giữa chữ đen và chữ trắng theo công thức WCAG.
	return luminance > 0.179 ? '#000000' : '#ffffff';
}

/**
 * Biến màu của VS Code (không kèm `--`) lấy theo cảnh. Trả về rỗng khi cảnh sáng mà theme tối
 * hoặc ngược lại: màu chữ cú pháp của theme sẽ không đọc được trên nền đó.
 */
export function wallpaperColors(theme: IWallpaperTheme, scheme: ColorScheme): Record<string, string> {
	if (theme.light === isDark(scheme)) {
		return {};
	}
	const colour = (key: string) => String(theme[key]);
	const groups: [string, string[]][] = [
		[colour('chrome'), ['activityBar-background', 'titleBar-activeBackground', 'titleBar-inactiveBackground', 'statusBar-background', 'statusBar-noFolderBackground']],
		[colour('panel'), ['editor-background', 'sideBar-background', 'sideBarSectionHeader-background', 'panel-background', 'editorGroupHeader-tabsBackground']],
		[colour('card'), ['editorWidget-background', 'input-background', 'dropdown-background', 'quickInput-background', 'menu-background', 'tab-activeBackground', 'button-secondaryBackground']],
		[colour('fg'), ['foreground', 'sideBar-foreground', 'sideBarTitle-foreground', 'activityBar-foreground', 'titleBar-activeForeground', 'statusBar-foreground']],
		[colour('muted'), ['descriptionForeground', 'activityBar-inactiveForeground', 'tab-inactiveForeground']],
		[colour('border'), ['sideBar-border', 'panel-border', 'editorGroup-border', 'input-border', 'widget-border']],
		[colour('accent'), ['focusBorder', 'button-background', 'button-hoverBackground', 'textLink-foreground', 'activityBarBadge-background', 'activityBar-activeBorder', 'progressBar-background']],
		[textOn(colour('accent')), ['button-foreground', 'activityBarBadge-foreground']]
	];
	const result: Record<string, string> = {};
	for (const [value, names] of groups) {
		for (const name of names) {
			result[`vscode-${name}`] = value;
		}
	}
	return result;
}
