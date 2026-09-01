# susamn.desktop-widgets

Two desktop-layer widgets for the Omarchy shell, with **no bar widget / no
panel icon**. Loaded as a `keepLoaded` `panel` plugin, so `omarchy-shell`
mounts it at startup and it just sits on the background layer of every screen.

| Widget | Position | Notes |
|--------|----------|-------|
| Clock card | top-left | `HH:mm` + `yyyy-MM-dd`, theme-coloured |
| Pipes card | bottom-right | square; waves of runners draw slowly on a grid as flat coloured lines; finished runners stay; up to 5 kept, the 6th fades the oldest out |

Both surfaces are click-through (`mask: Region {}`), sit on `WlrLayer.Bottom`
(below normal windows — a maximised window covers them), never take keyboard
focus, and carry the Hyprland namespace `omarchy-desktop-widget`.

## Theme colours

Foundational roles (background / foreground / accent / muted) bind to the
shared `qs.Commons` `Color` singleton, which `omarchy-shell` updates over IPC
on every `omarchy theme set …` — no restart needed. The extended hues for the
pipes aren't on that singleton, so they're parsed from
`~/.local/state/omarchy/current/theme/colors.toml`
(`red/orange/yellow/green/cyan/blue/magenta` + `bright_*`), re-read whenever a
`Color` property changes. A wave then picks the most visually distinct hues
available (`_pickColors`).

## Files

- `manifest.json` — `kinds: ["panel"]`, `keepLoaded: true`
- `DesktopWidgets.qml` — the two `Variants { PanelWindow … }` surfaces + theme reader
- `Pipes.js` — pure grid/animation logic; head advances sub-cell so a
  `FrameAnimation` (~60 fps) renders it gliding, not stepping
- `PipeStroke.qml` — one flat stroked polyline (single line per runner, no 3D)

## Tunables

`DesktopWidgets.qml` top: margins, `pipesSize` (square side), `cardOpacity`,
`clockFont` (swap for a 7-segment face like `DSEG7 Classic` if installed).
Line width: the `w:` on the two `PipeStroke` lines.

`Pipes.js` top:
- `SPEED` — px/sec the head advances (lower = slower).
- `MIN_STRAIGHT` — cells travelled straight between turns (higher = calmer).
- `TURN_CHANCE` — odds of turning once a straight run is done.
- `CONCURRENT` runners per wave, `MAX_KEEP`, `FADE_PER_SEC`,
  `WANDER_MIN/MAX`, `CELL`.

Each runner enters from off the grid, wanders, then steers out an edge — it
never stops mid-card and never reverses (`_exitDir` excludes the backward
direction; wander only goes straight or 90°). Committed geometry (`bodyList`)
is whole-pixel and only rebuilt when a cell is added; the moving tip
(`headList`) is sub-pixel and rebuilt per frame — this stops the whole line
shimmering. A turn is only ever assigned to a segment that *starts* at the
cell the head has reached, so a corner never sprouts from a point the head
already passed. Wave colours are auto-picked for visual distinctness
(`_pickColors`).

To put the widgets **above** windows instead, change both
`WlrLayershell.layer: WlrLayer.Bottom` to `WlrLayer.Top`.

## Enable / apply changes

Enabled via an entry in `~/.config/omarchy/shell.json` `plugins[]`:

```json
{ "id": "susamn.desktop-widgets" }
```

**After editing any file here, run `omarchy restart shell`.** Plugin hot-reload
does *not* re-mount a `keepLoaded` panel — only a full shell restart picks up
changes to these surfaces.
