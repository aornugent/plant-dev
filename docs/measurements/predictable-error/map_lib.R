# Shared readers for the drop map's scoring: nodal data, the own part of a
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib", .libPaths()))
# drop from P alone, the map's per-panel field part, the measured split.
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap"
D <- dirname(dirname(A))
source("/home/user/plant-dev/harness/node_parts.R")  # nodes_of, panel_moves
rd <- function(f) if (file.exists(f)) readRDS(f)
run <- function(name) rd(file.path(A, "runs", paste0(name, ".rds")))
eps <- c(lnJ = 0.025, lma = 0.0865, a_dG2 = 0.0190)
eps_inv <- c(lnJ = 0.025, lma = 0.20, a_dG2 = 0.050)

nodes_from <- function(birth, w, nrr) {
  patches <- plant::Weibull_Disturbance_Regime(40)
  m <- min(length(w), length(nrr))
  data.frame(birth = birth[1:m], w = w[1:m], nrr = nrr[1:m],
             offspring = nrr[1:m] * vapply(birth[1:m], patches$density, 0))
}
nd <- function(x, nodes = x$stand$nodes)
  nodes_from(nodes$birth, nodes$establishment, nodes$nrr)

# Per dropped node of P (1-based index j into P's nodes): the own part of
# D = Q(C) - Q(P) in J units, -w_j (f_j - (1-l) f_{j-1} - l f_{j+1}).
own_drop <- function(b, dropped) {
  j <- dropped
  l <- (b$birth[j] - b$birth[j - 1]) / (b$birth[j + 1] - b$birth[j - 1])
  -b$w[j] * (b$offspring[j] - (1 - l) * b$offspring[j - 1] - l * b$offspring[j + 1])
}
# The map: per dropped node, the field part of D in J units (light, soil).
field_drop <- function(x) list(light = colSums(x$light), soil = colSums(x$soil))

# One map run P against its coarsening C (a run with nodes): totals as fractions
# of J, and per panel. The census J and sum(w * offspring) differ by a constant
# factor, so each part is taken over its own normaliser.
score_pair <- function(xP, xC) {
  b <- nd(xP); a <- nd(xC)
  JnP <- sum(b$w * b$offspring); JnC <- sum(a$w * a$offspring)
  pm <- panel_moves(a, b)
  own <- own_drop(b, xP$dropped) / JnP
  f <- field_drop(xP)
  field <- (f$light + f$soil) / xP$stand$J
  D <- log(xC$stand$J) - log(xP$stand$J)
  list(D = D, meas_field = -sum(pm$field) / JnC, meas_own = -sum(pm$interpolation) / JnC,
       meas_est = -sum(pm$establishment) / JnC,
       own = sum(own), field = sum(field), light = sum(f$light) / xP$stand$J,
       soil = sum(f$soil) / xP$stand$J, own_p = own, field_p = field,
       birth_p = b$birth[xP$dropped], pm = pm)
}
fmt <- function(v, d = 5) sprintf(paste0("%+.", d, "f"), v)
