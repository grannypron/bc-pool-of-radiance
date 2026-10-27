# Brief: shared Gold Box units (analysis only), 2026-10-26

Brian ports SSI's Gold Box games from reconstructed Turbo Pascal 6 source. Five ports have Pascal source in
/home/brian/repos: pool-of-radiance (PoR, the most advanced: refactored, native FPC/SDL3 build), curse-of-the-azure-bonds
(Curse), secret-of-the-silver-blades (Secret), pools-of-darkness (Pools), champions-of-krynn (CoK). Each re-implements the
same engine though the source is astoundingly alike. Goal: identify every unit, routine, table and constant that can be
shared by all the Gold Box games, and how. Each game stays its own repository, compiled by itself; within a game's
repository its versions (v1.0, v1.1...) become one source tree with the version differences overlaid (not a folder per
version). So the target shape is a shared core, used by every game's repository, plus a thin per-game layer (parameters,
tables, hooks): not five copies kept in step, and not one repository for all games.

Brian's specific wish: take all the definitions, tables and constants and consolidate them from level 1 up to whatever
Pools of Darkness allows (its level caps, class tables, XP, THAC0, saves, spell slots, thief skills, turning, etc.), with
each game enforcing its own level limits and gear limits on top.

## Rules

- ANALYSIS ONLY. Do not modify, commit to, push, or open PRs/issues in any repository. A Curse agent is migrating PoR's
  work into Curse right now, and the other repos have work in flight.
- Read each game at its origin/main: `git -C ~/repos/<repo> show origin/main:src/<file>` and
  `git -C ~/repos/<repo> ls-tree -r origin/main`, or `git -C ~/repos/<repo> worktree add --detach <scratchpad dir> origin/main`
  (remove the worktree when done: `git -C ~/repos/<repo> worktree remove --force <dir>`). Never edit a checkout.
- Read /home/brian/repos/CLAUDE.md and the cross-game cleanup spec it names
  (goldbox-re-tools/docs/superpowers/specs/2026-10-04-cross-game-cleanup-design.md) for the fleet's conventions; it governs
  the byte-matched disassembly trees, which must stay byte-matched.
- PoR's docs/refactor-plan.md and docs/detailed-changes.md say what PoR changed; each port's docs say the same for it.
- Diff routines across games to classify each as: identical; identical but for data (tables, constants, strings, game
  numbers); same logic with game-specific branches (say which, and whether a parameter/hook covers it); diverged
  (different rules or features, say what). Use diff tooling on normalized text (strip comments/whitespace) where useful,
  then read the differences: they are the point.
- Note PoR-only features (bestiary, journal quests, vault, dual-class, native layer...) that other ports lack or have
  partly (Curse is receiving them now): shareable later.
- Be concrete: file and routine names, line counts, what parameter or hook would absorb each difference.

## Output

Write your report to /tmp/claude-1000/-home-brian-repos-pool-of-radiance/76f98367-99ca-4028-b60d-7be679625eb9/scratchpad/shared-<your area>.md
(markdown: a table per unit or group, then a proposal: what the shared unit is, what stays per game, the per-game
parameters/hooks, risks such as save-format or byte-layout differences and DOS memory/overlay constraints). Your final
message: a short summary (the headline findings and the counts), and the report's path.
