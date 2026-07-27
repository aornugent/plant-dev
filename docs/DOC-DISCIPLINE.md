# Handoff and compaction guidelines — MUST be followed

**Why this file exists.** The failure that costs this project the most is not a wrong gradient. It is
a new session reading a confident sentence that stopped being true three sessions ago, and spending
half its context acting on it. Sessions 15, 16, 19, 20, 21 and 22 each lost time this way, and two of
them reported *proven* failure counts that were invocation artefacts. **Desync is lethal:** a doc that
disagrees with the code is worse than no doc, because it is trusted.

These are rules, not advice. `./docs/check-docs.sh` enforces the mechanical ones; the rest are checked
by the end-of-session ritual at the bottom.

---

## 1. The five ledgers, and nothing else is a source of truth

| document | holds | rule |
|---|---|---|
| [`HANDOFF.md`](./HANDOFF.md) Part 1 | the rules and the rebuild runbook | persistent; never weakened |
| [`HANDOFF.md`](./HANDOFF.md) `OPEN` | **the one to-do list** | authoritative over the task list |
| [`v3-facts.md`](./v3-facts.md) | measured numbers + the command for each | a row is *measured*, never argued |
| [`v3-dead-ends.md`](./v3-dead-ends.md) | refuted claims | read before proposing a mechanism |
| the design doc of the day | commitment, deletions, kill condition | one commitment |

Everything else — deepenings, oracle files, `v3-*` narratives — is **narrative**. Narrative may be
read for a derivation. It is never cited for a status.

## 2. There is exactly ONE to-do list

It is `HANDOFF.md` → `OPEN`. The task list mirrors it and carries the same IDs.

**Never create a second ordered list of next steps.** Session 21 wrote `SIGNPOSTS` beside `OPEN`; both
were plausible, they disagreed, and the stale one came first in the file. A second list is not
redundancy — it is a coin flip for whoever reads next.

- Adding a next step → it goes in `OPEN`, with its task ID in brackets.
- Superseding a next step → **delete it and record what refuted it.** Do not leave it marked
  "superseded" in place at the top of the file where it is still the first thing read.

## 3. Every status claim carries the command that reproduces it

A number without a re-run command is an opinion. Write `**484 pass**` only beside
`` `cd odelia && make test` ``.

**Re-measured and got something else? EDIT THE ROW.** Do not add a second row. Two rows for one
quantity is the same failure as two to-do lists.

**Estimates never enter `v3-facts.md`.** Label them as estimates and keep them in the design doc.
`v3-reverse-memory-design.md` §6d tabulated an estimate without saying so; it was off by 2× and cost a
session's worth of work aimed at the wrong lever.

## 4. A citation is code. If you change the code, RUN THE CITATION

This is the rule that had already been broken when this file was written. `v3-facts.md` cited
`docs/reference/segment-rerecord-probe.R`; a `.cpp` commit removed three fields from the probe's return
list; the driver was never re-run and **errored on every invocation** for as long as the fact was
cited. The number was still true. The citation was dead, which means the fact was untestable, which
means it had reverted to prose.

- Touched a `docs/reference/*.cpp` → run its `.R` **in the same commit**.
- Deleted a metric because it was malformed → say so in the driver's header, so it does not return.
- `./docs/check-docs.sh` verifies every cited path exists. **It cannot verify a script still runs** —
  that is on you.

## 5. Refutations move; they are never inlined

Refuted a claim → the claim moves to `v3-dead-ends.md` with what refuted it, and a one-line pointer is
left where it was asserted. **Do not retract inline.** A linear reader meets the claim before the
correction, and a hurried one never reaches the correction. Session 22 produced four design docs for
one design at four stages of discovery, retracting claims inside documents it had just written.

## 6. Compaction protocol — assume you lost something, then prove what landed

Compaction can land mid-edit, so the docs may be half-written and your memory of them is a summary,
not the file.

**On resuming after a compaction, before writing any more prose:**

1. **Execute the runbook** (`HANDOFF.md` Part 1, Steps 0–3). Do not read prose to rebuild status —
   the whole point is that prose is what went stale.
2. **Verify what actually landed:** `git log --oneline -5`, `git status --short`, and read the
   sections you believe you edited. The summary tells you what you *intended*.
3. **Re-run one cited command** from the work in progress. This is where session 22 found the dead
   probe driver.
4. **Report low confidence explicitly, split by claim.** "High — the algebra; Moderate — unwitnessed
   composition; Low — the coupling, and here is the measurement that lowered it." A single confidence
   number over a mixed bag is not usable by the next session.
5. **Never restate a summary's number as measured.** Either re-run it or attribute it to the summary.

## 7. What a session must do before it ends

```bash
./docs/check-docs.sh          # links resolve, cited paths exist, one to-do list
cd odelia && make test        # and update v3-facts.md §6 if the count moved
```

Then, by hand:

- [ ] every number written this session is a row in `v3-facts.md` with a command
- [ ] every claim refuted this session is a row in `v3-dead-ends.md`
- [ ] `OPEN` reflects reality and the task list mirrors it
- [ ] narratives written this session are listed in `README.md` as narratives
- [ ] `git status` clean and 0 unpushed, in **all three** repos
- [ ] anything you are unsure of is written down as unsure, not omitted

**An absence is a finding.** "This composition has no witness anywhere" is one of the most valuable
sentences in these docs. Write it; do not quietly leave a gap for the next session to rediscover.
