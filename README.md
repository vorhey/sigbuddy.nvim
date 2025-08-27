# SigBuddy.nvim 🤖

> **⚠️ EXPERIMENTAL PROJECT ⚠️**
> This plugin was built during a live coding session as an educational exercise. Expect things to be broken, APIs to change, and your cat to judge your life choices. This is NOT a serious project for production use!

AI-powered signature help for built-in functions in Neovim. When you're staring at `string.gsub()` wondering what the heck those parameters do, SigBuddy asks an AI and shows you a friendly explanation.

![Demo GIF would go here if this were a real project]

## What Does It Do? 🤔

1. You put your cursor on a built-in function like `print()`, `len()`, or `Array.isArray()`
2. You run `:SigBuddy`
3. It asks your AI of choice: "Hey, what's this function do?"
4. Shows you a nice floating window with explanation and example
5. Caches the response so you don't waste API calls

## Installation 📦

**Again, this is an experimental project. You've been warned!**

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "vorhey/sigbuddy.nvim", -- Replace with actual repo when you publish this
  dependencies = {
    "nvim-lua/plenary.nvim", -- For async operations
  },
  config = function()
    require("sigbuddy").setup({
      provider = "gemini", -- only gemini is supported for now
        gemini = {
          api_key = os.getenv("GEMINI_API_KEY"),
          model = "gemini-1.5-flash"
        },
      }
    })
  end
}
```

## Configuration 🛠️

```lua
require("sigbuddy").setup({
  -- AI Provider (only Gemini is supported for now)
  provider = "gemini", -- only "gemini" is supported for now

  -- Language for explanations
  language = "english", -- porque no español?

  -- Cache settings (save those API calls!)
  cache_enabled = true,
  cache_ttl = 86400 * 7, -- 1 week
  cache_dir = vim.fn.stdpath("data") .. "/sigbuddy/cache",

  -- UI settings
  ui = {
    popup_type = "popup", -- "popup", "horizontal", "vertical"
    border = "rounded",   -- "none", "single", "double", "rounded", "solid", "shadow"
    max_width = 80,
    max_height = 20
  },

  -- Provider configurations (currently only Gemini)
  providers = {
    gemini = {
      api_key = os.getenv("GEMINI_API_KEY"),
      model = "gemini-1.5-flash",
      -- add Gemini-specific options here
    },
  },

  -- Hooks (for when you want to get fancy)
  hooks = {
    request_started = function()
      print("🤖 Asking AI...")
    end,
    request_finished = function()
      print("✅ Got answer!")
    end
  }
})
```

## Usage 🚀

### Commands

- `:SigBuddy` - Explain the function under your cursor
- `:SigBuddyPickProvider` - Switch between AI providers
- `:SigBuddyStatus` - Show plugin status and cache info

### Key Mappings

No default key mappings because we're not monsters. Set your own:

```lua
-- Example mappings
vim.keymap.set('n', '<leader>sf', '<cmd>SigBuddy<CR>', { desc = 'SigBuddy: Explain function' })
vim.keymap.set('n', '<leader>sp', '<cmd>SigBuddyPickProvider<CR>', { desc = 'SigBuddy: Pick provider' })

-- Or use the <Plug> mappings
vim.keymap.set('n', '<leader>sf', '<Plug>SigBuddyExplain')
vim.keymap.set('n', '<leader>sp', '<Plug>SigBuddyPickProvider')
```

### Supported Languages

Anything with tree-sitter support! The plugin detects function calls using tree-sitter (with regex fallback), then asks the AI if it's a built-in function. Tested with:

- Lua 🌙
- Python 🐍
- JavaScript/TypeScript 📜
- Go 🐹
- Rust 🦀 (probably)
- Java ☕ (maybe)
- Your favorite language (hopefully)

## How It Works 🔧

1. **Function Detection**: Uses tree-sitter (or regex fallback) to detect function calls under cursor
2. **AI Query**: Sends function name + language to your chosen AI provider
3. **Smart Filtering**: Only shows popup for built-in functions (ignores your `doTheThing()` functions)
4. **Caching**: Saves responses locally to avoid repeated API calls
5. **Pretty Display**: Shows explanation in a floating window with syntax highlighting

## API Keys 🔐

Currently only the Gemini provider is supported. Get a Gemini API key from [Google AI Studio](https://aistudio.google.com/) and set it as an environment variable:

```bash
export GEMINI_API_KEY="your-key-here"
```

Notes: support for other providers may be added in the future; the README will be updated when that happens.

## Debugging 🐛

When things inevitably break:

```lua
-- Check plugin status
:lua print(require("sigbuddy").get_status())

-- Test function detection
:lua print(vim.inspect(require("sigbuddy")._get_function_under_cursor()))

-- Clean up cache
:lua print(require("sigbuddy")._cleanup_cache())

-- Close all windows if they're stuck
:lua require("sigbuddy")._close_all_windows()
```

## Contributing 🤝

This was built in a live coding session, so the code is probably terrible. PRs welcome to make it less terrible!

### Running Tests

```bash
# Install test dependencies
luarocks --local install nlua --lua-version=5.1
luarocks --local install busted --lua-version=5.1

# Run tests
eval $(luarocks --local path) && busted
```

### Code Formatting

This project uses [StyLua](https://github.com/JohnnyMorganz/StyLua) for code formatting. To format the code, run:

```bash
stylua .
```

To check for formatting issues without modifying files:

```bash
stylua --check .
```

### Architecture

- `lua/sigbuddy/init.lua` - Main orchestration with async support
- `lua/sigbuddy/config.lua` - Configuration management
- `lua/sigbuddy/detector.lua` - Tree-sitter function detection
- `lua/sigbuddy/providers/` - AI provider implementations
- `lua/sigbuddy/cache.lua` - TTL-based response caching
- `lua/sigbuddy/ui.lua` - Floating window management
- `tests/` - Comprehensive test suite (68 tests!)

## Inspiration 🎯

Built during a coding session exploring:
- TDD in Neovim plugin development
- Tree-sitter for accurate parsing
- Async/await patterns in Lua
- Multi-provider AI integration
- Modern Neovim plugin architecture

Similar plugins that do this properly:
- [wtf.nvim](https://github.com/piersolenski/wtf.nvim) - AI debugging help
- [copilot.nvim](https://github.com/github/copilot.vim) - GitHub Copilot
- [codeium.nvim](https://github.com/Exafunction/codeium.nvim) - Free AI completion

## License 📄

MIT - Because sharing broken code should be free!

## Disclaimer 🙈

- This plugin sends your function names to AI services (privacy implications)
- API calls cost money (set usage limits!)
- Built for educational purposes (seriously, don't rely on this)
- May summon Cthulhu or format your hard drive (probably not though)

---

**Remember**: This was a live coding experiment. Use at your own risk, expect bugs, and have fun! 🚀

*Made with ❤️ and questionable life choices*
