# tft-overlay — working agreement

Read this before starting any work in this repo.

## Product context

Native macOS overlay and companion app for Teamfight Tactics. See `README.md` for
why this exists and the phase breakdown, and `docs/adr/` for decisions already made.

**The priority is the overlay working standalone.** It must be fully usable with no
game running and no host detected. Host integration (Mactician, and a native client
if Riot restores macOS support) is an enhancement layered on top behind `GameHost`,
never a prerequisite. Do not let host specifics leak into the overlay, the UI, or
the data layer.

**Mactician is a temporary stopgap.** Riot calls the macOS removal temporary. Treat
Mactician as replaceable: everything Mactician-shaped lives behind `MacticianHost`.

## Workflow — non-negotiable

Work autonomously. Do not stop to ask for approval on ordinary implementation
decisions; make the call, write it down, keep moving. Ask only when genuinely
blocked or when a decision is irreversible and unclear.

Every change ships through a pull request:

1. Branch from `main`. One branch per logical unit of work.
2. **Atomic commits.** Each commit is one coherent change that builds and passes
   tests on its own. Never mix a refactor with a feature, or a fix with a rename.
3. **Tests are part of the change, not a follow-up.** A PR that adds behaviour
   without adding tests for it is incomplete. Bugs get a regression test that fails
   before the fix and passes after.
4. Open a PR. Reference the GitHub issue it closes.
5. **Wait for CI to pass.** Do not merge on a red or pending build.
6. Merge once green with `gh pr merge --rebase`, then delete the branch.

**Use `--rebase`, never `--squash`.** Squashing collapses carefully separated
commits into one and throws away the atomicity that made them reviewable. If the
branch's commits are not worth keeping individually, they were not atomic and the
branch needs restructuring, not squashing.

Never commit directly to `main`.

## Verification — learned the hard way

`swift test` passing is not evidence the UI works. Layout defects (text wrapping,
clipping, contrast, sizing) are invisible to unit tests and have shipped past them
in this repo already.

For any change that affects what the user sees:

- Launch the built binary.
- Enumerate the window with `CGWindowListCopyWindowInfo` to confirm it exists, and
  check its layer and frame.
- Screenshot it with `screencapture -x -o -l<windowid>` and actually look at it.

`scripts/probe/` has reusable helpers for this. If your session cannot get a
WindowServer surface, say so plainly in your report — state what you did verify and
what you could not. Never assume or fabricate a visual result.

## Concurrent agents in a shared worktree

When several agents work in the same worktree at once, **repo-wide git commands are
destructive**. `git checkout .`, `git restore .`, `git reset`, `git stash`, `git clean`
and `git add -A` all reach outside the caller's own files and silently wipe other
agents' uncommitted work. This has already happened once here: five tracked files in
`Packages/TFTData` reverted to HEAD mid-edit and the work had to be redone.

Rules for any agent that does not own the whole worktree:

- The only permitted git commands are read-only: `status`, `diff`, `log`.
- To discard your own change, edit the file back or delete it. Never use git for it.
- If a file outside your area looks wrong, report it. Do not fix or revert it.
- The coordinator owns all commits, branches and merges.

Prefer giving each concurrent agent its own worktree when the work allows it. A shared
worktree is only safe when every agent stays strictly inside disjoint paths *and*
follows the rules above.

## Architecture constraints

- `Packages/TFTUI` and `Packages/OverlayKit` must not depend on each other. The app
  target in `Sources/TFTOverlay/` is the only place they meet.
- `Packages/TFTData` is pure and testable: no UI, no window, no host, no capture.
- `Packages/LCUClient` is a deferred stub. There is no League client on macOS. Do
  not implement it.
- Prefer adding files over editing existing ones across package boundaries. If you
  must edit another package's file, keep it minimal and explain why.

## Hard rules

**Pixels and documented local APIs only.** Never read the memory of the game, the
emulator, or any host process. Never inject into any process. This is not
negotiable and is not subject to a "just for testing" exception.

**Never use someone else's Riot account.** Do not sign in, do not enter a queue, do
not accept a session that is already logged in as someone else.

Riot's third-party rules bound the feature set: no tracking or predicting
opponents during gameplay (including aggregate lobby stats), no input automation,
and never obscure the shop, board, trait rail or system menus. See issue #69.
