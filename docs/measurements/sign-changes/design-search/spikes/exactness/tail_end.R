D <- readRDS("local_end.rds")
P <- D[D$method == "plain", ]; S <- D[D$method == "endpoint", ]; B <- D[D$method == "bracket", ]
for (v in c("eS", "dS", "dH")) {
  o <- order(-abs(S[[v]]))
  cat(v, ": share of endpoint's sum sq in top 10:", round(sum(S[[v]][o[1:10]]^2) / sum(S[[v]]^2), 3), "\n")
  print(data.frame(step = S$step[o[1:10]], node = S$node[o[1:10]], h_days = round(S$h[o[1:10]] * 365, 2),
                   dP = signif(S$dP[o[1:10]], 3), plain = signif(P[[v]][o[1:10]], 3), endpoint = signif(S[[v]][o[1:10]], 3),
                   bracket = signif(B[[v]][o[1:10]], 3)))
}
