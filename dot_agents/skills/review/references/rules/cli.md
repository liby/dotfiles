# CLI And Packaging

Load when changed code touches CLI entrypoints, installers, packages, archives, generated wrappers, stdout or stderr contracts, TTY behavior, exit codes, local servers, installed-runtime checks, or source-to-package mapping.

**Tooling fails at the boundary between source, packaged files, installed runtime, and caller expectations.** Review the artifact or process the user actually runs, not only the source file.

- command contract: help, version, subcommands, flags, exit code, stdout, stderr, JSON output, and TTY versus non-interactive behavior.
- package or archive inclusion: new scripts, templates, executable bits, generated mirrors, and source-to-install path mapping; published client packages must not depend on server-only source or files omitted from the package.
- runtime readiness: a launched command is not enough; verify the service is listening and required dependencies are available before clients connect.
- installer defaults, floating refs, remote downloads, cache paths, and package-manager or Corepack assumptions.
- failure paths print an actionable setup or refusal message without leaking secret-bearing paths or process output (see [security](../concerns/security.md)).

Sandbox privilege and agent-controlled runtimes: [agent](agent.md). Generated wrappers and installed copies staying in sync with source: [contract](../concerns/contract.md).
