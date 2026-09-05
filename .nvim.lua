vim.api.nvim_create_autocmd("BufEnter", {
	pattern = "*/tests/*",
	callback = function(ev)
		vim.b[ev.buf].autoformat = false
	end,
})
