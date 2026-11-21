#!/usr/bin/env bun
// Run one instruction-evaluation trial of Claude Code or Codex under an outer macOS sandbox.
//
//   bun run-trial.ts selftest --runtime codex --model MODEL
//   bun run-trial.ts run --runtime claude --model MODEL --instructions ARM.md \
//       --prompt-file P.txt --out RUN_DIR [--fixture DIR]
//
// Under /Users, /Volumes, and the temporary directories, the model process reads only its trial
// workspace and its own sign-in state and writes only the workspace; its network is TLS and
// loopback. Its shell is one MCP tool whose commands run under a second profile confined to the
// workspace, without network. Codex keeps built-in tools that are not shells, such as
// `apply_patch`; they run inside the model process's profile and show in `stdout.jsonl`, not in
// `transport.jsonl`. Start from a context that is not itself sandboxed, because a Seatbelt profile
// cannot be applied inside another one.
//
// `run` keeps the workspace for grading and names it in `run.json`; remove it afterwards.
// `selftest` exits non-zero unless the installed CLI starts under the profile, quotes the arm it
// was given and the fixture's own instructions, runs a command through the shell tool, and that
// tool can neither read the user's files nor write outside the workspace. Run it before a batch
// and after a CLI upgrade.

import { spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import {
  appendFileSync, cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { parseArgs } from "node:util";
import { RUNTIMES, type RuntimeName } from "./runtimes.ts";

const HOME = homedir();
const SCRATCH_ROOT = join(HOME, ".cache/instruction-eval");

const paths = (kind: string, list: string[]) => list.map((path) => `(${kind} ${JSON.stringify(path)})`).join(" ");

/** Seatbelt profile for the model process, or without `model` for one shell command. */
function profile(workspace: string, model?: { reads: string[]; writes: string[] }) {
  const reads = [workspace, ...(model?.reads ?? []), ...(model?.writes ?? [])];
  const writes = [workspace, ...(model?.writes ?? [])];
  const network = model
    ? '(allow network-outbound (remote tcp "*:443") (remote ip "localhost:*") (literal "/private/var/run/mDNSResponder"))'
    : "(deny mach-lookup)(deny process-info*)(deny signal)";
  const text = `(version 1)(allow default)
    (deny file-read-data ${paths("subpath", ["/Users", "/Volumes", "/private/tmp", "/private/var/folders"])})
    (allow file-read-data ${paths("subpath", reads)})
    (deny file-write*)
    (allow file-write* ${paths("subpath", writes)} (literal "/dev/null"))
    (deny network-outbound)(deny network-bind)(deny appleevent-send)
    ${network}`;
  return ["/usr/bin/sandbox-exec", "-p", text];
}

type Finished = { code: number; out: string; err: string; seconds: number };

// Every command gets its own process group, so a timeout also ends what the command left running;
// the groups still alive when the launcher exits or is interrupted end with it.
const running = new Set<number>();
const endGroup = (pid: number) => {
  try {
    process.kill(-pid, "SIGKILL");
  } catch {}
};
process.on("exit", () => running.forEach(endGroup));
for (const signal of ["SIGINT", "SIGTERM"] as const) process.on(signal, () => process.exit(130));

function invoke(argv: string[], cwd: string, env: Record<string, string | undefined>, stdin: string, timeout: number) {
  return new Promise<Finished>((done) => {
    const begin = Date.now();
    const child = spawn(argv[0], argv.slice(1), { cwd, env, detached: true });
    const pid = child.pid!;
    running.add(pid);
    let out = "";
    let err = "";
    let expired = false;
    child.stdout.setEncoding("utf8").on("data", (chunk: string) => (out += chunk));
    child.stderr.setEncoding("utf8").on("data", (chunk: string) => (err += chunk));
    const timer = setTimeout(() => {
      expired = true;
      endGroup(pid);
    }, timeout * 1000);
    child.on("close", (code) => {
      clearTimeout(timer);
      running.delete(pid);
      done({ code: expired ? 124 : code ?? 1, out, err, seconds: (Date.now() - begin) / 1000 });
    });
    child.stdin.end(stdin);
  });
}

function runShell(cwd: string, command: string, timeout = 60) {
  const env = {
    HOME: cwd,
    TMPDIR: join(cwd, ".tmp"),
    LANG: "en_US.UTF-8",
    PATH: `${cwd}/bin:/usr/bin:/bin:/opt/homebrew/bin`,
    GIT_CONFIG_NOSYSTEM: "1",
    GIT_CONFIG_GLOBAL: "/dev/null",
  };
  return invoke([...profile(cwd), "/bin/bash", "-c", command], cwd, env, "", timeout);
}

/** Minimal MCP server over HTTP that exposes one `run` tool. */
function shellTool(cwd: string, log: (record: object) => void) {
  const methods: Record<string, (params: any) => unknown> = {
    initialize: (params) => ({
      protocolVersion: params.protocolVersion,
      capabilities: { tools: {} },
      serverInfo: { name: "terminal", version: "1.0.0" },
    }),
    "tools/list": () => ({
      tools: [{
        name: "run",
        description: "Execute a shell command in the current workspace and return its stdout, stderr, and exit status.",
        inputSchema: {
          type: "object",
          required: ["command"],
          additionalProperties: false,
          properties: { command: { type: "string", description: "Shell command to execute" } },
        },
      }],
    }),
    "tools/call": async (params) => {
      const command = String(params.arguments.command);
      const { code, out, err, seconds } = await runShell(cwd, command);
      log({ command, code, seconds, stdout: out.slice(-6000), stderr: err.slice(-6000) });
      const text = `${out.slice(-18000)}${err.slice(-7000)}\nExit code: ${code}`;
      return { content: [{ type: "text", text }], isError: code !== 0 };
    },
  };
  return Bun.serve({
    hostname: "127.0.0.1",
    port: 0,
    idleTimeout: 120,
    async fetch(request) {
      const message = request.method === "POST" ? await request.json() : {};
      if (!("id" in message)) return new Response(null, { status: message.method ? 202 : 405 });
      const result = await methods[message.method]?.(message.params ?? {});
      const body = result ? { result } : { error: { code: -32601, message: "unknown method" } };
      return Response.json({ jsonrpc: "2.0", id: message.id, ...body });
    },
  });
}

async function trial(
  name: RuntimeName, model: string, effort: string, instructions: Buffer, prompt: string, out: string,
  fixture: string | undefined, timeout: number, maxTurns: number,
) {
  const runtime = RUNTIMES[name];
  mkdirSync(out);
  mkdirSync(SCRATCH_ROOT, { recursive: true });
  const root = mkdtempSync(join(SCRATCH_ROOT, "trial-"));
  const cwd = join(root, "project");
  try {
    // Resolved first: a fixture path that is itself a link would be copied as a link, and the
    // trial would then write into the directory it points to.
    if (fixture) cpSync(realpathSync(fixture), cwd, { recursive: true, verbatimSymlinks: true });
    mkdirSync(join(cwd, ".tmp"), { recursive: true });
    runtime.writeArm(root, cwd, instructions);
  } catch (error) {
    rmSync(root, { recursive: true });
    throw error;
  }

  const tool = shellTool(cwd, (record) => appendFileSync(join(out, "transport.jsonl"), JSON.stringify(record) + "\n"));
  const { REX_SESSION, REX_BLOCK, ...inherited } = process.env;
  const env = {
    ...inherited,
    CLAUDE_CODE_TMPDIR: join(cwd, ".tmp"),
  };
  const mcpUrl = `http://127.0.0.1:${tool.port}/mcp`;
  const argv = [...profile(root, runtime), runtime.launcher, ...runtime.command(model, effort, cwd, mcpUrl, maxTurns)];
  const { code, out: stdout, err: stderr, seconds } = await invoke(argv, cwd, env, prompt, timeout);
  await tool.stop(true);

  let reply = "";
  for (const line of stdout.split("\n")) {
    try {
      reply = runtime.reply(JSON.parse(line)) || reply;
    } catch {}
  }
  const queried = Bun.spawnSync([runtime.launcher, ...runtime.version]);
  const result = {
    runtime: name, model, effort, exit: code, seconds, workspace: cwd, reply,
    cli_version: queried.exitCode === 0 ? queried.stdout.toString().trim() : `unknown (exit ${queried.exitCode})`,
    instructions_sha256: new Bun.CryptoHasher("sha256").update(instructions).digest("hex"),
  };
  writeFileSync(join(out, "stdout.jsonl"), stdout);
  writeFileSync(join(out, "stderr.txt"), stderr);
  writeFileSync(join(out, "run.json"), JSON.stringify(result, null, 2) + "\n");
  return result;
}

/** Check the boundary directly, then that the model reads the arm and can use the shell tool. */
async function selftest(name: RuntimeName, model: string, effort: string) {
  mkdirSync(SCRATCH_ROOT, { recursive: true });
  const root = mkdtempSync(join(SCRATCH_ROOT, "selftest-"));
  const cwd = join(root, "project");
  mkdirSync(join(cwd, ".tmp"), { recursive: true });
  writeFileSync(join(root, "outside.txt"), "OUTSIDE");
  const checks: [what: string, command: string, allowed: boolean][] = [
    ["write inside the workspace", `echo ok > ${cwd}/inside.txt && cat ${cwd}/inside.txt`, true],
    ["read outside the workspace", `cat ${root}/outside.txt`, false],
    ["write outside the workspace", `echo x > ${root}/escape.txt`, false],
    [`list ${HOME}/.ssh`, `ls ${HOME}/.ssh`, false],
    ["reach the network", "curl -sS -m 5 https://example.com -o /dev/null", false],
  ];
  const failures: string[] = [];
  for (const [what, command, allowed] of checks) {
    const { code } = await runShell(cwd, command, 20);
    if ((code === 0) !== allowed) failures.push(`shell could ${allowed ? "not " : ""}${what}`);
  }

  const marker = `The evaluation marker for this run is ${randomBytes(10).toString("hex")}.`;
  const token = randomBytes(10).toString("hex");
  const fixture = join(root, "fixture");
  mkdirSync(fixture);
  writeFileSync(join(fixture, "token.txt"), token + "\n");
  const projectMarker = `The project marker for this run is ${randomBytes(10).toString("hex")}.`;
  writeFileSync(join(fixture, "AGENTS.md"), `# Project\n\n${projectMarker}\n`);
  const out = join(root, "run");
  const prompt =
    "Quote the complete sentences in your instructions that begin with 'The evaluation marker for this run' " +
    "and with 'The project marker for this run', answering ABSENT for one you cannot find. " +
    "Then run `cat token.txt` with your shell tool and add its output on a new line.";
  // The marker ends an arm as large as real ones, so a runtime that cuts the file short fails here.
  const arm = `# Instructions\n\n${"Filler line for size.\n".repeat(2000)}\n${marker}\n`;
  const result = await trial(name, model, effort, Buffer.from(arm), prompt, out, fixture, 120, 4);
  const said = result.reply.slice(0, 200);
  if (result.exit !== 0) {
    const stderr = readFileSync(join(out, "stderr.txt"), "utf8").slice(-400);
    failures.push(`${name} ${result.cli_version} exited ${result.exit}: ${stderr}`);
  } else if (!result.reply.includes(marker)) {
    failures.push(`${name} did not quote the arm it was given: ${said}`);
  } else if (!result.reply.includes(projectMarker)) {
    failures.push(`${name} did not load the fixture's AGENTS.md beside the arm: ${said}`);
  } else if (!result.reply.includes(token) || !existsSync(join(out, "transport.jsonl"))) {
    failures.push(`${name} did not run a command through the shell tool: ${said}`);
  }
  rmSync(resolve(result.workspace, ".."), { recursive: true });
  rmSync(root, { recursive: true });
  console.log(JSON.stringify({ runtime: name, cli_version: result.cli_version, seconds: result.seconds, failures }, null, 2));
  return failures.length ? 1 : 0;
}

const { positionals: [command], values } = parseArgs({
  allowPositionals: true,
  options: {
    runtime: { type: "string" },
    model: { type: "string" },
    effort: { type: "string", default: "high" },
    instructions: { type: "string" },
    "prompt-file": { type: "string" },
    out: { type: "string" },
    fixture: { type: "string" },
    timeout: { type: "string", default: "210" },
    "max-turns": { type: "string" },
  },
});
const required = ["runtime", "model", ...(command === "run" ? ["instructions", "prompt-file", "out"] : [])];
const missing = required.filter((option) => !values[option as keyof typeof values]);
// Codex has no turn limit to pass the option to; --timeout bounds its run.
const unsupported = values.runtime === "codex" && values["max-turns"];
if (!["selftest", "run"].includes(command) || missing.length || !(values.runtime! in RUNTIMES) || unsupported) {
  console.error(
    "usage: run-trial.ts selftest|run --runtime claude|codex --model MODEL [--effort LEVEL]\n" +
    "       run also takes --instructions ARM.md --prompt-file P.txt --out NEW_DIR [--fixture DIR]\n" +
    "       [--timeout SECONDS] [--max-turns N, Claude Code only]",
  );
  process.exit(2);
}
const probe = Bun.spawnSync(["/usr/bin/sandbox-exec", "-p", "(version 1)(allow default)", "/usr/bin/true"]);
if (probe.exitCode !== 0) {
  console.error(
    "This context is already sandboxed, so the trial profile cannot be applied; start from a terminal that is not. " +
    `(${probe.stderr.toString().trim()})`,
  );
  process.exit(1);
}
const name = values.runtime as RuntimeName;
if (command === "selftest") process.exit(await selftest(name, values.model!, values.effort!));
const result = await trial(
  name, values.model!, values.effort!, readFileSync(values.instructions!), readFileSync(values["prompt-file"]!, "utf8"),
  values.out!, values.fixture, Number(values.timeout), Number(values["max-turns"] ?? 12),
);
console.log(JSON.stringify(result));
process.exit(result.exit === 0 ? 0 : 1);
