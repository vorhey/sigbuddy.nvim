rockspec_format = "3.0"
package = "sigbuddy"
version = "scm-1"
source = {
   url = "git+https://github.com/username/sigbuddy.nvim.git"
}
description = {
   summary = "AI-powered signature help for built-in functions in Neovim",
   detailed = [[
      SigBuddy is an experimental Neovim plugin built during a live coding session.
      It provides AI-powered explanations for built-in programming language functions.
      
      Features:
      - Tree-sitter based function detection
      - Multi-AI provider support (OpenAI, Anthropic, Gemini, Ollama)
      - Smart caching with TTL
      - Async operations with plenary.nvim
      - Beautiful floating window UI
      - Comprehensive test suite (68+ tests)
      
      ⚠️ WARNING: Experimental project! Expect bugs and breaking changes.
   ]],
   homepage = "https://github.com/username/sigbuddy.nvim",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "plenary.nvim"
}
test_dependencies = {
   "busted >= 2.0.0",
   "nlua"
}
build = {
   type = "builtin"
}