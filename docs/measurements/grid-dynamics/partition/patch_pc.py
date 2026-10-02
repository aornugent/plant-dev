p = "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/split_stepper.R"
s = open(p).read()


def sub(a, b):
    global s
    assert s.count(a) == 1, a[:70]
    s = s.replace(a, b)


sub("""#   defect  held, then the soil's end corrected by the stages' quadrature of the
#           uptake each member stage evaluated against the held uptake there.
#""", """#   defect  held, then the soil's end corrected by the stages' quadrature of the
#           uptake each member stage evaluated against the held uptake there;
#   stagelin stage, each node's collar extrapolated linearly in time from its last
#           two values (the previous step's start and this one's, then stage by
#           stage);
#   pc      held as a predictor; then the soil again with each collar interpolated
#           in time through the predictor's stage collars, and the member stages
#           evaluated again on that soil (five more member evaluations a step).
# DEFECT=1 adds defect's correction to stage, stagelin or pc.
#""")

sub("""COUPLING <- match.arg(Sys.getenv("COUPLING", "held"), c("held", "exact", "stage", "defect"))""",
    """COUPLING <- match.arg(Sys.getenv("COUPLING", "held"), c("held", "exact", "stage", "defect", "stagelin", "pc"))
DEFECT <- COUPLING == "defect" || Sys.getenv("DEFECT") == "1\"""")

sub("""# Every member's leaf re-solved at layer moisture th, the members at y0, time t0.""",
    """# The held uptake with each collar a function of time.
timed_uptake <- function(held, nodes, collar_at) {
  function(th, tt) held_uptake(held, nodes, collar_at(tt))(th, tt)
}
# Every member's leaf re-solved at layer moisture th, the members at y0, time t0.""")

sub("""  hsub <- sub$h
  if (COUPLING == "stage") {""", """  hsub <- sub$h
  if (COUPLING == "stagelin") {
    # As stage, with each node's collar carried on its trend: from the previous
    # step's start to t for [0, .2], then between the last two stages reached.
    hold <- held
    s <- y[s_idx]; tt <- t
    Cb <- plant:::split_collars_tf24(held); tb_ <- t
    Ca <- if (!is.null(sv$held_prev)) plant:::split_collars_tf24(sv$held_prev) else NULL
    slope <- if (length(Ca) == length(Cb) && sv$t_prev < t) (Cb - Ca) / (t - sv$t_prev) else 0 * Cb
    line <- function(Cb, tb_, slope) function(x) Cb + (x - tb_) * slope
    kss <- ks
    for (i in 2:4) {
      cyc <- soil_cycle(tt, s, kss, stage_t[i], timed_uptake(hold, nn, line(Cb, tb_, slope)), hsub, plan[[i - 1]])
      if (is.null(cyc)) return(NULL)
      plans[[i - 1]] <- cyc$plan
      s <- cyc$at[[1]]; tt <- stage_t[i]; hsub <- cyc$h
      soil_at[[i]] <- s
      e <- stage_rates(i, s)
      if (is.null(e)) return(NULL)
      k[[i]] <- e$k
      true_up[i, ] <- e$a
      a_h <- timed_uptake(hold, nn, line(Cb, tb_, slope))(s[1:5], stage_t[i])
      if (is.null(a_h)) return(NULL)
      defect[i, ] <- e$a - a_h
      hold <- plant:::split_hold_tf24(patch)
      cnt$holds <- cnt$holds + 1
      Cn <- plant:::split_collars_tf24(hold)
      slope <- (Cn - Cb) / (stage_t[i] - tb_); Cb <- Cn; tb_ <- stage_t[i]
      kss <- soil_rates(s, tt, e$a)
    }
    cyc <- soil_cycle(tt, s, kss, stage_t[c(6, 5)], timed_uptake(hold, nn, line(Cb, tb_, slope)), hsub, plan[[4]])
    if (is.null(cyc)) return(NULL)
    plans[[4]] <- cyc$plan
    soil_at[[6]] <- cyc$at[[1]]; soil_at[[5]] <- cyc$at[[2]]
    for (i in 5:6) {
      e <- stage_rates(i, soil_at[[i]])
      if (is.null(e)) return(NULL)
      k[[i]] <- e$k
      true_up[i, ] <- e$a
      a_h <- timed_uptake(hold, nn, line(Cb, tb_, slope))(soil_at[[i]][1:5], stage_t[i])
      if (is.null(a_h)) return(NULL)
      defect[i, ] <- e$a - a_h
    }
  } else if (COUPLING == "pc") {
    # Predictor: the held soil, and the member stages on it, each stage's collars
    # kept.
    cyc <- soil_cycle(t, y[s_idx], ks, stage_t[STAGE_BY_TIME], up0, hsub, plan[[1]])
    if (is.null(cyc)) return(NULL)
    plans[[1]] <- cyc$plan
    for (j in seq_along(STAGE_BY_TIME)) soil_at[[STAGE_BY_TIME[j]]] <- cyc$at[[j]]
    C <- matrix(0, 6, nn + 1)
    C[1, ] <- plant:::split_collars_tf24(held)
    for (i in 2:6) {
      e <- stage_rates(i, soil_at[[i]])
      if (is.null(e)) return(NULL)
      k[[i]] <- e$k
      C[i, ] <- plant:::split_collars_tf24(plant:::split_hold_tf24(patch))
      cnt$holds <- cnt$holds + 1
    }
    # Corrector: the soil again, each collar piecewise linear in time through
    # the stages', and the member stages again on it.
    o <- c(1, STAGE_BY_TIME)
    ts_ <- stage_t[o]; Cs <- C[o, , drop = FALSE]
    collar_at <- function(x) {
      j <- min(max(findInterval(x, ts_), 1), 5)
      w <- (x - ts_[j]) / (ts_[j + 1] - ts_[j])
      (1 - w) * Cs[j, ] + w * Cs[j + 1, ]
    }
    cyc <- soil_cycle(t, y[s_idx], ks, stage_t[STAGE_BY_TIME], timed_uptake(held, nn, collar_at), hsub, plan[[2]])
    if (is.null(cyc)) return(NULL)
    plans[[2]] <- cyc$plan
    for (j in seq_along(STAGE_BY_TIME)) soil_at[[STAGE_BY_TIME[j]]] <- cyc$at[[j]]
    for (i in 2:6) {
      e <- stage_rates(i, soil_at[[i]])
      if (is.null(e)) return(NULL)
      k[[i]] <- e$k
      true_up[i, ] <- e$a
      a_h <- timed_uptake(held, nn, collar_at)(soil_at[[i]][1:5], stage_t[i])
      if (is.null(a_h)) return(NULL)
      defect[i, ] <- e$a - a_h
    }
  } else if (COUPLING == "stage") {""")

sub("""  if (COUPLING == "defect") {""", """  if (DEFECT && COUPLING != "exact") {""")

sub("""    sv$y <- a$y
    sv$dydt <- a$rates
    sv$P <- a$P
    sv$K <- a$K
    sv$held <- a$held
    return(invisible())""", """    sv$held_prev <- sv$held
    sv$t_prev <- t0
    sv$y <- a$y
    sv$dydt <- a$rates
    sv$P <- a$P
    sv$K <- a$K
    sv$held <- a$held
    return(invisible())""")

sub("""        sv$t <- program$time[i]
        sv$y <- a$y; sv$dydt <- a$rates; sv$P <- a$P; sv$K <- a$K; sv$held <- a$held
""", """        sv$held_prev <- sv$held
        sv$t_prev <- sv$t
        sv$t <- program$time[i]
        sv$y <- a$y; sv$dydt <- a$rates; sv$P <- a$P; sv$K <- a$K; sv$held <- a$held
""")

sub("""    sv$held <- plant:::split_hold_tf24(patch)
    cnt$holds <- cnt$holds + 1
    sv$P <- production(sv$y)""", """    sv$held <- plant:::split_hold_tf24(patch)
    sv$held_prev <- NULL
    sv$t_prev <- -Inf
    cnt$holds <- cnt$holds + 1
    sv$P <- production(sv$y)""")
open(p, "w").write(s)
print("ok")
