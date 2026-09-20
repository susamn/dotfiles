# yazi plugin patches

`plugins/` is gitignored and rewritten by every `ya pkg install|upgrade`, so
fixes to third-party plugins live here as patches and are re-applied afterwards
by `workspace/scripts/yazi-pkg.sh` (alias `ypkg`).

Each file is `<plugin-dir-name>.patch`, a `-p1` diff rooted at `plugins/`:

    --- a/bookmarks.yazi/main.lua
    +++ b/bookmarks.yazi/main.lua

## Current patches

| Patch | Why |
|---|---|
| `glow.yazi.patch` | `ya.mgr_emit` was removed in yazi 26 (`ya.emit` now), and it is still called in the preview `peek`/`seek` path: `<C-e>` / `<C-y>` scrolling of rendered markdown fails. Upstream last shipped 2025-06-13. |

## Regenerating one

Fetch the pristine file at the rev pinned in `package.toml`, edit a copy, diff:

    curl -o a/<plugin>.yazi/main.lua \
      https://raw.githubusercontent.com/<owner>/<repo>/<rev>/main.lua
    cp ~/.config/yazi/plugins/<plugin>.yazi/main.lua b/<plugin>.yazi/main.lua
    diff -u a/<plugin>.yazi/main.lua b/<plugin>.yazi/main.lua > patches/<plugin>.yazi.patch

`ypkg status` reports whether each patch is currently applied. When a patch
stops applying, upstream moved — check whether the fix landed there first, and
drop the patch if so.
