/* LLM wiki viewer — navigation, search, inbox TOC tables, cheat-sheet tabs, raw-line links. No dependencies.
   Reads window.WIKI_CFG ({facets, types, tocs}) written by build-site.py from wiki.json. */
(function () {
  'use strict';
  const ROOT = window.ROOT || '';
  const $ = (s, el) => (el || document).querySelector(s);
  const $$ = (s, el) => Array.from((el || document).querySelectorAll(s));
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const CFG = window.WIKI_CFG || {}, FACET_KEYS = CFG.facets || [], TOC_TYPES = CFG.tocs || {};
  const FILTER_KEYS = ['type', 'kind', 'tag'].concat(FACET_KEYS);
  const isToc = e => !!TOC_TYPES[e.type];

  /* ---------- theme: auto (follows the system) / light / dark ----------
     The inline script in <head> has already applied the stored choice, so there is no flash here;
     this only wires the header button and tells the canvas graphs to repaint. */
  const themeBtn = $('#theme');
  if (themeBtn) {
    const ICON = {
      auto: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3" aria-hidden="true"><circle cx="8" cy="8" r="5.6"/><path d="M8 2.4a5.6 5.6 0 0 1 0 11.2z" fill="currentColor" stroke="none"/></svg>',
      light: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" aria-hidden="true"><circle cx="8" cy="8" r="3.1"/><path d="M8 .9v1.8M8 13.3v1.8M.9 8h1.8M13.3 8h1.8M2.9 2.9l1.3 1.3M11.8 11.8l1.3 1.3M13.1 2.9l-1.3 1.3M4.2 11.8l-1.3 1.3"/></svg>',
      dark: '<svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M13.6 9.7A5.9 5.9 0 0 1 6.3 2.4 5.9 5.9 0 1 0 13.6 9.7z"/></svg>'
    };
    const NEXT = { auto: 'light', light: 'dark', dark: 'auto' };
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const pref = () => { try { return NEXT[localStorage.getItem('theme')] ? localStorage.getItem('theme') : 'auto'; } catch (e) { return 'auto'; } };
    function applyTheme(p) {
      document.documentElement.dataset.theme = p === 'auto' ? (mq.matches ? 'dark' : 'light') : p;
      themeBtn.innerHTML = ICON[p];
      themeBtn.title = 'theme: ' + p + (p === 'auto' ? ' (follows your system)' : '') + ' — click for ' + NEXT[p];
      themeBtn.setAttribute('aria-label', themeBtn.title);
      document.dispatchEvent(new CustomEvent('themechange'));
    }
    themeBtn.addEventListener('click', () => {
      const p = NEXT[pref()];
      try { localStorage.setItem('theme', p); } catch (e) { /* storage unavailable */ }
      applyTheme(p);
    });
    mq.addEventListener('change', () => { if (pref() === 'auto') applyTheme('auto'); });
    applyTheme(pref());
  }

  /* ---------- sidebar: mark the current page, remember open groups, filter ---------- */
  function samePage(href) {
    try { return new URL(href, location.href).pathname === location.pathname; } catch (e) { return false; }
  }
  $$('.side a, .topnav a').forEach(a => {
    if (a.id === 'random') return;
    if (samePage(a.getAttribute('href'))) {
      a.classList.add('on');
      const d = a.closest('details'); if (d) d.open = true;
    }
  });
  $$('details.grp').forEach(d => {
    const k = 'grp:' + d.dataset.grp;
    try {
      const v = localStorage.getItem(k);
      if (v === '1') d.open = true;
      else if (v === '0' && !d.querySelector('a.on')) d.open = false;
    } catch (e) { /* storage unavailable */ }
    d.addEventListener('toggle', () => { try { localStorage.setItem(k, d.open ? '1' : '0'); } catch (e) { /* ignore */ } });
  });
  const act = $('.side a.on'), side = $('.side');
  if (act && side) side.scrollTop = Math.max(0, act.offsetTop - side.clientHeight / 2);  // scroll the sidebar only, never the document
  const sf = $('.side-filter');
  if (sf) sf.addEventListener('input', () => {
    const q = sf.value.trim().toLowerCase();
    $$('.side .grp').forEach(d => {
      let any = false;
      $$('li', d).forEach(li => { const hit = !q || li.textContent.toLowerCase().includes(q); li.hidden = !hit; any = any || hit; });
      d.hidden = !!q && !any;
      if (q) d.open = true;
    });
  });
  const rnd = $('#random');
  if (rnd) rnd.addEventListener('click', e => {
    e.preventDefault();
    const as = $$('.side a[data-slug]');
    const a = as[Math.floor(Math.random() * as.length)];
    if (a) location.href = a.href;
  });

  /* ---------- search ---------- */
  const ov = $('#search'), q = $('#q'), res = $('#qres'), qraw = $('#qraw'), qhelp = $('#qhelp');
  let idx = null, raw = null, loadingIdx = null, loadingRaw = null, sel = 0, items = [], timer = null, rawTimer = null;
  const helpHtml = qhelp ? qhelp.innerHTML : '';

  function loadScript(src) {
    return new Promise((ok, err) => {
      const s = document.createElement('script'); s.src = src; s.onload = ok; s.onerror = err; document.head.appendChild(s);
    });
  }
  function prep(e) {
    e.lc = {
      title: e.title.toLowerCase(), aliases: (e.aliases || []).join(' | ').toLowerCase(),
      headings: (e.headings || []).join(' | ').toLowerCase(), text: (e.text || '').toLowerCase(),
      tags: (e.tags || []).join(' ').toLowerCase(), id: e.id.toLowerCase()
    };
  }
  async function ensureIndex() {
    if (idx) return idx;
    if (!window.SEARCH_INDEX) { if (!loadingIdx) loadingIdx = loadScript(ROOT + 'search-index.js'); await loadingIdx; }
    idx = window.SEARCH_INDEX || [];
    idx.forEach(prep);
    return idx;
  }
  async function ensureRaw() {
    if (raw) return raw;
    if (!window.RAW_INDEX) { if (!loadingRaw) loadingRaw = loadScript(ROOT + 'raw-index.js'); await loadingRaw; }
    raw = window.RAW_INDEX || [];
    raw.forEach(f => f.paras.forEach(p => { if (p.length < 3) p.push(p[1].toLowerCase()); }));
    return raw;
  }
  function openSearch(prefill) {
    if (!ov) return;
    ov.hidden = false;
    if (prefill != null) q.value = prefill;
    q.focus(); q.select();
    ensureIndex().then(run);
  }
  function closeSearch() { if (ov) ov.hidden = true; }
  function parse(s) {
    const f = {}, terms = [];
    s.trim().split(/\s+/).forEach(t => {
      if (!t) return;
      const m = t.match(/^([a-z][\w-]*):(.+)$/i);
      if (m && FILTER_KEYS.includes(m[1].toLowerCase())) f[m[1].toLowerCase()] = m[2].toLowerCase(); else terms.push(t.toLowerCase());
    });
    return { f, terms };
  }
  function count(h, n) { let c = 0, i = 0; while ((i = h.indexOf(n, i)) >= 0) { c++; i += n.length; if (c > 20) break; } return c; }
  function score(e, terms) {
    let s = 0;
    for (const t of terms) {
      let hit = 0;
      if (e.lc.title === t || e.lc.id === t) hit += 60;
      else if (e.lc.title.startsWith(t)) hit += 30;
      else if (e.lc.title.includes(t)) hit += 20;
      if (e.lc.aliases.includes(t)) hit += 15;
      if (e.lc.headings.includes(t)) hit += 8;
      if (e.lc.tags.includes(t)) hit += 5;
      const c = count(e.lc.text, t);
      if (c) hit += Math.min(c, 8) + 2;
      if (!hit) return 0;
      s += hit;
    }
    if (isToc(e)) s *= 0.75;
    else if (e.type === 'summary') s *= 0.9;
    else if (e.type === 'cheatsheet') s *= 0.85;
    else if (e.type === 'wanted') s *= 0.6;
    return s;
  }
  function hi(s, terms) {
    let t = s;
    terms.filter(x => x.length).forEach(x => {
      const re = new RegExp(x.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi');
      t = t.replace(re, m => '\x01' + m + '\x02');
    });
    return esc(t).replace(/\x01/g, '<mark>').replace(/\x02/g, '</mark>');
  }
  function snippet(text, lc, terms, w) {
    w = w || 90;
    let pos = -1;
    for (const t of terms) { const i = lc.indexOf(t); if (i >= 0 && (pos < 0 || i < pos)) pos = i; }
    if (pos < 0) return esc(text.slice(0, 2 * w)) + (text.length > 2 * w ? '…' : '');
    const a = Math.max(0, pos - w), b = Math.min(text.length, pos + w);
    return (a > 0 ? '…' : '') + hi(text.slice(a, b), terms) + (b < text.length ? '…' : '');
  }
  function resultHtml(e, terms, i) {
    const badge = '<span class="badge t-' + esc(e.type) + '">' + esc(isToc(e) ? TOC_TYPES[e.type].label : (e.kind || e.type)) + '</span>';
    let extra = '';
    if (isToc(e) && e.raw) extra = ' <a class="rm" href="' + esc(ROOT + e.raw) + '" data-stop="1">read in source ↗</a>';
    const sn = isToc(e) ? esc(e.meta) : snippet(e.text, e.lc.text, terms);
    return '<a class="res' + (i === sel ? ' on' : '') + '" data-i="' + i + '" href="' + esc(ROOT + e.url) + '"><div class="rt">' + badge + ' ' + hi(e.title, terms) + (!isToc(e) && e.meta ? ' <span class="rm">' + esc(e.meta) + '</span>' : '') + extra + '</div><div class="rs">' + sn + '</div></a>';
  }
  function run() {
    if (!idx) return;
    const { f, terms } = parse(q.value);
    items = []; sel = 0;
    if (!terms.length && !Object.keys(f).length) { res.innerHTML = ''; qhelp.hidden = false; return; }
    qhelp.hidden = true;
    const cands = idx.filter(e => {
      if (f.type && e.type !== f.type) return false;
      if (f.kind && e.kind !== f.kind) return false;
      for (const k of FACET_KEYS) if (f[k] && !((e.f || {})[k] || []).includes(f[k])) return false;
      if (f.tag && !(e.tags || []).includes(f.tag)) return false;
      return true;
    });
    let scored = cands.map(e => [terms.length ? score(e, terms) : 1, e]).filter(x => x[0] > 0);
    scored.sort((a, b) => b[0] - a[0] || a[1].title.localeCompare(b[1].title));
    scored = scored.slice(0, 80);
    items = scored.map(x => x[1]);
    let h = '';
    if (!items.length) h = '<div class="qempty">nothing found' + (qraw && qraw.checked ? '' : ' — tick <em>raw sources</em> to search the original texts') + '</div>';
    else {
      const pages = items.filter(e => !isToc(e));
      if (pages.length) h += '<div class="qgrp">pages · ' + pages.length + '</div>' + pages.map(e => resultHtml(e, terms, items.indexOf(e))).join('');
      Object.keys(TOC_TYPES).forEach(id => {
        const tw = items.filter(e => e.type === id);
        if (tw.length) h += '<div class="qgrp">' + esc(TOC_TYPES[id].nav) + ' articles · ' + tw.length + '</div>' + tw.map(e => resultHtml(e, terms, items.indexOf(e))).join('');
      });
    }
    res.innerHTML = h;
    res.scrollTop = 0;
    if (qraw && qraw.checked && terms.length) {
      const box = document.createElement('div'); box.className = 'qrawbox'; box.innerHTML = '<div class="qgrp">raw sources · loading…</div>'; res.appendChild(box);
      const my = ++rawTimer;
      ensureRaw().then(() => { if (my === rawTimer) rawResults(box, terms); });
    }
  }
  function rawResults(box, terms) {
    const hits = [];
    for (const f of raw) {
      for (const p of f.paras) {
        const lc = p[2];
        let ok = true, sc = 0;
        for (const t of terms) { const c = count(lc, t); if (!c) { ok = false; break; } sc += c; }
        if (ok) { hits.push([sc, f, p]); if (hits.length > 400) break; }
      }
      if (hits.length > 400) break;
    }
    hits.sort((a, b) => b[0] - a[0]);
    const top = hits.slice(0, 60);
    let h = '<div class="qgrp">raw sources · ' + (hits.length > 400 ? '400+' : hits.length) + ' paragraphs' + (hits.length > 60 ? ' (showing 60)' : '') + '</div>';
    h += top.map(([sc, f, p]) => '<a class="res rawres" href="' + esc(ROOT + f.url + '#L' + p[0]) + '"><div class="rt"><span class="badge">raw</span> ' + esc(f.title) + ' <span class="rm">line ' + p[0] + '</span></div><div class="rs">' + snippet(p[1], p[2], terms, 110) + '</div></a>').join('');
    box.innerHTML = h;
  }
  function moveSel(d) {
    const all = $$('.res', res);
    if (!all.length) return;
    sel = (sel + d + all.length) % all.length;
    all.forEach((el, i) => el.classList.toggle('on', i === sel));
    all[sel].scrollIntoView({ block: 'nearest' });
  }
  if (ov) {
    $$('#sopen, #sopen2').forEach(b => b.addEventListener('click', () => openSearch()));
    $('#qclose').addEventListener('click', closeSearch);
    ov.addEventListener('click', e => { if (e.target === ov) closeSearch(); });
    q.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(run, 60); });
    if (qraw) qraw.addEventListener('change', run);
    q.addEventListener('keydown', e => {
      if (e.key === 'ArrowDown') { e.preventDefault(); moveSel(1); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); moveSel(-1); }
      else if (e.key === 'Enter') { const el = $$('.res', res)[sel]; if (el) location.href = el.href; }
      else if (e.key === 'Escape') closeSearch();
    });
    res.addEventListener('click', e => { const s = e.target.closest('[data-stop]'); if (s) e.stopPropagation(); });
    document.addEventListener('keydown', e => {
      const tag = (e.target.tagName || '').toLowerCase();
      const typing = tag === 'input' || tag === 'textarea' || tag === 'select' || e.target.isContentEditable;
      if (e.key === '/' && !typing && !e.metaKey && !e.ctrlKey) { e.preventDefault(); openSearch(); }
      else if (e.key === 'Escape' && !ov.hidden) closeSearch();
    });
    // prefetch the index shortly after load so the first search is instant
    setTimeout(() => { ensureIndex(); }, 1500);
    if (location.hash.startsWith('#q=')) openSearch(decodeURIComponent(location.hash.slice(3)));
  }

  /* ---------- inbox TOC tables ---------- */
  const tab = $('#toctab');
  if (tab) {
    const rows = $$('tbody tr', tab), tq = $('#tocq'), tn = $('#tocn');
    let flag = 'all';
    function apply() {
      const s = tq.value.trim().toLowerCase();
      let n = 0;
      rows.forEach(r => {
        const fl = r.dataset.flags || '', ing = r.dataset.ing === 'y';
        let ok = true;
        if (flag === '★') ok = fl.includes('★');
        else if (flag === 'ingested') ok = ing;
        else if (flag === 'open') ok = !ing && !fl.includes('skip');
        else if (flag === 'noskip') ok = !fl.includes('skip');
        else if (flag !== 'all') ok = fl.split(' ').includes(flag);
        if (ok && s) ok = r.textContent.toLowerCase().includes(s);
        r.hidden = !ok; if (ok) n++;
      });
      tn.textContent = n + ' / ' + rows.length + ' rows';
    }
    tq.addEventListener('input', apply);
    $$('.tocctl .chips button').forEach(b => b.addEventListener('click', () => {
      $$('.tocctl .chips button').forEach(x => x.classList.remove('on')); b.classList.add('on'); flag = b.dataset.f; apply();
    }));
    $$('thead th', tab).forEach(th => th.addEventListener('click', () => {
      const k = +th.dataset.k, dir = th.dataset.dir === 'a' ? 'd' : 'a';
      $$('thead th', tab).forEach(x => delete x.dataset.dir); th.dataset.dir = dir;
      const tb = tab.tBodies[0];
      const val = r => { const t = r.cells[k].textContent.trim(); if (/^-?\d+(\.\d+)?$/.test(t)) return parseFloat(t); if (/\d{4}|\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}/.test(t)) { const d = Date.parse(t); if (!isNaN(d)) return d; } return t.toLowerCase(); };
      rows.slice().sort((a, b) => { const x = val(a), y = val(b); const c = (typeof x === 'number' && typeof y === 'number') ? x - y : String(x).localeCompare(String(y)); return dir === 'a' ? c : -c; }).forEach(r => tb.appendChild(r));
    }));
    apply();
    if (location.hash) { const r = $(location.hash.replace(/[^#\w-]/g, '')); if (r) { r.classList.add('hit'); r.scrollIntoView({ block: 'center' }); } }
  }

  /* ---------- cheat-sheet tabs ---------- */
  const tabs = $$('.cstabs button[data-cs]');
  if (tabs.length) {
    tabs.forEach(b => b.addEventListener('click', () => {
      tabs.forEach(x => x.classList.remove('on')); b.classList.add('on');
      $$('.cs').forEach(s => { s.hidden = s.id !== 'cs-' + b.dataset.cs; });
      history.replaceState(null, '', '#' + b.dataset.cs);
    }));
    if (location.hash) { const b = tabs.find(x => x.dataset.cs === location.hash.slice(1)); if (b) b.click(); }
    const pr = $('#csprint'); if (pr) pr.addEventListener('click', () => window.print());
  }

  /* ---------- raw pages: click a line number to link to it ---------- */
  const rawpre = $('pre.raw');
  if (rawpre) {
    rawpre.addEventListener('click', e => {
      const l = e.target.closest('.l');
      if (l && e.offsetX < 56) { history.replaceState(null, '', '#' + l.id); $$('.l.hit', rawpre).forEach(x => x.classList.remove('hit')); l.classList.add('hit'); }
    });
    if (location.hash) { const t = $(location.hash.replace(/[^#\w-]/g, '')); if (t) setTimeout(() => t.scrollIntoView({ block: 'center' }), 0); }
  }
})();
