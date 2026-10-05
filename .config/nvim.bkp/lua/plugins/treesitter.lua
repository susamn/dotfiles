return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    local treesitterconfig = require("nvim-treesitter.configs")
    treesitterconfig.setup({ensure_installed={ "javascript", "lua", "python", "go", "java", "clojure","html", "css", "query", "vimdoc", "vim", "markdown",
			"markdown_inline", "typescript", "xml", "json", "yaml",
			"tmux", "sql", "scala", "ruby", "proto", "graphql"},
			highlight={enable=true}, 
			indent={enable=true},
		})
  end
}
  
