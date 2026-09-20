-- init.lua — plugin setup. Plugins themselves are installed by `ya pkg install`
-- from package.toml and are not tracked in this repo.

require("full-border"):setup({ type = ui.Border.ROUNDED })

require("git"):setup()

-- starship prompt as the yazi header (uses ~/.config/starship.toml)
require("starship"):setup()

