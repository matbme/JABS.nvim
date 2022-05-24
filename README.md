# JABS.nvim
**J**ust **A**nother **B**uffer **S**witcher is a minimal buffer switcher window for Neovim written in Lua.

## How minimal? One command and one window minimal!

JABS shows exactly what you would expect to see with `:buffers` or `:ls`, but in a prettier and interactive way.

![](https://raw.githubusercontent.com/matbme/JABS.nvim/main/screenshots/JABS_demo.gif)

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
All configuration happens within the setup function, which you *must* call inside your `init.lua` file even if you want to stick with the defaut values. Alternatively, you can redefine a number of parameters to tweak JABS to your liking such as the window's size, border, and placement.

A minimal configuration keeping all the defaults would look like this:

```lua
require 'jabs'.setup {}
```

A more complex config changing every default value would look like this:

```lua
require 'jabs'.setup {
    -- Options for the main window
    position = 'center', -- center, corner. Default corner
    width = 80, -- default 50
    height = 20, -- default 10
    border = 'single', -- none, single, double, rounded, solid, shadow, (or an array or chars). Default shadow

    -- Options for preview window
    preview_position = 'left', -- top, bottom, left, right. Default top
    preview = {
        width = 40, -- default 70
        height = 60, -- default 30
        border = 'single', -- none, single, double, rounded, solid, shadow, (or an array or chars). Default double
    },
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

### Symbols

<img src="screenshots/icons.png"/>

## Future work

JABS is in its infancy and there's still a lot to be done. Here's the currently planned features:

- [x] Switch to buffer by typing its number
- [x] Preview buffer
- [x] Close buffer with keymap (huge thanks to [@garymjr](https://github.com/garymjr))
- [x] Open buffer in split
- [ ] Sort modes (maybe visible and alternate on top)
- [ ] Custom keymaps

Suggestions are always welcome 🙂!
