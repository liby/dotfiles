# Stacked Pull Requests

A stack is an ordered chain of branches on a trunk where each PR is based on the branch below it, so each PR shows only its own layer. The `gh stack` extension (`github/gh-stack`) manages it locally and links the PRs into a Stack on GitHub. It prints a stack trunk first, `(main) <- models <- api`: the left end is the bottom, which merges first, and `up` moves away from the trunk. `gh stack <command> --help` is the flag reference; `gh stack help <command>` prints only the top-level help.

Use a stack when work must build on a branch or PR that has not merged, or when one change splits into dependent layers that should be reviewed separately. A stack is strictly linear, so unrelated changes get their own PRs or stacks.

## Keep every command non-interactive

`gh stack` prompts whenever stdout is a terminal, so in a terminal pane even the forms below can stop at a confirmation or a menu, one of which deletes the GitHub stack, and wait forever. An agent's shell tool normally has no terminal; in a terminal pane, pipe each `gh stack` command through `cat` under `set -o pipefail`. Use these forms, which work without a terminal:

| Run | Never | Why |
| --- | --- | --- |
| `gh stack view --json` | `gh stack view` | opens a TUI |
| `gh stack init <branch>...` | `gh stack init` | prompts for branch names |
| `gh stack add <branch>` | `gh stack add` | prompts for a name |
| `gh stack checkout <target>` | `gh stack checkout` | opens a picker |
| `gh stack up`, `down`, `top`, `bottom` | `gh stack switch` | menu only |
| `gh stack merge <target> --yes` with a method flag | `gh stack merge` | opens a wizard |
| `gh stack unstack`, then `gh stack init` | `gh stack modify` | TUI only |

With more than one remote, pass `--remote <name>` to `push`, `submit`, `sync`, `rebase`, and `link`; `checkout` and `trunk` have no such flag and need `remote.pushDefault`.

`gh stack view --json` writes the stack to stdout and status to stderr. A branch's `base` is the parent SHA it was last known to contain, which can be older than the parent's tip; `needsRebase` is true when the parent's current tip is no longer its ancestor.

## Build and publish

`gh stack init a b c` lays down the chain bottom to top and checks out the last branch unless another worktree has it. It adopts branches that exist and creates each missing one from the branch before it, so naming an unmerged PR's branch first makes that PR the bottom layer. Names are used verbatim. It looks only at local branches: one that exists only as `origin/<branch>` is recreated from the branch below, and the next push overwrites the PR with it, so first make each adopted PR branch's local ref match that PR's `headRefOid`. `gh stack add <branch>` runs only from the top branch (exit 5 elsewhere) and carries uncommitted changes onto the new branch. To change a lower layer, check it out, commit there, run `gh stack rebase --upstack`, and return with `gh stack top`.

`gh stack push` pushes every unmerged layer with per-branch `--force-with-lease`; it is not atomic, and rerunning after fixing a rejected branch is safe. Open each layer's PR like any other PR, with `--base` set to the branch below it, so its title and body describe that layer. Then group the PRs bottom to top with `gh stack link --base <trunk> <pr-number>...`, which adds them to a Stack and retargets each to the branch below it and the bottom one to `--base`, the repository default branch when omitted; this also turns an existing chain of PRs that all target the trunk into a stack. Pass PR numbers: for a branch without a PR, `link` creates one with a generated title, and so does `gh stack submit` for every layer that lacks one, which `--open` also marks, along with existing PRs, ready for review.

Exit 9 from `link` or `submit` means stacked PRs are unavailable on that repository; tell the user, and leave any PRs already opened as ordinary PRs.

## Keep the stack current

`gh stack sync` fetches, fast-forwards the trunk, cascade-rebases each layer whose parent moved or merged (squash merges included), pushes, and links open PRs; it never opens PRs, and `--prune` deletes local branches of merged PRs. When the local and GitHub stacks have diverged, it changes nothing, prints `Sync aborted`, and still exits 0, so check its output before assuming it synced. To keep GitHub's version, run `gh stack unstack --local` and `gh stack checkout <stack-number>`; to keep the local one, rebuild it as for a reorder below. The same `unstack --local` clears a local stack that blocks `checkout` of a stack covering the same branches.

`rebase` and `sync` also rewrite each affected branch in the clean worktree that has it checked out, including one another session is working in, and their lock coordinates only `gh stack` processes; check `git worktree list` first.

There is no non-interactive reorder, rename, or removal. Record the trunk and branch order from `gh stack view --json` and fix the Git ancestry with ordinary rebases. Then run `gh stack unstack`, which drops the local stack as well as the GitHub one, `gh stack init --base <trunk> <branches>...` to adopt the branches in their new order, and link the PRs again; PRs and branches survive `unstack`.

## Merge

Merging a stacked PR lands it together with every unmerged PR below it, all or nothing; a PR above an unmerged one cannot merge alone. `gh pr merge` uses the synchronous merge mutation, which cannot merge a stacked PR.

`gh stack merge <pr> --yes` checks only that the PRs are open and not drafts, reuses the last merge method unless `--merge`, `--squash`, or `--rebase` is passed, and sends no head commit, so it merges whatever the PRs hold when the request arrives. When the merge relies on a recorded `headRefOid`, as the `gh pr merge` rule in `SKILL.md` requires, merge through the asynchronous endpoint instead and pass the top PR's recorded OID as `sha`; the stack's linear history means that head fixes what lands from every layer below. Pass `merge_method`, because the endpoint otherwise creates merge commits:

```bash
gh api -X PUT 'repos/OWNER/REPO/pulls/N/merge-async' -f sha=HEAD_OID -f merge_method=METHOD --jq '.status, .details.uuid'
gh api 'repos/OWNER/REPO/pulls/N/merge-async/UUID' --jq '.status, .details.message'
```

Only a `pending` response has a `uuid`; poll it until the status changes. When a request for that PR already exists, the PUT fails with HTTP 409 and prints the existing request's raw body: poll its `uuid` only when its `details.expected_head_sha` and `details.merge_method` match yours, otherwise tell the user. `merged` is done, `enqueued` means the base branch's merge queue took the stack, and `failed` merged nothing. After `merged`, run `gh stack sync` to update the local branches.

## Exit codes

| Code | Meaning | Recovery |
| --- | --- | --- |
| 2 | Not in a stack | `gh stack init`, or `gh stack checkout <target>` |
| 3 | Rebase conflict | After `rebase`: resolve, `git add`, then `gh stack rebase --continue`, or `--abort` to restore every branch. After `sync`: the branches are already restored; run `gh stack rebase` to reach the conflict. |
| 6 | The branch belongs to several stacks | Check out a branch unique to the intended stack, or pass a stack number |
| 7 | A rebase is in progress | `gh stack rebase --continue` or `--abort` |
| 8 | Another `gh stack` process holds the stack lock | Retry after a few seconds; never delete the lock files |
| 10 | An interrupted `modify` | `gh stack modify --abort` |
