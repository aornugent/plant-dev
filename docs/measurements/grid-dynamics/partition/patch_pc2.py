p = "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/split_stepper.R"
s = open(p).read()
start = s.index('  } else if (COUPLING == "pc") {')
end = s.index('  } else if (COUPLING == "stage") {')
new = '''  } else if (COUPLING == "pc") {
    # Predictor: the held soil, and the member stages on it, each stage's hold
    # kept. Corrector (PC_ITER passes): the soil again, its uptake interpolated
    # in time between the holds of consecutive stages, so collars and members
    # both move; and the member stages again on that soil.
    o <- c(1, STAGE_BY_TIME)
    ts_ <- stage_t[o]
    up_now <- up0
    holds <- vector("list", 6)
    holds[[1]] <- held
    for (pass in 0:PC_ITER) {
      cyc <- soil_cycle(t, y[s_idx], ks, stage_t[STAGE_BY_TIME], up_now, hsub, plan[[pass + 1]])
      if (is.null(cyc)) return(NULL)
      plans[[pass + 1]] <- cyc$plan
      for (j in seq_along(STAGE_BY_TIME)) soil_at[[STAGE_BY_TIME[j]]] <- cyc$at[[j]]
      up_used <- up_now
      for (i in 2:6) {
        e <- stage_rates(i, soil_at[[i]])
        if (is.null(e)) return(NULL)
        k[[i]] <- e$k
        true_up[i, ] <- e$a
        a_h <- up_used(soil_at[[i]][1:5], stage_t[i])
        if (is.null(a_h)) return(NULL)
        defect[i, ] <- e$a - a_h
        holds[[i]] <- plant:::split_hold_tf24(patch)
        cnt$holds <- cnt$holds + 1
      }
      hs <- holds[o]
      up_now <- local({
        hs <- hs
        function(th, tt) {
          j <- min(max(findInterval(tt, ts_), 1), 5)
          w <- (tt - ts_[j]) / (ts_[j + 1] - ts_[j])
          a0 <- held_uptake(hs[[j]], nn)(th, tt)
          if (w == 0) return(a0)
          a1 <- held_uptake(hs[[j + 1]], nn)(th, tt)
          if (is.null(a0) || is.null(a1)) return(NULL)
          (1 - w) * a0 + w * a1
        }
      })
    }
'''
s = s[:start] + new + s[end:]
a = 'DEFECT <- COUPLING == "defect" || Sys.getenv("DEFECT") == "1"'
assert s.count(a) == 1
s = s.replace(a, a + '\nPC_ITER <- as.integer(Sys.getenv("PC_ITER", "1"))')
a = """#   pc      held as a predictor; then the soil again with each collar interpolated
#           in time through the predictor's stage collars, and the member stages
#           evaluated again on that soil (five more member evaluations a step)."""
b = """#   pc      held as a predictor; then the soil again with its uptake interpolated
#           in time between the holds of the predictor's stages, and the member
#           stages evaluated again on that soil (five more member evaluations a
#           step for each of PC_ITER passes)."""
assert s.count(a) == 1
s = s.replace(a, b)
open(p, "w").write(s)
print("ok")
