# The recruitment window is where the forward model diverges.  Decompose the
# disagreement there into the part caused by the probe diluting the reserve
# fraction (A - B) and the part that is genuinely the missing along-curve
# storage term (B - C).
source("probes/lib.R"); suppressMessages(library(dplyr))
setwd("/home/user/plant-dev")

p  <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
s1 <- p$strategies[[1]]
h0 <- TF24_Individual(s1)$state("height")
scm <- scm_collect(p, "TF24")
times <- vapply(seq_along(scm$history), function(k) scm$history[[k]]$time, 0)
sel <- which(times > 0.5 & times < 15)
sel <- unique(c(sel, round(seq(max(sel)+1, length(times), length.out = 12))))
cat("sweeping", length(sel), "patches, t in [", round(min(times[sel]),3), ",",
    round(max(times[sel]),1), "]\n")
d <- bind_rows(lapply(sel, function(k) patch_operators(scm$history[[k]], s1, h0, TRUE)))
saveRDS(d, "probes/out/window-TF24.rds")

i <- d |> filter(node < max(node), is.finite(C), is.finite(A), dh > 0)
i$dilution <- i$A - i$B          # probe artefact: reserve fraction diluted by the perturbation
i$missing  <- i$B - i$C          # genuine along-curve storage term not in any partial
i$total    <- i$A - i$C

cat("\n=== decomposition of the disagreement (interior nodes) ===\n")
i$era <- cut(i$time, c(0.5, 1, 2, 3, 4, 6, 10, 15, Inf))
print(as.data.frame(i |> group_by(era) |> summarise(n = n(),
    med_A = median(A), med_B = median(B), med_C = median(C),
    med_dilution = median(dilution), med_missing = median(missing),
    frac_dilution = median(abs(dilution)) / median(abs(dilution) + abs(missing)),
    corCA = cor(C, A), corCB = cor(C, B), .groups = "drop")), digits = 3)

cat("\n=== overall shares of |A - C| ===\n")
cat(sprintf("sum|A-C| = %.4g   sum|A-B| (dilution) = %.4g   sum|B-C| (missing) = %.4g\n",
            sum(abs(i$total)), sum(abs(i$dilution)), sum(abs(i$missing))))
cat(sprintf("dilution accounts for %.1f%% of the total absolute disagreement\n",
            100*sum(abs(i$dilution))/(sum(abs(i$dilution))+sum(abs(i$missing)))))

cat("\n=== gap closing and folds (interior pairs only) ===\n")
low <- i$node == ave(i$node, i$time, FUN = max)
q  <- i[!low, ]
q$close <- q$gb - q$g                       # >0 means the gap is shrinking
cat(sprintf("interior pairs=%d  shrinking=%.3f  min dh=%.4g  frac dh<1e-4=%.3f\n",
            nrow(q), mean(q$close > 0), min(q$dh), mean(q$dh < 1e-4)))
sh <- q[q$close > 0, ]
tt <- sh$dh / sh$close
cat(sprintf("shrinking pairs=%d  time-to-fold: min=%.4g yr  1%%ile=%.4g  median=%.4g\n",
            nrow(sh), min(tt), quantile(tt, .01), median(tt)))
cat(sprintf("pairs that would fold within the remaining patch lifetime (105.3-t): %d (%.3f)\n",
            sum(tt < (105.32 - sh$time)), mean(tt < (105.32 - sh$time))))
