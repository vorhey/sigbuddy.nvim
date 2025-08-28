local detector = require("sigbuddy.detector")

describe("sigbuddy.detector", function()
  describe("get_function_under_cursor", function()
    it("should return nil when no function is found", function()
      -- Mock vim API for empty buffer
      local original_api = vim.api
      vim.api = {
        nvim_get_current_buf = function()
          return 1
        end,
        nvim_buf_get_lines = function()
          return { "" }
        end,
        nvim_win_get_cursor = function()
          return { 1, 0 }
        end,
        nvim_buf_get_option = function()
          return "lua"
        end,
      }

      local result = detector.get_function_under_cursor()
      assert.is_nil(result)

      -- Restore original API
      vim.api = original_api
    end)

    it("should return nil when cursor is not on a function call", function()
      local original_api = vim.api
      local original_notify = vim.notify
      vim.api = {
        nvim_get_current_buf = function()
          return 1
        end,
        nvim_buf_get_lines = function()
          return { "local variable = 42" }
        end,
        nvim_win_get_cursor = function()
          return { 1, 6 }
        end, -- cursor on 'variable'
        nvim_buf_get_option = function()
          return "lua"
        end,
        nvim_echo = function() end, -- Mock nvim_echo
      }
      vim.notify = function() end -- Mock vim.notify

      local result = detector.get_function_under_cursor()
      assert.is_nil(result)

      vim.api = original_api
      vim.notify = original_notify
    end)

    it("should detect simple function call", function()
      local original_api = vim.api
      vim.api = {
        nvim_get_current_buf = function()
          return 1
        end,
        nvim_buf_get_lines = function()
          return { "print('hello world')" }
        end,
        nvim_win_get_cursor = function()
          return { 1, 2 }
        end, -- cursor on 'print'
        nvim_buf_get_option = function()
          return "lua"
        end,
      }

      local result = detector.get_function_under_cursor()

      assert.is_not_nil(result)
      assert.equals("print", result.function_name)
      assert.equals("lua", result.language)
      assert.equals("function", result.type)
      assert.is_string(result.context)

      vim.api = original_api
    end)

    it("should detect method call", function()
      local original_api = vim.api
      vim.api = {
        nvim_get_current_buf = function()
          return 1
        end,
        nvim_buf_get_lines = function()
          return { "string.format('%s', name)" }
        end,
        nvim_win_get_cursor = function()
          return { 1, 10 }
        end, -- cursor on 'format'
        nvim_buf_get_option = function()
          return "lua"
        end,
      }

      local result = detector.get_function_under_cursor()

      assert.is_not_nil(result)
      assert.equals("string.format", result.function_name)
      assert.equals("lua", result.language)
      assert.equals("method", result.type)
      assert.matches("string%.format", result.context)

      vim.api = original_api
    end)

    it("should detect functions in different languages", function()
      local test_cases = {
        {
          language = "python",
          line = "len(my_list)",
          cursor_col = 1,
          expected_name = "len",
          expected_type = "function",
        },
        {
          language = "javascript",
          line = "console.log('debug')",
          cursor_col = 8,
          expected_name = "console.log",
          expected_type = "method",
        },
        {
          language = "go",
          line = "fmt.Println(message)",
          cursor_col = 6,
          expected_name = "fmt.Println",
          expected_type = "method",
        },
        {
          language = "python",
          line = "os.path.join(dir, file)",
          cursor_col = 10,
          expected_name = "os.path.join",
          expected_type = "method",
        },
      }

      for _, case in ipairs(test_cases) do
        local original_api = vim.api
        vim.api = {
          nvim_get_current_buf = function()
            return 1
          end,
          nvim_buf_get_lines = function()
            return { case.line }
          end,
          nvim_win_get_cursor = function()
            return { 1, case.cursor_col }
          end,
          nvim_buf_get_option = function()
            return case.language
          end,
        }

        local result = detector.get_function_under_cursor()

        assert.is_not_nil(
          result,
          "Should detect function in " .. case.language .. ": " .. case.line
        )
        assert.equals(
          case.expected_name,
          result.function_name,
          "Function name mismatch for " .. case.language
        )
        assert.equals(case.language, result.language)
        assert.equals(case.expected_type, result.type)
        assert.is_string(result.context)

        vim.api = original_api
      end
    end)

    it("should handle cursor at different positions on function name", function()
      local original_api = vim.api
      local line = "print('test')"

      -- Test different cursor positions on 'print' (0-indexed columns)
      for col = 0, 4 do
        vim.api = {
          nvim_get_current_buf = function()
            return 1
          end,
          nvim_buf_get_lines = function()
            return { line }
          end,
          nvim_win_get_cursor = function()
            return { 1, col }
          end,
          nvim_buf_get_option = function()
            return "lua"
          end,
        }

        local result = detector.get_function_under_cursor()

        assert.is_not_nil(result, "Should detect function at column " .. col)
        assert.equals("print", result.function_name)
      end

      vim.api = original_api
    end)

    it("should provide meaningful context for AI", function()
      local original_api = vim.api
      vim.api = {
        nvim_get_current_buf = function()
          return 1
        end,
        nvim_buf_get_lines = function()
          return {
            "local items = {'a', 'b', 'c'}",
            "local count = #items",
            "print(count) -- should print 3",
          }
        end,
        nvim_win_get_cursor = function()
          return { 3, 2 }
        end, -- cursor on 'print'
        nvim_buf_get_option = function()
          return "lua"
        end,
      }

      local result = detector.get_function_under_cursor()

      assert.is_not_nil(result)
      assert.equals("print", result.function_name)
      assert.is_string(result.context)
      -- Context should include surrounding lines for better AI understanding
      assert.matches("print%(count%)", result.context)

      vim.api = original_api
    end)

    it("should handle nested function calls", function()
      local original_api = vim.api
      vim.api = {
        nvim_get_current_buf = function()
          return 1
        end,
        nvim_buf_get_lines = function()
          return { "print(string.upper('hello'))" }
        end,
        nvim_win_get_cursor = function()
          return { 1, 8 }
        end, -- cursor on 'string'
        nvim_buf_get_option = function()
          return "lua"
        end,
      }

      local result = detector.get_function_under_cursor()

      assert.is_not_nil(result)
      assert.equals("string.upper", result.function_name)
      assert.equals("method", result.type)

      vim.api = original_api
    end)

    it("should ignore variables and non-function identifiers", function()
      local test_cases = {
        { "local variable = 42", 6 }, -- cursor on 'variable'
        { "local table = {key = 'value'}", 12 }, -- cursor on 'key'
        { "if condition then", 3 }, -- cursor on 'condition'
        { "for i = 1, 10 do", 4 }, -- cursor on 'i'
      }

      for _, case in ipairs(test_cases) do
        local line, col = case[1], case[2]
        local original_api = vim.api
        local original_notify = vim.notify
        vim.api = {
          nvim_get_current_buf = function()
            return 1
          end,
          nvim_buf_get_lines = function()
            return { line }
          end,
          nvim_win_get_cursor = function()
            return { 1, col }
          end,
          nvim_buf_get_option = function()
            return "lua"
          end,
          nvim_echo = function() end, -- Mock nvim_echo
        }
        vim.notify = function() end -- Mock vim.notify

        local result = detector.get_function_under_cursor()
        assert.is_nil(result, "Should not detect function in: " .. line)

        vim.api = original_api
        vim.notify = original_notify
      end
    end)
  end)
end)
