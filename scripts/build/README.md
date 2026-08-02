# Build and gate assets

These lived only in a container home directory until Phase 3 and were lost every
time the container was reclaimed, while the corpus cited them by absolute path.
They are here so a gate can be re-run by someone who was not there.

| file | what it is |
|---|---|
| `Makevars-O2` | the pinned build's flags, and the whole of it. Every value gate in this project is stated against a build that used it |
| `style-sweep.sh` | the mechanical review pass `ORCHESTRATOR.md` section 7 requires before a diff lands. Reports candidates, not verdicts |
| `ff16k93.R` | the FF16 and K93 cross-model tripwire at the configuration their reference numbers belong to |

## The pinned build

```sh
cd <plant worktree> && rm -f src/*.o src/*.so
R_LIBS_USER=<your odelia library> R_MAKEVARS_USER=<abs path>/Makevars-O2 \
  Rscript -e 'pkgbuild::compile_dll(".", debug = FALSE)' 2>&1 | tee build.log
grep -c -- '-O0' build.log || true                      # must be 0; grep exits 1 on no match
grep -o "\-I'[^']*odelia[^']*'" build.log | sort -u      # must be the library you meant
```

`debug = FALSE` is required: `pkgbuild::compile_dll()` appends `-UNDEBUG -g -O0` after
your flags, so the last `-O` wins and a Makevars asking for `-O2` is silently overridden.
The same tree at `-O0` differs by 0.145% in offspring and 0.79% in accepted steps, so a
value gate that does not name its flags measures the compiler.

`rm -f src/*.o src/*.so` is correctness, not hygiene: R's make does not track header
dependencies and this core is header-inline, so a header edit compiles into only some
translation units and yields a `.so` that is a mixture — it loads fine and returns
plausible wrong numbers.

The second grep is the one that is easy to omit. `R_LIBS_USER` set for an *install* does
not tell you which library the *build* resolved, and those can differ.
