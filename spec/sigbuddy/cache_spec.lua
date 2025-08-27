local cache = require("sigbuddy.cache")

describe("sigbuddy.cache", function()
  local test_cache_dir = "/tmp/sigbuddy_test_cache"

  before_each(function()
    -- Clean up test cache directory
    os.execute("rm -rf " .. test_cache_dir)

    -- Mock config
    local config = require("sigbuddy.config")
    config.setup({
      cache_enabled = true,
      cache_dir = test_cache_dir,
      cache_ttl = 3600, -- 1 hour for tests
      provider = "openai",
      providers = { openai = {} },
    })
  end)

  after_each(function()
    -- Clean up test cache directory
    os.execute("rm -rf " .. test_cache_dir)
  end)

  describe("get_cache_key", function()
    it("should generate consistent cache key for same function info", function()
      local function_info = {
        function_name = "print",
        language = "lua",
      }

      local key1 = cache.get_cache_key(function_info)
      local key2 = cache.get_cache_key(function_info)

      assert.equals(key1, key2)
    end)

    it("should generate different keys for different functions", function()
      local function_info1 = {
        function_name = "print",
        language = "lua",
      }

      local function_info2 = {
        function_name = "len",
        language = "python",
      }

      local key1 = cache.get_cache_key(function_info1)
      local key2 = cache.get_cache_key(function_info2)

      assert.is_not_equal(key1, key2)
    end)

    it("should include provider in cache key", function()
      local function_info = {
        function_name = "print",
        language = "lua",
      }

      -- Test with OpenAI
      local config = require("sigbuddy.config")
      config.setup({ provider = "openai", providers = { openai = {} } })
      local key1 = cache.get_cache_key(function_info)

      -- Test with Anthropic
      config.setup({ provider = "anthropic", providers = { anthropic = {} } })
      local key2 = cache.get_cache_key(function_info)

      assert.is_not_equal(key1, key2)
    end)
  end)

  describe("set and get", function()
    it("should store and retrieve cache entries", function()
      local function_info = {
        function_name = "print",
        language = "lua",
      }

      local explanation = {
        status = "success",
        explanation = "print() outputs text to the console.",
      }

      cache.set(function_info, explanation)
      local retrieved = cache.get(function_info)

      assert.is_not_nil(retrieved)
      assert.equals(explanation.status, retrieved.status)
      assert.equals(explanation.explanation, retrieved.explanation)
    end)

    it("should return nil for non-existent entries", function()
      local function_info = {
        function_name = "nonexistent",
        language = "lua",
      }

      local result = cache.get(function_info)
      assert.is_nil(result)
    end)

    it("should handle cache disabled", function()
      -- Disable cache
      local config = require("sigbuddy.config")
      config.setup({
        cache_enabled = false,
        provider = "openai",
        providers = { openai = {} },
      })

      local function_info = {
        function_name = "print",
        language = "lua",
      }

      local explanation = { status = "success", explanation = "test" }

      cache.set(function_info, explanation)
      local retrieved = cache.get(function_info)

      -- Should return nil when cache is disabled
      assert.is_nil(retrieved)
    end)
  end)

  describe("TTL (time-to-live)", function()
    it("should respect TTL and expire old entries", function()
      -- Set very short TTL
      local config = require("sigbuddy.config")
      config.setup({
        cache_enabled = true,
        cache_dir = test_cache_dir,
        cache_ttl = 1, -- 1 second
        provider = "openai",
        providers = { openai = {} },
      })

      local function_info = {
        function_name = "print",
        language = "lua",
      }

      local explanation = { status = "success", explanation = "test" }

      cache.set(function_info, explanation)

      -- Should be available immediately
      local retrieved1 = cache.get(function_info)
      assert.is_not_nil(retrieved1)

      -- Wait for TTL to expire
      os.execute("sleep 2")

      -- Should be expired now
      local retrieved2 = cache.get(function_info)
      assert.is_nil(retrieved2)
    end)

    it("should handle entries without expiry gracefully", function()
      local function_info = {
        function_name = "print",
        language = "lua",
      }

      -- Manually create cache file without expiry
      cache.set(function_info, { status = "success", explanation = "test" })

      -- Manually modify the cache file to remove expiry
      local cache_key = cache.get_cache_key(function_info)
      local cache_file = test_cache_dir .. "/" .. cache_key .. ".json"

      local file = io.open(cache_file, "w")
      file:write('{"explanation":"test","status":"success"}') -- No expiry field
      file:close()

      -- Should still be retrievable (treats as non-expiring)
      local retrieved = cache.get(function_info)
      assert.is_not_nil(retrieved)
    end)
  end)

  describe("cache cleanup", function()
    it("should clean expired entries", function()
      -- Set very short TTL
      local config = require("sigbuddy.config")
      config.setup({
        cache_enabled = true,
        cache_dir = test_cache_dir,
        cache_ttl = 1, -- 1 second
        provider = "openai",
        providers = { openai = {} },
      })

      local function_info1 = { function_name = "print", language = "lua" }
      local function_info2 = { function_name = "len", language = "python" }

      cache.set(function_info1, { status = "success", explanation = "test1" })
      cache.set(function_info2, { status = "success", explanation = "test2" })

      -- Wait for expiry
      os.execute("sleep 2")

      -- Run cleanup
      local cleaned_count = cache.cleanup_expired()

      assert.equals(2, cleaned_count)

      -- Entries should be gone
      assert.is_nil(cache.get(function_info1))
      assert.is_nil(cache.get(function_info2))
    end)

    it("should keep non-expired entries during cleanup", function()
      -- Set long TTL
      local config = require("sigbuddy.config")
      config.setup({
        cache_enabled = true,
        cache_dir = test_cache_dir,
        cache_ttl = 3600, -- 1 hour
        provider = "openai",
        providers = { openai = {} },
      })

      local function_info = { function_name = "print", language = "lua" }
      cache.set(function_info, { status = "success", explanation = "test" })

      -- Run cleanup
      local cleaned_count = cache.cleanup_expired()

      assert.equals(0, cleaned_count)

      -- Entry should still be there
      assert.is_not_nil(cache.get(function_info))
    end)
  end)

  describe("error handling", function()
    it("should handle invalid cache directory gracefully", function()
      local config = require("sigbuddy.config")
      config.setup({
        cache_enabled = true,
        cache_dir = "/root/invalid_permission_dir", -- Should fail to create
        provider = "openai",
        providers = { openai = {} },
      })

      local function_info = { function_name = "print", language = "lua" }

      -- Should not error, just fail silently
      assert.has_no.errors(function()
        cache.set(function_info, { status = "success", explanation = "test" })
      end)

      assert.has_no.errors(function()
        cache.get(function_info)
      end)
    end)

    it("should handle corrupted cache files", function()
      local function_info = { function_name = "print", language = "lua" }

      -- Create corrupted cache file
      local cache_key = cache.get_cache_key(function_info)
      os.execute("mkdir -p " .. test_cache_dir)
      local cache_file = test_cache_dir .. "/" .. cache_key .. ".json"

      local file = io.open(cache_file, "w")
      file:write('{"invalid": json content}') -- Corrupted JSON
      file:close()

      -- Should handle gracefully and return nil
      local result = cache.get(function_info)
      assert.is_nil(result)
    end)
  end)

  describe("cache statistics", function()
    it("should return cache stats", function()
      local function_info1 = { function_name = "print", language = "lua" }
      local function_info2 = { function_name = "len", language = "python" }

      cache.set(function_info1, { status = "success", explanation = "test1" })
      cache.set(function_info2, { status = "success", explanation = "test2" })

      local stats = cache.get_stats()

      assert.is_table(stats)
      assert.is_number(stats.total_entries)
      assert.is_number(stats.total_size)
      assert.is_string(stats.cache_dir)
      assert.equals(2, stats.total_entries)
      assert.is_true(stats.total_size > 0)
    end)
  end)
end)
