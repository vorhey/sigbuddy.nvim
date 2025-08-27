local M = {}

-- Generate a consistent cache key for function info
function M.get_cache_key(function_info)
  local config = require("sigbuddy.config")

  -- Include provider in cache key to avoid conflicts
  local provider = config.options and config.options.provider or "unknown"

  -- Create a simple hash-like key from function info
  local key_data = string.format(
    "%s|%s|%s",
    function_info.function_name or "",
    function_info.language or "",
    provider
  )

  -- Simple hash function (not cryptographic, just for uniqueness)
  local hash = 0
  for i = 1, #key_data do
    hash = ((hash * 31) + string.byte(key_data, i)) % 0xFFFFFFFF
  end

  return string.format("%08x", hash)
end

-- Ensure cache directory exists
local function ensure_cache_dir(cache_dir)
  if not cache_dir or cache_dir == "" then
    return false
  end

  local success = os.execute("mkdir -p " .. cache_dir .. " 2>/dev/null")
  return success == 0 or success == true -- Different Lua versions return different values
end

-- Get cache file path for a function
local function get_cache_file_path(function_info)
  local config = require("sigbuddy.config")

  if not config.options or not config.options.cache_enabled then
    return nil
  end

  local cache_dir = config.options.cache_dir
  if not ensure_cache_dir(cache_dir) then
    return nil
  end

  local cache_key = M.get_cache_key(function_info)
  return cache_dir .. "/" .. cache_key .. ".json"
end

-- Check if cache entry is expired
local function is_expired(cache_entry, ttl)
  if not cache_entry.cached_at or not ttl or ttl <= 0 then
    return false -- No expiry if no timestamp or TTL
  end

  local current_time = os.time()
  return (current_time - cache_entry.cached_at) > ttl
end

function M.set(function_info, explanation)
  local config = require("sigbuddy.config")

  if not config.options or not config.options.cache_enabled then
    return -- Cache disabled
  end

  local cache_file = get_cache_file_path(function_info)
  if not cache_file then
    return -- Failed to create cache directory
  end

  -- Create cache entry with timestamp
  local cache_entry = vim.deepcopy(explanation)
  cache_entry.cached_at = os.time()

  -- Write to file
  local success, file = pcall(io.open, cache_file, "w")
  if not success or not file then
    return -- Failed to create cache file
  end

  local json_success, json_data = pcall(vim.fn.json_encode, cache_entry)
  if not json_success then
    file:close()
    return -- Failed to encode JSON
  end

  file:write(json_data)
  file:close()
end

function M.get(function_info)
  local config = require("sigbuddy.config")

  if not config.options or not config.options.cache_enabled then
    return nil -- Cache disabled
  end

  local cache_file = get_cache_file_path(function_info)
  if not cache_file then
    return nil
  end

  -- Check if file exists
  local file = io.open(cache_file, "r")
  if not file then
    return nil -- Cache miss
  end

  -- Read file content
  local content = file:read("*a")
  file:close()

  -- Parse JSON
  local success, cache_entry = pcall(vim.fn.json_decode, content)
  if not success or not cache_entry then
    -- Corrupted cache file, remove it
    os.remove(cache_file)
    return nil
  end

  -- Check if expired
  if is_expired(cache_entry, config.options.cache_ttl) then
    -- Remove expired entry
    os.remove(cache_file)
    return nil
  end

  -- Remove internal cache metadata before returning
  local result = vim.deepcopy(cache_entry)
  result.cached_at = nil

  return result
end

function M.cleanup_expired()
  local config = require("sigbuddy.config")

  if not config.options or not config.options.cache_enabled then
    return 0
  end

  local cache_dir = config.options.cache_dir
  if not cache_dir or cache_dir == "" then
    return 0
  end

  local cleaned_count = 0

  -- List all cache files
  local ls_handle = io.popen("find " .. cache_dir .. " -name '*.json' 2>/dev/null")
  if not ls_handle then
    return 0
  end

  for cache_file in ls_handle:lines() do
    -- Read and check each file
    local file = io.open(cache_file, "r")
    if file then
      local content = file:read("*a")
      file:close()

      local success, cache_entry = pcall(vim.fn.json_decode, content)
      if success and cache_entry then
        if is_expired(cache_entry, config.options.cache_ttl) then
          os.remove(cache_file)
          cleaned_count = cleaned_count + 1
        end
      else
        -- Corrupted file, remove it
        os.remove(cache_file)
        cleaned_count = cleaned_count + 1
      end
    end
  end

  ls_handle:close()
  return cleaned_count
end

function M.get_stats()
  local config = require("sigbuddy.config")

  local stats = {
    cache_enabled = config.options and config.options.cache_enabled or false,
    cache_dir = config.options and config.options.cache_dir or "",
    cache_ttl = config.options and config.options.cache_ttl or 0,
    total_entries = 0,
    total_size = 0,
  }

  if not stats.cache_enabled or not stats.cache_dir then
    return stats
  end

  -- Count cache files and calculate total size
  local ls_handle = io.popen("find " .. stats.cache_dir .. " -name '*.json' 2>/dev/null")
  if ls_handle then
    for cache_file in ls_handle:lines() do
      stats.total_entries = stats.total_entries + 1

      -- Get file size
      local stat_handle = io.popen("stat -c%s " .. cache_file .. " 2>/dev/null")
      if stat_handle then
        local size_str = stat_handle:read("*a")
        stat_handle:close()
        local size = tonumber(size_str)
        if size then
          stats.total_size = stats.total_size + size
        end
      end
    end
    ls_handle:close()
  end

  return stats
end

return M
