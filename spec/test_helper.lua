-- Test helper to mock vim API functions
-- This file is automatically loaded by busted as a helper

-- Ensure vim table exists
if not vim then
  vim = {}
end

-- Mock vim.api if not already mocked
if not vim.api then
  vim.api = {}
end

-- Mock vim.notify if it doesn't exist
if not vim.notify then
  vim.notify = function() end
end

-- Mock nvim_echo
if not vim.api.nvim_echo then
  vim.api.nvim_echo = function() end
end

-- Mock nvim__get_runtime
if not vim.api.nvim__get_runtime then
  vim.api.nvim__get_runtime = function()
    return {}
  end
end

-- Mock log levels if they don't exist
if not vim.log then
  vim.log = {
    levels = {
      TRACE = 0,
      DEBUG = 1,
      INFO = 2,
      WARN = 3,
      ERROR = 4,
    },
  }
end
