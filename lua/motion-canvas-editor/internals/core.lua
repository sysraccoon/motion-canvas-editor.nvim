local Core = {}

local nvim_set_visual_mode_by_key = function(key)
	if key ~= "v" and key ~= "V" then
		return error("invalid visual mode key")
	end

	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "x", true)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "x!", true)
end

local function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

Core.get_active_selection = function(bufnr)
	local mode = vim.api.nvim_get_mode().mode
	if mode == "v" or mode == "V" then
		Core.nvim_set_normal_mode()
		local sel_start_row, sel_start_col = unpack(vim.api.nvim_buf_get_mark(bufnr, "<"))
		local sel_end_row, sel_end_col = unpack(vim.api.nvim_buf_get_mark(bufnr, ">"))

		return {
			start_row = sel_start_row - 1, -- fix 1-based index
			start_col = sel_start_col,
			end_row = sel_end_row - 1, -- fix 1-based index
			end_col = sel_end_col,
		}
	end

	return nil
end

Core.get_relative_buffer_name = function(bufnr)
	if type(bufnr) ~= "number" or bufnr % 1 ~= 0 then
		return error(vim.inspect(bufnr) .. ": invalid bufnr type")
	end

	return vim.fn.expand("#" .. bufnr .. ":.")
end

Core.get_buffer_content = function(bufnr)
	local buffer_line_count = vim.api.nvim_buf_line_count(bufnr)
	local buffer_lines = vim.api.nvim_buf_get_lines(bufnr, 0, buffer_line_count, false)
	local buffer_content = table.concat(buffer_lines, "\n")
	return buffer_content
end

Core.nvim_set_normal_mode = function()
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "x", true)
end

Core.nvim_set_visual_mode = function()
	nvim_set_visual_mode_by_key("v")
end

Core.nvim_set_visual_line_mode = function()
	nvim_set_visual_mode_by_key("V")
end

Core.clamp_row_range = function(bufnr, row, size)
	if size <= 0 then
		return error(vim.inspect(size) .. " size should be greater than 0")
	end

	if row < 0 then
		return error(vim.inspect(row) .. " start_row should be greater or equal 0")
	end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local start_row = clamp(row, 0, line_count - 1)
	local end_row = clamp(start_row + size - 1, 0, line_count - 1)

	return {
		start_row = start_row,
		end_row = end_row,
	}
end

Core.set_viewport_region = function(bufnr, start_row, size, hl_group)
	local viewport_region = Core.clamp_row_range(bufnr, start_row, size)

	if not viewport_region then
		return error("invalid viewport region")
	end

	local hl_start = vim.api.nvim_buf_set_extmark(bufnr, ns, viewport_region.start_row, 0, {
		line_hl_group = hl_group,
	})
	local hl_end = vim.api.nvim_buf_set_extmark(bufnr, ns, viewport_region.end_row, 0, {
		line_hl_group = hl_group,
	})

	return {
		hl_start = hl_start,
		hl_end = hl_end,
		row_start = viewport_region.start_row,
		row_end = viewport_region.end_row,
	}
end

return Core
