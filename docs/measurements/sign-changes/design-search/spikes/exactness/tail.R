D <- readRDS("local.rds")
P <- D[D$method == "plain", ]; S <- D[D$method == "smooth", ]; B <- D[D$method == "bracket", ]
o <- order(-abs(S$dH))
cat("total sum sq dH: plain", sum(P$dH^2), " smooth", sum(S$dH^2), " bracket", sum(B$dH^2), "\n")
cat("share of smooth's sum sq in top 10:", sum(S$dH[o[1:10]]^2) / sum(S$dH^2), "\n")
print(data.frame(step = S$step[o[1:12]], node = S$node[o[1:12]], h_days = round(S$h[o[1:12]] * 365, 3),
                 dP = signif(S$dP[o[1:12]], 3), plain = signif(P$dH[o[1:12]], 3), smooth = signif(S$dH[o[1:12]], 3),
                 bracket = signif(B$dH[o[1:12]], 3)))
