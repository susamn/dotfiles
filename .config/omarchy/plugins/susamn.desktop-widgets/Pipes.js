.pragma library

// Accumulating "pipes" field. Runners enter together in waves, each a
// different colour, from different edges. A runner ENTERS from off the grid,
// wanders with occasional 90-degree turns, then STEERS OUT an edge — it
// never stops mid-card and never doubles back on itself. Finished trails
// stay; MAX_KEEP are kept and the next to finish fades the oldest out.
//
// Rendering split: bodyList() is the committed, whole-pixel geometry that
// only changes when a cell is added; headList() is the sub-pixel leading
// segment that moves every frame. Keeping them separate stops the whole
// polyline from re-rasterising (and shimmering) 60 times a second.

var CELL = 24;            // grid pitch in px
var SPEED = 20;           // head advance, px per second (lower = slower)
var CONCURRENT = 3;       // runners drawing at once, per wave
var MAX_KEEP = 5;         // finished runners kept fully visible
var FADE_PER_SEC = 1.1;   // opacity lost per second while a runner fades
var WANDER_MIN = 4;       // cells wandered before steering for an exit
var WANDER_MAX = 10;
var TURN_CHANCE = 0.28;   // chance of a turn once a straight run is allowed
var MIN_STRAIGHT = 3;     // cells travelled straight between turns

function _rand(n) { return Math.floor(Math.random() * n); }

function _shuffled(arr) {
  var a = arr.slice();
  for (var i = a.length - 1; i > 0; i--) {
    var j = _rand(i + 1);
    var t = a[i]; a[i] = a[j]; a[j] = t;
  }
  return a;
}

function _rgb(hex) {
  var h = String(hex).replace("#", "");
  return [parseInt(h.substr(0, 2), 16), parseInt(h.substr(2, 2), 16), parseInt(h.substr(4, 2), 16)];
}

function _dist(a, b) {
  var x = _rgb(a), y = _rgb(b);
  return Math.sqrt((x[0] - y[0]) * (x[0] - y[0]) + (x[1] - y[1]) * (x[1] - y[1]) + (x[2] - y[2]) * (x[2] - y[2]));
}

// Greedily pick n colours as visually distinct from each other as possible
// (matters on near-monochrome themes). Falls back to repeats only when the
// palette genuinely can't offer n separable hues.
function _pickColors(pal, n) {
  if (pal.length === 0) return ["#f38d70"];
  var pool = _shuffled(pal);
  var chosen = [pool.shift()];
  while (chosen.length < n && pool.length > 0) {
    var bestI = 0, bestScore = -1;
    for (var i = 0; i < pool.length; i++) {
      var minD = Infinity;
      for (var c = 0; c < chosen.length; c++) minD = Math.min(minD, _dist(pool[i], chosen[c]));
      if (minD > bestScore) { bestScore = minD; bestI = i; }
    }
    chosen.push(pool.splice(bestI, 1)[0]);
  }
  while (chosen.length < n) chosen.push(pal[chosen.length % pal.length]);
  return chosen;
}

function createManager(colorsProvider) {
  return {
    finished: [],   // [{ cells, color, opacity, fading }]
    active: [],     // [{ cells, dir, color, frac, phase, wanderLeft, straightRun, exitDir, done }]
    cols: 3,
    rows: 3,
    colors: colorsProvider,
    structDirty: true,   // committed geometry changed — QML should rebuild bodyList()

    _resize: function (w, h) {
      var c = Math.max(4, Math.floor(w / CELL));
      var r = Math.max(4, Math.floor(h / CELL));
      if (c !== this.cols || r !== this.rows) { this.cols = c; this.rows = r; this.structDirty = true; }
    },

    _inside: function (c, r) {
      return c >= 0 && c < this.cols && r >= 0 && r < this.rows;
    },

    // Direction to steer for an exit: the nearest edge, but never a reversal
    // of the current heading (that would draw the pipe backwards).
    _exitDir: function (cell, cur) {
      var rev = { c: -cur.c, r: -cur.r };
      var cand = [
        { dir: { c: -1, r: 0 }, n: cell.c },
        { dir: { c: 1,  r: 0 }, n: this.cols - 1 - cell.c },
        { dir: { c: 0,  r: -1 }, n: cell.r },
        { dir: { c: 0,  r: 1 }, n: this.rows - 1 - cell.r }
      ].filter(function (o) { return !(o.dir.c === rev.c && o.dir.r === rev.r); });
      cand.sort(function (a, b) { return a.n - b.n; });
      return cand[0].dir;
    },

    _spawnWave: function () {
      var pal = this.colors() || ["#f38d70"];
      var colors = _pickColors(pal, Math.max(1, CONCURRENT));
      var edges = _shuffled([0, 1, 2, 3]);
      var n = Math.max(1, CONCURRENT);
      for (var i = 0; i < n; i++) {
        var edge = edges[i % edges.length];
        var head, dir;
        if (edge === 0)      { head = { c: -1,         r: 1 + _rand(this.rows - 2) }; dir = { c: 1,  r: 0 }; }
        else if (edge === 1) { head = { c: this.cols,  r: 1 + _rand(this.rows - 2) }; dir = { c: -1, r: 0 }; }
        else if (edge === 2) { head = { c: 1 + _rand(this.cols - 2), r: -1 };         dir = { c: 0,  r: 1 }; }
        else                 { head = { c: 1 + _rand(this.cols - 2), r: this.rows };  dir = { c: 0,  r: -1 }; }
        this.active.push({
          cells: [head], dir: dir, color: colors[i % colors.length],
          frac: 0, phase: "enter",
          wanderLeft: WANDER_MIN + _rand(WANDER_MAX - WANDER_MIN),
          straightRun: 0, exitDir: null, done: false
        });
      }
      this.structDirty = true;
    },

    _perp: function (dir) {
      return dir.c !== 0 ? [{ c: 0, r: -1 }, { c: 0, r: 1 }]
                         : [{ c: -1, r: 0 }, { c: 1, r: 0 }];
    },

    _inwardPerp: function (cell, dir) {
      var perp = this._perp(dir), out = [];
      for (var i = 0; i < perp.length; i++)
        if (this._inside(cell.c + perp[i].c, cell.r + perp[i].r)) out.push(perp[i]);
      return out;
    },

    // A commit advances the head exactly ONE cell along its current direction —
    // the cell the head has already visually reached — and only THEN picks the
    // direction for the *next* segment. The direction never changes for a
    // stretch that is already drawn, so a turn always sprouts from the cell the
    // head is at, never from a point it passed earlier.
    _commit: function (r) {
      var head = r.cells[r.cells.length - 1];

      if (r.phase === "enter") {
        var nx = { c: head.c + r.dir.c, r: head.r + r.dir.r };
        r.cells.push(nx);
        if (this._inside(nx.c, nx.r)) { r.phase = "wander"; r.straightRun = 0; }
        this.structDirty = true;
        return;
      }

      if (r.phase === "exit") {
        var ox = { c: head.c + r.dir.c, r: head.r + r.dir.r };
        r.cells.push(ox);
        if (!this._inside(ox.c, ox.r)) {
          r.outSteps = (r.outSteps || 0) + 1;
          if (r.outSteps >= 2) r.done = true;
        }
        this.structDirty = true;
        return;
      }

      // ---- wander -------------------------------------------------------
      // 1. step one cell along the current heading.
      var step = { c: head.c + r.dir.c, r: head.r + r.dir.r };
      if (!this._inside(step.c, step.r)) {
        // guard: about to walk off-grid — turn at `head` instead.
        var esc = this._inwardPerp(head, r.dir);
        if (esc.length) {
          r.dir = esc[_rand(esc.length)];
          r.straightRun = 0;
          step = { c: head.c + r.dir.c, r: head.r + r.dir.r };
        }
      }
      r.cells.push(step);
      r.straightRun++;
      this.structDirty = true;

      if (--r.wanderLeft <= 0) {
        r.phase = "exit";
        r.dir = this._exitDir(step, r.dir);
        return;
      }

      // 2. decide the heading of the segment that STARTS at `step`.
      var inward = this._inwardPerp(step, r.dir);
      var straightOk = this._inside(step.c + r.dir.c, step.r + r.dir.r);
      var forceTurn = !straightOk && inward.length > 0;
      var wantTurn = r.straightRun >= MIN_STRAIGHT && Math.random() < TURN_CHANCE && inward.length > 0;
      if (forceTurn || wantTurn) {
        r.dir = inward[_rand(inward.length)];
        r.straightRun = 0;
      }
    },

    _retire: function (r) {
      this.finished.push({ cells: r.cells, color: r.color, opacity: 1, fading: false });
      var solid = 0;
      for (var i = 0; i < this.finished.length; i++)
        if (!this.finished[i].fading) solid++;
      if (solid > MAX_KEEP) {
        for (var j = 0; j < this.finished.length; j++)
          if (!this.finished[j].fading) { this.finished[j].fading = true; break; }
      }
      this.structDirty = true;
    },

    // dt in seconds.
    step: function (dt, w, h) {
      this._resize(w, h);
      if (this.active.length === 0) this._spawnWave();

      for (var i = this.active.length - 1; i >= 0; i--) {
        var r = this.active[i];
        r.frac += (SPEED * dt) / CELL;
        var guard = 0;
        while (r.frac >= 1 && !r.done && guard++ < 8) { r.frac -= 1; this._commit(r); }
        if (r.done) { this._retire(r); this.active.splice(i, 1); }
      }

      for (var k = this.finished.length - 1; k >= 0; k--) {
        if (this.finished[k].fading) {
          this.finished[k].opacity -= FADE_PER_SEC * dt;
          this.structDirty = true;   // opacity moved — bodyList carries it
          if (this.finished[k].opacity <= 0) this.finished.splice(k, 1);
        }
      }
    },

    _origin: function (w, h) {
      return [
        Math.round((w - this.cols * CELL) / 2 + CELL / 2),
        Math.round((h - this.rows * CELL) / 2 + CELL / 2)
      ];
    },

    // Committed geometry. [{ pts: [[x,y],...], color, opacity }]
    bodyList: function (w, h) {
      var o = this._origin(w, h), ox = o[0], oy = o[1];
      var px = function (cell) { return [ox + cell.c * CELL, oy + cell.r * CELL]; };
      var out = [];
      for (var i = 0; i < this.finished.length; i++) {
        var f = this.finished[i], fp = [];
        for (var a = 0; a < f.cells.length; a++) fp.push(px(f.cells[a]));
        out.push({ pts: fp, color: f.color, opacity: f.opacity });
      }
      for (var j = 0; j < this.active.length; j++) {
        var r = this.active[j], ap = [];
        for (var b = 0; b < r.cells.length; b++) ap.push(px(r.cells[b]));
        out.push({ pts: ap, color: r.color, opacity: 1 });
      }
      return out;
    },

    // Moving leading segments only. [{ pts: [[x,y],[x,y]], color }]
    headList: function (w, h) {
      var o = this._origin(w, h), ox = o[0], oy = o[1];
      var out = [];
      for (var j = 0; j < this.active.length; j++) {
        var r = this.active[j];
        if (r.frac <= 0.02) continue;
        var last = r.cells[r.cells.length - 1];
        var lx = ox + last.c * CELL, ly = oy + last.r * CELL;
        out.push({
          pts: [[lx, ly], [lx + r.dir.c * r.frac * CELL, ly + r.dir.r * r.frac * CELL]],
          color: r.color
        });
      }
      return out;
    }
  };
}
