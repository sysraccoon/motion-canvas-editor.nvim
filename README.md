# motion-canvas-editor.nvim

Save neovim buffer state as json, that can be used as part of animation inside motion canvas
(see [motion-canvas-editor](https://github.com/sysraccoon/motion-canvas-editor) library for additional information)

## Basic Usage

NeoVim workflow:

1. Start new session with command `:MCEStartSession` (or by pressing keymap `<leader>ms`)
2. Change viewport position with command `:MCEScrollViewportToCursor` (or by pressing keymap `<leader>mz`)
3. Modify buffer
4. Push snapshot with command `:MCEPushSnapshot` (or by pressing keymap `<leader>mn`)
5. End session if complete, otherwise goto 2

## Installation

Minimal setup with [lazy.nvim](https://github.com/folke/lazy.nvim) package manager:

```lua
{
  "sysraccoon/motion-canvas-editor.nvim",
  opts = {},
}
```

## Configuration

Default configuration options:

```lua
{
	viewport_height = 24, -- set viewport line count that can be present in animation
	viewport_highlight = "#313244", -- set viewport indicator background color
	auto_save = true, -- automatically save session when snapshot list modified
	default_session_path = "mce-session.json", -- default session file name
	default_commands = true, -- enable default commands
	default_keymaps = true, -- enable default keymaps
}
```

## Default Commands

| command name                 | lua name                    | description                                                                                 |
| ---------------------------- | --------------------------- | ------------------------------------------------------------------------------------------- |
| `:MCEStartSession`           | `start_session`             | Start new session. Fail if file exist                                                       |
| `:MCELoadSession`            | `load_session`              | Load session file. Fail if file not exist                                                   |
| `:MCETryLoadSession`         | `try_load_session`          | Try load session file or start new session if file not exist                                |
| `:MCEEndSession`             | `end_session`               | End active session and save result to file                                                  |
| `:MCEWriteSession`           | `write_session`             | Write snapshot to session file                                                              |
| `:MCEPushSnapshot`           | `push_snapshot`             | Push current buffer to snapshot list.\\ Write result to session file if 'auto_save' enabled |
| `:MCEScrollViewportToCursor` | `scroll_viewport_to_cursor` | Scroll viewport to cursor                                                                   |

## Default Keymaps

| mods  | keys       | action                      |
| ----- | ---------- | --------------------------- |
| n     | <leader>ms | M.start_session             |
| n     | <leader>ma | M.try_load_session          |
| n     | <leader>ml | M.load_session              |
| n     | <leader>me | M.end_session               |
| n     | <leader>mw | M.write_session             |
| n v x | <leader>mn | M.push_snapshot             |
| n     | <leader>mz | M.scroll_viewport_to_cursor |
