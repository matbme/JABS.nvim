local M = {}
local api = vim.api

local ui = api.nvim_list_uis()[1]

M.win = nil
M.buf = nil
M.bopen = {}

require 'split'

M.opts = {
    ['relative']    = 'cursor',
    ['width']       = 50,
    ['height']      = 10,
    ['col']         = (ui.width) - 7,
    ['row']         = (ui.height) - 3,
    ['anchor']      = 'SE',
    ['style']       = 'minimal',
    ['border']      = 'shadow',
}

M.bufinfo = {
    ['%a']          = {'', 'StatusLine'},
    ['#a']          = {'', 'StatusLine'},
    ['a']           = {'', 'StatusLine'},
    ['#h']          = {'', 'WarningMsg'},
    ['h']           = {'﬘', 'ModeMsg'},
    ['-']           = '',
    ['=']           = '',
    ['+']           = '',
    ['R']           = '',
    ['F']           = '',
}

M.openOptions = {
    window          = 'b%s',
    vsplit          = 'vert sb %s',
    hsplit          = 'sb %s',
}

-- Open buffer from line
function M.selBufNum(win, opt, count)
    local buf = nil

    -- Check for buffer number
    if count ~= 0 then
        local lines = api.nvim_buf_get_lines(0, 1, -1, true)

        for _, line in pairs(lines) do
            local linebuf = line:split(' ', true)[4]
            if tonumber(linebuf) == count then
                buf = linebuf
                break
            end
        end
    -- Or if it's just an ENTER
    else
        local l = api.nvim_get_current_line()
        buf = l:split(' ', true)[4]
    end

    M.close()

    if not buf then
        print('Buffer number not found!')
        return
    end

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
    local highlight = ''	-- Line highlight group
    local linenr			-- Buffer line number

    for si, s in ipairs(b:split(' ', true)) do
        -- Split with buffer information
        if si == 4 then
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
            symbol = symbol or M.bufinfo['h'][1]

            line = '· '..symbol..' '..line
        -- Other non-empty splits (filename, RO, modified, ...)
        else
            if s:sub(2, 8) == 'term://' then
                line = line..'Terminal'..s:gsub("^.*:", ": \"")
            else
                if tonumber(s) ~= nil and si > 4 then linenr = s else
                    if s:sub(1,4) ~= 'line' and s ~= '' then
                        line = line..(M.bufinfo[s] or s)..' '
                    end
                end
            end
        end
    end

    -- Remove quotes from filename
    line = line:gsub('\"', '')

    -- Truncate line if too long
    local filename_space = M.opts['width']-linenr:len()-3
    if line:len() > filename_space then
        line = line:gsub(string.rep('%S', line:len()-filename_space+3), '...', 1)
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
                            string.format([[:<C-U>lua require'jabs'.selBufNum(%s, 'window', vim.v.count)<CR>]], win),
                            { nowait = true, noremap = true, silent = true } )
    api.nvim_buf_set_keymap(buf, 'n', 's',
                            string.format([[:<C-U>lua require'jabs'.selBufNum(%s, 'hsplit', vim.v.count)<CR>]], win),
                            { nowait = true, noremap = true, silent = true } )
    api.nvim_buf_set_keymap(buf, 'n', 'v',
                            string.format([[:<C-U>lua require'jabs'.selBufNum(%s, 'vsplit', vim.v.count)<CR>]], win),
                            { nowait = true, noremap = true, silent = true } )
    api.nvim_buf_set_keymap(buf, 'n', 'D',
                            string.format([[:lua require'jabs'.closeBufNum(%s)<CR>]], win),
                            { nowait = true, noremap = true, silent = true } )

    -- Navigation keymaps
    api.nvim_buf_set_keymap(buf, 'n', 'q', ':lua require"jabs".close()<CR>',
                            { nowait = true, noremap = true, silent = true } )
    api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':lua require"jabs".close()<CR>',
                            { nowait = true, noremap = true, silent = true } )
    api.nvim_buf_set_keymap(buf, 'n', '<Tab>', 'j',
                            { nowait = true, noremap = true, silent = true } )
    api.nvim_buf_set_keymap(buf, 'n', '<S-Tab>', 'k',
                            { nowait = true, noremap = true, silent = true } )
end

function M.close()
    api.nvim_win_close(M.win, false)
    api.nvim_buf_delete(M.buf, {})
    M.win = nil
    M.buf = nil
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
    local back_win = api.nvim_get_current_win()
    -- Create the buffer for the window
    if not M.buf and not M.win then
        M.buf = api.nvim_create_buf(false, true)
        M.win = api.nvim_open_win(M.buf, 1, M.opts)
        M.refresh(M.buf)
        M.setKeymaps(back_win, M.buf)
    else
        M.close()
    end
end

return M
