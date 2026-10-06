# Spread over the seven meshes, per treatment: gradient and curvatures, against
# the converged answer; and the treatment's extra ratings per node step.
args <- commandArgs(TRUE)
d <- readRDS(args[1])
res <- d$res; ref <- d$ref
g_ref <- ref$cut[["grad"]]; c1_ref <- ref$cut[["c1e2"]]; c3_ref <- ref$cut[["c3e2"]]
cat(sprintf("reference (cut, %d steps): lnJ %.10f grad %.6f c1e2 %.4f c3e2 %.4f; plain on it: grad %.6f\n",
            ref$steps, ref$cut[["lnJ"]], g_ref, c1_ref, c3_ref, ref$plain[["grad"]]))
out <- do.call(rbind, lapply(split(res, res$arm), function(r) {
  data.frame(arm = r$arm[1],
             grad_range = diff(range(r$grad)), grad_sd = sd(r$grad),
             grad_err = mean(r$grad) - g_ref, grad_maxabs = max(abs(r$grad - g_ref)),
             c3e3_sd = sd(r$c3e3), c1e2_sd = sd(r$c1e2), c3e2_sd = sd(r$c3e2),
             c1e2_err = mean(r$c1e2) - c1_ref,
             lnJ_err = mean(r$lnJ) - ref$cut[["lnJ"]],
             treated_share = mean(r$treated / r$node_steps),
             sign_share = mean(r$sign_steps / r$node_steps),
             extra_per_node_step = mean(r$extra / r$node_steps))
}))
ord <- c("plain", "sub2", "sub3", "sub4", "sub8", "cut", "glob2", "glob3")
out <- out[match(ord, out$arm), ]
p <- out[out$arm == "plain", ]
out$grad_sd_vs_plain <- out$grad_sd / p$grad_sd
out$c1e2_sd_vs_plain <- out$c1e2_sd / p$c1e2_sd
out$c3e3_sd_vs_plain <- out$c3e3_sd / p$c3e3_sd
print(format(out, digits = 3), row.names = FALSE)
