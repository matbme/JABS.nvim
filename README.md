# JABS.nvim
**J**ust **A**nother **B**uffer **S**witcher is a minimal buffer switcher window for Neovim written in Lua. 

## How minimal? One command and one window minimal!

JABS shows exactly what you would expect to see with `:buffers` or `:ls`, but in a prettier and interactive way.

<img src="screenshots/buf_window.png"/>

## Requirements

- Neovim ≥ v0.5
- A patched [nerd font](https://www.nerdfonts.com/) for the buffer icons

## Installation

You can install JABS with your plugin manager of choice. If you use `packer.nvim`, simply add to your plugin list:

``` lua
use 'matbme/JABS.nvim'
```

## Usage

As previously mentioned, JABS only has one command: `:JABSOpen`, which opens JABS' window.

By default, you can navigate between buffers with `j` and `k` as well as `<Tab>` and `<S-Tab>`, and jump to a buffer with `<CR>`. When switching buffers the window closes automatically, but it can also be closed with `<Esc>` or `q`.

You can also open a preview window for the buffer selected under the cursor with `<S-p>`, which by default appears above JABS' window. See below how to change its default behavior.

## Configuration
All configuration happens within the setup function, where you can change the window's size, border, and placement. JABS appears by default on the bottom right, but you can change it to be in any corner or even in the center:

```lua
-- (Optional) easy way to get Neovim current size.
local ui = vim.api.nvim_list_uis()[1]

require 'jabs'.setup {
    position = 'corner', -- center, corner
   	width = 50,
   	height = 10,
   	border = 'shadow', -- none, single, double, rounded, solid, shadow, (or an array or chars)

    -- Options for preview window
    preview_position = 'left', -- top, bottom, left, right
    preview = {
        width = 40,
        height = 30,
        border = 'double', -- none, single, double, rounded, solid, shadow, (or an array or chars)
    },

   	-- the options below are ignored when position = 'center'
   	col = ui.width,  -- Window appears on the right
   	row = ui.height/2, -- Window appears in the vertical middle
}
```

### Default Keymaps

| Key               | Action                          |
|-------------------|---------------------------------|
| j or `<Tab>`      | navigate down                   |
| k or `<S-Tab>`    | navigate up                     |
| D                 | close buffer                    |
| `<CR>`            | jump to buffer                  |
| s                 | open buffer in horizontal split |
| v                 | open buffer in vertical split   |
| `<S-p>`           | open preview for buffer         |

If you don't feel like manually navigating to the buffer you want to open, you can type its number before `<CR>`, `s`, or `v` to quickly split or switch to it.

### Color coding

- Your current visible buffers are shown in a green background
- The alternate buffer (`<C-^>`) is shown in yellow
- All other buffers are shown in plain white/green (depending on colorscheme)

### Symbols

<img src="screenshots/icons.png"/>

## Future work

JABS is in its infancy and there's still a lot to be done. Here's the currently planned features:

- [x] Switch to buffer by typing its number
- [x] Preview buffer
- [x] Close buffer with keymap (huge thanks to [@garymjr](https://github.com/garymjr))
- [x] Open buffer in split
- [ ] Sort modes (maybe visible and alternate on top)

Suggestions are always welcome 🙂!
