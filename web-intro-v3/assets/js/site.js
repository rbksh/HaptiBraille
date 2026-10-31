/* HaptiBraille website – shared behaviour.
   Everything here is progressive: the site reads fine with JS off or with reduced motion. */
(function () {
  "use strict";

  document.documentElement.classList.add("js");
  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var finePointer = window.matchMedia("(pointer: fine)").matches;

  /* ------------------------------------------------------------------
     Braille: Grade 1 letters (dot numbers), same table as the app.
     ------------------------------------------------------------------ */
  var LETTERS = {
    a: "1", b: "12", c: "14", d: "145", e: "15", f: "124", g: "1245", h: "125",
    i: "24", j: "245", k: "13", l: "123", m: "134", n: "1345", o: "135", p: "1234",
    q: "12345", r: "1235", s: "234", t: "2345", u: "136", v: "1236", w: "2456",
    x: "1346", y: "13456", z: "1356"
  };

  /** Fill an element with six dot <i>s; `dots` is a string like "125". */
  function fillCell(el, dots) {
    if (!el.children.length) {
      for (var n = 0; n < 6; n++) el.appendChild(document.createElement("i"));
    }
    for (var d = 1; d <= 6; d++) {
      el.children[d - 1].classList.toggle("on", dots.indexOf(String(d)) !== -1);
    }
  }

  document.querySelectorAll("[data-cell]").forEach(function (el) {
    el.classList.add("cell");
    el.setAttribute("aria-hidden", "true");
    fillCell(el, el.getAttribute("data-cell"));
  });

  /* ------------------------------------------------------------------
     Background: a field of dots that ripples like a vibration.
     ------------------------------------------------------------------ */
  var canvas = document.getElementById("field");
  var ripples = [];
  var pointer = { x: -9999, y: -9999 };

  function addRipple(x, y, strength) {
    if (reduceMotion || !canvas) return;
    ripples.push({ x: x, y: y, t0: performance.now(), s: strength });
    if (ripples.length > 14) ripples.shift();
  }

  if (canvas) {
    var ctx = canvas.getContext("2d");
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    var spacing = 30;
    var W = 0, H = 0, cols = 0, rows = 0;

    function resize() {
      W = window.innerWidth;
      H = window.innerHeight;
      canvas.width = W * dpr;
      canvas.height = H * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      spacing = W < 600 ? 24 : 30;
      cols = Math.ceil(W / spacing) + 1;
      rows = Math.ceil(H / spacing) + 1;
      if (reduceMotion) draw(performance.now());
    }

    function draw(now) {
      ctx.clearRect(0, 0, W, H);
      var live = [];
      for (var r = 0; r < ripples.length; r++) {
        var age = (now - ripples[r].t0) / 1000;
        if (age < 2.6) live.push({ x: ripples[r].x, y: ripples[r].y, age: age, s: ripples[r].s });
      }
      ripples = ripples.filter(function (rp) { return (now - rp.t0) < 2600; });

      for (var i = 0; i < cols; i++) {
        for (var j = 0; j < rows; j++) {
          var x = i * spacing + (j % 2 ? spacing / 2 : 0) - spacing / 2;
          var y = j * spacing;
          var lift = 0;

          for (var k = 0; k < live.length; k++) {
            var rp = live[k];
            var dx = x - rp.x, dy = y - rp.y;
            var dist = Math.sqrt(dx * dx + dy * dy);
            var front = rp.age * 420;
            var band = (dist - front) / 34;
            lift += Math.exp(-band * band) * (1 - rp.age / 2.6) * rp.s;
          }

          var px = x - pointer.x, py = y - pointer.y;
          var pd = Math.sqrt(px * px + py * py);
          var near = pd < 140 ? (1 - pd / 140) * 0.55 : 0;

          var glow = Math.min(1, lift);
          var radius = 1.15 + glow * 2.4 + near * 1.3;
          var alpha = 0.11 + glow * 0.55 + near * 0.25;

          ctx.beginPath();
          ctx.arc(x, y, radius, 0, Math.PI * 2);
          ctx.fillStyle = glow > 0.04
            ? "rgba(111,214,198," + alpha.toFixed(3) + ")"
            : "rgba(241,236,226," + alpha.toFixed(3) + ")";
          ctx.fill();
        }
      }
    }

    var running = false;
    function loop(now) {
      draw(now);
      if (!document.hidden) requestAnimationFrame(loop); else running = false;
    }

    window.addEventListener("resize", resize);
    resize();

    if (!reduceMotion) {
      running = true;
      requestAnimationFrame(loop);
      document.addEventListener("visibilitychange", function () {
        if (!document.hidden && !running) { running = true; requestAnimationFrame(loop); }
      });

      // A slow ambient "heartbeat" so the page feels alive even when untouched.
      setInterval(function () {
        if (document.hidden) return;
        addRipple(Math.random() * W, Math.random() * H * 0.9, 0.45);
      }, 3800);
      setTimeout(function () { addRipple(W * 0.72, H * 0.38, 0.9); }, 400);

      var lastMoveRipple = 0;
      window.addEventListener("pointermove", function (e) {
        pointer.x = e.clientX; pointer.y = e.clientY;
        var now = performance.now();
        if (now - lastMoveRipple > 420 && (Math.abs(e.movementX) + Math.abs(e.movementY)) > 14) {
          lastMoveRipple = now;
          addRipple(e.clientX, e.clientY, 0.3);
        }
      }, { passive: true });
      window.addEventListener("pointerdown", function (e) { addRipple(e.clientX, e.clientY, 1); }, { passive: true });
      document.addEventListener("pointerleave", function () { pointer.x = pointer.y = -9999; });
    }
  }

  /* ------------------------------------------------------------------
     Cursor follower: a ring that becomes a Braille cell over controls.
     (The system cursor is never hidden.)
     ------------------------------------------------------------------ */
  if (finePointer && !reduceMotion) {
    var cur = document.createElement("div");
    cur.className = "cursor";
    cur.setAttribute("aria-hidden", "true");
    for (var c = 0; c < 6; c++) cur.appendChild(document.createElement("i"));
    document.body.appendChild(cur);

    var target = { x: 0, y: 0 }, pos = { x: 0, y: 0 };
    window.addEventListener("pointermove", function (e) {
      target.x = e.clientX; target.y = e.clientY;
      cur.classList.add("is-visible");
      var hit = e.target.closest && e.target.closest("a, button, input, label, [data-cursor]");
      cur.classList.toggle("is-active", !!hit);
    }, { passive: true });
    document.addEventListener("pointerleave", function () { cur.classList.remove("is-visible"); });
    window.addEventListener("pointerdown", function () { cur.classList.add("is-down"); });
    window.addEventListener("pointerup", function () { cur.classList.remove("is-down"); });

    (function follow() {
      pos.x += (target.x - pos.x) * 0.22;
      pos.y += (target.y - pos.y) * 0.22;
      cur.style.transform = "translate3d(" + pos.x + "px," + pos.y + "px,0)";
      requestAnimationFrame(follow);
    })();
  }

  /* ------------------------------------------------------------------
     Header border on scroll, chapter rail reading progress.
     ------------------------------------------------------------------ */
  var header = document.querySelector(".site-header");
  var current = document.querySelector('.rail a[aria-current="page"]');
  function onScroll() {
    if (header) header.classList.toggle("is-scrolled", window.scrollY > 8);
    if (current) {
      var max = document.documentElement.scrollHeight - window.innerHeight;
      var pct = max > 0 ? Math.min(100, Math.max(0, (window.scrollY / max) * 100)) : 100;
      current.style.setProperty("--read", pct.toFixed(1) + "%");
    }
  }
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* ------------------------------------------------------------------
     Scroll reveal. Cells marked data-play tap their dots in when seen.
     ------------------------------------------------------------------ */
  function playCell(el) {
    var dots = Array.prototype.filter.call(el.children, function (i) { return i.classList.contains("on"); });
    dots.forEach(function (dot, n) {
      setTimeout(function () {
        dot.classList.add("hit");
        setTimeout(function () { dot.classList.remove("hit"); }, 220);
      }, 140 + n * 170);
    });
  }

  if ("IntersectionObserver" in window && !reduceMotion) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("in");
        entry.target.querySelectorAll("[data-play]").forEach(playCell);
        if (entry.target.hasAttribute("data-play")) playCell(entry.target);
        io.unobserve(entry.target);
      });
    }, { rootMargin: "0px 0px -10% 0px", threshold: 0.12 });
    document.querySelectorAll("[data-reveal], [data-play]").forEach(function (el) { io.observe(el); });
  } else {
    document.querySelectorAll("[data-reveal]").forEach(function (el) { el.classList.add("in"); });
  }

  /* ------------------------------------------------------------------
     The rhythm instrument: text -> Braille -> timed pattern -> vibration.
     Mirrors HapticTranslationEngine in the app (lib/domain/engine/).
     ------------------------------------------------------------------ */
  var PROFILES = {
    beginner: { dot: 50, empty: 80, intra: 150, inter: 500, space: 1000 },
    standard: { dot: 40, empty: 50, intra: 100, inter: 300, space: 600 },
    fast: { dot: 30, empty: 40, intra: 70, inter: 200, space: 450 }
  };
  var TICK = 15;

  /** Build segments for `text`: [{kind: tick|tap|gap|word, ms, cell, slot, char}] */
  function buildSequence(text, p) {
    var segs = [];
    var cells = [];
    var pendingGap = 0;
    var pendingKind = "gap";

    function gap(ms, kind) {
      pendingGap += ms;
      if (kind === "word") pendingKind = "word";
    }
    function flush() {
      if (pendingGap > 0) segs.push({ kind: pendingKind, ms: pendingGap });
      pendingGap = 0;
      pendingKind = "gap";
    }
    function pulse(kind, ms, cell, slot) {
      flush();
      segs.push({ kind: kind, ms: ms, cell: cell, slot: slot });
    }

    var chars = text.toLowerCase().split("");
    var wordBreak = false;
    chars.forEach(function (ch, idx) {
      if (ch === " ") { if (cells.length) wordBreak = true; return; }
      var dots = LETTERS[ch];
      if (!dots) return;
      if (cells.length) gap(wordBreak ? p.space : p.inter, wordBreak ? "word" : "gap");
      wordBreak = false;
      var ci = cells.length;
      cells.push({ dots: dots, index: idx });
      pulse("tick", TICK, ci, null);
      gap(p.intra);
      for (var s = 0; s < 6; s++) {
        if (s > 0) gap(p.intra);
        if (dots.indexOf(String(s + 1)) !== -1) pulse("tap", p.dot, ci, s);
        else gap(p.empty);
      }
    });
    flush();

    var t = 0;
    segs.forEach(function (sg) { sg.start = t; t += sg.ms; });
    return { segs: segs, cells: cells, total: t };
  }

  /** Vibration pattern for one cell (navigator.vibrate alternates on/off, starting on). */
  function cellPattern(seq, ci) {
    var pattern = [];
    var on = true;
    seq.segs.forEach(function (sg, n) {
      if (sg.cell !== ci) {
        // include silences that sit inside this cell
        var prev = seq.segs[n - 1], next = seq.segs[n + 1];
        var inside = sg.kind === "gap" && prev && next && prev.cell === ci && next.cell === ci;
        if (!inside) return;
      }
      var isOn = sg.kind === "tick" || sg.kind === "tap";
      if (isOn !== on) { pattern.push(0); on = !on; }
      pattern.push(sg.ms);
      on = !on;
    });
    return pattern;
  }

  function Instrument(root) {
    this.root = root;
    this.cell = root.querySelector(".instrument-stage .cell");
    this.readout = root.querySelector(".instrument-readout");
    this.dotsLabel = root.querySelector(".instrument-dots");
    this.strip = root.querySelector(".strip");
    this.head = root.querySelector(".strip-head");
    this.input = root.querySelector("input[type=text]");
    this.button = root.querySelector("[data-play-button]");
    this.status = root.querySelector(".instrument-status");
    this.fixed = root.getAttribute("data-text");
    this.raf = 0;
    this.canVibrate = typeof navigator.vibrate === "function";
    fillCell(this.cell, "");

    var self = this;
    if (this.button) {
      this.button.addEventListener("click", function () {
        if (self.raf) self.stop(); else self.play();
      });
    }
    if (this.input) {
      this.input.addEventListener("input", function () { self.stop(); self.render(); });
      this.input.addEventListener("keydown", function (e) {
        if (e.key === "Enter") { e.preventDefault(); self.play(); }
      });
    }
    root.querySelectorAll("input[name=speed]").forEach(function (r) {
      r.addEventListener("change", function () { self.stop(); self.render(); });
    });
    this.render();
  }

  Instrument.prototype.text = function () {
    return (this.fixed || (this.input && this.input.value) || "").slice(0, 24);
  };

  Instrument.prototype.profile = function () {
    var checked = this.root.querySelector("input[name=speed]:checked");
    return PROFILES[(checked && checked.value) || "standard"];
  };

  Instrument.prototype.render = function () {
    var text = this.text();
    this.seq = buildSequence(text, this.profile());
    var seq = this.seq;

    this.readout.innerHTML = "";
    var self = this;
    text.split("").forEach(function (ch) {
      var span = document.createElement("span");
      span.textContent = ch;
      self.readout.appendChild(span);
    });

    this.strip.querySelectorAll("b").forEach(function (b) { b.remove(); });
    seq.segs.forEach(function (sg) {
      var b = document.createElement("b");
      b.className = sg.kind;
      b.style.width = (seq.total ? (sg.ms / seq.total) * 100 : 0) + "%";
      self.strip.insertBefore(b, self.head);
    });

    var letters = seq.cells.length;
    var secs = (seq.total / 1000).toFixed(1);
    this.strip.setAttribute("aria-label",
      letters ? "Timeline of " + letters + " letters lasting " + secs + " seconds" : "Empty timeline");
    if (this.status && !this.raf) {
      this.status.textContent = letters
        ? letters + (letters === 1 ? " letter" : " letters") + ", " + secs + " seconds of rhythm."
        : "Type some letters a to z.";
    }
    fillCell(this.cell, seq.cells.length ? seq.cells[0].dots : "");
    this.dotsLabel.textContent = seq.cells.length ? "Dots " + seq.cells[0].dots.split("").join(", ") : "";
  };

  Instrument.prototype.play = function () {
    this.stop();
    this.render();
    var seq = this.seq;
    if (!seq.total) return;
    var self = this;
    var start = performance.now();
    var lastCell = -1;
    var spans = this.readout.children;
    var dots = this.cell.children;

    this.button && (this.button.querySelector("span").textContent = "Stop");
    this.head.style.opacity = "1";
    if (this.status) {
      this.status.textContent = this.canVibrate
        ? "Playing. Hold your phone to feel it."
        : "Playing. This device can't vibrate from a web page, so watch the dots. On an Android phone in Chrome you'll feel it.";
    }

    function frame(now) {
      var t = now - start;
      if (t >= seq.total) { self.stop(true); return; }
      self.head.style.left = ((t / seq.total) * 100) + "%";

      var seg = null;
      for (var n = 0; n < seq.segs.length; n++) {
        if (t >= seq.segs[n].start && t < seq.segs[n].start + seq.segs[n].ms) { seg = seq.segs[n]; break; }
      }
      var ci = seg && seg.cell != null ? seg.cell : lastCell;

      if (ci !== lastCell && ci >= 0) {
        lastCell = ci;
        var info = seq.cells[ci];
        fillCell(self.cell, info.dots);
        self.dotsLabel.textContent = "Dots " + info.dots.split("").join(", ");
        for (var s = 0; s < spans.length; s++) {
          spans[s].className = s < info.index ? "done" : s === info.index ? "now" : "";
        }
        // Vibration is the content here, not decorative motion, so it plays even with reduced motion.
        if (self.canVibrate) navigator.vibrate(cellPattern(seq, ci));
        if (!self.fixed) {
          var r = self.cell.getBoundingClientRect();
          addRipple(r.left + r.width / 2, r.top + r.height / 2, 0.6);
        }
      }
      for (var d = 0; d < 6; d++) {
        dots[d].classList.toggle("hit", !!seg && seg.kind === "tap" && seg.slot === d);
      }
      self.cell.style.outline = seg && seg.kind === "tick" ? "2px solid rgba(255,201,64,.5)" : "";
      self.cell.style.outlineOffset = "10px";
      self.cell.style.borderRadius = "14px";
      self.raf = requestAnimationFrame(frame);
    }
    this.raf = requestAnimationFrame(frame);
  };

  Instrument.prototype.stop = function (finished) {
    if (this.raf) cancelAnimationFrame(this.raf);
    this.raf = 0;
    if (this.canVibrate) navigator.vibrate(0);
    if (this.button) this.button.querySelector("span").textContent = this.fixed ? "Play again" : "Feel it";
    if (this.head) this.head.style.opacity = "0";
    if (this.cell) {
      this.cell.style.outline = "";
      Array.prototype.forEach.call(this.cell.children, function (i) { i.classList.remove("hit"); });
    }
    Array.prototype.forEach.call(this.readout ? this.readout.children : [], function (s) {
      s.className = finished ? "done" : "";
    });
    if (finished && this.status) this.status.textContent = "Done. Change the word or the speed and try again.";
  };

  document.querySelectorAll("[data-instrument]").forEach(function (el) { new Instrument(el); });
})();
