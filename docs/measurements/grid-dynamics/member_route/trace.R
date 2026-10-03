# One member's step, stage by stage: the pool's fill, the mortality state and its
# rate, and the log density plant checks, at each stage and at the end, beside the
# reference's end state.
#   PLANT_LIB=$DEV/lib_guard [REC=ld_ruleA] INVADER=lma=2 NODE=45 T0=32.37080 \
#     HD=22 METHOD=dp Rscript trace.R
INVADER <- Sys.getenv("INVADER", "lma=2")
Sys.setenv(INVADERS = INVADER)
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/spike_methods/snap/spike_lib.R")
P1 <- readRDS(file.path(S, Sys.getenv("PASS1", paste0("pass1_", REC, ".rds"))))
key <- function(t) sprintf("%.10f", t)
NODE <- as.integer(Sys.getenv("NODE"))
HD <- as.numeric(Sys.getenv("HD", "22"))
i_ref <- match(INVADER, P1$invaders)
# the start as the reference pass saved it: the nearest saved start
t0 <- P1$starts$t0[which.min(abs(P1$starts$t0 - as.numeric(Sys.getenv("T0"))))]
m <- match(NODE, P1$members[[i_ref]]$node)
y0 <- P1$saved[[key(t0)]][[i_ref]][, m]
yr <- P1$saved[[key(t0 + HD * DAY)]][[i_ref]][, m]
reset_invader(1, P1$members[[i_ref]]$birth[m], NODE)
Y0 <- list(matrix(y0, 7))
rates_fn <- function(tau, Yx, fld = NULL) rates_at(tau, Yx, fld)
fld0 <- field_at(t0)
K0 <- rates_at(t0, Y0, fld0)
h <- HD * DAY
for (meth in strsplit(Sys.getenv("METHOD", "ck,dp,tsit,ssprk,rodas"), ",")[[1]]) {
  res <- switch(meth,
                ck = step_erk(TABLEAU$ck, t0, h, Y0, K0, rates_fn),
                dp = step_erk(TABLEAU$dp, t0, h, Y0, K0, rates_fn),
                tsit = step_erk(TABLEAU$tsit, t0, h, Y0, K0, rates_fn),
                ssprk = step_ssprk(t0, h, Y0, K0, rates_fn),
                rodas = step_rodas(t0, h, Y0, K0, rates_fn, rodas_prep(t0, Y0, K0, rates_fn, fld0)))
  Kend <- rates_at(t0 + h, res$Y1)
  cat(sprintf("\n%s, %s member %d (born %.3f), t0 %.5f, %g days; tau_eff from -1/J_SS needs steps.R\n", meth,
              INVADER, NODE, P1$members[[i_ref]]$birth[m], t0, HD))
  tab <- data.frame(stage = c(seq_along(res$Ys), "end", "reference"), c = c(res$cs, 1, 1),
                    r = c(vapply(res$Ys, function(z) z[[1]][I_STORE, 1] / capacity(1, max(z[[1]][1, 1], 0)), 0),
                          res$Y1[[1]][I_STORE, 1] / capacity(1, res$Y1[[1]][1, 1]), yr[I_STORE] / capacity(1, yr[1])),
                    mortality = c(vapply(res$Ys, function(z) z[[1]][I_MORT, 1], 0), res$Y1[[1]][I_MORT, 1], yr[I_MORT]),
                    mort_rate = c(vapply(res$Kl, function(z) z[[1]][I_MORT, 1], 0), Kend[[1]][I_MORT, 1], NA),
                    offspring = c(vapply(res$Ys, function(z) z[[1]][I_OFF, 1], 0), res$Y1[[1]][I_OFF, 1], yr[I_OFF]),
                    height = c(vapply(res$Ys, function(z) z[[1]][1, 1], 0), res$Y1[[1]][1, 1], yr[1]))
  tab$log_density <- log(birth_rate(1, t0)) - tab$mortality
  print(tab, row.names = FALSE, digits = 4)
}
