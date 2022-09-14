local M = {}
local api = vim.api

local ui = api.nvim_list_uis()[1]

-- JABS main popup
M.main_win = nil
M.main_buf = nil

-- Buffer preview popup
M.prev_win = nil
M.prev_buf = nil

M.bopen = {}
M.conf = {}
M.win_conf = {}
M.preview_conf = {}
M.keymap_conf = {}

M.openOptions = {
    window = "b%s",
    vsplit = "vert sb %s",
    hsplit = "sb %s",
}

require "split"

function M.setup(c)
    local c = c or {}

    -- If preview opts table not provided in config
    if not c.preview then
        c.preview = {}
    end

    -- If highlight opts table not provided in config
    if not c.highlight then
        c.highlight = {}
    end

    -- If symbol opts table not provided in config
    if not c.symbols then
        c.symbols = {}
    end

    -- If keymap opts table not provided in config
    if not c.keymap then
        c.keymap = {}
    end

    -- If offset opts table not provided in config
    if not c.offset then
        c.offset = {}
    end

    -- Highlight names
    M.highlight = {
        ["%a"] = c.highlight.current or "StatusLine",
        ["#a"] = c.highlight.split or "StatusLine",
        ["a"] = c.highlight.split or "StatusLine",
        ["#h"] = c.highlight.alternate or "WarningMsg",
        ["#"] = c.highlight.alternate or "WarningMsg",
        ["h"] = c.highlight.hidden or "ModeMsg",
    }

    -- Buffer info symbols
    M.bufinfo = {
        ["%a"] = c.symbols.current or "",
        ["#a"] = c.symbols.split or "",
        ["a"] = c.symbols.split or "",
        ["#h"] = c.symbols.alternate or "",
        ["h"] = c.symbols.hidden or "﬘",
        ["-"] = c.symbols.locked or "",
        ["="] = c.symbols.ro or "",
        ["+"] = c.symbols.edited or "",
        ["R"] = c.symbols.terminal or "",
        ["F"] = c.symbols.terminal or "",
    }

    -- Use devicons file symbols
    M.use_devicons = c.use_devicons and true

    -- Fallback file symbol for devicon
    M.default_file = c.symbols.default_file or ""

    -- Main window setup
    M.win_conf = {
        width = c.width or 50,
        height = c.height or 10,
        style = c.style or "minimal",
        border = c.border or "shadow",
        anchor = "NW",
        relative = c.relative or "win",
    }

    -- Preview window setup
    M.preview_conf = {
        width = c.preview.width or 70,
        height = c.preview.height or 30,
        style = c.preview.style or "minimal",
        border = c.preview.border or "double",
        anchor = M.win_conf.anchor,
        relative = c.preview.relative or "win",
    }

    -- Keymap setup
    M.keymap_conf = {
        close = c.keymap.close or "D",
        jump = c.keymap.jump or "<cr>",
        h_split = c.keymap.h_split or "s",
        v_split = c.keymap.v_split or "v",
        preview = c.keymap.preview or "P",
    }

    -- Position setup
    M.conf = {
        position = c.position or "corner",

        top_offset = c.offset.top or 0;
        bottom_offset = c.offset.bottom or 0;
        left_offset = c.offset.left or 0;
        right_offset = c.offset.right or 0;

        preview_position = c.preview_position or "top",
    }

    -- TODO: Convert to a table
    if M.conf.preview_position == "top" then
        M.preview_conf.col = M.win_conf.width / 2 - M.preview_conf.width / 2
        M.preview_conf.row = -M.preview_conf.height - 2
    elseif M.conf.preview_position == "bottom" then
        M.preview_conf.col = M.win_conf.width / 2 - M.preview_conf.width / 2
        M.preview_conf.row = M.win_conf.height
    elseif M.conf.preview_position == "right" then
        M.preview_conf.col = M.win_conf.width
        M.preview_conf.row = M.win_conf.height / 2 - M.preview_conf.height / 2
    elseif M.conf.preview_position == "left" then
        M.preview_conf.col = -M.preview_conf.width
        M.preview_conf.row = M.win_conf.height / 2 - M.preview_conf.height / 2
    end

    M.updatePos()
end

-- Update window position
function M.updatePos()
    ui = api.nvim_list_uis()[1]

    if M.conf.position == "corner" then
        M.win_conf.col = ui.width + M.conf.left_offset - (M.win_conf.width + M.conf.right_offset)
        M.win_conf.row = ui.height + M.conf.top_offset - (M.win_conf.height + M.conf.bottom_offset)
    elseif M.conf.position == "center" then
        M.win_conf.relative = "win"
        M.win_conf.col = (ui.width / 2) + M.conf.left_offset - (M.win_conf.width / 2 + M.conf.right_offset)
        M.win_conf.row = (ui.height / 2) + M.conf.top_offset - (M.win_conf.height / 2 + M.conf.bottom_offset)
    end
end

-- Get file symbol from devicons
function M.getFileSymbol(s)
    local file = s:split("/", true)
    local filename = file[#file]

    local ext = filename:split(".", true)
    ext = ext[#ext]

    local devicons = pcall(require, "nvim-web-devicons")
    if devicons then
        local icon, hl = require("nvim-web-devicons").get_icon(filename, ext)
        return icon, hl
    else
        return nil, nil
    end
end

-- Open buffer from line
function M.selBufNum(win, opt, count)
    local buf = nil

    -- Check for buffer number
    if count ~= 0 then
        local lines = api.nvim_buf_get_lines(0, 1, -1, true)

        for _, line in pairs(lines) do
            local linebuf = line:split(" ", true)[3]
            if tonumber(linebuf) == count then
                buf = linebuf
                break
            end
        end
        -- Or if it's just an ENTER
    else
        local l = api.nvim_get_current_line()
        buf = l:split(" ", true)[3]
    end

    M.close()

    if not buf then
        print "Buffer number not found!"
        return
    end

    api.nvim_set_current_win(win)
    vim.cmd(string.format(M.openOptions[opt], buf))
end

-- Preview buffer
function M.previewBuf()
    local l = api.nvim_get_current_line()
    local buf = l:split(" ", true)[3]

    -- Create the buffer for preview window
    M.prev_win = api.nvim_open_win(tonumber(buf), 1, M.preview_conf)
end

-- Close buffer from line
function M.closeBufNum(win)
    local l = api.nvim_get_current_line()
    local buf = l:split(" ", true)[3]

    local current_buf = api.nvim_win_get_buf(win)
    local jabs_buf = api.nvim_get_current_buf()

    if tonumber(buf) ~= current_buf then
        vim.cmd(string.format("bd %s", buf))
        local ln = api.nvim_win_get_cursor(0)[1]
        table.remove(M.bopen, ln - 1)

        M.refresh(jabs_buf)
    else
        api.nvim_notify("JABS: Cannot close current buffer!", 3, {})
    end

    vim.wo.number = false
    vim.wo.relativenumber = false
end

-- Parse ls string
function M.parseLs(buf)
    -- Quit immediately if ls output is empty
    if #M.bopen == 1 and M.bopen[1] == "" then
        return
    end

    for i, b in ipairs(M.bopen) do
        local si = 0 -- not empty split count
        local line = "" -- Line to be added to buffer
        local highlight = "" -- Line highlight group
        local linenr = "" -- Buffer line number

        for _, s in ipairs(b:split(" ", true)) do
            if s:len() == 0 then
                goto continue
            end
            si = si + 1
            -- Split with buffer information
            if si == 2 then
                -- If we're reading filename here, symbol is empty (prob. because of shada)
                if s:sub(1, 1) == '"' then
                    line = M.bufinfo["h"] .. " " .. line .. s .. " "
                    goto continue
                end

                highlight = M.highlight[s] or M.highlight[s:sub(1, s:len() - 1)]
                local symbol = M.bufinfo[s] or M.bufinfo[s:sub(1, s:len() - 1)]

                -- Fixes #3
                symbol = symbol or M.bufinfo["h"]

                line = symbol .. " " .. line
                -- Other non-empty splits (filename, RO, modified, ...)
            else
                if s:sub(2, 8) == "term://" then
                    line = line .. "Terminal" .. s:gsub("^.*:", ': "')
                else
                    if tonumber(s) ~= nil and si > 2 then
                        linenr = s
                    else
                        if s:sub(1, 4) ~= "line" and s ~= "" then
                            line = line .. (M.bufinfo[s] or s) .. " "
                        end
                    end
                end
            end
            ::continue::
        end

        -- Remove quotes from filename
        line = line:gsub('"', "")

        -- Add devicon
        local symbol = nil
        local icon_hl_group = nil
        if M.use_devicons then
            local filename = line:split(" ", true)
            filename = filename[#filename - 1]
            symbol, icon_hl_group = M.getFileSymbol(filename)

            if not symbol then
                if filename:match "Terminal" then
                    symbol = M.bufinfo["R"]
                else
                    symbol = M.default_file
                end
            end

            local escaped_filename = filename:gsub("(%W)", "%%%1")
            line = line:gsub(escaped_filename, symbol .. " " .. escaped_filename, 1)
        end

        -- Truncate line if too long
        local filename_space = M.win_conf.width - (linenr:len() + 2) - 3
        if line:len() > filename_space then
            line = line:gsub(string.rep("%S", line:len() - filename_space + 3), "...", 1)
        end

        -- Write line
        api.nvim_buf_set_text(buf, i, 1, i, line:len(), { line })

        -- Write line number
        local linenr_text = " " .. linenr

        -- Calculate offset caused by special characters (i.e. symbols)
        local special_chars = string.gmatch(string.gsub(line:gsub("%p", ""), "%s", ""), "%W%W%W")
        local offset = 0
        for ch in special_chars do
            offset = offset + ch:len() - 1
        end

        -- Add linenr at the end of line
        local start_col = 0
        if offset - linenr_text:len() > 0 then
            start_col = M.win_conf.width
        else
            start_col = M.win_conf.width + offset - linenr_text:len()
        end

        api.nvim_buf_set_text(buf, i, start_col, i, M.win_conf.width, { linenr_text })

        -- Highlight line and icon
        api.nvim_buf_add_highlight(buf, -1, highlight, i, 0, -1)
        if icon_hl_group then
            local pos = line:find(symbol, 1, true)
            api.nvim_buf_add_highlight(buf, -1, icon_hl_group, i, pos, pos + symbol:len())
        end
    end
end

-- Set floating window keymaps
function M.setKeymaps(win, buf)
    -- Basic window buffer configuration
    api.nvim_buf_set_keymap(
        buf,
        "n",
        M.keymap_conf.jump,
        string.format([[:<C-U>lua require'jabs'.selBufNum(%s, 'window', vim.v.count)<CR>]], win),
        { nowait = true, noremap = true, silent = true }
    )
    api.nvim_buf_set_keymap(
        buf,
        "n",
        M.keymap_conf.h_split,
        string.format([[:<C-U>lua require'jabs'.selBufNum(%s, 'hsplit', vim.v.count)<CR>]], win),
        { nowait = true, noremap = true, silent = true }
    )
    api.nvim_buf_set_keymap(
        buf,
        "n",
        M.keymap_conf.v_split,
        string.format([[:<C-U>lua require'jabs'.selBufNum(%s, 'vsplit', vim.v.count)<CR>]], win),
        { nowait = true, noremap = true, silent = true }
    )
    api.nvim_buf_set_keymap(
        buf,
        "n",
        M.keymap_conf.close,
        string.format([[:lua require'jabs'.closeBufNum(%s)<CR>]], win),
        { nowait = true, noremap = true, silent = true }
    )
    api.nvim_buf_set_keymap(
        buf,
        "n",
        M.keymap_conf.preview,
        string.format([[:lua require'jabs'.previewBuf()<CR>]], win),
        { nowait = true, noremap = true, silent = true }
    )

    -- Navigation keymaps
    api.nvim_buf_set_keymap(
        buf,
        "n",
        "q",
        ':lua require"jabs".close()<CR>',
        { nowait = true, noremap = true, silent = true }
    )
    api.nvim_buf_set_keymap(
        buf,
        "n",
        "<Esc>",
        ':lua require"jabs".close()<CR>',
        { nowait = true, noremap = true, silent = true }
    )
    api.nvim_buf_set_keymap(buf, "n", "<Tab>", "j", { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, "n", "<S-Tab>", "k", { nowait = true, noremap = true, silent = true })

    -- Prevent cursor from going to buffer title
    vim.cmd(string.format("au CursorMoved <buffer=%s> if line(\".\") == 1 | call feedkeys('j', 'n') | endif", buf))
end

function M.close()
    -- If JABS is closed using :q the window and buffer indicator variables
    -- are not reset, so we need to take this into account
    xpcall(function()
        api.nvim_win_close(M.main_win, false)
        api.nvim_buf_delete(M.main_buf, {})
        M.main_win = nil
        M.main_buf = nil
    end, function()
        M.main_win = nil
        M.main_buf = nil
        M.open()
    end)
end

-- Set autocmds for JABS window
function M.set_autocmds(buffer_nr, win_nr)
    api.nvim_create_autocmd({"BufLeave"}, {
        buffer = buffer_nr,
        callback = function()
            api.nvim_win_close(win_nr, 0)
        end
    })
end

function M.refresh(buf)
    local empty = {}
    for _ = 1, #M.bopen + 1 do
        empty[#empty + 1] = string.rep(" ", M.win_conf.width)
    end

    api.nvim_buf_set_option(buf, "modifiable", true)
    api.nvim_buf_set_lines(buf, 0, -1, false, empty)

    M.parseLs(buf)

    -- Draw title
    local title = "Open buffers:"
    api.nvim_buf_set_text(buf, 0, 1, 0, title:len() + 1, { title })
    api.nvim_buf_add_highlight(buf, -1, "Folded", 0, 0, -1)

    -- Disable modifiable when done
    api.nvim_buf_set_option(buf, "modifiable", false)
end

-- Floating buffer list
function M.open()
    M.bopen = api.nvim_exec(":ls", true):split("\n", true)
    local back_win = api.nvim_get_current_win()
    -- Create the buffer for the window
    if not M.main_buf and not M.main_win then
        M.updatePos()
        M.main_buf = api.nvim_create_buf(false, true)
        vim.bo[M.main_buf]["filetype"] = "JABSwindow"
        M.main_win = api.nvim_open_win(M.main_buf, 1, M.win_conf)
        if M.main_win ~= 0 then
            M.refresh(M.main_buf)
            M.setKeymaps(back_win, M.main_buf)
            M.set_autocmds(M.main_buf, M.main_win)
        end
    else
        M.close()
    end
end

return M
