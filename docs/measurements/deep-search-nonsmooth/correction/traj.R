# traj.R: round4/JT/probe.R's pinned forward with the trajectory kept, run as is except
# that TRAIT_REL=name=rel sets a trait whose value is 0 to rel (an absolute step), so
# every scored trait can be perturbed. Env as probe.R (PIN TOL LIB OUT TRAIT_REL SAVETRAJ STOPONLY).
src <- readLines("/home/user/plant-dev/docs/measurements/schedule-search/round4/JT/probe.R")
old <- "st_$pars[[kv[1]]] * (1 + as.numeric(kv[2]))"
new <- "(function(v, r) if (v == 0) r else v * (1 + r))(st_$pars[[kv[1]]], as.numeric(kv[2]))"
i <- grep(old, src, fixed = TRUE); stopifnot(length(i) == 1)
src[i] <- sub(old, new, src[i], fixed = TRUE)
eval(parse(text = src))
