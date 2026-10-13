# Composition of the leader's committed and check schedules: nodes and rows by region.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
env <- new.env(); sys.source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/search/any/structure/c05_graded.R", env)
for (cs in names(CASES)) { cd <- prepare(cs); p <- cd$pilot; h <- env$hfun_of(p); Sc <- build_graded(p, h)
  mid <- (head(Sc, -1) + Sc[-1]) / 2; wide <- diff(Sc) > 0.5 * vapply(mid, h, 0) + 1e-9
  Sf <- sort(unique(round(c(Sc, mid[wide & p$shut(mid) < 0.5]), 10)))
  co <- coef(cd$rowsfit); rows <- function(S) co[1] * length(S) + co[2] * sum(H - S)
  isedge <- function(S) vapply(S, function(s) min(abs(p$edges - s)) < 1e-6, TRUE)
  reg <- function(S) cut(S, c(-1, p$b1 - 1e-9, 20, 40))
  part <- function(S) { r <- co[1] + co[2] * (H - S); c(tapply(r[!isedge(S)], reg(S)[!isedge(S)], sum), edges = sum(r[isedge(S)])) / rows(S) }
  pc <- part(Sc); pf <- part(Sf); pc[is.na(pc)] <- 0
  # truncation at 34.5 under the rows model
  tr <- function(S, T) (co[1] * sum(S < T) + co[2] * sum(pmax(0, T - S))) / rows(S)
  cat(sprintf("%-13s n_c %d (edges %d, window %d) n_f %d  Cf/Cc %.2f | Cc rows share: window %.2f b1-20 %.2f >20 %.2f edges %.2f | check extra rows by region: window %.2f b1-20 %.2f >20 %.2f | rows-model keep at T=34.5 %.2f\n",
    cs, length(Sc), sum(isedge(Sc)), sum(Sc < p$b1), length(Sf), rows(Sf) / rows(Sc), pc[1], pc[2], pc[3], pc[4],
    (rows(Sf)*pf[1]-rows(Sc)*pc[1])/(rows(Sf)-rows(Sc)), (rows(Sf)*pf[2]-rows(Sc)*pc[2])/(rows(Sf)-rows(Sc)), (rows(Sf)*pf[3]-rows(Sc)*pc[3])/(rows(Sf)-rows(Sc)), tr(Sc, 34.5))) }
