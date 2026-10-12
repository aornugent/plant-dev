# Late intervals of H touching a first-pass edge, bisected once (Hea) and twice (Hea2:
# the halves touching the edge bisected again); late intervals touching no edge,
# bisected once (Hna).
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs"); b1 <- 3.529
cr <- readRDS(file.path(Q, "m_th0_f_dry.rds"))$stand$creation; op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); ed <- cr$end[e][-length(e)]
h <- readRDS(file.path(S, "rp50/H_dry.rds")); isedge <- round(h, 9) %in% round(ed, 9)
lo <- head(h, -1); hi <- h[-1]; late <- lo > b1
touch <- late & (isedge[-length(h)] | isedge[-1]); far <- late & !touch
ea <- sort(c(h, (lo + hi)[touch] / 2)); na <- sort(c(h, (lo + hi)[far] / 2))
e2 <- round(ea, 9) %in% round(ed, 9); lo2 <- head(ea, -1); hi2 <- ea[-1]; t2 <- lo2 > b1 & (e2[-length(ea)] | e2[-1])
ea2 <- sort(c(ea, (lo2 + hi2)[t2] / 2))
for (nm in c("Hea", "Hea2", "Hna")) saveRDS(get(tolower(sub("^H", "", nm)) |> (\(x) if (x == "ea") "ea" else if (x == "ea2") "ea2" else "na")()), file.path(S, sprintf("rp50/%s_dry.rds", nm)))
cat(sprintf("H %d nodes; late intervals touching an edge %d, not %d; Hea %d, Hea2 %d, Hna %d nodes\n", length(h), sum(touch), sum(far), length(ea), length(ea2), length(na)))
