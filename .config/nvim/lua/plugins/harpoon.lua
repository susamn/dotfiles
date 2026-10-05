return {
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("harpoon"):setup()
    end,
    keys = {
      {
        "<leader>ha",
        function()
          require("harpoon"):list():add()
        end,
        desc = "Harpoon Add File",
      },
      {
        "<leader>hh",
        function()
          require("harpoon").ui:toggle_quick_menu(require("harpoon"):list())
        end,
        desc = "Harpoon Menu",
      },
      {
        "<leader>hs",
        function()
          local harpoon = require("harpoon")
          local list = harpoon:list()
          local items = {}

          for idx, item in ipairs(list.items) do
            local file = item.value
            if file and file ~= "" then
              items[#items + 1] = { idx = idx, text = file, file = file }
            end
          end

          if #items == 0 then
            Snacks.notify("Harpoon list is empty", { level = "warn" })
            return
          end

          Snacks.picker({
            title = "Harpoon",
            finder = function()
              return items
            end,
            format = "file",
            actions = {
              confirm = function(picker, item)
                picker:close()
                if item then
                  list:select(item.idx)
                end
              end,
            },
          })
        end,
        desc = "Harpoon Search",
      },
      {
        "<leader>h1",
        function()
          require("harpoon"):list():select(1)
        end,
        desc = "Harpoon File 1",
      },
      {
        "<leader>h2",
        function()
          require("harpoon"):list():select(2)
        end,
        desc = "Harpoon File 2",
      },
      {
        "<leader>h3",
        function()
          require("harpoon"):list():select(3)
        end,
        desc = "Harpoon File 3",
      },
      {
        "<leader>h4",
        function()
          require("harpoon"):list():select(4)
        end,
        desc = "Harpoon File 4",
      },
      {
        "<leader>hp",
        function()
          require("harpoon"):list():prev()
        end,
        desc = "Harpoon Previous",
      },
      {
        "<leader>hn",
        function()
          require("harpoon"):list():next()
        end,
        desc = "Harpoon Next",
      },
    },
  },
}
