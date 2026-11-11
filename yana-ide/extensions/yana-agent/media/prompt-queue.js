'use strict';
// Hàng đợi lời nhắc của panel chat: gõ tiếp khi agent đang chạy thì xếp hàng, tự gửi khi lượt xong.
// Chỉ chứa trạng thái và chính sách, không đụng DOM, để kiểm thử được bằng node (tests/prompt-queue.test.cjs).
//
// Chính sách quan trọng nhất là afterTurn(): chỉ tự gửi khi lượt kết thúc bằng 'completed'.
// - Lượt dừng chờ duyệt ('paused'): tiến trình đã thoát nên busy = false, nhưng lời xin duyệt còn treo. Không được gửi
//   tiếp, nếu không lời nhắc mới sẽ chen vào giữa một quyết định chưa xong. Chờ duyệt xong, lượt chạy lại rồi hoàn tất.
// - Lượt bị huỷ, bị lỗi, hoặc không rõ kết thúc thế nào: tạm dừng hàng đợi, người dùng bấm Resume mới chạy tiếp.
(function (root, factory) {
	const api = factory();
	if (typeof module === 'object' && module.exports) module.exports = api;
	else root.YanaPromptQueue = api;
})(typeof window !== 'undefined' ? window : globalThis, function () {
	const MAX_ITEMS = 20; // đủ cho một chuỗi việc, đủ nhỏ để người dùng còn nhìn hết

	function create() {
		return { items: [], paused: false, note: '' };
	}

	// Hàng đợi đầy thì trả về đúng trạng thái cũ; bên gọi so độ dài để biết có thêm được hay không.
	function enqueue(state, item) {
		if (state.items.length >= MAX_ITEMS) return state;
		// Thêm vào hàng đợi rỗng thì bỏ trạng thái tạm dừng còn sót lại.
		const resetPause = state.items.length === 0;
		return { items: [...state.items, item], paused: resetPause ? false : state.paused, note: resetPause ? '' : state.note };
	}

	function remove(state, id) {
		const items = state.items.filter(item => item.id !== id);
		return items.length === 0 ? create() : { ...state, items };
	}

	function move(state, id, delta) {
		const from = state.items.findIndex(item => item.id === id);
		const to = from + delta;
		if (from < 0 || to < 0 || to >= state.items.length) return state;
		const items = [...state.items];
		const [moved] = items.splice(from, 1);
		items.splice(to, 0, moved);
		return { ...state, items };
	}

	function clear() {
		return create();
	}

	// Không có gì để tạm dừng thì giữ nguyên, tránh cờ "paused" treo lại cho lần xếp hàng sau.
	function pause(state, note) {
		return state.items.length === 0 ? state : { ...state, paused: true, note: note || '' };
	}

	function resume(state) {
		return { ...state, paused: false, note: '' };
	}

	function dropFirst(state) {
		const items = state.items.slice(1);
		return items.length === 0 ? create() : { ...state, items };
	}

	function first(state) {
		return state.items[0];
	}

	// outcome: 'completed' | 'paused' (chờ duyệt) | 'cancelled' | 'error' | null/undefined (không rõ).
	// Trả về 'idle' (không có gì), 'wait' (không làm gì lúc này), 'send' (gửi lời nhắc kế tiếp), 'pause' (tạm dừng hàng đợi).
	function afterTurn(state, outcome) {
		if (state.items.length === 0) return 'idle';
		if (state.paused) return 'wait';
		if (outcome === 'completed') return 'send';
		if (outcome === 'paused') return 'wait';
		return 'pause'; // huỷ, lỗi, hoặc không biết: không tự gửi
	}

	return { MAX_ITEMS, create, enqueue, remove, move, clear, pause, resume, dropFirst, first, afterTurn };
});
