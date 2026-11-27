'use strict';
// Báo cho hình nền trong workbench biết đang có bao nhiêu lượt agent chạy. Chỉ gửi một con số.

const vscode = require('vscode');
const { activity } = require('../runtime');

const COMMAND = '_yana.wallpaper.agents';

function activate(context) {
	const send = count => Promise.resolve(vscode.commands.executeCommand(COMMAND, count))
		// Bản editor không có hình nền thì không có lệnh này.
		.catch(error => console.warn(`[yana-agent] wallpaper activity not delivered: ${error.message}`));
	activity.on('turns', send);
	context.subscriptions.push({ dispose: () => activity.removeListener('turns', send) });
}

module.exports = { id: 'wallpaper-activity', activate };
