# q4_panels.R: layout D on the 18 pilots. Per case: nodes (D, D with late opening edges
# out, E6 committed), panels with 0 and 1 interior nodes and their J and establishment
# shares, the parity hole (panels with an even interior count: one breakpoint-side
# interval the alternate drop never merges), the drop's rows over the run's, and the
# share of panels whose count does not move when rho is scaled by 1.25.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/layout.R")
out <- list()
for (cs in c(BANK, HELD)) {
  px <- pilot_run(cs); p <- pilot_of(cs); h <- alg$hfun_of(p); st <- px$times
  D <- layout_D(cs, 1, p, px, h); Dl <- layout_D(cs, 1, p, px, h, late = FALSE); D2 <- layout_D(cs, 1.25, p, px, h)
  P <- D$panels; e6 <- E6_c(cs)
  r_run <- rows_model(D$S, st); r_drop <- rows_model(setdiff(D$S, D$drop), st)
  even <- P$n_interior > 0 & P$n_interior %% 2 == 0
  out[[cs]] <- data.frame(case = cs, nodes_D = length(D$S), nodes_Dlate_out = length(Dl$S), nodes_E6 = if (is.null(e6)) NA else length(e6),
    rows_D_over_E6 = if (is.null(e6)) NA else r_run / rows_model(e6, st), panels = nrow(P),
    p0 = sum(P$n_interior == 0), p1 = sum(P$n_interior == 1), share_lt2 = mean(P$n_interior < 2),
    J_p0 = sum(P$Jsh[P$n_interior == 0]), J_lt2 = sum(P$Jsh[P$n_interior < 2]), E_lt2 = sum(P$Esh[P$n_interior < 2]),
    even = sum(even), J_even = sum(P$Jsh[even]), drop_rows = r_drop / r_run,
    stuck_125 = mean(D2$panels$n_int == P$n_int), stuck_125_J = sum(P$Jsh[D2$panels$n_int == P$n_int]),
    max_panel_days = max(P$days), max_int_days = max(diff(D$S)) * 365)
  saveRDS(D, file.path(SC, "evidence", sprintf("layoutD_%s.rds", cs)))
}
tab <- do.call(rbind, out); print(format(tab, digits = 3), row.names = FALSE)
saveRDS(tab, file.path(SC, "evidence", "q4_panels.rds"))
