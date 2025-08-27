local M = {}

-- Keep track of open windows
local active_windows = {}

-- Simple popup window
local function create_popup(title, content_lines, ui_config)
  local buf = vim.api.nvim_create_buf(false, true)

  local width = math.min(ui_config.max_width or 80, vim.o.columns - 4)
  local height = math.min(ui_config.max_height or 20, #content_lines + 2, vim.o.lines - 4)

  local config = {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = ui_config.border or "rounded",
    title = title,
    title_pos = "center",
  }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content_lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "markdown"

  local win = vim.api.nvim_open_win(buf, true, config)  -- Focus the window

  -- Enable text wrapping
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].breakindent = true

  -- Close keymaps
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, noremap = true, silent = true })
  
  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, noremap = true, silent = true })

  return win
end

-- Format explanation for display
function M.format_explanation(explanation, function_info)
  local title
  local content_lines = {}

  if explanation.status == "success" then
    title = string.format("󰡱 %s (%s)", function_info.function_name, function_info.language)
    local lines = vim.split(explanation.explanation, "\n", { plain = true })
    for _, line in ipairs(lines) do
      table.insert(content_lines, line)
    end
  elseif explanation.status == "error" then
    title = " Error"
    table.insert(content_lines, "Failed to get explanation:")
    table.insert(content_lines, explanation.error or "Unknown error")
  else
    title = " Unknown Response"
    table.insert(content_lines, "Unexpected response format")
  end

  return { title = title, lines = content_lines }
end

function M.show_explanation(explanation, function_info)
  if
    explanation.status == "success"
    and explanation.explanation
    and explanation.explanation:match("Not a built%-in function")
  then
    return
  end

  M.close_all_windows()

  local ui_config = {}
  local success, config = pcall(require, "sigbuddy.config")
  if success and config.options and config.options.ui then
    ui_config = config.options.ui
  end

  local formatted = M.format_explanation(explanation, function_info)
  local win = create_popup(formatted.title, formatted.lines, ui_config)
  table.insert(active_windows, win)

  return win
end

function M.show_loading(function_info)
  M.close_all_windows()

  local ui_config = {}
  local success, config = pcall(require, "sigbuddy.config")
  if success and config.options and config.options.ui then
    ui_config = config.options.ui
  end

  local title = string.format("󰇘 Looking up %s...", function_info.function_name)
  local content_lines = {
    "Querying AI for explanation...",
    "",
    "Press 'q' or <Esc> to cancel",
  }

  local win = create_popup(title, content_lines, ui_config)
  table.insert(active_windows, win)

  return win
end

function M.close_loading(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
    for i, w in ipairs(active_windows) do
      if w == win then
        table.remove(active_windows, i)
        break
      end
    end
  end
end

function M.close_window(win)
  M.close_loading(win)
end

function M.close_all_windows()
  for _, win in ipairs(active_windows) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  active_windows = {}
end

return M

