local M = {}

-- Get surrounding context for better AI understanding
local function get_context(lines, current_line_num)
  local context_lines = {}
  local start_line = math.max(1, current_line_num - 1)
  local end_line = math.min(#lines, current_line_num + 1)

  for i = start_line, end_line do
    local line = lines[i]
    if line and line:match("%S") then
      -- trim leading whitespace only (preserve indentation-aware content after)
      context_lines[#context_lines + 1] = line:gsub("^%s+", "")
    end
  end

  return table.concat(context_lines, "\n")
end

-- Returns word, start_pos, end_pos (1-indexed) under cursor if any.
local function get_word_bounds(text, cursor_col)
  if not text or text == "" or cursor_col < 0 then
    return nil, nil, nil
  end

  -- cursor_col comes in 0-indexed from Neovim API; convert to 1-indexed position
  local pos = math.min(#text, cursor_col + 1)
  pos = math.max(1, pos)

  -- find start
  local start_pos = pos
  while start_pos > 1 and text:sub(start_pos - 1, start_pos - 1):match("[%w_]") do
    start_pos = start_pos - 1
  end

  -- find end
  local end_pos = pos
  while end_pos <= #text and text:sub(end_pos, end_pos):match("[%w_]") do
    end_pos = end_pos + 1
  end
  end_pos = end_pos - 1

  if start_pos > end_pos then
    return nil, nil, nil
  end

  return text:sub(start_pos, end_pos), start_pos, end_pos
end

-- Function call detection helper functions
local function escape_pattern(text)
  return text:gsub("([%.%+%-%%%(%)%[%]%*%?%^%$])", "%%%1")
end

-- Method detection helper functions
local function get_line_segment(line, start_pos, end_pos)
  local before_word_start = math.max(1, start_pos - 20)
  local after_word_end = math.min(#line, end_pos + 20)
  return line:sub(before_word_start, after_word_end)
end

local function find_full_method(line_segment, word)
  local pattern = "([%w_%.]+%." .. escape_pattern(word) .. ")%s*%("
  return line_segment:match(pattern)
end

local function find_method_name(line_segment, word)
  local pattern = escape_pattern(word) .. "%.([%w_]+)%s*%("
  return line_segment:match(pattern)
end

-- Fallback function detection using regex (for testing and when tree-sitter unavailable)
local function fallback_get_function_info(line, col)
  local word, start_pos, end_pos = get_word_bounds(line, col)
  if not word then
    return nil
  end

  -- Check for method call pattern (object.method)
  local line_segment = get_line_segment(line, start_pos, end_pos)

  -- Pattern: object.method() where cursor is on method
  local full_method = find_full_method(line_segment, word)
  if full_method then
    return full_method, "method"
  end

  -- Pattern: object.method() where cursor is on object
  local method_name = find_method_name(line_segment, word)
  if method_name then
    return word .. "." .. method_name, "method"
  end

  -- Check for simple function call: look for '(' after the word
  local after_word = line:sub(end_pos + 1):match("^%s*(.)")
  if after_word == "(" then
    return word, "function"
  end

  return nil
end

-- Tree-sitter helper functions
local function check_treesitter_availability()
  return pcall(require, "vim.treesitter")
end

local function get_parser(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if ok and parser then
    return parser
  end
  return nil
end

local function get_node_at_cursor(buf, row, col)
  return vim.treesitter.get_node({
    bufnr = buf,
    pos = { row, col },
  })
end

local function is_function_call_node(node_type)
  return node_type == "function_call"
    or node_type == "call_expression"
    or node_type == "call"
    or node_type == "method_invocation"
end

local function get_function_nodes(current_node, field)
  local function_nodes = current_node:field(field)
  if function_nodes and function_nodes[1] then
    return function_nodes[1]
  end
  return nil
end

local function extract_function_name(buf, function_node)
  if not function_node then
    return nil
  end
  local ok, function_name = pcall(vim.treesitter.get_node_text, function_node, buf)
  if ok and function_name and function_name ~= "" then
    local call_type = function_name:match("%.") and "method" or "function"
    return function_name, call_type
  end
  return nil
end

local function try_extract_function_name(buf, current_node)
  local function_fields = { "function", "name", "method" }
  for _, field in ipairs(function_fields) do
    local function_node = get_function_nodes(current_node, field)
    if function_node then
      local function_name, call_type = extract_function_name(buf, function_node)
      if function_name then
        return function_name, call_type
      end
    end
  end
  return nil
end

-- Tree-sitter based function detection (when available)
local function treesitter_get_function_info(buf, row, col)
  -- Check if treesitter is available and has parser for this language
  if not check_treesitter_availability() then
    return nil
  end

  local parser = get_parser(buf)
  if not parser then
    return nil
  end

  -- Ensure we have a parsed tree available
  local trees = parser:parse()
  if not trees or not trees[1] then
    return nil
  end

  -- Get node under cursor
  local node = get_node_at_cursor(buf, row, col)
  if not node then
    return nil
  end

  -- Look for function call in the AST
  local current_node = node
  for _ = 1, 5 do -- Traverse up max 5 levels
    if not current_node then
      break
    end

    local node_type = current_node:type()

    -- Check for function call node types
    if is_function_call_node(node_type) then
      -- Try to get function name
      local function_name, call_type = try_extract_function_name(buf, current_node)
      if function_name then
        return function_name, call_type
      end
    end

    local parent_node = current_node:parent()
    if not parent_node then
      break
    end

    current_node = parent_node
  end

  return nil
end

-- Buffer information helper functions
local function get_buffer_info()
  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- Convert to 0-indexed
  local col = cursor[2]
  return buf, row, col
end

local function get_buffer_lines(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function validate_buffer_lines(all_lines, row)
  return all_lines and #all_lines > 0 and row < #all_lines
end

local function get_current_line(all_lines, row)
  return all_lines[row + 1] -- Convert to 1-indexed for array access
end

local function validate_current_line(current_line)
  return current_line and current_line ~= ""
end

local function get_buffer_language(buf)
  local language = vim.api.nvim_buf_get_option(buf, "filetype")
  return language and language ~= "" and language or nil
end

-- Main function detection
function M.get_function_under_cursor()
  local buf, row, col = get_buffer_info()

  -- Get all lines for context
  local all_lines = get_buffer_lines(buf)
  if not validate_buffer_lines(all_lines, row) then
    return nil
  end

  local current_line = get_current_line(all_lines, row)
  if not validate_current_line(current_line) then
    return nil
  end

  -- Get filetype/language
  local language = get_buffer_language(buf)
  if not language then
    return nil
  end

  -- Try tree-sitter first, fallback to regex
  local function_name, call_type = treesitter_get_function_info(buf, row, col)

  if not function_name then
    -- Fallback to regex-based detection
    function_name, call_type = fallback_get_function_info(current_line, col)
  end

  if not function_name then
    vim.notify("No function or method call found under cursor", vim.log.levels.INFO)
    return nil
  end

  -- Get context for AI
  local context = get_context(all_lines, row + 1)

  return {
    function_name = function_name,
    language = language,
    type = call_type,
    context = context,
    line = current_line,
    column = col,
  }
end

return M
