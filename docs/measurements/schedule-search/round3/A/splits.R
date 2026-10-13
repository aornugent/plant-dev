# Splitting each node's step at sign changes, against a 5% tolerance nudge, on the
# 6 October bank (108 nodes, tolerance 1e-4 and 1.05e-4). In eps; rooting_depth_max aside.
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
B <- file.path(DEV, "bank/runs")
q <- function(n) { x <- readRDS(file.path(B, paste0(n, ".rds"))); if (is.null(x$stand$elasticity) || !all(is.finite(x$stand$elasticity))) NULL else quantities(x) }
mv <- function(a, b) { qa <- q(a); qb <- q(b); if (is.null(qa) || is.null(qb)) return(NULL); k <- setdiff(intersect(names(qa), names(qb)), "rooting_depth_max"); (qb[k] - qa[k]) / eps_vec(k) }
st <- function(m) if (is.null(m)) "  n/a" else sprintf("rms %.3f max %.3f (%s)", sqrt(mean(m^2)), max(abs(m)), names(m)[which.max(abs(m))])
for (r in c("dry", "epi", "ld", "wet", "const")) {
  sp <- mv(paste0(r, "_plain"), paste0(r, "_split")); sn <- mv(paste0(r, "_nplain"), paste0(r, "_nsplit"))
  np <- mv(paste0(r, "_plain"), paste0(r, "_nplain")); ns <- mv(paste0(r, "_split"), paste0(r, "_nsplit"))
  c1 <- if (!is.null(sp) && !is.null(sn)) cor(sp, sn[names(sp)]) else NA
  cat(sprintf("%-6s split-plain at 1e-4: %s | at 1.05e-4: %s | corr %.2f\n       nudge plain: %s | nudge split: %s\n", r, st(sp), st(sn), c1, st(np), st(ns))) }
