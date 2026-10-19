# Long-drought invasion "refused below empty": not PLANT-97, not PLANT-95

The reported failure, and the `J` 13.276378401 that disagrees with PLANT-97's 13.7626, both
come from a run that loaded neither branch. `docs/prs/PLANT-95/ld.R` was run with `PLANT_LIB`
unset. `harness/long_drought.R` then falls back to `pkgload::load_all()` on the plant-dev
submodule. That checkout is 6613dd24 (`establishment-window`), with a prebuilt
`plant/src/plant.so` from 2026-09-23. odelia came from `R_LIBS`, so it looked like the
intended library. That plant still has develop's stage guard and has no
`storage_relaxation_offset`. `set_offset()` writes a list name that `TF24_Pars` ignores, so
"offset 7 d" ran at no offset at all. On the real libraries, both branches reproduce
PLANT-97's numbers, and their invaders run. No plant code is at fault, and no plant branch
changes.

## Evidence (one SCM process at a time, `nice -n 10`, ld.R stand: TF24, 40 yr, 108 uniform introductions, birth date, tol 1e-3)

| build loaded (verified by `getNamespaceInfo("plant","path")`) | resident `J`, steps | x0.9 | x1.2 | x0.7 |
|---|---|---|---|---|
| submodule 6613dd24 via load_all (`R_LIBS`=PLANT-97/lib, no `PLANT_LIB`) | 13.276378401, 10 577 | stage guard throws, −1.15773e-07 kg | — | — |
| develop bd09645d (`PLANT-93/lib-dev`) | 13.348749767, 10 550 | stage guard throws, −1.03176e-08 kg | stage guard throws, −1.5508e-07 kg | — |
| PLANT-97 b23b2d67 (`PLANT-97/lib`) | **13.762607917, 9 262** | 61.0044 | 0.0763684 | leaf solve fails (PLANT-97 run3) |
| PLANT-95 28b96d3b (`PLANT-95/lib`, odelia 0.8.1) | **13.762607917, 9 262** | 59.4899 | 0.0876754 | 464.342 |

- The first row reproduces the reported output exactly: `J`, the step count and the error
  value. Running the old ld.R with `PLANT_LIB` set gives the third and fourth rows.
- The libraries are what they claim to be:
  - `PLANT-93/lib-dev`'s source tree (`dev-src`) and installed headers match `git archive
    bd09645d` file for file. It is develop.
  - `PLANT-97/lib`'s headers differ from b23b2d67 only in three comments. Its build predates
    the comment-only edit, as PLANT-97.md says.
  - The probe build behind PLANT-97.md's table added only `REprintf` calls and an env-gated
    throw. It runs the same `measure/ld.R` byte for byte, which is why it quoted 13.762607917.
- The error text `"TF24 storage is negative (...): the pool's flow does not leave [0,
  capacity], so this is a step that overshot the empty boundary"` is develop's **stage**
  guard, `stop_domain` in TF24's rates (develop `tf24_strategy.h:2017`, submodule `:1987`).
  It appears in neither branch's headers nor `plant.so` (`strings | grep` gives 0). PLANT-97
  deletes this guard. Its own refusal of a step end, `Patch::ode_state_valid()`, returns
  false and has a different message. So the report's "refused step end" was a thrown stage.
- develop ignores the offset: its `J` at "OFFSET 7" is bit-identical to its offset-0 run in
  PLANT-97's run1 (13.348749767).

## The questions

1. **Does the invasion succeed on plain develop?** No. On bd09645d x0.9 and x1.2 both fail on
   the stage guard. This is the failure PLANT-97 was written to remove, and PLANT-97 did not
   introduce it. On PLANT-97 and PLANT-95 both invaders run.
2. **Why does the recording pass refuse what the resident accepted?** It doesn't. The
   failure is in the invader's walk:
   - On the first call, `SCM::run_mutant` re-runs the resident pinned to its own accepted
     steps (`r_set_ode_steps`). It stores `resident_recording` only after that `run()`
     returns.
   - After x0.9 fails, invading with the resident's own traits (x1) replays in 15–16 s with
     the resident's `J` and step count. On develop that is 13.348749767 over 10 550 steps;
     on the submodule, 13.276378399 over 10 577. So the recording was complete, and no
     second recording pass ran.
   - In the ld.R output, x1.2 fails at 0 s, which points the same way.
   - x0.9 fails late in its walk; x1.2 fails at its first step. A walk takes the resident's
     steps and cannot shrink one, so a thrown stage is fatal. The adaptive resident just
     shrinks the step and retries.
   - Script: `inv_check.R` in the scratchpad (below).
3. **Root cause and fix.** The cause is measurement error: the harness loaded the wrong
   plant, silently, and silently ignored the offset. No plant branch owns a fix.
   - **Made (uncommitted in plant-dev):**
     - `docs/prs/PLANT-95/ld.R` prints the plant path it loaded. It stops if TF24 has no
       `storage_relaxation_offset`. Checked: it stops on the submodule fallback and passes
       on `PLANT-97/lib`.
     - `ld-PLANT-97.out` and `ld-PLANT-95.out` are replaced with the correct runs.
     - PLANT-95.md's long-drought bullet now has the right resident and an invader table.
     - PLANT-97.md is unchanged, because its numbers reproduce: 13.762607917, 9 262 steps,
       x0.9 61.0044, x1.2 0.0763684.
   - **Recommended, not made** (it is shared, and other agents source it while running):
     `harness/long_drought.R` should refuse to fall back to `load_all` when `R_LIBS` is set
     but `PLANT_LIB` is not. At least, it should print which plant it loaded. A
     `TF24_Pars` that ignores unknown names also lets a misspelled or absent parameter pass.

## Notes for the PR cases

- PLANT-95 changes no resident numerics on long drought: it is bit-identical to PLANT-97,
  including under odelia 0.8.1.
- Its own-leaf invaders move `J′` by −2.5% at x0.9 and +15% at x1.2. It turns x0.7 from a
  leaf-solve failure into a run.
- No rebuild, test sweep or push was needed: no plant code changed. Commands, scripts and
  logs are under
  `/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/ldbg/`
  (`ld_trace.R`, `inv_check.R`, `out/`).
