return {
  "ThePrimeagen/harpoon",
  dependencies = { "nvim-lua/plenary.nvim" },  -- Ensure plenary is installed
  config = function()
    local harpoon = require("harpoon")
    local mark = require("harpoon.mark")
    local ui = require("harpoon.ui")

    harpoon.setup()

    -- Keybindings
    vim.keymap.set("n", "<leader>a", mark.add_file, { desc = "Harpoon Add File" })
    vim.keymap.set("n", "<C-e>", ui.toggle_quick_menu, { desc = "Harpoon Menu" })

    vim.keymap.set("n", "<C-h>", function() ui.nav_file(1) end, { desc = "Harpoon to File 1" })
    vim.keymap.set("n", "<C-t>", function() ui.nav_file(2) end, { desc = "Harpoon to File 2" })
    vim.keymap.set("n", "<C-n>", function() ui.nav_file(3) end, { desc = "Harpoon to File 3" })
    vim.keymap.set("n", "<C-s>", function() ui.nav_file(4) end, { desc = "Harpoon to File 4" })
  end
}

