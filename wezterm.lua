local wezterm = require 'wezterm'
  local config = {}
  local act = wezterm.action

  -- Cross-platform path handling
  local function get_obsidian_path()
      if wezterm.target_triple:find("windows") then
          return os.getenv("USERPROFILE") .. "\\Private\\Terminal Sessions\\"
      else
          return os.getenv("HOME") .. "/Private/Terminal Sessions/"
      end
  end

  -- Save session helper
  local function save_pane_content(pane, prefix)
      local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
      local dir = get_obsidian_path()
      local filepath = dir .. prefix .. timestamp .. ".md"

      local dims = pane:get_dimensions()
      local text = pane:get_lines_as_text(dims.scrollback_top, dims.cursor_row)

      os.execute('mkdir -p "' .. dir .. '" 2>/dev/null || mkdir "' .. dir .. '" 2>nul')
      local f = io.open(filepath, "w")
      if f then
          f:write("# Terminal Session " .. timestamp .. "\n\n```\n")
          f:write(text)
          f:write("\n```\n")
          f:close()
          return filepath
      end
      return nil
  end

  -- Manual save (Cmd+Shift+S)
  wezterm.on('save-session', function(window, pane)
      local filepath = save_pane_content(pane, "")
      if filepath then
          window:toast_notification('WezTerm', 'Session saved to ' .. filepath, nil, 3000)
      end
  end)

  -- Auto-save when pane closes
  wezterm.on('pane-closed', function(pane)
      save_pane_content(pane, "auto-")
  end)

  config.font_size = 20.0
  config.scrollback_lines = 50000

  config.keys = {
      -- Save session
      { key = 'S', mods = 'CMD|SHIFT', action = act.EmitEvent('save-session') },
      { key = 'S', mods = 'CTRL|SHIFT', action = act.EmitEvent('save-session') },

      -- Cmd+Delete: delete entire line
      { key = 'Backspace', mods = 'CMD', action = act.SendKey { key = 'u', mods = 'CTRL' } },

      -- Cmd+Left: jump to start of line
      { key = 'LeftArrow', mods = 'CMD', action = act.SendKey { key = 'a', mods = 'CTRL' } },

      -- Cmd+Right: jump to end of line
      { key = 'RightArrow', mods = 'CMD', action = act.SendKey { key = 'e', mods = 'CTRL' } },

      -- Option+Left/Right for word jumping
      { key = 'LeftArrow', mods = 'OPT', action = act.SendKey { key = 'b', mods = 'ALT' } },
      { key = 'RightArrow', mods = 'OPT', action = act.SendKey { key = 'f', mods = 'ALT' } },

      -- Option+Delete for delete word
      { key = 'Backspace', mods = 'OPT', action = act.SendKey { key = 'w', mods = 'CTRL' } },
  }

  return config