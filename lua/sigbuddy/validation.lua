local M = {}

local valid_providers = { "openai", "anthropic", "gemini", "ollama" }
local valid_popup_types = { "popup", "horizontal", "vertical" }

function M.validate_opts(opts)
  assert(type(opts) == "table", "Options must be a table")

  -- Validate provider
  if opts.provider then
    assert(type(opts.provider) == "string", "provider must be a string")
    assert(
      vim.tbl_contains(valid_providers, opts.provider),
      "provider must be one of: " .. table.concat(valid_providers, ", ")
    )

    -- Check that the provider configuration exists
    assert(
      opts.providers and opts.providers[opts.provider],
      "Provider configuration missing for: " .. opts.provider
    )
  end

  -- Validate language
  if opts.language then
    assert(type(opts.language) == "string", "language must be a string")
  end

  -- Validate cache options
  if opts.cache_enabled ~= nil then
    assert(type(opts.cache_enabled) == "boolean", "cache_enabled must be boolean")
  end

  if opts.cache_ttl then
    assert(type(opts.cache_ttl) == "number", "cache_ttl must be a number")
    assert(opts.cache_ttl >= 0, "cache_ttl must be non-negative")
  end

  if opts.cache_dir then
    assert(type(opts.cache_dir) == "string", "cache_dir must be a string")
  end

  -- Validate UI options
  if opts.ui then
    assert(type(opts.ui) == "table", "ui must be a table")

    if opts.ui.popup_type then
      assert(type(opts.ui.popup_type) == "string", "ui.popup_type must be a string")
      assert(
        vim.tbl_contains(valid_popup_types, opts.ui.popup_type),
        "ui.popup_type must be one of: " .. table.concat(valid_popup_types, ", ")
      )
    end

    if opts.ui.border then
      assert(type(opts.ui.border) == "string", "ui.border must be a string")
    end

    if opts.ui.max_width then
      assert(
        type(opts.ui.max_width) == "number" and opts.ui.max_width > 0,
        "ui.max_width must be a positive number"
      )
    end

    if opts.ui.max_height then
      assert(
        type(opts.ui.max_height) == "number" and opts.ui.max_height > 0,
        "ui.max_height must be a positive number"
      )
    end
  end

  -- Validate providers configuration
  if opts.providers then
    assert(type(opts.providers) == "table", "providers must be a table")

    for provider_name, provider_config in pairs(opts.providers) do
      assert(
        type(provider_config) == "table",
        "provider config for " .. provider_name .. " must be a table"
      )

      if provider_config.api_key then
        assert(
          type(provider_config.api_key) == "string",
          "api_key for " .. provider_name .. " must be a string"
        )
      end

      if provider_config.model then
        assert(
          type(provider_config.model) == "string",
          "model for " .. provider_name .. " must be a string"
        )
      end

      if provider_config.endpoint then
        assert(
          type(provider_config.endpoint) == "string",
          "endpoint for " .. provider_name .. " must be a string"
        )
      end
    end
  end

  -- Validate hooks
  if opts.hooks then
    assert(type(opts.hooks) == "table", "hooks must be a table")

    if opts.hooks.request_started then
      assert(
        type(opts.hooks.request_started) == "function",
        "hooks.request_started must be a function"
      )
    end

    if opts.hooks.request_finished then
      assert(
        type(opts.hooks.request_finished) == "function",
        "hooks.request_finished must be a function"
      )
    end
  end
end

return M
