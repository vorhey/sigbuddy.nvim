local M = {}

-- Check if plenary async is available
local has_plenary, async = pcall(require, "plenary.async")
if not has_plenary then
  -- Fallback for environments without plenary
  async = {
    void = function(fn)
      return fn
    end,
    run = function(fn, callback)
      local success, result = pcall(fn)
      if callback then
        callback(success, result)
      end
    end,
  }
end

-- Setup function (synchronous)
function M.setup(opts)
  local success, config = pcall(require, "sigbuddy.config")
  if not success then
    error("Failed to load sigbuddy.config: " .. config)
  end

  config.setup(opts)
end

-- Get current status information
function M.get_status()
  local success, config = pcall(require, "sigbuddy.config")
  if not success then
    return "SigBuddy: Error loading configuration"
  end

  if not config.options then
    return "SigBuddy: Not initialized. Call require('sigbuddy').setup() first."
  end

  local cache_success, cache = pcall(require, "sigbuddy.cache")
  local cache_stats = cache_success and cache.get_stats() or { total_entries = 0, total_size = 0 }

  local status_lines = {
    "SigBuddy Status:",
    "  Provider: " .. (config.options.provider or "none"),
    "  Cache: " .. (config.options.cache_enabled and "enabled" or "disabled"),
    "  Cache entries: " .. cache_stats.total_entries,
    "  Cache size: " .. math.floor(cache_stats.total_size / 1024) .. "KB",
  }

  return table.concat(status_lines, "\n")
end

-- Pick AI provider interactively
function M.pick_provider()
  local success, providers = pcall(require, "sigbuddy.providers")
  if not success then
    print("SigBuddy: Error loading providers")
    return
  end

  providers.pick_provider()
end

-- Main explanation function (async)
M.explain = async.void(function()
  -- Check if plugin is initialized
  local config = require("sigbuddy.config")
  if not config.options then
    print("SigBuddy: Plugin not initialized. Please run :lua require('sigbuddy').setup()")
    return
  end

  local detector = require("sigbuddy.detector")
  local cache = require("sigbuddy.cache")
  local providers = require("sigbuddy.providers")
  local ui = require("sigbuddy.ui")

  -- Step 1: Detect function under cursor
  local function_info
  local success, result = pcall(detector.get_function_under_cursor)

  if not success then
    -- Handle detector errors gracefully
    print("SigBuddy: Error detecting function - " .. tostring(result))
    return
  end

  function_info = result
  if not function_info then
    return
  end

  -- Step 2: Check cache first
  local cached_explanation = cache.get(function_info)
  if cached_explanation then
    -- Cache hit - show explanation immediately
    vim.schedule(function()
      ui.show_explanation(cached_explanation, function_info)
    end)
    return
  end

  -- Step 3: Show loading indicator
  local loading_win
  vim.schedule(function()
    loading_win = ui.show_loading(function_info)
  end)

  -- Step 4: Get AI explanation asynchronously
  local provider_success, provider_error = pcall(function()
    local provider = providers.get_current_provider()
    local provider_config = config.get_provider_config()

    if not provider_config then
      -- Handle config error immediately
      vim.schedule(function()
        if loading_win then
          ui.close_loading(loading_win)
        end
        local error_explanation = {
          status = "error",
          error = "Provider configuration not found for " .. (config.options.provider or "unknown"),
        }
        ui.show_explanation(error_explanation, function_info)
      end)
      return
    end

    -- Make async request with callback
    provider.get_explanation(function_info, provider_config, function(explanation)
      -- This callback runs when the async operation completes
      -- Close loading indicator
      if loading_win then
        ui.close_loading(loading_win)
      end

      -- Cache the result (only if successful)
      if explanation and explanation.status == "success" then
        cache.set(function_info, explanation)
      end

      -- Show the explanation
      if explanation then
        ui.show_explanation(explanation, function_info)
      end
    end)
  end)

  -- Handle provider setup errors
  if not provider_success then
    vim.schedule(function()
      if loading_win then
        ui.close_loading(loading_win)
      end
      local error_explanation = {
        status = "error",
        error = "Provider error: " .. tostring(provider_error),
      }
      ui.show_explanation(error_explanation, function_info)
    end)
  end
end)

-- Utility functions for testing and debugging
function M._get_function_under_cursor()
  local detector = require("sigbuddy.detector")
  return detector.get_function_under_cursor()
end

function M._cleanup_cache()
  local cache = require("sigbuddy.cache")
  return cache.cleanup_expired()
end

function M._close_all_windows()
  local ui = require("sigbuddy.ui")
  ui.close_all_windows()
end

function M._test_ui()
  local ui = require("sigbuddy.ui")
  local test_explanation = {
    status = "success",
    explanation = "This is a test explanation.\nMultiple lines work too.",
  }
  local test_function_info = {
    function_name = "test_function",
    language = "lua",
  }
  ui.show_explanation(test_explanation, test_function_info)
end

return M
