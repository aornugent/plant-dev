# Does the probe's crown formula match plant's own node contribution?
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap"
Sys.setenv(PLANT_LIB = file.path(A, "lib"))
source(file.path(A, "harness", "long_drought.R"))
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- 3
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(seq(0, 2.5, by = 0.25))
ct <- control(); ct$node_density_in_birth_date <- TRUE
scm <- run_scm(p, mkenv(), ct)
sp <- scm$patch$species[[1]]
st <- matrix(sp$ode_state, ncol = sp$size, dimnames = list(sp$new_node$ode_names))
s <- p$strategies[[1]]
k_I <- s$pars$k_I; eta <- s$pars$eta; a_l1 <- s$pars$a_l1; a_l2 <- s$pars$a_l2
cat("k_I", k_I, "eta", eta, "a_l1", a_l1, "a_l2", a_l2, "\n")
nodes <- sp$nodes
H <- st["height", ]; mu <- st["mortality", ]
d <- exp(-mu)  # birth rate 1
for (j in c(1, 3, 6)) {
  nd <- nodes[[j]]
  for (z in c(0, 0.3 * H[j], 0.8 * H[j], 0.97 * H[j])) {
    mine <- k_I * d[j] * (H[j] / a_l1)^(1 / a_l2) * (1 - (z / H[j])^eta)^2
    theirs <- nd$compute_competition(z)
    cat(sprintf("node %d H %.4f z %.4f: probe %.6g plant %.6g ratio %.6f\n", j, H[j], z, mine, theirs, mine / theirs))
  }
}
cat("done\n")
