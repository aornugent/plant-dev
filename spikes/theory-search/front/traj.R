a <- readRDS(sprintf("/tmp/front/%s_an.rds", Sys.getenv("CASE", "closed")))
d <- a$d
options(width = 220)
nodes <- as.integer(strsplit(Sys.getenv("NODES", "1,5,13,21"), ",")[[1]])
for (n in nodes) {
  z <- d[d$node == n, ]; z <- z[order(z$time), ]
  z$A_plant <- NA
  cat("\n== node", n, "\n")
  k <- seq(1, nrow(z), by = as.integer(Sys.getenv("BY", "2")))
  print(data.frame(t = z$time, h = z$height, P = z$net_mass_production_dt, assim = z$assimilation,
                   r = z$r, mu = z$mu, M = z$mortality, Smax = z$Smax,
                   PoverS = z$net_mass_production_dt / z$Smax, fec = z$offspring_produced_survival_weighted)[k, ],
        digits = 3, row.names = FALSE)
}
