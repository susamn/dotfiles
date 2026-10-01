return {
  "nvim-neo-tree/neo-tree.nvim",
  keys = {
    {
      "<leader>ge",
      function()
        vim.g.neo_tree_git_numstat_enabled = 0
        require("neo-tree.command").execute({ source = "git_status", toggle = true })
      end,
      desc = "Git Explorer",
    },
    {
      "<leader>gE",
      function()
        vim.g.neo_tree_git_numstat_enabled = vim.g.neo_tree_git_numstat_enabled == 1 and 0 or 1

        local ok, manager = pcall(require, "neo-tree.sources.manager")
        if ok then
          local state = manager.get_state("git_status")
          if state then
            state.dirty = true
          end
        end

        local command = require("neo-tree.command")
        command.execute({ source = "git_status", action = "close" })
        vim.schedule(function()
          command.execute({ source = "git_status" })
        end)
      end,
      desc = "Toggle Git Explorer Counts",
    },
  },
}
