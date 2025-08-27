-- sigbuddy.nvim - AI-powered signature help for built-in functions
-- plugin/sigbuddy.lua

if vim.g.loaded_sigbuddy then
  return
end
vim.g.loaded_sigbuddy = 1

-- Create user commands
vim.api.nvim_create_user_command("SigBuddy", function()
  require("sigbuddy").explain_sync()
end, {
  desc = "Show AI-powered explanation for function under cursor",
})

vim.api.nvim_create_user_command("SigBuddyPickProvider", function()
  require("sigbuddy").pick_provider()
end, {
  desc = "Pick AI provider for SigBuddy",
})

vim.api.nvim_create_user_command("SigBuddyStatus", function()
  print(require("sigbuddy").get_status())
end, {
  desc = "Show SigBuddy status information",
})

-- Create <Plug> mappings for user customization
vim.keymap.set("n", "<Plug>SigBuddyExplain", function()
  require("sigbuddy").explain_sync()
end, { desc = "SigBuddy: Explain function under cursor" })

vim.keymap.set("n", "<Plug>SigBuddyPickProvider", function()
  require("sigbuddy").pick_provider()
end, { desc = "SigBuddy: Pick AI provider" })
