local M = {}

local available_providers = { "gemini" }

function M.get_current_provider()
  local config = require("sigbuddy.config")

  if not config.options then
    error("SigBuddy not initialized. Please call require('sigbuddy').setup() first")
  end

  local provider_name = config.options.provider
  if not provider_name then
    error("No provider configured")
  end

  -- Check if provider is supported
  if not vim.tbl_contains(available_providers, provider_name) then
    error(
      "Unsupported provider: "
        .. provider_name
        .. ". Available providers: "
        .. table.concat(available_providers, ", ")
    )
  end

  -- Load and return the provider module
  local success, provider = pcall(require, "sigbuddy.providers." .. provider_name)
  if not success then
    error("Failed to load provider: " .. provider_name .. ". Error: " .. provider)
  end

  return provider
end

function M.list_available_providers()
  return vim.deepcopy(available_providers)
end

function M.pick_provider()
  -- Interactive provider selection (will be implemented later with UI)
  local config = require("sigbuddy.config")

  print("Available providers:")
  for i, provider in ipairs(available_providers) do
    local marker = (config.options and config.options.provider == provider) and " (current)" or ""
    print(string.format("%d. %s%s", i, provider, marker))
  end

  -- For now, just print - later we'll implement proper UI selection
  print("Use setup() to change provider: require('sigbuddy').setup({provider = 'provider_name'})")
end

return M
