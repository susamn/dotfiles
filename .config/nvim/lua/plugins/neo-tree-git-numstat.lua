local cache = {}

local function normalize(path)
  return path and vim.fs.normalize(path) or nil
end

local function git_root(cwd)
  local lines = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 or not lines[1] or lines[1] == "" then
    return nil
  end
  return normalize(lines[1])
end

local function read_numstat(root)
  local now = vim.uv.now()
  local item = cache[root]
  if item and now - item.time < 1000 then
    return item.stats
  end

  local stats = {}
  local lines = vim.fn.systemlist({ "git", "-C", root, "diff", "--numstat", "--no-renames", "HEAD", "--" })
  if vim.v.shell_error == 0 then
    for _, line in ipairs(lines) do
      local added, deleted, file = line:match("^(%S+)%s+(%S+)%s+(.+)$")
      if added and deleted and file then
        local text
        if added == "-" or deleted == "-" then
          text = "+? -?"
        else
          text = "+" .. added .. " -" .. deleted
        end
        stats[normalize(root .. "/" .. file)] = text
      end
    end
  end

  cache[root] = { time = now, stats = stats }
  return stats
end

return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = function(_, opts)
    opts.git_status = opts.git_status or {}
    opts.git_status.components = opts.git_status.components or {}
    opts.git_status.components.git_numstat = function(_, node, state)
      if node.type ~= "file" or not node.path then
        return nil
      end

      if vim.g.neo_tree_git_numstat_enabled ~= 1 then
        return nil
      end

      local root = git_root(state.path or vim.uv.cwd())
      if not root then
        return nil
      end

      local text = read_numstat(root)[normalize(node.path)]
      if not text then
        return nil
      end

      return {
        text = " " .. text,
        highlight = "Comment",
      }
    end

    opts.git_status.renderers = opts.git_status.renderers or {}
    opts.git_status.renderers.file = opts.git_status.renderers.file or {
      { "indent" },
      { "icon" },
      {
        "container",
        content = {
          { "name", zindex = 10 },
          { "git_numstat", zindex = 20, align = "right" },
          { "git_status", zindex = 10, align = "right" },
        },
      },
    }
  end,
}
