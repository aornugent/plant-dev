Sys.setenv(NODES = "108", TOL = "3e-5", ATOL = "1e-4", METHOD = "ck")
source("/home/user/plant-dev/.claude/worktrees/agent-a4e5afe75b72479f0/harness/ark_prototype.R")
cat("control a_y", ct$ode_a_y, "a_dydt", ct$ode_a_dydt, "hmin", ct$ode_step_size_min, "hmax", ct$ode_step_size_max, "h0", ct$ode_step_size_initial, "\n")
print(names(env))
e2 <- patch$environment
print(class(e2))
print(names(e2))
print(names(patch))
patch$introduce_new_node(1L, times[1])
y <- patch$ode_state
cat("ode size", length(y), "\n")
print(y)
r <- patch$derivs(y, 0)
print(r)
aux <- patch$ode_aux
cat("aux length", length(aux), "\n")
print(aux)
sp <- patch$species[[1]]
print(names(sp))
nn <- sp$new_node
print(class(nn))
print(names(nn))
ind <- nn$individual
print(names(ind))
print(ind$aux_names)
print(ind$internals$auxs)
