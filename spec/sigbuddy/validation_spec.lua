local validation = require("sigbuddy.validation")

describe("sigbuddy.validation", function()
  describe("validate_opts", function()
    it("should pass validation for valid default options", function()
      local valid_opts = {
        provider = "openai",
        language = "english",
        cache_enabled = true,
        cache_ttl = 86400,
        cache_dir = "/tmp/cache",
        providers = {
          openai = {
            api_key = nil,
            model = "gpt-4o-mini",
          },
        },
        ui = {
          popup_type = "popup",
          border = "rounded",
          max_width = 80,
          max_height = 20,
        },
        hooks = {
          request_started = nil,
          request_finished = nil,
        },
      }

      -- Should not throw any errors
      assert.has_no.errors(function()
        validation.validate_opts(valid_opts)
      end)
    end)

    it("should reject invalid provider", function()
      local invalid_opts = {
        provider = "invalid_provider",
        providers = {},
      }

      assert.has.errors(function()
        validation.validate_opts(invalid_opts)
      end)
    end)

    it("should reject invalid language", function()
      local invalid_opts = {
        provider = "openai",
        language = 123, -- Should be string
        providers = { openai = {} },
      }

      assert.has.errors(function()
        validation.validate_opts(invalid_opts)
      end)
    end)

    it("should reject invalid cache_ttl", function()
      local invalid_opts = {
        provider = "openai",
        cache_ttl = "invalid", -- Should be number
        providers = { openai = {} },
      }

      assert.has.errors(function()
        validation.validate_opts(invalid_opts)
      end)
    end)

    it("should reject invalid UI popup_type", function()
      local invalid_opts = {
        provider = "openai",
        providers = { openai = {} },
        ui = {
          popup_type = "invalid_type", -- Should be popup, horizontal, or vertical
        },
      }

      assert.has.errors(function()
        validation.validate_opts(invalid_opts)
      end)
    end)

    it("should accept valid popup_type values", function()
      local valid_types = { "popup", "horizontal", "vertical" }

      for _, popup_type in ipairs(valid_types) do
        local opts = {
          provider = "openai",
          providers = { openai = {} },
          ui = { popup_type = popup_type },
        }

        assert.has_no.errors(function()
          validation.validate_opts(opts)
        end, "popup_type: " .. popup_type)
      end
    end)

    it("should reject negative cache_ttl", function()
      local invalid_opts = {
        provider = "openai",
        cache_ttl = -1,
        providers = { openai = {} },
      }

      assert.has.errors(function()
        validation.validate_opts(invalid_opts)
      end)
    end)

    it("should validate hook functions", function()
      local invalid_opts = {
        provider = "openai",
        providers = { openai = {} },
        hooks = {
          request_started = "not_a_function",
        },
      }

      assert.has.errors(function()
        validation.validate_opts(invalid_opts)
      end)
    end)

    it("should allow nil hooks", function()
      local valid_opts = {
        provider = "openai",
        providers = { openai = {} },
        hooks = {
          request_started = nil,
          request_finished = nil,
        },
      }

      assert.has_no.errors(function()
        validation.validate_opts(valid_opts)
      end)
    end)
  end)
end)
