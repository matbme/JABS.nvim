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

    M.sort_mru = c.sort_mru or false
    M.split_filename = c.split_filename or false
    M.split_filename_path_width = c.split_filename_path_width or 0

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
    M.use_devicons = not (c.use_devicons == false)

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
        relative = "win",
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

        top_offset = c.offset.top or 0,
        bottom_offset = c.offset.bottom or 0,
        left_offset = c.offset.left or 0,
        right_offset = c.offset.right or 0,

        preview_position = c.preview_position or "top",
    }

    -- TODO: Convert to a table
    if M.conf.preview_position == "top" then
        M.preview_conf.col = M.win_conf.width / 2 - M.preview_conf.width / 2
        M.preview_conf.row = -M.preview_conf.height - 2

        if M.win_conf.border ~= "none" then
            M.preview_conf.row = M.preview_conf.row - 1
        end
    elseif M.conf.preview_position == "bottom" then
        M.preview_conf.col = M.win_conf.width / 2 - M.preview_conf.width / 2
        M.preview_conf.row = M.win_conf.height

        if M.win_conf.border ~= "none" then
            M.preview_conf.row = M.preview_conf.row + 1
        end
    elseif M.conf.preview_position == "right" then
        M.preview_conf.col = M.win_conf.width
        M.preview_conf.row = M.win_conf.height / 2 - M.preview_conf.height / 2

        if M.win_conf.border ~= "none" then
            M.preview_conf.col = M.preview_conf.col + 1
        end
    elseif M.conf.preview_position == "left" then
        M.preview_conf.col = -M.preview_conf.width
        M.preview_conf.row = M.win_conf.height / 2 - M.preview_conf.height / 2

        if M.win_conf.border ~= "none" then
            M.preview_conf.col = M.preview_conf.col - 1
        end
    end

    M.updatePos()
end

--[[*******************************************************
    ******************** BEGIN UTILS **********************
    *******************************************************]]
--

local function iter2array(...)
    local arr = {}
    for v in ... do
        arr[#arr + 1] = v
    end
    return arr
end

local function getBufferHandleFromLine(line)
    local handle = iter2array(string.gmatch(line, "[^%s]+"))[2]
    return assert(tonumber(handle))
end

-- Get file symbol from devicons
local function getFileSymbol(filename)
    local devicons = pcall(require, "nvim-web-devicons")
    if not devicons then
        return "", nil
    end

    local ext = filename
    while string.match(ext, "%.(.*)$") do
        ext = string.match(ext, "%.(.*)$")
    end

    print(ext)
    local symbol, hl = require("nvim-web-devicons").get_icon(filename, ext)
    if not symbol then
        symbol = M.default_file
    end

    return symbol, hl
end

local function getBufferIcon(flags)
    flags = flags ~= "" and flags or "h"

    -- if flags do not end with a or h extract trailing char (-> -, =, +, R, F)
    local iconFlag = string.match(flags, "([^ah])$")
    iconFlag = iconFlag or flags

    -- extract '#' or '.*[ah]'
    local hlFlag = string.match(flags, "(.[ah#])")
    hlFlag = hlFlag or flags

    return M.bufinfo[iconFlag], M.highlight[hlFlag]
end

local function formatFilename(filename, filename_max_length)
    local function trunc_filename(fn, fn_max)
        if string.len(fn) <= fn_max then
            return fn
        end

        local substr_length = fn_max - string.len "..."
        if substr_length <= 0 then
            return string.rep(".", fn_max)
        end

        return "..." .. string.sub(fn, -substr_length)
    end

    local function split_filename(fn)
        return string.match(fn, "(.-)([^\\/]-%.?[^%.\\/]*)$")
    end

    filename = string.gsub(filename, "term://", "Terminal: ", 1)

    if M.split_filename then
        local path, file = split_filename(filename)
        local path_width = M.split_filename_path_width
        local file_width = filename_max_length - M.split_filename_path_width
        filename = string.format(
            "%-" .. file_width .. "s%-" .. path_width .. "s",
            trunc_filename(file, file_width),
            trunc_filename(path, path_width)
        )
    else
        filename = trunc_filename(filename, filename_max_length)
    end

    return string.format("%-" .. filename_max_length .. "s", filename)
end

--[[*****************************************************
    ******************** END UTILS **********************
    *****************************************************]]
--

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

-- Open buffer from line
function M.selBufNum(win, opt, count)
    local buf = nil

    -- Check for buffer number
    if count ~= 0 then
        local lines = api.nvim_buf_get_lines(0, 1, -1, true)

        for _, line in pairs(lines) do
            local buffer_handle = getBufferHandleFromLine(line)
            if buffer_handle == count then
                buf = buffer_handle
                break
            end
        end
        -- Or if it's just an ENTER
    else
        buf = getBufferHandleFromLine(api.nvim_get_current_line())
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
    local buf = getBufferHandleFromLine(vim.api.nvim_get_current_line())

    -- Create the buffer for preview window
    M.prev_win = api.nvim_open_win(
        buf,
        false,
        vim.tbl_extend("force", M.preview_conf, {
            win = M.main_win,
        })
    )
    api.nvim_set_current_win(M.prev_win)

    -- Close preview with "q"
    api.nvim_buf_set_keymap(
        buf,
        "n",
        "q",
        [[:lua require'jabs'.closePreviewBuf()<CR>]],
        { nowait = true, noremap = true, silent = true }
    )

    -- Or close preview when cursor leaves window
    api.nvim_create_autocmd({ "WinLeave" }, {
        group = "JABS",
        callback = function()
            M.closePreviewBuf()
            return true
        end,
    })
end

function M.closePreviewBuf()
    if M.prev_win then
        api.nvim_win_close(M.prev_win, false)
        M.prev_win = nil
    end
end

-- Close buffer from line
function M.closeBufNum(win)
    local buf = getBufferHandleFromLine(api.nvim_get_current_line())

    local current_buf = api.nvim_win_get_buf(win)
    local jabs_buf = api.nvim_get_current_buf()

    if buf ~= current_buf then
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
    for i, ls_line in ipairs(M.bopen) do
        -- extract data from ls string
        local match_cmd = '(%d+)%s+([^%s]*)%s+([^%s]?)%s+"(.*)"'
        if not M.sort_mru then
            match_cmd = match_cmd .. "%s*line%s(%d+)"
        else
            -- dummy so we get '' as result for linenr
            match_cmd = match_cmd .. "(%d*)"
        end

        local buffer_handle, flags, modified, filename, linenr = string.match(ls_line, match_cmd)

        -- get symbol and icon
        local fn_symbol, fn_symbol_hl = "", nil
        if M.use_devicons then
            fn_symbol, fn_symbol_hl = getFileSymbol(filename)
        end
        local icon, icon_hl = getBufferIcon(flags)

        local modified_icon = M.bufinfo[modified] or " "

        -- format preLine and postLine
        local preLine = string.format("%s %3d %s %s ", icon, buffer_handle, modified_icon, fn_symbol)
        local postLine = linenr ~= "" and string.format("  %3d ", linenr) or ""

        -- some symbols magic, they increase the string.len by more
        -- than 1 and this is a magic trick to get the extra width
        local extra_width = #preLine + #postLine - #string.gsub(preLine .. postLine, "[\128-\191]", "")

        -- determine filename field length and format filename
        local filename_max_length = M.win_conf.width - #preLine - #postLine + extra_width
        local filename_str = formatFilename(filename, filename_max_length)

        -- concat final line for the buffer
        local line = preLine .. filename_str .. postLine

        -- set line and highligh
        api.nvim_buf_set_lines(buf, i, i + 1, true, { line })
        api.nvim_buf_add_highlight(buf, -1, icon_hl, i, 0, -1)
        if fn_symbol_hl and fn_symbol ~= "" then
            local pos = string.find(line, fn_symbol, 1, true)
            api.nvim_buf_add_highlight(buf, -1, fn_symbol_hl, i, pos, pos + string.len(fn_symbol))
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

    api.nvim_clear_autocmds {
        group = "JABS",
    }
end

-- Set autocmds for JABS window
function M.set_autocmds()
    api.nvim_create_augroup("JABS", { clear = true })

    api.nvim_create_autocmd({ "WinEnter" }, {
        group = "JABS",
        callback = function()
            if api.nvim_get_current_win() ~= M.main_win and M.prev_win == nil then
                M.close()
                return true
            end
        end,
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
    local ls_result = api.nvim_exec(M.sort_mru and ":ls t" or ":ls", true)
    M.bopen = iter2array(string.gmatch(ls_result, "([^\n]+)"))

    if #M.bopen == 0 then
        print "No buffer in list...."
        return
    end

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
            M.set_autocmds()
        end
    else
        M.close()
    end
end

return M
