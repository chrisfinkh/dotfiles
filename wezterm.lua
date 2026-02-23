local wezterm = require 'wezterm'
local config = {}
local act = wezterm.action

-- Cross-platform path handling
local function get_session_path()
  local home = wezterm.home_dir or os.getenv('HOME') or os.getenv('USERPROFILE') or '.'
  if wezterm.target_triple:find('windows') then
    return home:gsub('/', '\\') .. '\\Private\\Terminal Sessions\\'
  end
  return home .. '/Private/Terminal Sessions/'
end

local function ensure_directory_exists(dir)
  if wezterm.target_triple:find('windows') then
    os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '"')
  else
    os.execute('mkdir -p "' .. dir .. '"')
  end
end

local function get_pane_scrollback_text(pane)
  local dims = pane:get_dimensions()
  local nlines = dims.scrollback_rows or dims.viewport_rows or 1
  if nlines < 1 then
    nlines = dims.viewport_rows or 1
  end

  local ok, text = pcall(function()
    return pane:get_logical_lines_as_text(nlines)
  end)
  if ok and text then
    return text
  end

  ok, text = pcall(function()
    return pane:get_lines_as_text(nlines)
  end)
  if ok and text then
    return text
  end

  return ''
end

-- Save a pane's scrollback to a named file in the session directory
local function save_pane_to_file(pane, filename)
  if not pane or not pane.get_dimensions then
    return nil
  end

  local text = get_pane_scrollback_text(pane)
  local dir = get_session_path()
  ensure_directory_exists(dir)

  local full_path = dir .. filename
  local f = io.open(full_path, 'w')
  if f then
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    f:write('# Terminal Session ' .. timestamp .. '\n\n```\n')
    f:write(text)
    f:write('\n```\n')
    f:close()
    return full_path
  end
  return nil
end

-- Manual save (Cmd+Shift+S / Ctrl+Shift+S)
wezterm.on('save-session', function(window, pane)
  local timestamp = os.date('%Y-%m-%d_%H-%M-%S')
  local filepath = save_pane_to_file(pane, timestamp .. '.md')
  if filepath then
    window:toast_notification('WezTerm', 'Session saved to ' .. filepath, nil, 3000)
  else
    window:toast_notification('WezTerm', 'Failed to save session', nil, 3000)
  end
end)

-- Periodic auto-save: rolling snapshot per pane (overwrites each cycle)
local autosave_interval_secs = 300 -- 5 minutes
local last_autosave = 0

wezterm.on('update-status', function(window)
  local now = os.time()
  if now - last_autosave < autosave_interval_secs then
    return
  end
  last_autosave = now

  for _, tab in ipairs(window:mux_window():tabs()) do
    for _, pane_info in ipairs(tab:panes_with_info()) do
      local pane = pane_info.pane
      save_pane_to_file(pane, 'auto-pane-' .. tostring(pane:pane_id()) .. '.md')
    end
  end
end)

config.font_size = 20.0
config.scrollback_lines = 50000
config.send_composed_key_when_left_alt_is_pressed = true
config.send_composed_key_when_right_alt_is_pressed = true

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
