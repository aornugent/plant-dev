---
name: systematic-debugging
description: Find the root cause of a bug, test failure, build or load error, or unexpected number before changing any code. Use whenever something in the packages fails or misbehaves, including after a fix attempt didn't work.
---

# Systematic debugging

A fix made before you know the cause treats a symptom. In these packages, a symptom fix is worse than none. The numbers usually stay plausible, so a wrong fix hides the real fault, and the next person debugs both. Find the cause first, then make one change that removes it.

Work through the four phases in order. Each phase ends with something written down: the reproduction, the difference, the hypothesis, the test. If you can't write it, you haven't finished the phase.

## 1. Find the cause

- **Read the whole error.** That means the full message, the R traceback (`traceback()`, or `options(error = recover)` to stop in the failing frame), and every warning above it. In this workspace, many failures name something far from their cause:
  - An `undefined symbol` or a "symbol not found" naming an untouched accessor usually means stale object files. Run `rm -f src/*.o src/*.so` and rebuild before anything else.
  - Under `load_all("odelia")`, an `undefined symbol: …xad4Tape…` means odelia needs a real install (see AGENTS.md).
  - `attempt to use zero-length variable name` from testthat means parallel workers under `load_all()`. Set `TESTTHAT_PARALLEL=false`.
- **Reproduce it in the smallest form.** One `testthat::test_file()`, or a few lines of R against `load_all()`. If it doesn't reproduce every time, gather more evidence before guessing. Note the seed, the build flags (`-O0` and `-O2` round differently), and the platform, because the golden files are bit-exact on one platform only.
- **Check what changed.** Look at `git diff`, the recent commits in every package involved (a submodule pointer move is a change), and which installed build R actually loaded (`find.package()`). If it worked before, `git bisect` finds the commit that broke it faster than reading does.
- **Trace across the boundary.** A wrong number reaching R usually started earlier: in C++, or in another package. Trace it backward: where was the bad value produced, what called that with what input, and so on until you reach the place where a correct input became a wrong output. Fix it there, not where it surfaced.
  - For crashes in compiled code, run R under a debugger (`R -d lldb` or `R -d gdb`).
  - For memory errors, use `R -d valgrind`. Note that valgrind cannot see a dangling expression template from a deduced `auto` return; see plant's guide on active scalars.

## 2. Compare with something that works

Find the nearest working case: the same model at another parameter, FF16 where TF24 fails, the double path where the active one fails, the previous commit. List every difference between it and the failing case, including the ones that "can't matter". Read the reference implementation in full, not in parts, before you assume you know how it differs.

## 3. Test one hypothesis

Write down one hypothesis: "X is the cause, because Y." Then make the smallest change that would confirm or refute it, and change one thing at a time. If it's refuted, form a new hypothesis from what you learned. Don't stack a second change on the first.

If you don't understand something, say so plainly and say what you'd need to find out. A guess presented as a finding costs the reader more than an admitted gap.

## 4. Fix the cause, with a test

1. Write the test that fails because of the bug, in the package's test file for that component, before the fix. Tests land with the change, not after it.
2. Make one change that removes the cause. Don't bundle a refactor or a "while I'm here" improvement into the fix; the reviewer can't then tell which change fixed it.
3. Run the component's test file, and the FF16 bit-identity guard if numerics could have moved (AGENTS.md → Testing plant). Confirm the original reproduction is gone, not just that the new test passes.

**If a fix doesn't work, go back to phase 1 with what it taught you.** If three fixes have failed, stop fixing. Repeated failures that each reveal a problem somewhere new mean the design is wrong, not the latest line. Say so to the user, and treat the next step as a design question (the system-design skill), not a fourth fix.

## When the cause is outside the code

Sometimes the cause really is environmental: a platform's libm, a runner's clock, an install that R picked up from the site library. Write down what you checked and how you ruled out the code. Then handle it where the environment enters, for example with the golden files' `--cross-platform` tolerance or a check of `find.package()`. Most "no root cause" conclusions are incomplete investigations, so be sure you have checked before concluding this.

## Signs you are guessing

You are guessing if you notice any of these:
- you're about to try a change "to see if it helps"
- you're making several changes before running anything
- you're widening a tolerance to make a test pass
- you're re-recording a golden file or a reference result to make a failure go away
- you're proposing fixes before you can say where the bad value first appears

Each means returning to phase 1. Re-recording a baseline is a result, not a fix. Do it only when the change in numbers is intended, and say by how much it moved.

---

*Adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/systematic-debugging) (MIT; see `LICENSE`). The original's defense-in-depth technique is not included: it adds validation at every layer, which these packages' principles reject in favour of stating an invariant once, at its owning boundary.*
