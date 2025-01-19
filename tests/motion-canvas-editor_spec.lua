local assert = require("luassert")

local create_buffer = function(name, content)
	local bufnr = vim.api.nvim_create_buf(true, true)
	assert(bufnr ~= 0, "failed to create temp buffer")

	vim.api.nvim_buf_set_name(bufnr, name)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, content)
	return bufnr
end

local split_lines = function(str)
	local result = {}
	for line in str:gmatch("[^\n]+") do
		table.insert(result, line)
	end
	return result
end

describe("motion-canvas-editor", function()
	it("can be required", function()
		require("motion-canvas-editor")
	end)
end)

describe("motion-canvas-editor.internals.core", function()
	local core = require("motion-canvas-editor.internals.core")

	local buf_name = "dummy.lua"
	local buf_content = split_lines([[
    function hello()
      print('hello lua')
    end
  ]])
	local bufnr = create_buffer(buf_name, buf_content)

	it("change nvim mode to normal", function()
		core.nvim_set_normal_mode()
		assert.are.equal("n", vim.api.nvim_get_mode().mode)
	end)

	it("change nvim mode to visual", function()
		core.nvim_set_visual_mode()
		assert.are.equal("v", vim.api.nvim_get_mode().mode)
	end)

	it("change nvim mode to visual line", function()
		core.nvim_set_visual_line_mode()
		assert.are.equal("V", vim.api.nvim_get_mode().mode)
	end)

	it("return active selection in visual mode", function()
		local expected_selection = {
			start_row = 1,
			start_col = 9,
			end_row = 1,
			end_col = 17,
		}

		core.nvim_set_visual_mode()

		vim.api.nvim_buf_set_mark(bufnr, "<", expected_selection.start_row + 1, expected_selection.start_col, {})
		vim.api.nvim_buf_set_mark(bufnr, ">", expected_selection.end_row + 1, expected_selection.end_col, {})

		local selection = core.get_active_selection(bufnr)
		assert.are.same(expected_selection, selection)

		core.nvim_set_normal_mode()
	end)

	it("return empty selection in normal mode", function()
		core.nvim_set_normal_mode()

		local selection = core.get_active_selection(bufnr)
		assert.is_nil(selection)
	end)

	it("return buffer content as string", function()
		local expected_content = table.concat(buf_content, "\n")
		local actual_content = core.get_buffer_content(bufnr)

		assert.are.equal(expected_content, actual_content)
	end)

	it("return relative buffer name", function()
		local actual_name = core.get_relative_buffer_name(bufnr)
		assert.are.equal(buf_name, actual_name)
	end)

	it("should throw error when try get relative buffer name for non integer argument", function()
		assert.are.error(function()
			core.get_relative_buffer_name(0.5)
		end)

		assert.are.error(function()
			core.get_relative_buffer_name("test")
		end)
	end)

	it("clamp row range", function()
		local expected_range = {
			start_row = 1,
			end_row = 3,
		}
		local actual_range = core.clamp_row_range(bufnr, 1, 20)
		assert.are.same(expected_range, actual_range)
	end)
end)
