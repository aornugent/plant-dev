# Brief: land three concerns independently, each as one polished PR

The user wants exact counts, the storage pool and the soil subsystem to land first, each on its
own, as a change maintainers find easy to understand and accept. Principles: Laziness Protocol,
Subtract Before You Add, Minimize Reader Load, Foundational Thinking, Model the Domain;
AGENTS.md's code style and PR workflow (one PR per issue; branch named after the issue).

## State of the forks (refreshed 2026-10-18)
- plant origin/develop = upstream/develop = bd09645d. Upstream has moved since our stack began:
  - the census gradient by trait (#648, #657, #658: FF16 fitness);
  - odelia 0.6.x;
  - phylloptim 0.9.2;
  - the light field read through odelia's Hermite (#649);
  - K93's model body in its header (#659);
  - a retried birth-date stage (#662);
  - fitness in continuous and long patches (#661).
- odelia origin/master = upstream = 1e0f0f0 (0.7.x: a Dormand–Prince run recorded and swept,
  Hairer's step rule the default, an active cubic query as one tape statement).
- phylloptim origin/master = upstream = d216a17 (odelia as a floor).
- The old stack is archived on each fork as `archive/stack-2026-10-18/<branch>` (plant PLANT-93…110,
  odelia ODELIA-53…55, phylloptim PHYLLOPTIM-17…19). Branch names may now be reused; push with
  `--force-with-lease`.
- The aggregate review of the stack: docs/stack-split.md and
  docs/measurements/schedule-search/rootcause/review/stack/{A,B,C}-*.md.

## For each concern
1. **Port the smallest change** onto the refreshed default branch, on a fresh branch named
   after its issue:
   - start from the archived branches' diffs, not their history;
   - take what upstream now provides from upstream, and do not re-add it;
   - carry no renames-then-renames, no dead code, no demo or probe code, no test-only code in the
     shipped .so.
2. **Build** into a private library under
   /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/land/<name>/lib
   (copy the odelia/phylloptim it needs, or build them from the refreshed branches).
   - Every build or install goes through
     `flock /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/build.lock nice -n 10 ...`;
     three agents and several runs share four cores.
   - Run plant's tests by AGENTS.md's tiers, with the full serial sweep before you push.
   - If references move, re-bless them in this PR and say why in the commit.
3. **Review and polish** with the code-review skill (.claude/skills/code-review/SKILL.md, Tier 2):
   - write the review to docs/prs/<name>-review.md;
   - apply its findings, and check AGENTS.md's comment rules on every line you touch.
4. **The case for the PR:** docs/prs/<name>.md, written for plant's maintainers. It covers:
   - the problem, in the model's terms;
   - the mechanism;
   - the measured gain, each number cited to its source in plant-dev docs or measured afresh
     here. Re-measure only what upstream's changes invalidate, at most ~4 SCM runs, one at a time;
   - what it costs (runtime, lines, references moved);
   - how it is tested;
   - what a reviewer should check.

   Mirror plant's PR template if one exists (.github/pull_request_template.md). Keep it short;
   numbers over adjectives.
5. Push the branch to origin. Do NOT open the PR, comment on GitHub, or edit issues; the
   coordinator asks the user first. Do not edit plant-dev's harness. Report: branch and head, diff
   stat, tests run and their results, the review's verdict, and the case's three headline numbers.
