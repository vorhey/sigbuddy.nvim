local config = require("sigbuddy.config")

describe("sigbuddy.config", function()
  before_each(function()
    -- Reset config state before each test
    config.options = nil
  end)

  describe("setup", function()
    it("should initialize with default options when no opts provided", function()
      config.setup()

      assert.is_not_nil(config.options)
      assert.equals("openai", config.options.provider)
      assert.equals("english", config.options.language)
      assert.is_true(config.options.cache_enabled)
      assert.equals(86400 * 7, config.options.cache_ttl)
    end)

    it("should merge user options with defaults", function()
      config.setup({
        provider = "anthropic",
        language = "spanish",
        cache_ttl = 3600,
      })

      assert.equals("anthropic", config.options.provider)
      assert.equals("spanish", config.options.language)
      assert.equals(3600, config.options.cache_ttl)
      -- Should keep default values for unspecified options
      assert.is_true(config.options.cache_enabled)
    end)

    it("should deep merge provider configurations", function()
      config.setup({
        providers = {
          openai = {
            model = "gpt-3.5-turbo",
            -- Should preserve default endpoint and api_key
          },
          anthropic = {
            api_key = "custom-key",
          },
        },
      })

      assert.equals("gpt-3.5-turbo", config.options.providers.openai.model)
      assert.equals(
        "https://api.openai.com/v1/chat/completions",
        config.options.providers.openai.endpoint
      )
      assert.is_nil(config.options.providers.openai.api_key) -- Default
      assert.equals("custom-key", config.options.providers.anthropic.api_key)
    end)

    it("should handle nil options gracefully", function()
      config.setup(nil)

      assert.is_not_nil(config.options)
      assert.equals("openai", config.options.provider)
    end)

    it("should set cache directory with vim.fn.stdpath when not provided", function()
      config.setup()

      assert.is_string(config.options.cache_dir)
      assert.matches("sigbuddy/cache", config.options.cache_dir)
    end)

    it("should preserve user-provided cache directory", function()
      local custom_dir = "/tmp/custom/cache"
      config.setup({ cache_dir = custom_dir })

      assert.equals(custom_dir, config.options.cache_dir)
    end)

    it("should configure UI options correctly", function()
      config.setup({
        ui = {
          popup_type = "horizontal",
          max_width = 100,
        },
      })

      assert.equals("horizontal", config.options.ui.popup_type)
      assert.equals(100, config.options.ui.max_width)
      -- Should preserve defaults
      assert.equals("rounded", config.options.ui.border)
      assert.equals(20, config.options.ui.max_height)
    end)

    it("should handle hooks configuration", function()
      local start_hook = function() end
      local finish_hook = function() end

      config.setup({
        hooks = {
          request_started = start_hook,
          request_finished = finish_hook,
        },
      })

      assert.equals(start_hook, config.options.hooks.request_started)
      assert.equals(finish_hook, config.options.hooks.request_finished)
    end)
  end)

  describe("get_provider_config", function()
    before_each(function()
      config.setup({
        provider = "openai",
        providers = {
          openai = {
            api_key = "test-key",
            model = "gpt-4",
          },
        },
      })
    end)

    it("should return current provider config", function()
      local provider_config = config.get_provider_config()

      assert.equals("test-key", provider_config.api_key)
      assert.equals("gpt-4", provider_config.model)
    end)

    it("should return nil for unknown provider", function()
      config.options.provider = "unknown"
      local provider_config = config.get_provider_config()

      assert.is_nil(provider_config)
    end)
  end)
end)
