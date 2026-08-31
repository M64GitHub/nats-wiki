/* LLM wiki viewer — force-directed link graph on <canvas>. Used by graph.html and by the local graph on every page.
   Page types come from window.GRAPH.types (graph-data.js, generated from wiki.json); every colour is read
   from the live CSS variables (assets/theme.css + types.css) so the canvas follows the light/dark switch. */
window.WikiGraph = (function () {
  'use strict';
  const TYPE_DEFS = (window.GRAPH && window.GRAPH.types) || [{ id: 'technique', color: '#5fd9e0' }, { id: 'concept', color: '#ffb454' }, { id: 'entity', color: '#ff6fa5' }, { id: 'summary', color: '#7ee787' }];
  const COLORS = { wanted: '#ff5c5c', other: '#8890ad' };
  const PAINT = { edge: 'rgba(255,255,255,.1)', edgeDim: 'rgba(255,255,255,.05)', edgeSpoke: 'rgba(255,255,255,.22)',
    edgeOn: 'rgba(95,217,224,.8)', halo: 'rgba(14,18,32,.92)', label: '#dfe4f5', labelDim: '#b9c0d8', ring: '#fff',
    font: 'ui-monospace, Menlo, monospace' };
  let probe = null;
  function resolve(expr, fallback) {   // computed style resolves var() chains; getPropertyValue would not
    if (!probe) {
      probe = document.createElement('span');
      probe.style.cssText = 'position:absolute;left:-9999px;top:0;visibility:hidden';
      (document.body || document.documentElement).appendChild(probe);
    }
    probe.style.color = 'var(' + expr + ', ' + fallback + ')';
    return getComputedStyle(probe).color || fallback;
  }
  function readPaint() {   // re-read after a theme switch
    TYPE_DEFS.forEach(t => { COLORS[t.id] = resolve('--t-' + t.id, t.color); });
    COLORS.wanted = resolve('--t-wanted', '#ff5c5c');
    COLORS.other = resolve('--dim', '#8890ad');
    PAINT.edge = resolve('--g-edge', 'rgba(255,255,255,.1)');
    PAINT.edgeDim = resolve('--g-edge-dim', 'rgba(255,255,255,.05)');
    PAINT.edgeSpoke = resolve('--g-edge-spoke', 'rgba(255,255,255,.22)');
    PAINT.edgeOn = resolve('--g-edge-on', 'rgba(95,217,224,.8)');
    PAINT.halo = resolve('--g-halo', 'rgba(14,18,32,.92)');
    PAINT.label = resolve('--g-label', '#dfe4f5');
    PAINT.labelDim = resolve('--g-label-dim', '#b9c0d8');
    PAINT.ring = resolve('--g-ring', '#fff');
    probe.style.fontFamily = 'var(--ui, ui-monospace, Menlo, monospace)';
    PAINT.font = getComputedStyle(probe).fontFamily || 'ui-monospace, Menlo, monospace';
  }
  const instances = [];
  const ALL_TYPES = TYPE_DEFS.map(t => t.id).concat(['wanted']);
  const ORDER = {}; ALL_TYPES.forEach((t, i) => { ORDER[t] = i; });
  const color = t => COLORS[t] || COLORS.other;

  function adjacency(data) {
    const adj = data.nodes.map(() => []);
    data.links.forEach(([a, b]) => { adj[a].push(b); adj[b].push(a); });
    return adj;
  }

  function subgraph(data, focusIdx, depth, types) {
    const keep = new Set();
    if (focusIdx != null && focusIdx >= 0) {
      const adj = adjacency(data);
      let frontier = [focusIdx]; keep.add(focusIdx);
      for (let d = 0; d < depth; d++) {
        const next = [];
        for (const i of frontier) for (const j of adj[i]) if (!keep.has(j)) { keep.add(j); next.push(j); }
        frontier = next;
      }
    } else data.nodes.forEach((n, i) => keep.add(i));
    const idmap = new Map(), nodes = [];
    data.nodes.forEach((n, i) => {
      if (keep.has(i) && (types.has(n.type) || i === focusIdx)) { idmap.set(i, nodes.length); nodes.push(Object.assign({ i0: i, x: 0, y: 0, vx: 0, vy: 0, d: 0 }, n)); }
    });
    const links = [];
    data.links.forEach(([a, b]) => { if (idmap.has(a) && idmap.has(b)) links.push([idmap.get(a), idmap.get(b)]); });
    links.forEach(([a, b]) => { nodes[a].d++; nodes[b].d++; });
    const focus = focusIdx != null && idmap.has(focusIdx) ? idmap.get(focusIdx) : -1;
    return { nodes, links, focus };
  }

  function create(canvas, data, opts) {
    opts = opts || {};
    const ctx = canvas.getContext('2d');
    const st = {
      g: null, tx: 0, ty: 0, scale: 1, hover: -1, drag: null, pan: null, alpha: 1, autofit: true, raf: 0,
      types: new Set(opts.types || ALL_TYPES), depth: opts.depth || 2, labels: opts.labels !== false,
      focus: opts.focus || null, search: '', mini: !!opts.mini, dpr: window.devicePixelRatio || 1, w: 0, h: 0, moved: 0
    };
    const root = opts.root || '';

    function findIdx(slug) { return slug ? data.nodes.findIndex(n => n.id === slug) : -1; }

    function build() {
      const fi = findIdx(st.focus);
      st.g = subgraph(data, fi >= 0 ? fi : null, st.depth, st.types);
      st.hover = -1; st.autofit = true;
      if (opts.onCount) opts.onCount(st.g.nodes.length, st.g.links.length);
      if (st.mini) { layoutRadial(); st.alpha = 0; fit(); draw(); if (st.g.focus >= 0) caption(st.g.nodes[st.g.focus].d + ' linked pages · hover a dot'); return; }
      const n = st.g.nodes.length, R = Math.max(120, 16 * Math.sqrt(n) * 2.2);
      st.g.nodes.forEach((nd, i) => {   // deterministic spiral start so rebuilds look alike
        const a = i * 2.39996, r = R * Math.sqrt((i + 1) / n);
        nd.x = Math.cos(a) * r; nd.y = Math.sin(a) * r; nd.vx = nd.vy = 0;
        if (i === st.g.focus) { nd.x = nd.y = 0; }
      });
      st.alpha = 1;
      start();
    }

    /* local graph: focus in the centre, neighbours on a ring sorted by type, no physics */
    function layoutRadial() {
      const ns = st.g.nodes, f = st.g.focus;
      const others = ns.map((a, i) => i).filter(i => i !== f);
      const order = ORDER;
      others.sort((i, j) => (order[ns[i].type] || 9) - (order[ns[j].type] || 9) || ns[i].title.localeCompare(ns[j].title));
      const R = 100;
      others.forEach((i, k) => { const a = -Math.PI / 2 + (k / others.length) * Math.PI * 2; ns[i].x = Math.cos(a) * R; ns[i].y = Math.sin(a) * R; ns[i].ang = a; });
      if (f >= 0) { ns[f].x = 0; ns[f].y = 0; ns[f].ang = null; }
    }

    function resize() {
      const r = canvas.getBoundingClientRect();
      st.w = Math.max(1, r.width); st.h = Math.max(1, r.height);
      canvas.width = Math.round(st.w * st.dpr); canvas.height = Math.round(st.h * st.dpr);
      draw();
    }

    function tick() {
      const ns = st.g.nodes, ls = st.g.links, n = ns.length, al = st.alpha;
      const rep = 3200, len = 55 + 8 * Math.log2(n + 1), grav = 0.03, cut = 360000, vmax = 12;
      for (let i = 0; i < n; i++) ns[i].fx = ns[i].fy = 0;
      for (let i = 0; i < n; i++) {
        const a = ns[i];
        for (let j = i + 1; j < n; j++) {
          const b = ns[j];
          let dx = a.x - b.x, dy = a.y - b.y, d2 = dx * dx + dy * dy + 1;
          if (d2 > cut) continue;
          const f = rep / d2, d = Math.sqrt(d2);
          dx = dx / d * f; dy = dy / d * f;
          a.fx += dx; a.fy += dy; b.fx -= dx; b.fy -= dy;
        }
      }
      for (const [i, j] of ls) {   // springs, weakened on the high-degree side so hubs stay stable (d3-style bias)
        const a = ns[i], b = ns[j];
        const dx = b.x - a.x, dy = b.y - a.y, d = Math.sqrt(dx * dx + dy * dy) + 0.01;
        const L = len + 4 * (Math.sqrt(a.d) + Math.sqrt(b.d));
        const f = (d - L) * 0.08, ka = 1 / Math.sqrt(a.d || 1), kb = 1 / Math.sqrt(b.d || 1);
        a.fx += dx / d * f * ka; a.fy += dy / d * f * ka; b.fx -= dx / d * f * kb; b.fy -= dy / d * f * kb;
      }
      for (let i = 0; i < n; i++) {
        const a = ns[i];
        if (st.drag && st.drag.i === i) { a.vx = a.vy = 0; continue; }
        a.fx -= a.x * grav; a.fy -= a.y * grav;
        if (i === st.g.focus) { a.fx -= a.x * 0.3; a.fy -= a.y * 0.3; }
        a.vx = (a.vx + a.fx * al) * 0.6; a.vy = (a.vy + a.fy * al) * 0.6;
        const v = Math.sqrt(a.vx * a.vx + a.vy * a.vy);
        if (v > vmax) { a.vx *= vmax / v; a.vy *= vmax / v; }
        a.x += a.vx; a.y += a.vy;
      }
      st.alpha *= 0.985;
    }

    function fit() {
      const ns = st.g.nodes; if (!ns.length) return;
      let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
      ns.forEach(a => { x0 = Math.min(x0, a.x); y0 = Math.min(y0, a.y); x1 = Math.max(x1, a.x); y1 = Math.max(y1, a.y); });
      if (st.mini) {   // ring of radius 100 world units, centred, leaving room for labels above/below
        const Rpx = Math.min(st.w, st.h) / 2 - (miniLabels() ? 30 : 12);
        st.scale = Math.max(0.05, Rpx / 100); st.tx = st.w / 2; st.ty = st.h / 2; st.fitScale = st.scale; return;
      }
      const pad = 70, bw = Math.max(40, x1 - x0), bh = Math.max(40, y1 - y0);
      const s = Math.min((st.w - pad * 2) / bw, (st.h - pad * 2) / bh, 1.3);
      st.scale = s; st.fitScale = s; st.tx = st.w / 2 - (x0 + x1) / 2 * s; st.ty = st.h / 2 - (y0 + y1) / 2 * s;
    }
    function miniLabels() { return st.labels && st.g.nodes.length <= 6; }
    function caption(text) { const el = opts.caption; if (el) el.textContent = text; }

    function radius(a) { return (st.mini ? 4 : 2.5) + Math.sqrt(a.d) * (st.mini ? 1.2 : 1.4); }
    function short(t, n) { return t.length > n ? t.slice(0, n - 1) + '…' : t; }

    function draw() {
      if (!st.g) return;
      const ns = st.g.nodes, ls = st.g.links;
      ctx.setTransform(st.dpr, 0, 0, st.dpr, 0, 0);
      ctx.clearRect(0, 0, st.w, st.h);
      ctx.translate(st.tx, st.ty); ctx.scale(st.scale, st.scale);
      const hov = st.hover, nb = new Set();
      if (hov >= 0) { nb.add(hov); ls.forEach(([i, j]) => { if (i === hov) nb.add(j); if (j === hov) nb.add(i); }); }
      const q = st.search, hl = new Set();
      if (q) ns.forEach((a, i) => { if (a.title.toLowerCase().includes(q) || a.id.includes(q)) hl.add(i); });
      for (const [i, j] of ls) {
        const a = ns[i], b = ns[j];
        const on = hov >= 0 && (i === hov || j === hov);
        const spoke = st.mini && (i === st.g.focus || j === st.g.focus);
        ctx.strokeStyle = on ? PAINT.edgeOn : (hov >= 0 ? PAINT.edgeDim : (spoke ? PAINT.edgeSpoke : PAINT.edge));
        ctx.lineWidth = (on ? 1.6 : 1) / st.scale;
        ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
      }
      const fontPx = st.mini ? 10 / st.scale : Math.max(9, Math.min(13, 11 / Math.sqrt(st.scale)));
      ctx.font = fontPx + 'px ' + PAINT.font; ctx.textBaseline = 'middle';
      const cx = (st.w / 2 - st.tx) / st.scale;
      for (let i = 0; i < ns.length; i++) {
        const a = ns[i], r = radius(a), dimmed = (hov >= 0 && !nb.has(i)) || (hl.size && !hl.has(i));
        ctx.globalAlpha = dimmed ? 0.22 : 1;
        ctx.beginPath(); ctx.arc(a.x, a.y, r, 0, Math.PI * 2);
        ctx.fillStyle = color(a.type); ctx.fill();
        if (i === st.g.focus || hl.has(i)) { ctx.strokeStyle = PAINT.ring; ctx.lineWidth = 1.5 / st.scale; ctx.stroke(); }
        if (a.type === 'wanted') { ctx.strokeStyle = COLORS.wanted; ctx.lineWidth = 1 / st.scale; ctx.setLineDash([2 / st.scale, 2 / st.scale]); ctx.stroke(); ctx.setLineDash([]); }
      }
      ctx.globalAlpha = 1;
      /* labels: highest priority first, each one only if it does not overlap an already placed label */
      const want = [];
      if (st.mini) { if (miniLabels()) ns.forEach((a, i) => { if (i !== st.g.focus) want.push([0, i]); }); }
      else {
        ns.forEach((a, i) => {
          const pri = i === st.g.focus ? 0 : (i === hov ? 1 : nb.has(i) ? 2 : hl.has(i) ? 3 : 10);
          if (pri < 10 || st.labels) want.push([pri, i]);
        });
      }
      want.sort((p, q) => p[0] - q[0] || ns[q[1]].d - ns[p[1]].d);
      const placed = [], lh = fontPx * st.scale + 4;
      const free = (x, y, w) => { for (const b of placed) if (x < b[0] + b[2] && x + w > b[0] && y < b[1] + lh && y + lh > b[1]) return false; return true; };
      for (const [pri, i] of want) {
        const a = ns[i], r = radius(a), dimmed = (hov >= 0 && !nb.has(i)) || (hl.size && !hl.has(i));
        const t = short(a.title, st.mini ? 24 : 34), tw = ctx.measureText(t).width * st.scale;
        let lx, ly, align, sx, sy;   // world coords for drawing, screen coords for collision
        if (st.mini && a.ang != null) {
          const up = Math.sin(a.ang) < 0;
          lx = a.x; ly = a.y + (up ? -1 : 1) * (r + 9 / st.scale); align = 'center';
          sx = lx * st.scale + st.tx - tw / 2;
          sx = Math.max(3, Math.min(st.w - tw - 3, sx)); lx = (sx + tw / 2 - st.tx) / st.scale;   // keep inside the canvas
          sy = ly * st.scale + st.ty - lh / 2;
        } else {
          const left = a.x > cx; align = left ? 'right' : 'left';
          lx = left ? a.x - r - 4 / st.scale : a.x + r + 4 / st.scale; ly = a.y;
          sx = lx * st.scale + st.tx - (left ? tw : 0); sy = ly * st.scale + st.ty - lh / 2;
        }
        if (pri >= 3 && !free(sx, sy, tw)) continue;
        placed.push([sx, sy, tw]);
        ctx.globalAlpha = dimmed ? 0.35 : 1;
        ctx.textAlign = align;
        ctx.lineWidth = 3 / st.scale; ctx.strokeStyle = PAINT.halo; ctx.lineJoin = 'round';
        ctx.strokeText(t, lx, ly);
        ctx.fillStyle = nb.has(i) || i === hov || i === st.g.focus ? PAINT.ring : (pri < 10 ? PAINT.label : PAINT.labelDim);
        ctx.fillText(t, lx, ly);
      }
      ctx.globalAlpha = 1;
    }

    function frame() {
      if (st.alpha > 0.012) {
        tick();
        if (st.autofit) fit();
        draw();
        st.raf = requestAnimationFrame(frame);
      } else { st.raf = 0; draw(); }
    }
    function start() { if (!st.raf) st.raf = requestAnimationFrame(frame); }
    function reheat(a) { if (st.mini) return; st.alpha = Math.max(st.alpha, a); start(); }

    function toWorld(ev) {
      const r = canvas.getBoundingClientRect();
      return [(ev.clientX - r.left - st.tx) / st.scale, (ev.clientY - r.top - st.ty) / st.scale];
    }
    function hit(ev) {
      const [x, y] = toWorld(ev); let best = -1, bd = 1e9;
      st.g.nodes.forEach((a, i) => { const dx = a.x - x, dy = a.y - y, d = Math.sqrt(dx * dx + dy * dy); const rr = radius(a) + 5 / st.scale; if (d < rr && d < bd) { bd = d; best = i; } });
      return best;
    }
    function tip(ev, i) {
      const el = opts.tip; if (!el) { canvas.title = i >= 0 ? st.g.nodes[i].title : ''; return; }
      if (i < 0) { el.hidden = true; return; }
      const a = st.g.nodes[i];
      el.innerHTML = '<b>' + a.title.replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c])) + '</b>' + a.type + (a.kind ? ' · ' + a.kind : '') + ' · ' + a.d + ' link' + (a.d === 1 ? '' : 's') + '<br><span class="gdim">click: open · double-click: focus</span>';
      el.hidden = false; el.style.left = (ev.clientX + 14) + 'px'; el.style.top = (ev.clientY + 14) + 'px';
    }

    canvas.addEventListener('mousemove', ev => {
      if (st.drag) {
        const [x, y] = toWorld(ev); const a = st.g.nodes[st.drag.i]; a.x = x; a.y = y; st.moved++; st.autofit = false; reheat(0.25); draw(); return;
      }
      if (st.pan) { st.tx = st.pan.tx + (ev.clientX - st.pan.x); st.ty = st.pan.ty + (ev.clientY - st.pan.y); st.moved++; st.autofit = false; draw(); return; }
      const h = hit(ev);
      if (h !== st.hover) { st.hover = h; canvas.style.cursor = h >= 0 ? 'pointer' : (st.mini ? 'default' : 'grab'); draw(); if (st.mini) caption(h >= 0 ? st.g.nodes[h].title + ' · ' + st.g.nodes[h].type + (st.g.nodes[h].d > 1 ? ' · ' + st.g.nodes[h].d + ' links' : '') : (st.g.focus >= 0 ? st.g.nodes[st.g.focus].d + ' linked pages · hover a dot' : '')); }
      tip(ev, h);
    });
    canvas.addEventListener('mouseleave', () => { st.hover = -1; tip(null, -1); draw(); if (st.mini && st.g.focus >= 0) caption(st.g.nodes[st.g.focus].d + ' linked pages · hover a dot'); });
    canvas.addEventListener('mousedown', ev => {
      ev.preventDefault(); st.moved = 0;
      const h = hit(ev);
      if (h >= 0) st.drag = { i: h }; else if (!st.mini) st.pan = { x: ev.clientX, y: ev.clientY, tx: st.tx, ty: st.ty };
    });
    window.addEventListener('mouseup', () => {
      if (st.drag) {
        const i = st.drag.i; st.drag = null;
        if (st.moved < 3) { const a = st.g.nodes[i]; if (opts.onOpen) opts.onOpen(a); else location.href = root + a.url; }
        reheat(0.2);
      }
      st.pan = null;
    });
    canvas.addEventListener('dblclick', ev => {
      const h = hit(ev); if (h >= 0 && opts.onFocus) { ev.preventDefault(); opts.onFocus(st.g.nodes[h]); }
    });
    canvas.addEventListener('wheel', ev => {
      if (st.mini) return;
      ev.preventDefault();
      const r = canvas.getBoundingClientRect(), mx = ev.clientX - r.left, my = ev.clientY - r.top;
      const k = Math.exp(-ev.deltaY * 0.0015), ns = Math.min(6, Math.max(0.15, st.scale * k)), kk = ns / st.scale;
      st.tx = mx - (mx - st.tx) * kk; st.ty = my - (my - st.ty) * kk; st.scale = ns; st.autofit = false; draw();
    }, { passive: false });
    if (window.ResizeObserver) new ResizeObserver(() => { resize(); if (st.autofit) { fit(); draw(); } }).observe(canvas);
    else window.addEventListener('resize', resize);

    resize(); build();
    const api = {
      setTypes(types) { st.types = new Set(types); build(); },
      setFocus(slug) { st.focus = slug; build(); },
      setDepth(d) { st.depth = d; build(); },
      setSearch(s) { st.search = (s || '').trim().toLowerCase(); draw(); },
      setLabels(b) { st.labels = b; if (st.mini) fit(); draw(); },
      fit() { fit(); draw(); },
      state: st, tick, draw
    };
    instances.push(api);
    return api;
  }

  document.addEventListener('themechange', () => { readPaint(); instances.forEach(a => a.draw()); });

  /* ---------- wire up the graph page and the local graphs ---------- */
  document.addEventListener('DOMContentLoaded', () => {
    const data = window.GRAPH, ROOT = window.ROOT || '';
    if (!data) return;
    readPaint();
    const big = document.getElementById('graph');
    if (big) {
      const $ = s => document.querySelector(s);
      const params = new URLSearchParams(location.search);
      const gfocus = $('#gfocus'), gdepth = $('#gdepth'), gq = $('#gq'), gn = $('#gn'), gtip = $('#gtip'), gclear = $('#gclear'), glabels = $('#glabels');
      const focus = params.get('focus') || null;
      if (focus) gfocus.value = focus;
      const api = create(big, data, {
        focus, depth: +gdepth.value, root: ROOT, tip: gtip,
        onCount: (n, l) => { gn.textContent = n + ' nodes · ' + l + ' links' + (focus || gfocus.value ? '' : ''); },
        onFocus: nd => { gfocus.value = nd.id; api.setFocus(nd.id); params.set('focus', nd.id); history.replaceState(null, '', '?' + params); }
      });
      document.querySelectorAll('.legend input').forEach(cb => cb.addEventListener('change', () => {
        api.setTypes(Array.from(document.querySelectorAll('.legend input')).filter(x => x.checked).map(x => x.dataset.t));
      }));
      gq.addEventListener('input', () => api.setSearch(gq.value));
      gdepth.addEventListener('change', () => api.setDepth(+gdepth.value));
      let ft = null;
      gfocus.addEventListener('input', () => { clearTimeout(ft); ft = setTimeout(() => { const v = gfocus.value.trim(); api.setFocus(v || null); if (v) params.set('focus', v); else params.delete('focus'); history.replaceState(null, '', location.pathname + (v ? '?' + params : '')); }, 250); });
      gclear.addEventListener('click', () => { gfocus.value = ''; api.setFocus(null); history.replaceState(null, '', location.pathname); });
      glabels.addEventListener('change', () => api.setLabels(glabels.checked));
    }
    document.querySelectorAll('canvas.minigraph').forEach(c => create(c, data, { focus: c.dataset.focus, depth: 1, mini: true, root: ROOT, labels: true, caption: c.nextElementSibling && c.nextElementSibling.classList.contains('mgcap') ? c.nextElementSibling : null }));
  });

  return { create, COLORS };
})();
