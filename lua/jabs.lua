local M = {}
local api = vim.api

local ui = api.nvim_list_uis()[1]

M.bopen = {}

require 'split'

M.opts = {
	['relative']	= 'cursor',
	['width']		= 50,
	['height']		= 10,
	['col']			= (ui.width) - 7,
	['row']			= (ui.height) - 3,
	['anchor']		= 'SE',
	['style']		= 'minimal',
	['border']		= 'shadow',
}

M.bufinfo = {
	['%a']			= {'', 'MoreMsg'},
	['#a']			= {'', 'MoreMsg'},
	['a']			= {'', 'MoreMsg'},
	['#h']			= {'', 'WarningMsg'},
	['h']			= {'﬘', 'ModeMsg'},
	['-']			= '',
	['=']			= '',
	['+']			= '',
	['R']			= '',
	['F']			= '',
}

M.openOptions = {
	window			= 'b%s',
	vsplit			= 'vert sb %s',
	hsplit			= 'sb %s',
}

-- Open buffer from line
function M.selBufNum(win, opt)
	local l = api.nvim_get_current_line()
	local buf = l:split(' ', true)[4]

	vim.cmd('close')

	api.nvim_set_current_win(win)
	vim.cmd(string.format(M.openOptions[opt], buf))
end

-- Close buffer from line
function M.closeBufNum(win)
  local l = api.nvim_get_current_line()
  local buf = l:split(' ', true)[4]

  local current_buf = api.nvim_win_get_buf(win)
  local jabs_buf = api.nvim_get_current_buf()

  if tonumber(buf) ~= current_buf then
    vim.cmd(string.format('bd %s', buf))
    local ln = api.nvim_win_get_cursor(0)[1]
    table.remove(M.bopen, ln-1)

    M.refresh(jabs_buf)
  else
    api.nvim_notify('JABS: Cannot close current buffer!', 3, {})
  end

  vim.wo.number = false
  vim.wo.relativenumber = false
end


-- Parse ls string
function M.parseLs(buf)
	for i, b in ipairs(M.bopen) do
		local line = ''			-- Line to be added to buffer
		local si = 0			-- Non-empty split counter
		local highlight = ''	-- Line highlight group
		local linenr			-- Buffer line number

		for _, s in ipairs(b:split(' ', true)) do
			if s == '' then goto continue end	-- Empty splits are discarded
			si = si + 1

			-- Split with buffer information
			if si == 2 then
				_, highlight = xpcall(function()
					return M.bufinfo[s][2]
				end, function()
					return M.bufinfo[s:sub(1,s:len()-1)][2]
				end)

				local _, symbol = xpcall(function()
					return M.bufinfo[s][1]
				end, function()
					return M.bufinfo[s:sub(s:len(),s:len())]
				end)

				-- Fixes #3
				symbol = symbol or M.bufinfo['h']

				line = '· '..symbol..' '..line
			-- Other non-empty splits (filename, RO, modified, ...)
			else
				if s:sub(2, 8) == 'term://' then
					line = line..'Terminal'..s:gsub("^.*:", ": \"")
				else
					if tonumber(s) ~= nil and si > 2 then linenr = s else
						if s:sub(1,4) ~= 'line' then
							line = line..(M.bufinfo[s] or s)..' '
						end
					end
				end
			end

			::continue::
		end

		-- Remove quotes from filename
		line = line:gsub('\"', '')

		-- Truncate line if too long
		if line:len() > M.opts['width']-linenr:len()-3 then
			line = line:sub(1, M.opts['width']-linenr:len()-6)..'...'
		end

		-- Write line
		api.nvim_buf_set_text(buf, i, 1, i, line:len(), {line})
		api.nvim_buf_set_text(buf, i, M.opts['width']-linenr:len(), i,
							  M.opts['width'], {' '..linenr})

		api.nvim_buf_add_highlight(buf, -1, highlight, i, 0, -1)
	end
end

-- Set floating window keymaps
function M.setKeymaps(win, buf)
	-- Move to second line
	api.nvim_feedkeys('j', 'n', false)

	-- Basic window buffer configuration
	api.nvim_buf_set_keymap(buf, 'n', '<CR>',
							string.format([[:lua require'jabs'.selBufNum(%s, 'window')<CR>]], win),
							{ nowait = true, noremap = true, silent = true } )
	api.nvim_buf_set_keymap(buf, 'n', 's',
							string.format([[:lua require'jabs'.selBufNum(%s, 'hsplit')<CR>]], win),
							{ nowait = true, noremap = true, silent = true } )
	api.nvim_buf_set_keymap(buf, 'n', 'v',
							string.format([[:lua require'jabs'.selBufNum(%s, 'vsplit')<CR>]], win),
							{ nowait = true, noremap = true, silent = true } )
	api.nvim_buf_set_keymap(buf, 'n', 'D',
							string.format([[:lua require'jabs'.closeBufNum(%s)<CR>]], win),
							{ nowait = true, noremap = true, silent = true } )

	-- Navigation keymaps
	api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>',
							{ nowait = true, noremap = true, silent = true } )
	api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>',
							{ nowait = true, noremap = true, silent = true } )
	api.nvim_buf_set_keymap(buf, 'n', '<Tab>', 'j',
							{ nowait = true, noremap = true, silent = true } )
	api.nvim_buf_set_keymap(buf, 'n', '<S-Tab>', 'k',
							{ nowait = true, noremap = true, silent = true } )
end

function M.refresh(buf)
	local empty = {}
	for _ = 1, #M.bopen+1 do empty[#empty+1] = string.rep(' ', M.opts['width']) end

	api.nvim_buf_set_option(buf, 'modifiable', true)
	api.nvim_buf_set_lines(buf, 0, -1, false, empty)

	M.parseLs()

	-- Draw title
	local title = 'Open buffers:'
	api.nvim_buf_set_text(buf, 0, 1, 0, title:len()+1, {title})
	api.nvim_buf_add_highlight(buf, -1, 'Folded', 0, 0, -1)
	api.nvim_buf_set_option(buf, 'modifiable', false)
end

-- Floating buffer list
function M.open()
	M.bopen = api.nvim_exec(':ls', true):split('\n', true)
	-- Create the buffer for the window
	local win = api.nvim_get_current_win()
	local buf = api.nvim_create_buf(false, true)

	api.nvim_open_win(buf, 1, M.opts)

	M.refresh(buf)
	M.setKeymaps(win, buf)
end

return M
