local M = {}

local default_opts = {
  provider = "openai",
  language = "english",
  cache_enabled = true,
  cache_ttl = 86400 * 7, -- 1 week in seconds
  cache_dir = vim.fn.stdpath("data") .. "/sigbuddy/cache",

  providers = {
    openai = {
      api_key = nil,
      model = "gpt-4o-mini",
      endpoint = "https://api.openai.com/v1/chat/completions",
    },
    anthropic = {
      api_key = nil,
      model = "claude-3-haiku-20240307",
      endpoint = "https://api.anthropic.com/v1/messages",
    },
    gemini = {
      api_key = nil,
      model = "gemini-1.5-flash",
      endpoint = nil, -- Will use default Google AI endpoint
    },
    ollama = {
      api_key = nil,
      model = "llama2",
      endpoint = "http://localhost:11434/api/generate",
    },
  },

  ui = {
    popup_type = "popup", -- popup, horizontal, vertical
    border = "rounded",
    max_width = 80,
    max_height = 20,
  },

  hooks = {
    request_started = nil,
    request_finished = nil,
  },
}

function M.setup(opts)
  opts = opts or {}

  -- Deep merge user options with defaults
  local merged_opts = vim.tbl_deep_extend("force", default_opts, opts)

  -- Special handling for provider configurations to preserve defaults
  if opts.providers then
    for provider, config in pairs(opts.providers) do
      if default_opts.providers[provider] then
        merged_opts.providers[provider] =
          vim.tbl_deep_extend("force", default_opts.providers[provider], config)
      end
    end
  end

  -- Validate the merged configuration
  require("sigbuddy.validation").validate_opts(merged_opts)

  -- Store the final configuration
  M.options = merged_opts
end

function M.get_provider_config()
  if not M.options then
    return nil
  end

  local provider_name = M.options.provider
  return M.options.providers[provider_name]
end

return M
