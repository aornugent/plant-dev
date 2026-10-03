# A short test of the driver's STAGE_LOG: the first introductions' steps under
# DP at 1e-4, then the run's closing summary on the partial logs.
#   (from a snapshot dir holding harness/) PLANT_LIB=... METHOD=dp TOL=1e-4 NODES=108 ATOL=1e-4 \
#     STAGE_LOG=x.rds Rscript harness/stage_log_test.R
source("harness/ark_prototype.R")
sv$t <- 0; sv$h_last <- ct$ode_step_size_initial; sv$r_set <- sv$f_set <- NA_real_; sv$zone_until <- -Inf; sv$Pdot <- numeric()
for (k in 1:6) {
  patch$introduce_new_node(1L, times[k])
  sv$y <- patch$ode_state; sv$dydt <- rates(sv$y, sv$t); sv$P <- production(sv$y)
  sv$Pdot <- c(sv$Pdot, 0)[seq_along(sv$P)]; sv$K <- klass(sv$y)
  t_end <- times[k + 1]
  for (target in c(pulses[pulses > sv$t & pulses < t_end], t_end)) while (sv$t < target) step(target)
}
att <- as.data.frame(do.call(rbind, stage_log$att))
neg <- if (length(stage_log$neg)) as.data.frame(do.call(rbind, stage_log$neg)) else NULL
stopifnot(nrow(att) == attempt_log$k)
cat(sprintf("%d attempts to t = %.3f; %d stage states with a negative pool; raised %d; head of the attempt rows:\n",
            nrow(att), sv$t, sum(att$neg_stages), sum(!is.na(att$raised_at))))
print(head(att, 3))
if (!is.null(neg)) print(head(neg, 3))
