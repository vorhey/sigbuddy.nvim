local provider_factory = require("sigbuddy.providers")

describe("sigbuddy.providers", function()
  before_each(function()
    -- Mock config
    local config = require("sigbuddy.config")
    config.setup({
      provider = "gemini",
      providers = {
        gemini = {
          api_key = "test-key",
          model = "gemini-1.5-flash",
        },
      },
    })
  end)

  describe("get_current_provider", function()
    it("should return the current provider instance", function()
      local provider = provider_factory.get_current_provider()

      assert.is_not_nil(provider)
      assert.is_table(provider)
      assert.is_function(provider.get_explanation)
    end)

    it("should error for unknown provider", function()
      local config = require("sigbuddy.config")

      -- This should error during config setup itself (validation)
      assert.has.errors(function()
        config.setup({ provider = "unknown", providers = { unknown = {} } })
      end)
    end)
  end)

  describe("list_available_providers", function()
    it("should return list of available providers", function()
      local providers = provider_factory.list_available_providers()

      assert.is_table(providers)
      assert.are.same({ "gemini" }, providers)
    end)
  end)
end)
