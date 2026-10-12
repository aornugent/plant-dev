# Pre-registration: one pass of map-ranked batch bisection (dry, episodic), 12 October

G0 from mkG0.R (edges; open gaps cut into an even number of equal intervals, at most
b1/16 before b1 and 80 d after). G0 runs with the map on, dropping every other node of
each gap (C0). Panel p's move m_p = own + field part of ln J(C0) - ln J(G0) at that
drop. G1 bisects both intervals of the fewest panels carrying s = 0.75 of sum |m_p|.
G1 runs with the map on, dropping G1's new midpoints.

Predictions, errors in each quantity's eps against the training references:
P1. ln J(G1) - ln J(G0) = sum over chosen panels of m_p / 4, within 20%.
P2. Quantities with |err(G0)| > 1/3: median |err(G1)| / |err(G0)| in [0.3, 0.6]
    (a quarter of the error left in chosen panels, plus the unchosen share).
P3. Each quantity's estimate for G1, (Q(G0) - Q(G1)) / 3, is within x2 of err(G1)
    for at least 80% of quantities with error or estimate over 1/3.
P4. rows(G1) <= 1.35 rows(G0); rows(G0) within 10% of lattice (16, 70)'s.
P5. Every quantity of G1 within eps on both records.
Falsified: P1 off by more than 20% means the map's ranking cannot be trusted for
placement; P2 above 0.6 means J's ranking misses the elasticities' error.
