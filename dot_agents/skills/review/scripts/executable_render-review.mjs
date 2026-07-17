#!/usr/bin/env node
// render-review.mjs: read structured review JSON, render a single-file HTML
// report and open it. File-centric layout modeled on Anthropic's
// 03-code-review-pr html-effectiveness example: PR/scope header, risk map with
// anchor navigation, per-file cards whose findings render as line-anchored
// review bubbles, and local dark diff snippets. File cards form a single-open
// accordion (native <details name>): the first card is open, others collapsed.
// Run with node (>=18) or bun. Zero deps.
//
// Usage:
//   node render-review.mjs <data.json>     # or pipe JSON via stdin
//
// The agent's only job is to produce the JSON (see references/contracts/result.md).
// All HTML structure, escaping, colors, and the diff/risk-map live here.
//
// JSDoc typedefs document the JSON contract without a TS toolchain; no @ts-check.
//
// cspell:ignore noopener Segoe ivory clay oat olive btitle fixlabel mlabel tarrow

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { execFile } from 'node:child_process';
import { platform, tmpdir } from 'node:os';
import { join } from 'node:path';

/**
 * @typedef {'P1'|'P2'|'P3'} Sev
 * @typedef {'confirmed'|'manual'} FindingLevel
 * @typedef {'weak'} NoteLevel
 * @typedef {{ iid: number|string, title?: string, url: string }} MR
 * @typedef {{ requirement?: string, assessment?: string }} Rationale
 * @typedef {{ add?: number, del?: number, files?: number }} Stat
 * @typedef {{ project?: string, scope?: string, scope_slug?: string, reviewed_sha?: string, repo_root?: string, mr?: MR, verdict?: string, validation?: string, manual_gap?: string, rationale?: Rationale, author?: string, branch?: string, stat?: Stat }} Meta
 * @typedef {{ sev: Sev, path: string, line?: number, title: string, level?: FindingLevel, problem: string, trigger?: string[], fix: string, fix_code?: string, code_snippet?: string, evidence?: string, impact?: string }} Finding
 * @typedef {{ path: string, add?: number, del?: number, note?: string }} FileEntry
 * @typedef {{ text: string, level?: NoteLevel }} Note
 * @typedef {{ meta?: Meta, findings?: Finding[], files?: FileEntry[], notes?: Note[] }} ReviewData
 */

// --- helpers ---------------------------------------------------------------
/** @type {Record<string,string>} */
const escMap = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
/** @param {unknown} s @returns {string} */
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => escMap[c] ?? c);
// inline markdown applied AFTER escaping: `code` spans and ==highlight== marks.
/** @param {unknown} s @returns {string} */
const inline = (s) =>
  esc(s)
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/==([^=]+)==/g, '<mark class="hl">$1</mark>');

/** @param {string} p @returns {string} */
const basename = (p) => String(p).split('/').pop() || String(p);
/** @param {string} p @returns {string} */
const slug = (p) => String(p).replace(/[^a-zA-Z0-9]+/g, '-').replace(/^-|-$/g, '');
// Stable, collision-free DOM id per file path. slug() is lossy (`a/b.ts` and
// `a-b.ts` both fold to `a-b-ts`), so two such paths would emit the same id and
// the risk-map anchor would only ever reach the first. Suffix repeats `-2`, `-3`.
const fileId = (() => {
  /** @type {Map<string,string>} */ const byPath = new Map();
  /** @type {Map<string,number>} */ const counts = new Map();
  return (/** @type {string} */ p) => {
    const cached = byPath.get(p);
    if (cached) return cached;
    const base = slug(p) || 'file';
    const n = (counts.get(base) || 0) + 1;
    counts.set(base, n);
    const id = n === 1 ? base : `${base}-${n}`;
    byPath.set(p, id);
    return id;
  };
})();

/** @param {string} repoRoot @param {string} path @param {number} [line] @returns {string} */
function vscodeHref(repoRoot, path, line) {
  const abs = `/${repoRoot}/${path}`.replace(/\/+/g, '/');
  return `vscode://file${abs}${line ? ':' + line : ''}`;
}

/** Causal chain as a left-to-right train; last step is the consequence. */
/** @param {string[]} [steps] @returns {string} */
function train(steps = []) {
  return steps
    .map((s, i) => `<span class="car${i === steps.length - 1 ? ' bad' : ''}">${inline(s)}</span>`)
    .join('<span class="tarrow">&rarr;</span>');
}

/** Local diff snippet: each input line prefixed +/-/space; renders a dark block. */
/** @param {string} [snippet] @returns {string} */
function diffSnippet(snippet) {
  if (!snippet) return '';
  const rows = String(snippet)
    .replace(/\n$/, '')
    .split('\n')
    .map((line) => {
      let cls = 'ctx';
      let mark = '';
      let code = line;
      if (line[0] === '+') { cls = 'add'; mark = '+'; code = line.slice(1); }
      else if (line[0] === '-') { cls = 'del'; mark = '−'; code = line.slice(1); }
      else if (line[0] === ' ') { code = line.slice(1); }
      return `<div class="diff-row ${cls}"><span class="mark">${mark}</span><span class="code">${esc(code)}</span></div>`;
    })
    .join('');
  return `<div class="diff snippet">${rows}</div>`;
}

// --- input -----------------------------------------------------------------
const src = process.argv[2] ? readFileSync(process.argv[2], 'utf8') : readFileSync(0, 'utf8');
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
const findings = Array.isArray(data.findings) ? data.findings : [];
/** @type {FileEntry[]} */
const files = Array.isArray(data.files) ? data.files : [];
/** @type {Note[]} */
const notes = Array.isArray(data.notes) ? data.notes : [];
const repoRoot = m.repo_root || '';

// Required fields render blank or miscolored when missing; fail before HTML so
// the JSON contract is enforced at the same boundary that consumes it.
const VALID_SEV = new Set(['P1', 'P2', 'P3']);
const VALID_FINDING_LEVEL = new Set(['confirmed', 'manual']);
const VALID_NOTE_LEVEL = new Set(['weak']);
/** @param {unknown} v @returns {boolean} */
const blank = (v) => typeof v !== 'string' || v.trim() === '';
/** @type {string[]} */
const contractErrors = [];

if (!data.meta || typeof data.meta !== 'object' || Array.isArray(data.meta)) {
  contractErrors.push('meta missing required object');
} else {
  for (const key of ['project', 'verdict']) {
    if (blank(/** @type {Record<string, unknown>} */ (data.meta)[key])) {
      contractErrors.push(`meta.${key} missing required field`);
    }
  }
}

if (!Array.isArray(data.findings)) {
  contractErrors.push('findings must be an array; use [] for a clean review');
}

if (data.files != null && !Array.isArray(data.files)) {
  contractErrors.push('files must be an array when present');
}

if (data.notes != null && !Array.isArray(data.notes)) {
  contractErrors.push('notes must be an array when present');
}

/** @type {(keyof Finding)[]} */
const REQUIRED_FINDING = ['sev', 'title', 'problem', 'fix', 'path'];
findings.forEach((f, i) => {
  if (!f || typeof f !== 'object' || Array.isArray(f)) {
    contractErrors.push(`finding[${i}] must be an object`);
    return;
  }
  const missing = REQUIRED_FINDING.filter((k) => blank(f[k]));
  if (missing.length) {
    contractErrors.push(`finding[${i}] missing required field(s): ${missing.join(', ')}`);
  }
  if (!blank(f.sev) && !VALID_SEV.has(f.sev)) {
    contractErrors.push(`finding[${i}].sev must be P1, P2, or P3`);
  }
  if (f.level != null && !VALID_FINDING_LEVEL.has(f.level)) {
    contractErrors.push(`finding[${i}].level must be confirmed or manual; move weak items to notes[]`);
  }
});

files.forEach((f, i) => {
  if (!f || typeof f !== 'object' || Array.isArray(f)) {
    contractErrors.push(`files[${i}] must be an object`);
    return;
  }
  if (blank(f.path)) {
    contractErrors.push(`files[${i}].path missing required field`);
  }
});

notes.forEach((n, i) => {
  if (!n || typeof n !== 'object' || Array.isArray(n)) {
    contractErrors.push(`notes[${i}] must be an object`);
    return;
  }
  if (blank(n.text)) {
    contractErrors.push(`notes[${i}].text missing required field`);
  }
  if (n.level != null && !VALID_NOTE_LEVEL.has(n.level)) {
    contractErrors.push(`notes[${i}].level must be weak when present`);
  }
});

if (contractErrors.length) {
  for (const error of contractErrors) {
    console.error(`render-review: ${error}`);
  }
  process.exit(1);
}

// Group findings by file; a file's risk tag = the highest severity it carries.
/** @type {Map<string, Finding[]>} */
const byFile = new Map();
findings.forEach((f) => {
  if (!byFile.has(f.path)) byFile.set(f.path, []);
  (byFile.get(f.path) || []).push(f);
});
/** @type {Map<string, FileEntry>} */
const fileMap = new Map(files.map((f) => [f.path, f]));
/** @type {Record<Sev, number>} */
const SEV_RANK = { P1: 3, P2: 2, P3: 1 };
/** @type {Record<Sev, string>} */
const SEV_TAG = { P1: '需修复', P2: '值得关注', P3: '小问题' };
/** @param {string} path @returns {Sev} */
function fileSev(path) {
  const fs = byFile.get(path) || [];
  return fs.reduce((top, f) => (SEV_RANK[f.sev] > SEV_RANK[top] ? f.sev : top), /** @type {Sev} */ ('P3'));
}
/** @type {Record<Sev, number>} */
const counts = { P1: 0, P2: 0, P3: 0 };
findings.forEach((f) => { counts[f.sev] = (counts[f.sev] || 0) + 1; });

/** @param {FileEntry} [e] @returns {string} */
function deltaSpan(e) {
  if (!e || (e.add == null && e.del == null)) return '';
  const add = e.add != null ? `<span class="add">+${esc(e.add)}</span>` : '';
  const del = e.del != null ? `<span class="del">−${esc(e.del)}</span>` : '';
  return `<span class="file-delta">${add} ${del}</span>`;
}

/** A single finding rendered as a line-anchored review bubble. */
/** @param {Finding} f @returns {string} */
function bubble(f) {
  /** @type {string[]} */
  const more = [];
  if (f.trigger?.length)
    more.push(`<div class="mini"><span class="mlabel">怎么引起的</span><div class="train">${train(f.trigger)}</div></div>`);
  if (f.evidence)
    more.push(`<div class="mini"><span class="mlabel">证据</span><span>${inline(f.evidence)}</span></div>`);
  if (f.impact)
    more.push(`<div class="mini"><span class="mlabel">影响 / 边界</span><span>${inline(f.impact)}</span></div>`);
  const moreBlock = more.length
    ? `<details class="more"><summary>更多证据 / 影响</summary>${more.join('')}</details>`
    : '';
  const fixCode = f.fix_code ? `<pre><code>${esc(f.fix_code)}</code></pre>` : '';
  const anchor = f.line ? `line ${esc(f.line)}` : esc(basename(f.path));
  return `
        <div class="bubble sev-${esc(f.sev)}">
          <div class="anchor"><a href="${vscodeHref(repoRoot, f.path, f.line)}">${anchor}</a></div>
          <p class="btitle"><span class="label">${esc(f.sev)}</span>${inline(f.title)}</p>
          <p class="problem">${inline(f.problem)}</p>
          ${diffSnippet(f.code_snippet)}
          ${f.fix ? `<p class="fix"><span class="fixlabel">建议</span>${inline(f.fix)}</p>` : ''}
          ${fixCode}
          ${moreBlock}
        </div>`;
}

/** @param {string} path @param {boolean} open @returns {string} */
function fileCard(path, open) {
  const fs = (byFile.get(path) || []).slice().sort((a, b) => (a.line || 0) - (b.line || 0));
  const sev = fileSev(path);
  const e = fileMap.get(path);
  return `
    <details class="file-card sev-${sev}" id="file-${fileId(path)}" name="files"${open ? ' open' : ''}>
      <summary class="file-head">
        <span class="file-path">${esc(path)}</span>
        <span class="file-head-right">
          <span class="risk-tag sev-${sev}">${SEV_TAG[sev]}</span>
          ${deltaSpan(e)}
        </span>
      </summary>
      <div class="comments">${fs.map(bubble).join('')}</div>
    </details>`;
}

/** @param {FileEntry} e @returns {string} */
function collapsedFile(e) {
  return `
    <details class="file-collapsed" id="file-${fileId(e.path)}" name="files">
      <summary class="file-head">
        <span class="file-path">${esc(e.path)}</span>
        <span class="file-head-right"><span class="risk-tag clean">无问题</span>${deltaSpan(e)}</span>
      </summary>
      <div class="body">${e.note ? inline(e.note) : '本次改动未发现问题。'}</div>
    </details>`;
}

// --- assemble sections -----------------------------------------------------
const findingPaths = [...byFile.keys()].sort(
  (a, b) => SEV_RANK[fileSev(b)] - SEV_RANK[fileSev(a)] || a.localeCompare(b)
);
const cleanFiles = files.filter((e) => !byFile.has(e.path));
const riskPaths = [...findingPaths, ...cleanFiles.map((e) => e.path)];

const chips = riskPaths
  .map((p) => {
    const sev = byFile.has(p) ? `sev-${fileSev(p)}` : 'clean';
    return `<a class="chip ${sev}" href="#file-${fileId(p)}"><span class="dot"></span>${esc(basename(p))}</a>`;
  })
  .join('');

// GitLab numbers merge requests `!N`, GitHub pull requests `#N`; pick the symbol
// off the URL path. The host word ("Merge/Pull Request") is dropped as redundant.
const mrSym = /\/merge_requests\//.test(m.mr?.url || '') ? '!' : '#';
const repoLine = m.mr
  ? `${esc(m.project || '')} · <a href="${esc(m.mr.url)}" target="_blank" rel="noopener">${mrSym}${esc(m.mr.iid)}</a>`
  : `${esc(m.project || 'Review')}${m.scope ? ' · ' + esc(m.scope) : ''}`;
const h1html = m.mr?.title ? inline(m.mr.title) : esc(m.project || 'Code Review');

const initials = m.author
  ? esc(m.author.trim().split(/\s+/).map((w) => w[0] || '').join('').slice(0, 2).toUpperCase())
  : '';
const authorBlock = m.author
  ? `<div class="author"><div class="avatar">${initials}</div><div><div class="author-name">${esc(m.author)}</div>${m.reviewed_sha ? `<div class="author-sub">${esc(m.reviewed_sha)}</div>` : ''}</div></div>`
  : '';
const branchBlock = m.branch
  ? `<div class="branch">${esc(m.branch).replace(/-&gt;|→|&rarr;/g, '<span class="arrow">&rarr;</span>')}</div>`
  : '';
const st = m.stat || {};
const statBlock =
  st.add != null || st.del != null || st.files != null
    ? `<div class="stat">${st.add != null ? `<span class="add">+${esc(st.add)}</span>` : ''}${st.del != null ? ` / <span class="del">−${esc(st.del)}</span>` : ''}${st.files != null ? `<span class="files">${esc(st.files)} files changed</span>` : ''}</div>`
    : '';
const metaRow =
  authorBlock || branchBlock || statBlock
    ? `<div class="meta-row">${authorBlock}${branchBlock}${statBlock}</div>`
    : '';

const rat = m.rationale || {};
const countLine = findings.length
  ? `<p class="count-line">${findings.length} 个 finding：<span class="c p1">P1<b>${counts.P1}</b></span><span class="c p2">P2<b>${counts.P2}</b></span><span class="c p3">P3<b>${counts.P3}</b></span></p>`
  : `<p class="count-line clean-line">未发现 blocking 问题</p>`;
const summary = `
  <section class="summary">
    ${m.verdict ? `<p class="verdict">${inline(m.verdict)}</p>` : ''}
    ${rat.requirement ? `<p><span class="k">要解决什么</span>${inline(rat.requirement)}</p>` : ''}
    ${rat.assessment ? `<p><span class="k">方案是否合理</span>${inline(rat.assessment)}</p>` : ''}
    ${m.validation || m.manual_gap ? `<p class="bound"><span class="k">证据边界</span>${inline([m.validation, m.manual_gap].filter(Boolean).join('，'))}</p>` : ''}
    ${countLine}
  </section>`;

const riskMap = riskPaths.length
  ? `
  <section>
    <h2>Risk map</h2>
    <div class="risk-map">${chips}</div>
    <div class="legend">
      <span><span class="dot p1"></span> 需修复</span>
      <span><span class="dot p2"></span> 值得关注</span>
      <span><span class="dot p3"></span> 小问题</span>
      <span><span class="dot clean"></span> 无问题</span>
    </div>
  </section>`
  : '';

const filesSection =
  findingPaths.length || cleanFiles.length
    ? `
  <section>
    <h2>Files</h2>
    ${findingPaths.map((p, i) => fileCard(p, i === 0)).join('')}
    ${cleanFiles.map(collapsedFile).join('')}
  </section>`
    : '';

const notesBlock = notes.length
  ? `
  <section class="notes"><h2>Notes（weak）</h2>${notes.map((n) => `<p>${inline(n.text)}</p>`).join('')}</section>`
  : '';

// --- template (structure fixed; :root colors are the only theming entry point) --
const CSS = `
  /* Anthropic html-effectiveness palette (03-code-review-pr): ivory canvas,
     serif headings, hairline cards, dark diff. Severity is the multi-hue
     signal: P1 rust, P2 clay, P3 olive (red -> orange -> green, descending). */
  :root{
    --ivory:#FAF9F5; --slate:#141413; --clay:#D97757; --oat:#E3DACC; --olive:#788C5D; --rust:#B04A3F;
    --gray-150:#F0EEE6; --gray-300:#D1CFC5; --gray-500:#87867F; --gray-700:#3D3D3A;
    --p1:#B04A3F; --p2:#D97757; --p3:#788C5D; --hl:#E3DACC;
    /* GitLab-aligned diff tints (measured from a live GitLab MR diff): solid pale
       backgrounds, saturated green/rose ink for the rail+mark, near-black code text */
    --diff-add-bg:#ECFDF0; --diff-add-ink:#2F7549; --diff-del-bg:#FBE9EB; --diff-del-ink:#A83246; --diff-ink:#3A383F;
    --serif:ui-serif,Georgia,'Times New Roman',serif;
    --sans:system-ui,-apple-system,'Segoe UI','PingFang SC',Roboto,sans-serif;
    --mono:ui-monospace,'SF Mono',Menlo,Monaco,monospace;
  }
  *{box-sizing:border-box;margin:0;padding:0}
  html{scroll-behavior:smooth}
  body{background:var(--ivory);color:var(--gray-700);font-family:var(--sans);font-size:15px;line-height:1.6;padding:48px 24px 80px;-webkit-font-smoothing:antialiased}
  .page{max-width:1200px;margin:0 auto}
  a{color:var(--clay);text-decoration:none} a:hover{text-decoration:underline}
  mark.hl{background:linear-gradient(transparent 58%,var(--hl) 58%);color:inherit;padding:0 .04em}
  code{font-family:var(--mono);font-size:12.5px;background:var(--gray-150);padding:1px 5px;border-radius:0}
  /* comments are identifier-dense; the global code block is too heavy here (10+ spans per sentence read as a brick wall), so .bubble code uses a much fainter 5% ink wash + tight padding that marks a span as code without the mass. Squared to match the report's other containers */
  .bubble code{background:rgba(20,20,19,.05);color:var(--slate);font-weight:500;padding:.5px 3px}
  h2{font-family:var(--serif);font-weight:500;font-size:21px;color:var(--slate);margin-bottom:14px}
  section{margin-bottom:36px}

  /* header */
  header.pr-head{border:1.5px solid var(--gray-300);border-radius:0;padding:28px 32px;background:#fff;margin-bottom:28px}
  .repo-line{font-family:var(--mono);font-size:12.5px;color:var(--gray-500);margin-bottom:10px}
  h1{font-family:var(--serif);font-weight:500;font-size:30px;line-height:1.25;color:var(--slate);margin-bottom:18px}
  .meta-row{display:flex;align-items:center;flex-wrap:wrap;gap:20px}
  .author{display:flex;align-items:center;gap:10px}
  .avatar{width:36px;height:36px;border-radius:50%;background:var(--oat);color:var(--slate);display:flex;align-items:center;justify-content:center;font-weight:600;font-size:13px;border:1.5px solid var(--gray-300)}
  .author-name{font-weight:500;color:var(--slate)} .author-sub{font-size:12px;color:var(--gray-500);font-family:var(--mono)}
  .branch{font-family:var(--mono);font-size:12.5px;color:var(--gray-700);background:var(--gray-150);border:1.5px solid var(--gray-300);border-radius:0;padding:6px 10px}
  .branch .arrow{color:var(--gray-500);margin:0 6px}
  .stat{font-family:var(--mono);font-size:13px}
  .stat .add{color:var(--olive);font-weight:600} .stat .del{color:var(--rust);font-weight:600} .stat .files{color:var(--gray-500);margin-left:10px}

  /* summary */
  .summary{border-left:3px solid var(--clay);padding:2px 0 2px 18px}
  .summary .verdict{font-family:var(--serif);font-size:18px;color:var(--slate);font-weight:500;margin-bottom:10px;line-height:1.4}
  .summary p{margin-bottom:7px}
  .summary .k{display:inline-block;font-weight:600;color:var(--slate);margin-right:8px}
  .summary .bound{color:var(--gray-500);font-size:13.5px}
  .count-line{font-family:var(--mono);font-size:13px;color:var(--gray-500);margin-top:6px}
  .count-line .c{margin-right:10px;font-weight:600}
  .count-line .c.p1{color:var(--p1)} .count-line .c.p2{color:var(--p2)} .count-line .c.p3{color:var(--olive)}
  .count-line .c b{display:inline-block;color:#fff;font-style:normal;font-weight:700;padding:0 6px;margin-left:5px}
  .count-line .c.p1 b{background:var(--p1)} .count-line .c.p2 b{background:var(--p2)} .count-line .c.p3 b{background:var(--olive)}

  /* risk map */
  .risk-map{display:flex;flex-wrap:wrap;gap:10px}
  .chip{display:inline-flex;align-items:center;gap:8px;padding:8px 12px;border-radius:0;border:1.5px solid var(--gray-300);font-family:var(--mono);font-size:12.5px;color:var(--slate);background:#fff;transition:transform .12s ease}
  .chip:hover{transform:translateY(-1px);text-decoration:none}
  .chip .dot{width:9px;height:9px;border-radius:50%;flex-shrink:0;background:var(--gray-300)}
  .chip.sev-P1{background:rgba(176,74,63,.08);border-color:rgba(176,74,63,.45)} .chip.sev-P1 .dot{background:var(--p1)}
  .chip.sev-P2{background:rgba(217,119,87,.10);border-color:rgba(217,119,87,.5)} .chip.sev-P2 .dot{background:var(--p2)}
  .chip.sev-P3{background:rgba(120,140,93,.10);border-color:rgba(120,140,93,.45)} .chip.sev-P3 .dot{background:var(--olive)}
  .legend{margin-top:12px;font-size:12px;color:var(--gray-500);display:flex;gap:18px;flex-wrap:wrap}
  .legend span{display:inline-flex;align-items:center;gap:6px}
  .legend .dot{width:8px;height:8px;border-radius:50%}
  .legend .dot.p1{background:var(--p1)} .legend .dot.p2{background:var(--p2)} .legend .dot.p3{background:var(--olive)} .legend .dot.clean{background:var(--gray-300)}

  /* file cards */
  .file-card{position:relative;border:1.5px solid var(--gray-300);border-radius:0;background:#fff;margin-bottom:14px;scroll-margin-top:20px}
  .file-card::before{content:"";position:absolute;left:-1.5px;right:-1.5px;top:-1.5px;height:3px;z-index:1}
  .file-card.sev-P1::before{background:var(--p1)} .file-card.sev-P2::before{background:var(--p2)} .file-card.sev-P3::before{background:var(--olive)}
  summary.file-head{padding:15px 20px;display:flex;align-items:center;gap:14px;list-style:none;cursor:pointer}
  summary.file-head::-webkit-details-marker{display:none}
  summary.file-head::after{content:"+";font-family:var(--mono);color:var(--gray-500);font-size:16px;flex-shrink:0;width:14px;text-align:center}
  [open]>summary.file-head::after{content:"\\2212"}
  .file-card[open]>summary.file-head{border-bottom:1.5px solid var(--gray-150)}
  .file-path{font-family:var(--mono);font-size:13.5px;color:var(--slate);flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
  .file-head-right{display:flex;align-items:center;gap:12px;flex-shrink:0}
  .file-delta{font-family:var(--mono);font-size:12px;color:var(--gray-500);min-width:64px;text-align:right;font-variant-numeric:tabular-nums} .file-delta .add{color:var(--olive)} .file-delta .del{color:var(--rust)}
  .risk-tag{font-size:11px;text-transform:uppercase;letter-spacing:.06em;padding:3px 8px;border-radius:0;font-weight:600;white-space:nowrap}
  .risk-tag.sev-P1{background:rgba(176,74,63,.13);color:var(--p1)}
  .risk-tag.sev-P2{background:rgba(217,119,87,.15);color:var(--clay)}
  .risk-tag.sev-P3{background:rgba(120,140,93,.15);color:var(--olive)}
  .risk-tag.clean{background:var(--gray-150);color:var(--gray-500)}

  /* comments / bubbles */
  .comments{padding:18px 20px 20px;display:flex;flex-direction:column;gap:14px;background:var(--gray-150)}
  .bubble{position:relative;background:#fff;border:1.5px solid var(--gray-300);border-radius:0;padding:12px 14px 12px 16px}
  .bubble::before{content:"";position:absolute;left:-1.5px;top:-1.5px;bottom:-1.5px;width:4px;z-index:1}
  .bubble.sev-P1::before{background:var(--p1)} .bubble.sev-P2::before{background:var(--p2)} .bubble.sev-P3::before{background:var(--olive)}
  .bubble .anchor{font-family:var(--mono);font-size:11.5px;color:var(--gray-500);margin-bottom:5px}
  .bubble .anchor a{color:inherit;text-decoration:none} .bubble .anchor a:hover{color:var(--clay);text-decoration:underline}
  .bubble .label{display:inline-block;font-size:10.5px;text-transform:uppercase;letter-spacing:.08em;font-weight:700;margin-right:8px}
  .bubble.sev-P1 .label{color:var(--p1)} .bubble.sev-P2 .label{color:var(--p2)} .bubble.sev-P3 .label{color:var(--olive)}
  .bubble .btitle{font-size:14.5px;color:var(--slate);font-weight:500;margin-bottom:6px;line-height:1.45}
  .bubble .problem{font-size:13.5px;color:var(--gray-700);margin-bottom:2px}
  .bubble .fix{font-size:13.5px;color:var(--gray-700);margin-top:8px}
  .bubble .fixlabel{display:inline-block;font-size:10.5px;text-transform:uppercase;letter-spacing:.06em;font-weight:700;color:var(--olive);margin-right:8px}

  /* GitLab-aligned diff: white panel, solid pale add/del tints (GitLab uses solid
     fills, not low-alpha overlays; the old olive/rust overlays muddied against the
     warm panel), 3px rail + bold +/- in GitLab green/rose ink, near-black code text */
  .diff{background:#fff;border:1.5px solid var(--gray-300);border-radius:0;font-family:var(--mono);font-size:12.5px;line-height:1.7;overflow-x:auto;margin:8px 0}
  .diff-row{display:grid;grid-template-columns:18px 1fr;align-items:baseline;padding:0 12px;white-space:pre}
  .diff-row .mark{text-align:center;color:var(--gray-500)}
  .diff-row .code{color:var(--diff-ink)}
  .diff-row.ctx .code{color:#6B6A63}
  .diff-row.add{background:var(--diff-add-bg);box-shadow:inset 3px 0 0 var(--diff-add-ink)} .diff-row.add .mark{color:var(--diff-add-ink);font-weight:600}
  .diff-row.del{background:var(--diff-del-bg);box-shadow:inset 3px 0 0 var(--diff-del-ink)} .diff-row.del .mark{color:var(--diff-del-ink);font-weight:600}
  pre{background:#F3F1E9;border:1.5px solid var(--gray-300);color:#1F1E1C;font-family:var(--mono);font-size:12.5px;line-height:1.7;padding:12px 14px;border-radius:0;overflow-x:auto;margin-top:8px}
  pre code{background:none;padding:0;color:inherit;font-size:inherit}

  /* more details inside a bubble */
  details.more{margin-top:10px}
  details.more>summary{cursor:pointer;color:var(--clay);font-size:12.5px;list-style:none}
  details.more>summary::-webkit-details-marker{display:none}
  details.more>summary::before{content:"\\25B8 "} details.more[open]>summary::before{content:"\\25BE "}
  .mini{margin-top:9px;font-size:13px;color:var(--gray-700)}
  .mini .mlabel{display:block;font-size:10.5px;text-transform:uppercase;letter-spacing:.06em;font-weight:700;color:var(--gray-500);margin-bottom:4px}
  .train{display:flex;flex-wrap:wrap;gap:6px;align-items:center}
  .car{background:#fff;border:1.5px solid var(--gray-300);border-radius:0;padding:4px 9px;font-size:12.5px}
  .car.bad{border-color:var(--p1);color:var(--p1);background:rgba(176,74,63,.06)}
  .tarrow{color:var(--gray-500)}

  /* collapsed (clean) files */
  details.file-collapsed{border:1.5px solid var(--gray-300);border-radius:0;background:#fff;margin-bottom:14px;scroll-margin-top:20px}
  details.file-collapsed[open]>summary.file-head{border-bottom:1.5px solid var(--gray-150)}
  details.file-collapsed .body{padding:14px 20px 16px;font-size:13.5px;color:var(--gray-700)}

  /* notes */
  .notes{position:relative;border:1.5px solid var(--gray-300);border-radius:0;background:#fff;padding:16px 22px}
  .notes::before{content:"";position:absolute;left:-1.5px;top:-1.5px;bottom:-1.5px;width:3px;background:var(--gray-500)}
  .notes h2{font-family:var(--sans);font-size:15px;color:var(--gray-500);margin-bottom:6px;font-weight:600}
  .notes p{font-size:13px;color:var(--gray-700);margin-bottom:5px}

  @media print{ body{padding:0} .file-card,.file-collapsed,.summary,header.pr-head,.bubble{break-inside:avoid} }
`;

const html = `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${m.mr?.title ? esc(m.mr.title) : esc(m.project || 'Code Review')}</title>
<style>${CSS}</style></head>
<body>
<div class="page">
  <header class="pr-head">
    <div class="repo-line">${repoLine}</div>
    <h1>${h1html}</h1>
    ${metaRow}
  </header>
  ${summary}
  ${riskMap}
  ${filesSection}
  ${notesBlock}
</div>
<script>
  // Risk-map anchors: open a collapsed target and briefly ring the card.
  document.querySelectorAll('.risk-map a').forEach(function (a) {
    a.addEventListener('click', function () {
      var t = document.querySelector(a.getAttribute('href'));
      if (!t) return;
      if (t.tagName === 'DETAILS') t.open = true;
      t.style.transition = 'box-shadow 180ms ease';
      t.style.boxShadow = '0 0 0 3px rgba(217,119,87,0.35)';
      setTimeout(function () { t.style.boxShadow = 'none'; }, 1400);
    });
  });
</script>
</body></html>`;

// --- output ----------------------------------------------------------------
const slugName = m.scope_slug || 'review';
// Local timestamp, minute precision (e.g. 202606031019); orders reports, no hash.
const d = new Date();
const pad = (/** @type {number} */ n) => String(n).padStart(2, '0');
const stamp = `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}${pad(d.getHours())}${pad(d.getMinutes())}`;
// tmpdir() honors $TMPDIR, so the path lands in whatever temp dir the hosting
// agent (Claude sandbox, Codex, plain shell) has made writable.
const dir = join(tmpdir(), 'review', (m.project || 'review').replace(/[^\w.-]/g, '_'));
mkdirSync(dir, { recursive: true });
const out = `${dir}/${slugName}-${stamp}.html`;
writeFileSync(out, html);
const opener = platform() === 'darwin' ? 'open' : 'xdg-open';
execFile(opener, [out], () => {});
console.log(out);
