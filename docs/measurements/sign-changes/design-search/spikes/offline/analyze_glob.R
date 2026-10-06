# The refinement kept in the mesh (glob m) beside the per-node treatments, on the
# same seven meshes and against the same converged answer.
args <- commandArgs(TRUE)
d <- readRDS(args[1]); gl <- readRDS(args[2])
res <- d$res; ref <- d$ref
g_ref <- ref$cut[["grad"]]; c1_ref <- ref$cut[["c1e2"]]
rows <- function(r, an) data.frame(arm = an,
  grad_sd = sd(r$grad), grad_maxabs = max(abs(r$grad - g_ref)),
  c3e3_sd = sd(r$c3e3), c1e2_sd = sd(r$c1e2), c3e2_sd = sd(r$c3e2),
  c1e2_maxabs = max(abs(r$c1e2 - c1_ref)))
out <- rbind(do.call(rbind, lapply(c("plain", "sub2", "sub3", "sub4", "sub8", "cut"),
                                   function(a) rows(res[res$arm == a, ], a))),
             do.call(rbind, lapply(unique(gl$arm), function(a) rows(gl[gl$arm == a, ], a))))
p <- out[out$arm == "plain", ]
out$grad_sd_rel <- out$grad_sd / p$grad_sd
out$c1e2_sd_rel <- out$c1e2_sd / p$c1e2_sd
out$c3e3_sd_rel <- out$c3e3_sd / p$c3e3_sd
print(format(out, digits = 3), row.names = FALSE)
cat(sprintf("refined steps per mesh (glob2): %s of %s\n",
            paste(gl$refined[gl$arm == "glob2"], collapse = " "),
            paste(gl$steps[gl$arm == "glob2"], collapse = " ")))
