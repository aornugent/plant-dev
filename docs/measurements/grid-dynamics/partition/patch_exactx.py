p = "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/split_stepper.R"
s = open(p).read()


def sub(a, b):
    global s
    assert s.count(a) == 1, a[:70]
    s = s.replace(a, b)


sub("""exact_uptake <- function(y0, t0) {
  function(th, tt) {
    y <- y0
    y[soil(y)] <- th
    cnt$sub_members <- cnt$sub_members + n_nodes(y)
    ok <- tryCatch({ patch$derivs(y, t0); TRUE }, `odelia::util::DomainError` = function(e) FALSE)
    if (!ok) return(NULL)
    tail(patch$ode_aux, 5)
  }
}""", """exact_uptake <- function(y0, t0, k0 = NULL) {
  function(th, tt) {
    y <- y0
    if (!is.null(k0)) {
      # the members carried on their rates at t0, the pools kept from emptying
      m <- members_of(y)
      y[m] <- y0[m] + (tt - t0) * k0[m]
      pool <- pool_of(y)
      y[pool] <- pmax(y[pool], 0)
    }
    y[soil(y)] <- th
    cnt$sub_members <- cnt$sub_members + n_nodes(y)
    ok <- tryCatch({ patch$derivs(y, if (is.null(k0)) t0 else tt); TRUE },
                   `odelia::util::DomainError` = function(e) FALSE)
    if (!ok) return(NULL)
    tail(patch$ode_aux, 5)
  }
}""")

sub("""  up0 <- switch(COUPLING,
                exact = exact_uptake(y, t),
                held_uptake(held, nn))""", """  up0 <- switch(COUPLING,
                exact = exact_uptake(y, t),
                exactx = exact_uptake(y, t, k1),
                held_uptake(held, nn))""")

sub("""COUPLING <- match.arg(Sys.getenv("COUPLING", "held"), c("held", "exact", "stage", "defect", "stagelin", "pc"))""",
    """COUPLING <- match.arg(Sys.getenv("COUPLING", "held"), c("held", "exact", "exactx", "stage", "defect", "stagelin", "pc"))""")

sub("""    held_up <- if (COUPLING == "exact") up0 else held_uptake(held, nn)""",
    """    held_up <- if (COUPLING %in% c("exact", "exactx")) up0 else held_uptake(held, nn)""")

sub("""  if (DEFECT && COUPLING != "exact") {""", """  if (DEFECT && !(COUPLING %in% c("exact", "exactx"))) {""")

sub("""#   exact   every member's leaf re-solved at each soil stage, the members' state
#           held at t (one full rate evaluation per soil stage);""",
    """#   exact   every member's leaf re-solved at each soil stage, the members' state
#           held at t (one full rate evaluation per soil stage);
#   exactx  exact, with the members carried on their rates at t instead of held;""")
open(p, "w").write(s)
print("ok")
