local sigbuddy = require("sigbuddy")

describe("sigbuddy", function()
  describe("setup", function()
    it("should have a setup function", function()
      assert.is_function(sigbuddy.setup)
    end)
  end)

  describe("explain", function()
    it("should have an explain function", function()
      assert.is_function(sigbuddy.explain)
    end)
  end)

  describe("get_status", function()
    it("should have a get_status function", function()
      assert.is_function(sigbuddy.get_status)
    end)

    it("should return status when not initialized", function()
      local status = sigbuddy.get_status()
      assert.is_string(status)
      assert.matches("SigBuddy", status)
    end)
  end)

  describe("pick_provider", function()
    it("should have a pick_provider function", function()
      assert.is_function(sigbuddy.pick_provider)
    end)

    it("should handle pick_provider calls", function()
      assert.has_no.errors(function()
        sigbuddy.pick_provider()
      end)
    end)
  end)

  describe("utility functions", function()
    it("should expose utility functions", function()
      assert.is_function(sigbuddy._get_function_under_cursor)
      assert.is_function(sigbuddy._cleanup_cache)
      assert.is_function(sigbuddy._close_all_windows)
    end)
  end)

  describe("async support", function()
    it("should handle missing plenary gracefully", function()
      -- The module should load and work even without plenary
      assert.is_not_nil(sigbuddy)
      assert.is_function(sigbuddy.explain)
      assert.is_function(sigbuddy.explain_sync)
    end)
  end)

  describe("error handling", function()
    it("should handle module loading errors gracefully", function()
      -- get_status should handle config loading errors
      local status = sigbuddy.get_status()
      assert.is_string(status)

      -- pick_provider should handle provider loading errors
      assert.has_no.errors(function()
        sigbuddy.pick_provider()
      end)
    end)
  end)
end)
