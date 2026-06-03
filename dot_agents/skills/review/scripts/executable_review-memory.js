#!/usr/bin/env bun
import { Database } from "bun:sqlite";
import { mkdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const skillDir = dirname(scriptDir);
const dbPath = process.env.REVIEW_MEMORY_DB || join(skillDir, "state", "review-memory.sqlite3");

function usage() {
  console.log(`review-memory

Usage:
  review-memory init
  review-memory record-run <review.json|-> 
  review-memory propose-rule --episode <id> --type <text> --trigger <text> --root-cause <text> --rule <text> --boundary <text> --negative-example <text>
  review-memory search <query>
  review-memory pack <proposal-id>

This records review self-evolution data. It does not edit skill files.`);
}

function parseArgs(argv) {
  const positional = [];
  const flags = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "-h" || arg === "--help") {
      usage();
      process.exit(0);
    }
    if (!arg.startsWith("--")) {
      positional.push(arg);
      continue;
    }
    const key = arg.slice(2);
    const value = argv[++i];
    if (!value) throw new Error(`missing --${key}`);
    flags[key] = value;
  }
  return { positional, flags };
}

const CANDIDATE_TYPES = [
  "Recurring miss",
  "Near miss",
  "False positive",
  "Delegate signal",
  "Fix drift",
  "Codified rule",
];

function normalize(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fff]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function hash(value) {
  return new Bun.CryptoHasher("sha256").update(value).digest("hex");
}

function isSecretPath(value) {
  return /(^|\/)(\.env|\.ssh|id_rsa|id_dsa|id_ecdsa|id_ed25519|authorized_keys|known_hosts)(\/|$)|\.(pem|key|p12|pfx|crt|cer|log)$|credential|secret|token/i.test(
    String(value || ""),
  );
}

function clip(value, max = 1200) {
  const text = String(value || "");
  return text.length > max ? `${text.slice(0, max)}...` : text;
}

function requireFlag(flags, name) {
  if (!flags[name]) throw new Error(`missing --${name}`);
  return flags[name];
}

function openDb() {
  mkdirSync(dirname(dbPath), { recursive: true });
  const db = new Database(dbPath);
  db.run("PRAGMA foreign_keys = ON");
  db.run(`
    CREATE TABLE IF NOT EXISTS episodes (
      id TEXT PRIMARY KEY,
      created_at TEXT NOT NULL,
      repo TEXT,
      scope TEXT,
      reviewed_sha TEXT,
      verdict TEXT,
      validation TEXT,
      manual_gap TEXT,
      raw_hash TEXT NOT NULL UNIQUE
    )
  `);
  db.run(`
    CREATE TABLE IF NOT EXISTS observations (
      id TEXT PRIMARY KEY,
      episode_id TEXT NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
      kind TEXT NOT NULL,
      sev TEXT,
      level TEXT,
      title TEXT NOT NULL,
      path TEXT,
      line INTEGER,
      body TEXT,
      evidence TEXT,
      impact TEXT
    )
  `);
  db.run(`
    CREATE TABLE IF NOT EXISTS rule_proposals (
      id TEXT PRIMARY KEY,
      episode_id TEXT NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
      created_at TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'open',
      candidate_type TEXT NOT NULL,
      trigger TEXT NOT NULL,
      root_cause TEXT NOT NULL,
      rule TEXT NOT NULL,
      boundary TEXT NOT NULL,
      negative_example TEXT NOT NULL,
      normalized_key TEXT NOT NULL
    )
  `);
  return db;
}

function insertObservation(db, episodeId, kind, item) {
  const path = item.path || "";
  if (isSecretPath(path)) throw new Error("refusing to store secret-like path");
  db.query(`
    INSERT INTO observations
      (id, episode_id, kind, sev, level, title, path, line, body, evidence, impact)
    VALUES
      (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    crypto.randomUUID(),
    episodeId,
    kind,
    item.sev || null,
    item.level || (kind === "note" ? "weak" : "confirmed"),
    clip(item.title || item.text || "Observation"),
    path || null,
    Number.isInteger(item.line) ? item.line : null,
    clip(item.problem || item.text || item.manual_gap || ""),
    clip(item.evidence || ""),
    clip(item.impact || ""),
  );
}

function recordRun(db, file) {
  const raw = file === "-" ? readFileSync(0, "utf8") : readFileSync(file, "utf8");
  const rawHash = hash(raw);
  const existing = db.query("SELECT id FROM episodes WHERE raw_hash = ?").get(rawHash);
  if (existing) return { episodeId: existing.id, inserted: false };

  const data = JSON.parse(raw);
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new Error("invalid review JSON: expected an object");
  }
  const hasMeta = data.meta && typeof data.meta === "object" && !Array.isArray(data.meta);
  const hasFindings = Array.isArray(data.findings) && data.findings.length > 0;
  if (!hasMeta && !hasFindings) {
    throw new Error("invalid review JSON: needs a meta object or a non-empty findings array");
  }
  const meta = data.meta || {};
  const episodeId = crypto.randomUUID();
  db.transaction(() => {
    db.query(`
      INSERT INTO episodes
        (id, created_at, repo, scope, reviewed_sha, verdict, validation, manual_gap, raw_hash)
      VALUES
        (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      episodeId,
      new Date().toISOString(),
      meta.project || null,
      meta.scope || meta.scope_slug || null,
      meta.reviewed_sha || null,
      clip(meta.verdict || ""),
      clip(meta.validation || ""),
      clip(meta.manual_gap || ""),
      rawHash,
    );

    for (const finding of data.findings || []) insertObservation(db, episodeId, "finding", finding);
    for (const note of data.notes || []) insertObservation(db, episodeId, "note", note);
    if (meta.manual_gap) {
      insertObservation(db, episodeId, "manual_gap", {
        level: "manual",
        title: "Manual gap",
        manual_gap: meta.manual_gap,
      });
    }
  })();

  return { episodeId, inserted: true };
}

function proposeRule(db, flags) {
  const trigger = requireFlag(flags, "trigger");
  const rootCause = requireFlag(flags, "root-cause");
  const type = requireFlag(flags, "type");
  if (!CANDIDATE_TYPES.includes(type)) {
    throw new Error(`invalid --type "${type}"; must be one of: ${CANDIDATE_TYPES.join(", ")}`);
  }
  const key = normalize(`${trigger} ${rootCause}`);
  const id = crypto.randomUUID();
  db.query(`
    INSERT INTO rule_proposals
      (id, episode_id, created_at, candidate_type, trigger, root_cause, rule, boundary, negative_example, normalized_key)
    VALUES
      (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    id,
    requireFlag(flags, "episode"),
    new Date().toISOString(),
    type,
    trigger,
    rootCause,
    requireFlag(flags, "rule"),
    requireFlag(flags, "boundary"),
    requireFlag(flags, "negative-example"),
    key,
  );
  return { proposalId: id, candidateType: type };
}

function search(db, query) {
  const normalized = normalize(query);
  const terms = normalized.split(" ").filter(Boolean);
  const rows = db.query(`
    SELECT id, status, candidate_type, trigger, root_cause, rule, boundary, negative_example
    FROM rule_proposals
    WHERE status = 'open'
    ORDER BY created_at DESC
    LIMIT 50
  `)
    .all()
    .filter((row) => terms.every((term) => normalize(`${row.trigger} ${row.root_cause} ${row.rule}`).includes(term)))
    .slice(0, 5);
  return { query, results: rows };
}

function pack(db, proposalId) {
  const proposal = db.query("SELECT * FROM rule_proposals WHERE id = ?").get(proposalId);
  if (!proposal) throw new Error(`proposal not found: ${proposalId}`);
  const episode = db.query("SELECT * FROM episodes WHERE id = ?").get(proposal.episode_id);
  const observations = db.query(`
    SELECT kind, sev, level, title, path, line, body, evidence, impact
    FROM observations
    WHERE episode_id = ?
    ORDER BY rowid
  `).all(proposal.episode_id);

  return `# Rule Proposal Pack

Proposal: ${proposal.id}
Episode: ${proposal.episode_id}
Type: ${proposal.candidate_type || ""}
Repo: ${episode?.repo || ""}
Scope: ${episode?.scope || ""}

## Trigger

${proposal.trigger}

## Root Cause

${proposal.root_cause}

## Rule

${proposal.rule}

## Boundary

${proposal.boundary}

## Negative Example

${proposal.negative_example}

## Evidence From Review

${observations
  .map((o) => {
    const loc = o.path ? ` (${o.path}${o.line ? `:${o.line}` : ""})` : "";
    const head = `- ${o.kind}${o.sev ? ` ${o.sev}` : ""}: ${o.title}${loc}`;
    const detail = [
      o.body ? `  - problem: ${o.body}` : "",
      o.evidence ? `  - evidence: ${o.evidence}` : "",
      o.impact ? `  - impact: ${o.impact}` : "",
    ].filter(Boolean).join("\n");
    return detail ? `${head}\n${detail}` : head;
  })
  .join("\n")}

This pack is input for a separate skill-maintenance task. It does not edit skill files.
`;
}

const { positional, flags } = parseArgs(process.argv.slice(2));
const command = positional[0];
if (!command) {
  usage();
  process.exit(1);
}

try {
  const db = openDb();
  let result;
  if (command === "init") result = { db: dbPath };
  else if (command === "record-run") result = recordRun(db, positional[1] || "-");
  else if (command === "propose-rule") result = proposeRule(db, flags);
  else if (command === "search") result = search(db, positional.slice(1).join(" "));
  else if (command === "pack") result = pack(db, positional[1]);
  else throw new Error(`unknown command: ${command}`);

  if (typeof result === "string") process.stdout.write(result);
  else console.log(JSON.stringify(result, null, 2));
  db.close();
} catch (error) {
  console.error(`review-memory: ${error.message}`);
  process.exit(1);
}
