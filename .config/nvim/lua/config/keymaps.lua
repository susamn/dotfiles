-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Map <leader>th to change themes interactively
vim.keymap.set("n", "<leader>th", function()
  if package.loaded["snacks"] then
    Snacks.picker.colorschemes()
  else
    vim.cmd("Telescope colorscheme enable_preview=true")
  end
end, { desc = "Change Theme (Colorscheme Picker)" })

-- Map <leader>tt to cycle through your favorite themes
local themes = {
  "bamboo", "aether", "ethereal", "hackerman", "vantablack", "white",
  "catppuccin", "everforest", "flexoki", "gruvbox", "kanagawa",
  "matteblack", "monokai-pro", "nightfox", "rose-pine", "ashen",
  "tokyonight", "miasma", "retro-82", "lumon", "habamax"
}
local current_theme_idx = 1
vim.keymap.set("n", "<leader>tt", function()
  current_theme_idx = current_theme_idx % #themes + 1
  local next_theme = themes[current_theme_idx]
  vim.cmd("colorscheme " .. next_theme)
  vim.notify("Theme changed to: " .. next_theme, vim.log.levels.INFO)
end, { desc = "Toggle/Cycle Themes" })
