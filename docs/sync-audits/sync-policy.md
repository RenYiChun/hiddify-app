# Hiddify Weekly Sync Policy

Updated: 2026-06-03 16:02:14 +08:00

## Current Mode

Mode: catch-up

The weekly sync should now treat upstream catch-up as the target for every eligible repository/module, not only low-risk fixes. If a branch is clean and has clear lineage, missing upstream commits should be evaluated for integration even when they are feature commits or broad changes, including commits such as `ezytel` in `hiddify-core`.

## Catch-Up Rules

1. Discover the root repository and every recursive submodule with `git submodule status --recursive` or an equivalent command.
2. Inspect remotes, current branch, configured upstream, default branch, and working-tree cleanliness before changing any module.
3. Fetch/prune/tags for every discovered module before comparing deltas.
4. For normal branches with clear upstream lineage, aim to bring the branch up to date with its intended upstream/default comparison target.
5. Do not exclude a commit only because it is a feature or a large change. Instead, attempt integration planning, conflict assessment, and validation appropriate to the touched surface.
6. Preserve local Windows TUN, dynamic direct bypass, and direct DNS fallback behavior as protected behavior during conflict resolution and verification.
7. Commit and push from deepest changed submodules outward so parent submodule pointers remain correct.

## Hard Stops

Stop before syncing or pushing an affected module when any of these appear:

- Dirty unrelated worktree changes
- Detached HEAD without an explicit branch or pin-advance decision
- Ambiguous branch lineage or unusable remote/upstream
- Merge/cherry-pick conflict that cannot be resolved without risking protected behavior
- Test failure after integration
- Authentication or push failure

## Detached Pins

Catch-up mode does not automatically advance detached pinned modules. Modules such as `ray2sing` or `tailscale` still need an explicit pin-advance decision before their submodule pointers are moved.

Once a pin decision is explicit, evaluate and validate that module as part of the same deepest-first sync flow.
