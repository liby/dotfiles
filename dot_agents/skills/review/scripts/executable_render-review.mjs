#!/usr/bin/env node
// render-review.mjs — read structured review JSON, render a single-file HTML
// report, write it to /tmp, and open it. Run with node (>=18) or bun. Zero deps.
//
// Usage:
//   node render-review.mjs <data.json>     # or pipe JSON via stdin
//
// The agent's only job is to produce the JSON (see references/html-report.md).
// All HTML structure, escaping, colors, and the train diagram live here, so
// Codex and Claude Code produce byte-identical reports.
//
// JSDoc typedefs document the JSON contract without a TS toolchain; this file
// intentionally has no `// @ts-check` so the dotfiles tree needs no @types/node.
//
// cspell:ignore flabel chev codeloc noopener Segoe Consolas

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { execFile } from 'node:child_process';
import { platform } from 'node:os';

/**
 * @typedef {'P1'|'P2'|'P3'} Sev
 * @typedef {'confirmed'|'manual'|'weak'} Level
 * @typedef {{ iid: number|string, title?: string, url: string }} MR
 * @typedef {{ requirement?: string, assessment?: string }} Rationale
 * @typedef {{ project?: string, scope?: string, scope_slug?: string, reviewed_sha?: string, repo_root?: string, mr?: MR, verdict?: string, validation?: string, manual_gap?: string, rationale?: Rationale }} Meta
 * @typedef {{ sev: Sev, path: string, line?: number, title: string, level?: Level, problem: string, trigger?: string[], fix: string, fix_code?: string, evidence?: string, impact?: string, mr_hunk_url?: string }} Finding
 * @typedef {{ text: string, level?: Level }} Note
 * @typedef {{ meta?: Meta, findings?: Finding[], notes?: Note[] }} ReviewData
 */

// --- helpers ---------------------------------------------------------------
/** @type {Record<string, string>} */
const escMap = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;',
};
/** @param {unknown} s @returns {string} */
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => escMap[c] ?? c);
// inline markdown: only `code` spans, applied AFTER escaping (backtick is safe)
/** @param {unknown} s @returns {string} */
const inline = (s) => esc(s).replace(/`([^`]+)`/g, '<code>$1</code>');

/** @type {Record<Sev, string>} */
const SEV = { P1: 'p1', P2: 'p2', P3: 'p3' };

/** @param {string} repoRoot @param {string} path @param {number} [line] @returns {string} */
function vscodeHref(repoRoot, path, line) {
  const abs = `/${repoRoot}/${path}`.replace(/\/+/g, '/');
  return `vscode://file${abs}${line ? ':' + line : ''}`;
}

/** @param {string[]} [steps] @returns {string} */
function train(steps = []) {
  return steps
    .map((s, i) => {
      const bad = i === steps.length - 1 ? ' bad' : '';
      return `<span class="car${bad}">${inline(s)}</span>`;
    })
    .join('<span class="arrow">-&gt;</span>');
}

/** @param {Finding} f @param {string} repoRoot @param {boolean} open @returns {string} */
function findingBlock(f, repoRoot, open) {
  const loc = `${f.path}${f.line ? ':' + f.line : ''}`;
  const ev = f.level || 'confirmed';
  const trainBlock = f.trigger?.length
    ? `<div class="field"><div class="flabel">怎么引起的</div><div class="train">${train(
        f.trigger
      )}</div></div>`
    : '';
  const fixCode = f.fix_code ? `<pre><code>${esc(f.fix_code)}</code></pre>` : '';
  const mrLink = f.mr_hunk_url
    ? `<a class="mr" href="${esc(f.mr_hunk_url)}" target="_blank" rel="noopener">在 MR 查看</a>`
    : '';
  /** @type {string[]} */
  const moreBits = [];
  if (f.evidence)
    moreBits.push(
      `<div class="field"><div class="flabel">证据</div><p>${inline(f.evidence)}</p></div>`
    );
  if (f.impact)
    moreBits.push(
      `<div class="field"><div class="flabel">影响 / 边界</div><p>${inline(f.impact)}</p></div>`
    );
  const more = moreBits.length
    ? `<details class="more"><summary>更多证据 / 影响</summary>${moreBits.join('')}</details>`
    : '';

  return `
  <details class="finding" data-sev="${f.sev}" name="findings"${open ? ' open' : ''}>
    <summary>
      <span class="sev ${f.sev}">${esc(f.sev)}</span>
      <span class="sum-main">
        <span class="sum-title">${inline(f.title)}</span>
        <span class="sum-meta"><span class="loc">${esc(loc)}</span><span class="ev ${ev}">${esc(ev)}</span></span>
      </span>
      <span class="chev">&#9654;</span>
    </summary>
    <div class="body">
      <div class="field"><div class="flabel">什么问题</div><p>${inline(f.problem)}</p></div>
      ${trainBlock}
      <div class="field"><div class="flabel">代码位置</div>
        <div class="codeloc"><a class="file" href="${vscodeHref(repoRoot, f.path, f.line)}">${esc(loc)}</a>${mrLink}</div>
      </div>
      <div class="field"><div class="flabel">建议修复</div><p>${inline(f.fix)}</p>${fixCode}</div>
      ${more}
    </div>
  </details>`;
}

// --- input -----------------------------------------------------------------
const src = process.argv[2]
  ? readFileSync(process.argv[2], 'utf8')
  : readFileSync(0, 'utf8');
/** @type {ReviewData} */
let data;
try {
  data = JSON.parse(src);
} catch (e) {
  console.error(
    `render-review: invalid JSON from ${process.argv[2] || 'stdin'}: ${e instanceof Error ? e.message : String(e)}`
  );
  process.exit(1);
}
/** @type {Meta} */
const m = data.meta || {};
/** @type {Finding[]} */
const findings = data.findings || [];
/** @type {Note[]} */
const notes = data.notes || [];

/** @type {Record<Sev, number>} */
const counts = { P1: 0, P2: 0, P3: 0 };
findings.forEach((f) => (counts[f.sev] = (counts[f.sev] || 0) + 1));
/** @param {Sev} sev @returns {string} */
const countPill = (sev) =>
  counts[sev]
    ? `<span class="pill ${SEV[sev]}">${sev} ${counts[sev]}</span>`
    : `<span class="pill zero">${sev} 0</span>`;

// Required fields render to blank silently when missing; warn so a malformed
// JSON (e.g. a merge that dropped a field) is visible instead of an empty card.
/** @type {(keyof Finding)[]} */
const REQUIRED = ['sev', 'title', 'problem', 'fix', 'path'];
findings.forEach((f, i) => {
  const missing = REQUIRED.filter((k) => !f[k]);
  if (missing.length)
    console.error(
      `render-review: finding[${i}] missing required field(s): ${missing.join(', ')}`
    );
});

const h1 = m.mr
  ? `${esc(m.project || '')} · <a href="${esc(m.mr.url)}" target="_blank" rel="noopener">MR !${esc(m.mr.iid)}</a> · ${inline(m.mr.title || '')}`
  : `${esc(m.project || 'Review')}${m.scope ? ' · ' + inline(m.scope) : ''}`;

const rationale = m.rationale
  ? `<section class="rationale"><h2>需求与方案合理性</h2>
      ${m.rationale.requirement ? `<p><span class="label">要解决什么：</span>${inline(m.rationale.requirement)}</p>` : ''}
      ${m.rationale.assessment ? `<p><span class="label">方案是否合理：</span>${inline(m.rationale.assessment)}</p>` : ''}
    </section>`
  : '';

const notesBlock = notes.length
  ? `<section class="notes"><h2>Notes / 非 finding（weak）</h2>${notes
      .map((n) => `<p>${inline(n.text)}</p>`)
      .join('')}</section>`
  : '';

const findingsHtml = findings
  .map((f, i) => findingBlock(f, m.repo_root || '', i === 0))
  .join('\n');

// --- template (structure fixed; :root colors are the only theming surface) --
const CSS = `
  /* Rosé Pine Dawn, softened: dimmed off pure white, deepened ink + link,
     deepened severity so white badge text passes WCAG AA. Light only. */
  :root{
    --bg:#f3ece1; --card:#fcf7f0; --ink:#2e2935; --muted:#6b6677; --line:#e6dccf;
    --p1:#a13d57; --p2:#b45309; --p3:#286983;
    --ev-confirmed:#3d7a52; --ev-weak:#797593; --ev-manual:#6f5594;
    --accent:#235e85; --code-bg:#ece1d3; --code-text:#2e2935; --pre-bg:#efe6d8;
    --radius:12px;
  }
  *{box-sizing:border-box} html{font-size:17px}
  body{margin:0;background:var(--bg);color:var(--ink);line-height:1.65;padding:32px 40px 64px;
    font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif}
  code{font-family:"SF Mono",ui-monospace,Menlo,Consolas,monospace;font-size:.88em;background:var(--code-bg);color:var(--code-text);padding:.1em .4em;border-radius:5px}
  pre{background:var(--pre-bg);padding:14px 16px;border-radius:8px;overflow:auto;margin:.5em 0;border:1px solid var(--line)}
  pre code{background:none;padding:0}
  a{color:var(--accent);text-decoration:none} a:hover{text-decoration:underline}
  header h1{font-size:1.45rem;margin:0 0 18px;font-weight:700}
  .verdict{background:var(--card);border:1px solid var(--line);border-radius:var(--radius);padding:16px 20px;margin-bottom:18px;display:flex;flex-wrap:wrap;gap:14px 28px;align-items:center}
  .verdict .item{display:flex;flex-direction:column;gap:2px}
  .verdict .k{font-size:.76rem;color:var(--muted)}
  .verdict .v{font-weight:650;font-size:.98rem}
  .counts{display:flex;gap:8px}
  .pill{display:inline-flex;align-items:center;font-weight:650;font-size:.82rem;padding:3px 11px;border-radius:999px;color:#fff}
  .pill.p1{background:var(--p1)} .pill.p2{background:var(--p2)} .pill.p3{background:var(--p3)}
  .pill.zero{background:transparent;color:var(--muted);border:1px solid var(--line)}
  .rationale{background:var(--card);border:1px solid var(--line);border-left:4px solid var(--accent);border-radius:var(--radius);padding:16px 20px;margin-bottom:18px}
  .rationale h2{font-size:1rem;margin:0 0 8px} .rationale p{margin:.4em 0;font-size:.95rem} .rationale .label{color:var(--muted);font-weight:650}
  .finding{background:var(--card);border:1px solid var(--line);border-radius:var(--radius);margin-bottom:12px;overflow:hidden}
  .finding[data-sev="P1"]{border-left:4px solid var(--p1)} .finding[data-sev="P2"]{border-left:4px solid var(--p2)} .finding[data-sev="P3"]{border-left:4px solid var(--p3)}
  .finding>summary{list-style:none;cursor:pointer;padding:15px 20px;display:flex;gap:12px;align-items:flex-start;user-select:none}
  .finding>summary::-webkit-details-marker{display:none}
  .finding>summary:hover{background:color-mix(in srgb,var(--accent) 5%,transparent)}
  .sev{flex:none;font-weight:700;font-size:.8rem;padding:3px 9px;border-radius:6px;color:#fff;margin-top:2px}
  .sev.P1{background:var(--p1)} .sev.P2{background:var(--p2)} .sev.P3{background:var(--p3)}
  .sum-main{flex:1;min-width:0} .sum-title{font-weight:600;font-size:1.05rem}
  .sum-meta{display:flex;gap:10px;align-items:center;margin-top:5px;flex-wrap:wrap}
  .loc{font-family:"SF Mono",ui-monospace,Menlo,monospace;font-size:.82rem;color:var(--muted)}
  .ev{font-size:.72rem;padding:2px 8px;border-radius:999px;font-weight:650;border:1px solid currentColor}
  .ev.confirmed{color:var(--ev-confirmed)} .ev.weak{color:var(--ev-weak)} .ev.manual{color:var(--ev-manual)}
  .chev{flex:none;color:var(--muted);transition:transform .18s;margin-top:4px} .finding[open]>summary .chev{transform:rotate(90deg)}
  .body{padding:2px 20px 18px;border-top:1px solid var(--line)}
  .field{margin:15px 0 0} .field .flabel{font-size:.82rem;font-weight:700;color:var(--muted);margin-bottom:5px} .field p{margin:0}
  .codeloc{display:flex;gap:14px;align-items:center;flex-wrap:wrap;background:var(--code-bg);border:1px solid var(--line);border-radius:8px;padding:9px 12px}
  .codeloc a.file{font-family:"SF Mono",ui-monospace,Menlo,monospace;font-weight:600}
  .train{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin-top:4px}
  .car{background:var(--code-bg);border:1px solid var(--line);border-radius:8px;padding:7px 11px;font-size:.85rem} .car.bad{border-color:var(--p1);color:var(--p1)}
  .arrow{color:var(--muted);font-weight:700}
  details.more{margin-top:14px} details.more>summary{cursor:pointer;color:var(--muted);font-size:.85rem;list-style:none} details.more>summary::-webkit-details-marker{display:none} details.more>summary::before{content:"\\25B8 "} details.more[open]>summary::before{content:"\\25BE "}
  .notes{background:var(--card);border:1px solid var(--line);border-left:4px solid var(--ev-weak);border-radius:var(--radius);padding:14px 20px;margin-top:18px} .notes h2{font-size:.95rem;margin:0 0 6px;color:var(--muted)} .notes p{margin:.3em 0;font-size:.9rem;color:var(--muted)}
  @media print{.chev{display:none} .finding,.rationale,.verdict{break-inside:avoid} body{padding:0}}
`;

const html = `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${m.mr?.title ? esc(m.mr.title) : esc(m.project || 'Review')}</title>
<style>${CSS}</style></head>
<body>
  <header><h1>${h1}</h1></header>
  <section class="verdict">
    <div class="item"><span class="k">结论</span><span class="v">${inline(m.verdict || '')}</span></div>
    <div class="item"><span class="k">findings</span><span class="counts">${countPill('P1')}${countPill('P2')}${countPill('P3')}</span></div>
    ${m.validation || m.manual_gap ? `<div class="item"><span class="k">证据边界</span><span class="v">${inline([m.validation, m.manual_gap].filter(Boolean).join('，'))}</span></div>` : ''}
  </section>
  ${rationale}
  <main>${findingsHtml}</main>
  ${notesBlock}
</body></html>`;

// --- output ----------------------------------------------------------------
const slug = m.scope_slug || 'review';
// Local timestamp, minute precision (e.g. 202606031019); orders reports, no hash.
const d = new Date();
const pad = (/** @type {number} */ n) => String(n).padStart(2, '0');
const stamp = `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}${pad(d.getHours())}${pad(d.getMinutes())}`;
const dir = `/tmp/review/${(m.project || 'review').replace(/[^\w.-]/g, '_')}`;
mkdirSync(dir, { recursive: true });
const out = `${dir}/${slug}-${stamp}.html`;
writeFileSync(out, html);
const opener = platform() === 'darwin' ? 'open' : 'xdg-open';
execFile(opener, [out], () => {});
console.log(out);
