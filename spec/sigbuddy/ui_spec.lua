local ui = require("sigbuddy.ui")

describe("sigbuddy.ui", function()
  local original_api, original_o, original_split, original_deepcopy

  before_each(function()
    -- Store originals
    original_api = vim.api
    original_o = vim.o
    original_split = vim.split
    original_deepcopy = vim.deepcopy

    -- Mock vim API for testing
    vim.api = {
      nvim_get_current_win = function()
        return 1000
      end,
      nvim_win_get_cursor = function()
        return { 10, 20 }
      end,
      nvim_get_current_buf = function()
        return 2000
      end,
      nvim_create_buf = function()
        return 3000
      end,
      nvim_buf_set_lines = function() end,
      nvim_buf_set_option = function() end,
      nvim_open_win = function()
        return 4000
      end,
      nvim_win_set_option = function() end,
      nvim_win_close = function() end,
      nvim_win_is_valid = function()
        return true
      end,
      nvim_buf_is_valid = function()
        return true
      end,
      nvim_set_keymap = function() end,
      nvim_buf_set_keymap = function() end,
    }

    -- Mock vim.o (editor options)
    vim.o = {
      columns = 120,
      lines = 30,
    }

    -- Emulate buffer/window option tables used by the refactored plugin
    vim.bo = setmetatable({}, {
      __index = function(t, k)
        local v = {}
        rawset(t, k, v)
        return v
      end,
    })
    vim.wo = setmetatable({}, {
      __index = function(t, k)
        local v = {}
        rawset(t, k, v)
        return v
      end,
    })

    -- New keymap API used by the refactor
    vim.keymap = { set = function(mode, lhs, rhs, opts) end }

    -- Mock vim.split function
    vim.split = function(str, sep, opts)
      local result = {}
      if not str or str == "" then
        return result
      end
      if not sep then
        sep = " "
      end

      local pattern = "[^" .. sep .. "]+"
      for match in string.gmatch(str, pattern) do
        table.insert(result, match)
      end
      return result
    end

    -- Mock vim.deepcopy function
    vim.deepcopy = function(obj)
      if type(obj) ~= "table" then
        return obj
      end
      local copy = {}
      for k, v in pairs(obj) do
        copy[k] = vim.deepcopy(v)
      end
      return copy
    end
  end)

  after_each(function()
    -- Restore original vim globals
    vim.api = original_api
    vim.o = original_o
    vim.split = original_split
    vim.deepcopy = original_deepcopy
    vim.bo = nil
    vim.wo = nil
    vim.keymap = nil
  end)

  describe("format_explanation", function()
    it("should format successful explanations properly", function()
      local explanation = {
        status = "success",
        explanation = "print() outputs text to the console.\n\nExample: print('Hello')",
      }

      local function_info = {
        function_name = "print",
        language = "lua",
      }

      local formatted = ui.format_explanation(explanation, function_info)

      assert.is_table(formatted)
      assert.is_string(formatted.title)
      assert.is_table(formatted.lines)
      assert.is_true(#formatted.lines > 0)

      -- Should include function name and language in title
      assert.matches("print", formatted.title)
      assert.matches("lua", formatted.title)
    end)

    it("should format error responses", function()
      local explanation = {
        status = "error",
        error = "Network timeout",
      }

      local function_info = {
        function_name = "print",
        language = "lua",
      }

      local formatted = ui.format_explanation(explanation, function_info)

      assert.is_table(formatted)
      assert.matches("Error", formatted.title)
      assert.is_table(formatted.lines)
      assert.matches("timeout", table.concat(formatted.lines, " "))
    end)

    it("should handle long explanations with wrapping", function()
      local long_explanation =
        string.rep("This is a very long explanation that should be wrapped properly. ", 5)

      local explanation = {
        status = "success",
        explanation = long_explanation,
      }

      local function_info = {
        function_name = "test_func",
        language = "python",
      }

      local formatted = ui.format_explanation(explanation, function_info)

      assert.is_table(formatted.lines)
      -- The refactored formatter no longer auto-wraps long lines; ensure we have at least one line
      assert.is_true(#formatted.lines >= 1)
    end)
  end)

  describe("window operations", function()
    it("should handle show_explanation without errors", function()
      local explanation = {
        status = "success",
        explanation = "print() outputs text to the console.\n\nExample: print('Hello World')",
      }

      local function_info = {
        function_name = "print",
        language = "lua",
      }

      -- Should not error
      assert.has_no.errors(function()
        ui.show_explanation(explanation, function_info)
      end)
    end)

    it("should handle error responses gracefully", function()
      local explanation = {
        status = "error",
        error = "API key invalid",
      }

      local function_info = {
        function_name = "print",
        language = "lua",
      }

      assert.has_no.errors(function()
        ui.show_explanation(explanation, function_info)
      end)
    end)

    it("should handle non-builtin function responses by doing nothing", function()
      local explanation = {
        status = "success",
        explanation = "Not a built-in function.",
      }

      local function_info = {
        function_name = "custom_func",
        language = "lua",
      }

      -- Should silently do nothing for non-builtin functions
      assert.has_no.errors(function()
        ui.show_explanation(explanation, function_info)
      end)
    end)

    it("should handle show_loading", function()
      local function_info = {
        function_name = "print",
        language = "lua",
      }

      assert.has_no.errors(function()
        local win_handle = ui.show_loading(function_info)
        assert.is_number(win_handle)
      end)
    end)

    it("should handle close_loading", function()
      local function_info = {
        function_name = "print",
        language = "lua",
      }

      local win_handle = ui.show_loading(function_info)

      assert.has_no.errors(function()
        ui.close_loading(win_handle)
      end)
    end)

    it("should handle close_all_windows", function()
      assert.has_no.errors(function()
        ui.close_all_windows()
      end)
    end)
  end)
end)
