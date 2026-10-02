p = "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/split_stepper.R"
s = open(p).read()


def sub(a, b):
    global s
    assert s.count(a) == 1, a[:70]
    s = s.replace(a, b)


sub("""LEGS <- as.integer(Sys.getenv("LEGS", "0"))
""", """LEGS <- as.integer(Sys.getenv("LEGS", "0"))
# MONO=1 runs the driver's own monolithic Cash-Karp step instead, and
# UPTAKE_SCALE scales the uptake the soil loses in it (the stand's transpiration
# unchanged), for J's sensitivity to the water budget.
MONO <- Sys.getenv("MONO") == "1"
UPTAKE_SCALE <- as.numeric(Sys.getenv("UPTAKE_SCALE", "1"))
if (UPTAKE_SCALE != 1) {
  rates_unscaled <- rates
  rates <- function(y, t) {
    r <- rates_unscaled(y, t)
    if (is.null(r)) return(NULL)
    a <- tail(patch$ode_aux, 5)
    i <- soil(y)
    th <- y[i]
    r[i] <- ifelse(th <= 1e-2 & !(r[i] > 0), r[i], r[i] + (1 - UPTAKE_SCALE) * a / (env$depth / 5))
    r[length(y) - 1] <- r[length(y) - 1] - (1 - UPTAKE_SCALE) * sum(a)
    r
  }
}
""")

sub("""    if (CHECK) {
      # the monolithic steps of this leg, checking the chain at each start""",
    """    if (MONO) {
      for (target in c(pulses[pulses > sv$t & pulses < t_end], t_end)) {
        while (sv$t < target) step(target)
      }
      next
    }
    if (CHECK) {
      # the monolithic steps of this leg, checking the chain at each start""")
open(p, "w").write(s)
print("ok")
