# Dropping the tail edges: do the moves go toward the reference? Per quantity, |err| with
# and without, and the move against minus the base error.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
for (case in c("dry", "episodic")) { ref <- reference(case); b <- quantities(readRDS(file.path(AR, sprintf("val_c5g_c_%s.rds", case))))
  x <- quantities(readRDS(file.path(AR, sprintf("val_probe_noedge_%s.rds", case)))); k <- Reduce(intersect, list(names(ref), names(b), names(x))); e <- eps_vec(k)
  eb <- (b[k] - ref[k]) / e; ex <- (x[k] - ref[k]) / e; mv <- ex - eb; big <- abs(mv) > 0.1
  cat(sprintf("%-9s moves over 0.1: %d; toward the reference %d of them; corr(move, -base error) %.2f; rms error %.3f -> %.3f\n",
    case, sum(big), sum(abs(ex[big]) < abs(eb[big])), cor(mv, -eb), sqrt(mean(eb^2)), sqrt(mean(ex^2))))
  o <- order(-abs(mv))[1:6]; print(round(rbind(base = eb[o], noedge = ex[o]), 2)) }
