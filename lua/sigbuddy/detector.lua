local M = {}

-- Get surrounding context for better AI understanding
local function get_context(lines, current_line_num, function_name)
  local context_lines = {}
  local start_line = math.max(1, current_line_num - 1)
  local end_line = math.min(#lines, current_line_num + 1)

  for i = start_line, end_line do
    if lines[i] and lines[i]:match("%S") then -- Skip empty lines
      local trimmed_line = lines[i]:gsub("^%s+", "") -- Trim leading whitespace
      table.insert(context_lines, trimmed_line)
    end
  end

  return table.concat(context_lines, "\n")
end

-- Fallback function detection using regex (for testing and when tree-sitter unavailable)
local function fallback_get_function_info(line, col, language)
  -- Helper function to extract word under cursor position
  local function get_word_under_cursor(text, cursor_col)
    if not text or text == "" or cursor_col < 0 then
      return ""
    end

    if cursor_col >= #text then
      cursor_col = #text - 1
    end

    -- Find word boundaries (alphanumeric + underscore)
    local start_pos = cursor_col
    local end_pos = cursor_col

    -- Move backward to find start of word
    while start_pos > 0 and text:sub(start_pos, start_pos):match("[%w_]") do
      start_pos = start_pos - 1
    end
    if not text:sub(start_pos + 1, start_pos + 1):match("[%w_]") then
      start_pos = start_pos + 1
    end

    -- Move forward to find end of word
    while end_pos < #text and text:sub(end_pos + 1, end_pos + 1):match("[%w_]") do
      end_pos = end_pos + 1
    end

    if start_pos <= end_pos then
      return text:sub(start_pos + 1, end_pos)
    else
      return ""
    end
  end

  -- Check if word is followed by parentheses (function call)
  local function is_function_call(text, word, cursor_col)
    if not word or word == "" then
      return false
    end

    -- Find the word in the line
    local word_pattern = "%f[%w_]"
      .. word:gsub("([%.%+%-%%%(%)%[%]%*%?%^%$])", "%%%1")
      .. "%f[^%w_]"
    local word_start, word_end = text:find(word_pattern)

    if not word_start then
      return false
    end

    -- Check if cursor is within the word
    if cursor_col < word_start - 1 or cursor_col >= word_end then
      return false
    end

    -- Look for opening parenthesis after the word
    local after_word = text:sub(word_end + 1):match("^%s*(.)")
    return after_word == "("
  end

  local word = get_word_under_cursor(line, col)
  if not word or word == "" then
    return nil
  end

  -- Check for method call pattern (object.method)
  local before_word_start = math.max(1, col - #word - 20)
  local after_word_end = math.min(#line, col + #word + 20)
  local line_segment = line:sub(before_word_start, after_word_end)

  -- Pattern: object.method() where cursor is on method
  local full_method = line_segment:match(
    "([%w_%.]+%." .. word:gsub("([%.%+%-%%%(%)%[%]%*%?%^%$])", "%%%1") .. ")%s*%("
  )
  if full_method then
    return full_method, "method"
  end

  -- Pattern: object.method() where cursor is on object
  local method_pattern = word:gsub("([%.%+%-%%%(%)%[%]%*%?%^%$])", "%%%1") .. "%.([%w_]+)%s*%("
  local method_name = line_segment:match(method_pattern)
  if method_name then
    return word .. "." .. method_name, "method"
  end

  -- Check for simple function call
  if is_function_call(line, word, col) then
    return word, "function"
  end

  return nil
end

-- Tree-sitter based function detection (when available)
local function treesitter_get_function_info(buf, row, col, language)
  -- Check if treesitter is available and has parser for this language
  local has_treesitter = pcall(require, "vim.treesitter")
  if not has_treesitter then
    return nil
  end

  local has_parser, parser = pcall(vim.treesitter.get_parser, buf, language)
  if not has_parser then
    return nil
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

  -- Get node under cursor
  local node = vim.treesitter.get_node({
    bufnr = buf,
    pos = { row, col },
  })

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
    if
      node_type == "function_call"
      or node_type == "call_expression"
      or node_type == "call"
      or node_type == "method_invocation"
    then
      -- Try to get function name
      local function_fields = { "function", "name", "method" }
      for _, field in ipairs(function_fields) do
        local function_nodes = current_node:field(field)
        if function_nodes and function_nodes[1] then
          local function_node = function_nodes[1]
          local source = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
          if source and #source > 0 and function_node then
            local ok, function_name = pcall(vim.treesitter.get_node_text, function_node, source)
            if ok and function_name and function_name ~= "" then
              local call_type = function_name:match("%.") and "method" or "function"
              return function_name, call_type
            end
          end
        end
      end
    end

    current_node = current_node:parent()
  end

  return nil
end

function M.get_function_under_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- Convert to 0-indexed
  local col = cursor[2]

  -- Get all lines for context
  local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if not all_lines or #all_lines == 0 or row >= #all_lines then
    return nil
  end

  local current_line = all_lines[row + 1] -- Convert to 1-indexed for array access
  if not current_line or current_line == "" then
    return nil
  end

  -- Get filetype/language
  local language = vim.api.nvim_buf_get_option(buf, "filetype")
  if not language or language == "" then
    return nil
  end

  -- Try tree-sitter first, fallback to regex
  local function_name, call_type = treesitter_get_function_info(buf, row, col, language)

  if not function_name then
    -- Fallback to regex-based detection
    function_name, call_type = fallback_get_function_info(current_line, col, language)
  end

  if not function_name then
    return nil
  end

  -- Get context for AI
  local context = get_context(all_lines, row + 1, function_name) -- Convert back to 1-indexed

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
