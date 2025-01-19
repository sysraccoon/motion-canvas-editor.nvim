local default_config = {
	viewport_height = 24, -- set viewport line count that can be present in animation
	viewport_highlight = "#313244", -- set viewport indicator background color
	auto_save = true, -- automatically save session on snapshot list editing
	default_session_path = "mce-session.json", -- default session file name
	default_commands = true, -- enable default commands
	default_keymaps = true, -- enable default keymaps
}

local Core = require("motion-canvas-editor.internals.core")
local M = {}

M._active_session = nil

local ns = vim.api.nvim_create_namespace("MCENamespace")
local buf_enter_group = vim.api.nvim_create_augroup("MCEBufEnterGroup", { clear = true })
local buf_exit_group = vim.api.nvim_create_augroup("MCEBufExitGroup", { clear = true })
local hl_group = "MCEHighlight"

local create_session = function(session_path)
	return {
		session_path = session_path,
		buffer_viewport_scrolls = {},
		buffer_snapshots = {},
	}
end

local reset_buffer_viewport = function(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	M._active_session.buffer_viewport_scrolls[bufnr] = nil
end

local set_buffer_viewport = function(bufnr, start_row, size)
	reset_buffer_viewport(bufnr)

	vim.api.nvim_buf_set_extmark(bufnr, ns, start_row, 0, {
		line_hl_group = hl_group,
		strict = false,
	})

	local end_row = start_row + size - 1
	vim.api.nvim_buf_set_extmark(bufnr, ns, end_row, 0, {
		line_hl_group = hl_group,
		strict = false,
	})

	M._active_session.buffer_viewport_scrolls[bufnr] = start_row
end

local reset_viewport_update = function()
	vim.api.nvim_clear_autocmds({ group = buf_enter_group })
	vim.api.nvim_clear_autocmds({ group = buf_exit_group })

	local bufnr = vim.fn.bufnr("%")
	reset_buffer_viewport(bufnr)
end

local set_viewport_update = function()
	reset_viewport_update()

	M._highlight_match_cache = {}

	vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI", "InsertLeave" }, {
		group = buf_enter_group,
		callback = function(event)
			local bufnr = event.buf
			local scroll = M._active_session.buffer_viewport_scrolls[bufnr] or 0
			set_buffer_viewport(bufnr, scroll, M._config.viewport_height)
		end,
	})

	vim.api.nvim_create_autocmd("BufLeave", {
		group = buf_exit_group,
		callback = function(event)
			local bufnr = event.buf
			reset_buffer_viewport(bufnr)
		end,
	})

	local bufnr = vim.fn.bufnr("%")
	local scroll = M._active_session.buffer_viewport_scrolls[bufnr] or 0
	set_buffer_viewport(bufnr, scroll, M._config.viewport_height)
end

M.start_session = function(session_path)
	session_path = session_path or M._config.default_session_path

	if M._active_session then
		M.end_session()
	end

	local session_file = io.open(session_path)
	if session_file ~= nil then
		return error(
			"session file "
				.. vim.inspect(session_path)
				.. " already exist try use :MCELoadSession or :MCETryLoadSession if you want load it"
		)
	end

	M._active_session = create_session(session_path)
	set_viewport_update()
end

M.load_session = function(session_path)
	session_path = session_path or M._config.default_session_path

	if M._active_session then
		M.end_session()
	end

	local session_file = io.open(session_path, "r+")
	if session_file == nil then
		return error(
			"session file "
				.. vim.inspect(session_path)
				.. " not exist or not accepted for write,"
				.. " try use :MCEStartSession or :MCETryLoadSession if you want start new session"
		)
	end

	local content = session_file:read()
	session_file:close()

	local session_patch = vim.json.decode(content)

	local session = create_session(session_path)

	if session_patch.version ~= 1 then
		return error("unknown session file version (" .. session_patch.version .. ")")
	end

	session.buffer_snapshots = session_patch.buffer_snapshots or {}
	M._active_session = session
	set_viewport_update()
end

M.try_load_session = function(session_path)
	session_path = session_path or M._config.default_session_path

	if M._active_session then
		M.end_session()
	end

	local session_file = io.open(session_path)
	if session_file == nil then
		M.start_session(session_path)
		return
	end

	session_file:close()
	M.load_session(session_path)
end

M.push_snapshot = function()
	if not M._active_session then
		return error("active session not exists, try use :MCEStartSession")
	end

	local bufnr = vim.fn.bufnr("%")

	local name = Core.get_relative_buffer_name(bufnr)
	local selection = Core.get_active_selection(bufnr)
	local content = Core.get_buffer_content(bufnr)
	local scroll = M._active_session.buffer_viewport_scrolls[bufnr] or 0

	local snapshot = {
		name = name,
		selection = selection,
		content = content,
		scroll = scroll,
	}

	local snapshots = M._active_session.buffer_snapshots
	snapshots[#snapshots + 1] = snapshot

	if M._config.auto_save then
		M.write_session()
	end
end

M.scroll_viewport_to_cursor = function()
	if not M._active_session then
		return error("active session not exists, try use :MCEStartSession")
	end

	local bufnr = vim.fn.bufnr("%")
	local start_row, _ = unpack(vim.api.nvim_win_get_cursor(0))
	local viewport_height = M._config.viewport_height
	set_buffer_viewport(bufnr, start_row - 1, viewport_height)
end

M.write_session = function()
	local session = M._active_session
	if not session then
		return error("active session not exists, try use :MCEStartSession")
	end

	local session_file = io.open(session.session_path, "w")
	if not session_file then
		return error("failed to open session file " .. vim.inspect(session.session_path))
	end

	local session_content = {
		version = 1,
		snapshots = session.buffer_snapshots,
	}
	local session_json = vim.json.encode(session_content)
	session_file:write(session_json)
	session_file:close()
end

M.end_session = function()
	if not M._active_session then
		return
	end

	M.write_session()
	reset_viewport_update()
	M._active_session = nil
end

local create_default_commands = function()
	vim.api.nvim_create_user_command("MCEStartSession", function(args)
		M.start_session(args.fargs[1])
	end, {
		nargs = "?",
		complete = "file",
		desc = "Start new session. Fail if file exist",
	})

	vim.api.nvim_create_user_command("MCELoadSession", function(args)
		M.load_session(args.fargs[1])
	end, {
		nargs = "?",
		complete = "file",
		desc = "Load session file. Fail if file not exist",
	})

	vim.api.nvim_create_user_command("MCETryLoadSession", function(args)
		M.try_load_session(args.fargs[1])
	end, {
		nargs = "?",
		complete = "file",
		desc = "Try load session file or start new session if file not exist",
	})

	vim.api.nvim_create_user_command("MCEEndSession", M.end_session, {
		desc = "End active session and save result to file",
	})
	vim.api.nvim_create_user_command("MCEWriteSession", M.write_session, {
		desc = "Write snapshot to session file",
	})
	vim.api.nvim_create_user_command("MCEPushSnapshot", M.push_snapshot, {
		desc = "Push current buffer to snapshot list. Write result to session file if 'auto_save' enabled",
	})
	vim.api.nvim_create_user_command("MCEScrollViewportToCursor", M.scroll_viewport_to_cursor, {
		desc = "Scroll viewport to cursor",
	})
end

local create_default_keymaps = function()
	local map = function(mods, combo, action)
    vim.keymap.set(mods, combo, action, { noremap = true })
	end

	map({ "n" }, "<leader>ms", M.start_session)
	map({ "n" }, "<leader>ma", M.try_load_session)
	map({ "n" }, "<leader>ml", M.load_session)
	map({ "n" }, "<leader>me", M.end_session)
	map({ "n" }, "<leader>mw", M.write_session)
	map({ "n", "v", "x" }, "<leader>mn", M.push_snapshot)
	map({ "n" }, "<leader>mz", M.scroll_viewport_to_cursor)
end

M.setup = function(opts)
	M._config = vim.tbl_extend("force", default_config, opts or {})

	vim.api.nvim_set_hl(0, hl_group, {
		bg = M._config.viewport_highlight,
	})

	if M._config.default_commands then
		create_default_commands()
	end

	if M._config.default_keymaps then
		create_default_keymaps()
	end
end

return M
