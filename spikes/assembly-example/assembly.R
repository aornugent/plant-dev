## MacArthur consumer-resource competition on d resources with k = 2 + nw traits:
## x places a species' uptake along the resource axis, v scales it at a cost,
## and nw physiological traits w have an optimum set by x. The evolutionarily
## stable community is assembled by three routes that call the same two
## primitives, counted: a resident run and an invader evaluation in a held field.
## Base R, under a minute. docs/review/assembly-algorithm.md cites its output.

model <- function(z, K, sigma, mu = 0.125, cc = 1, nw = 48, seed = 1) {
  set.seed(seed)
  list(z = z, K = K, s2 = sigma^2, mu = mu, cc = cc, d = length(z), k = 2 + nw,
       om = runif(nw, -1, 1), q = runif(nw, 0.5, 5))
}

uptake <- function(m, x) {
  a <- exp(-(x - m$z)^2/(2*m$s2))
  list(a = a, a1 = -(x - m$z)/m$s2*a, a2 = ((x - m$z)^2/m$s2^2 - 1/m$s2)*a)
}
consumption <- function(m, th) th[2]*uptake(m, th[1])$a
consumption_jacobian <- function(m, th) {  # d x k
  u <- uptake(m, th[1])
  cbind(th[2]*u$a1, u$a, matrix(0, m$d, m$k - 2))
}
field <- function(m, thetas, N) {
  R <- m$K
  for (j in seq_along(N)) R <- R - N[j]*consumption(m, thetas[[j]])
  R
}

count <- new.env()
reset_counts <- function() { count$resident <- 0; count$invader <- 0 }

## Invader fitness, selection gradient and field sensitivity in a held field R.
fitness <- function(m, th, R) {
  x <- th[1]; v <- th[2]; dev <- th[-(1:2)] - m$om*x; u <- uptake(m, x)
  aR <- sum(u$a*R)
  list(phi = v*aR - m$mu - m$cc*v^2/2 - sum(m$q*dev^2)/2,
       g = c(v*sum(u$a1*R) + sum(m$q*m$om*dev), aR - m$cc*v, -m$q*dev),
       S = v*u$a)
}
invader <- function(m, th, R) { count$invader <- count$invader + 1; fitness(m, th, R) }

## Held-field Hessian H (k x k) and G = dg/dR (k x d): k probes of the gradient.
curvature <- function(m, th, R) {
  count$invader <- count$invader + m$k
  x <- th[1]; v <- th[2]; u <- uptake(m, x); k <- m$k; w <- 3:k
  H <- matrix(0, k, k)
  H[1, 1] <- v*sum(u$a2*R) - sum(m$q*m$om^2)
  H[1, 2] <- H[2, 1] <- sum(u$a1*R)
  H[1, w] <- H[w, 1] <- m$q*m$om
  H[2, 2] <- -m$cc
  H[w, w] <- -diag(m$q)
  list(H = H, G = rbind(v*u$a1, u$a, matrix(0, k - 2, m$d)))
}

## One run of the residents: the field they make, each one's F, g (the field
## cut) and S (the adjoints the cut zeroes), dR/dN_j and dR/dtheta_j (sweeps).
resident <- function(m, thetas, N) {
  count$resident <- count$resident + 1
  R <- field(m, thetas, N)
  f <- lapply(thetas, fitness, m = m, R = R)
  list(R = R, F = vapply(f, `[[`, 0, "phi"), g = lapply(f, `[[`, "g"),
       S = lapply(f, `[[`, "S"),
       C = matrix(vapply(thetas, function(th) -consumption(m, th), m$K), m$d),
       Eth = Map(function(th, n) -n*consumption_jacobian(m, th), thetas, N))
}

## Curvature carried forward and corrected along the columns of U: one gradient
## probe per direction gives H u and, from the change in S, G' u. H is updated
## symmetrically to match H U, and G to match G' U.
directional <- function(m, th, R, old, U) {
  U <- U[, colSums(U^2) > 1e-24, drop = FALSE]
  q <- qr(U); U <- qr.Q(q)[, seq_len(q$rank), drop = FALSE]
  count$invader <- count$invader + ncol(U)
  n <- count$invader; now <- curvature(m, th, R); count$invader <- n
  D <- now$H %*% U - old$H %*% U
  list(H = old$H + D %*% t(U) + U %*% t(D) - U %*% (t(U) %*% D) %*% t(U),
       G = old$G + U %*% (t(U) %*% (now$G - old$G)))
}

negative_definite <- function(H, floor = 1e-3) {
  e <- eigen(H, symmetric = TRUE)
  lam <- pmin(e$values, -floor*max(1, abs(e$values)))
  e$vectors %*% (lam*t(e$vectors))
}
cap_step <- function(s, cap) s*min(1, cap/max(abs(s)))

## Ascent of invader fitness in a held field: the pricing primitive. The
## curvature is probed once and then carried by BFGS updates; a step that
## loses fitness is undone, the step cap halved and the curvature probed again.
ascend <- function(m, th, R, tol = 1e-10, cap0 = 0.25, max_it = 500) {
  f <- invader(m, th, R); H <- NULL; cap <- cap0
  for (i in seq_len(max_it)) {
    if (max(abs(f$g)) < tol) break
    if (is.null(H)) H <- negative_definite(curvature(m, th, R)$H)
    s <- tryCatch(-solve(H, f$g), error = function(e) NULL)
    if (is.null(s)) { H <- NULL; next }
    s <- cap_step(s, cap)
    fn <- invader(m, th + s, R)
    if (fn$phi < f$phi - 1e-12*(1 + abs(f$phi))) { H <- NULL; cap <- cap/2; next }
    cap <- min(cap0, 2*cap)
    y <- fn$g - f$g; ys <- sum(y*s)
    if (ys < 0) {  # keeps H negative definite
      Hs <- H %*% s
      H <- H + y %*% t(y)/ys - Hs %*% t(Hs)/drop(t(s) %*% Hs)
    }
    th <- th + s; f <- fn
  }
  list(theta = th, phi = f$phi)
}
merge_close <- function(thetas, tol = 1e-4) {
  keep <- list()
  for (th in thetas) {
    if (!any(vapply(keep, function(t) max(abs(t - th)) < tol, TRUE))) keep <- c(keep, list(th))
  }
  keep
}
starts <- function(m, n = 13) {
  lapply(seq(min(m$z) - 0.25, max(m$z) + 0.25, length.out = n),
         function(x) c(x, 1, rep(0, m$k - 2)))
}
price <- function(m, R) {
  peaks <- lapply(starts(m), function(th) ascend(m, th, R))
  th <- merge_close(lapply(peaks, `[[`, "theta"))
  list(theta = th, phi = vapply(th, function(t) fitness(m, t, R)$phi, 0))
}

## Linear complementarity: N >= 0, w = q0 + M N <= 0, N w = 0, by supports of
## size at most `most`; among solutions, the one keeping most of `prefer`.
lcp <- function(q0, M, most, prefer, tol = 1e-12) {
  P <- length(q0); best <- NULL; score <- -Inf
  for (s in 0:min(most, P)) {
    sets <- if (s == 0) list(integer(0)) else combn(P, s, simplify = FALSE)
    for (S in sets) {
      N <- numeric(P)
      if (s > 0) {
        z <- tryCatch(solve(M[S, S, drop = FALSE], -q0[S]), error = function(e) NULL)
        if (is.null(z) || any(z < -tol)) next
        N[S] <- pmax(z, 0)
      }
      w <- q0 + M %*% N
      if (any(w[-S] > tol*max(1, abs(q0)))) next
      sc <- sum(S %in% prefer)*10 + s
      if (sc > score) { best <- N; score <- sc }
    }
  }
  best
}

report <- function(label, thetas, N, extra = "") {
  cat(sprintf("%-6s", label))
  for (j in seq_along(thetas)) {
    cat(sprintf(" [x %.6f v %.6f N %.6f]", thetas[[j]][1], thetas[[j]][2], N[j]))
  }
  cat(extra, "\n")
}

## Lean route. Rounds of column generation: price in the current field, let a
## rank-d complementarity problem choose who enters, then Newton passes on the
## residents and the entrants. Each pass is one resident run, curvature probes of
## every tracked strategy in parallel, and the same complementarity problem for
## the densities, with each strategy's traits taking a Newton step to its best
## response in the field those densities are predicted to make.
## `trust` caps each strategy's predicted gain, (1/2) dth' (-H) dth, in fitness
## units; `feedback` keeps the residents' trait steps in the predicted field;
## curvature is probed every `reprobe` passes and reused between, or with
## `reprobe = 0` probed in full once a round and then only along the last step and
## the best-response shifts H^-1 G.
lean <- function(m, tol_F = 1e-10, tol_g = 1e-8, trust = 0.2, feedback = TRUE,
                 reprobe = 1, max_pass = 100, max_round = 10, trace = TRUE) {
  reset_counts(); pricing <- 0; passes <- 0
  peaks <- list(); N <- numeric(0); R <- m$K
  for (round in seq_len(max_round)) {
    before <- count$invader; pr <- price(m, R); pricing <- pricing + count$invader - before
    near <- vapply(pr$theta, function(t)
      any(vapply(peaks, function(p) max(abs(p - t)) < 1e-4, TRUE)), TRUE)
    new <- which(pr$phi > 1e-9 & !near)
    if (trace) cat(sprintf("round %d: pricing finds %d strategies, %d with phi > 0 not resident (best %.2e)\n",
                           round, length(pr$theta), length(new), max(pr$phi)))
    if (!length(new)) break
    peaks <- c(peaks, pr$theta[new]); N <- c(N, numeric(length(new)))
    for (pass in seq_len(max_pass)) {
      passes <- passes + 1
      A <- which(N > 0)
      rec <- if (length(A)) resident(m, peaks[A], N[A]) else list(R = m$K, F = 0, g = list(0))
      R <- rec$R; P <- length(peaks)
      f <- lapply(seq_len(P), function(p) {
        if (p %in% A) {
          i <- match(p, A); list(phi = rec$F[i], g = rec$g[[i]], S = rec$S[[i]])
        } else invader(m, peaks[[p]], R)
      })
      cand <- setdiff(seq_len(P), A)
      gF <- max(abs(rec$F)); gg <- max(abs(unlist(rec$g)))
      top <- if (length(cand)) max(vapply(f[cand], `[[`, 0, "phi")) else -Inf
      if (trace) report(sprintf("  %d", pass), peaks[A], N[A],
                        sprintf(" |F| %.0e |g| %.0e%s", gF, gg,
                                if (length(cand)) sprintf("  tracking %d, best phi %.2e",
                                                          length(cand), top) else ""))
      if (length(A) && gF < tol_F && gg < tol_g && top < 0) break

      if (reprobe > 0) {
        if ((pass - 1) %% reprobe == 0) cv <- lapply(peaks, curvature, m = m, R = R)
      } else {
        cv <- lapply(seq_len(P), function(p) {
          if (pass == 1) return(curvature(m, peaks[[p]], R))
          directional(m, peaks[[p]], R, cv[[p]], cbind(moved[[p]], HG[[p]]))
        })
      }
      Hn <- lapply(cv, function(c) negative_definite(c$H))
      Hg <- Map(function(H, f) solve(H, f$g), Hn, f)
      HG <- Map(function(H, c) solve(H, c$G), Hn, cv)
      Q <- diag(m$d); r0 <- numeric(m$d)
      for (p in if (feedback) A) {
        E <- rec$Eth[[match(p, A)]]
        Q <- Q + E %*% HG[[p]]; r0 <- r0 - E %*% Hg[[p]]
      }
      Qi <- solve(Q)
      phit <- vapply(seq_len(P), function(p) f[[p]]$phi - sum(f[[p]]$g*Hg[[p]])/2, 0)
      St <- t(vapply(seq_len(P), function(p) f[[p]]$S - drop(t(HG[[p]]) %*% f[[p]]$g),
                     numeric(m$d)))
      Cm <- matrix(vapply(peaks, function(th) -consumption(m, th), m$K), m$d)
      M <- St %*% Qi %*% Cm
      q0 <- phit + St %*% Qi %*% (r0 - Cm %*% N)
      Nn <- lcp(drop(q0), M, m$d, A)
      if (is.null(Nn)) stop("no complementary densities in round ", round, " pass ", pass)
      dR <- Qi %*% (Cm %*% (Nn - N) + r0)
      dth <- lapply(seq_len(P), function(p) -drop(Hg[[p]] + HG[[p]] %*% dR))
      gain <- max(vapply(seq_len(P), function(p) -sum(dth[[p]]*(Hn[[p]] %*% dth[[p]]))/2, 0))
      alpha <- min(1, sqrt(trust/gain))  # one factor for densities and traits
      for (p in seq_len(P)) peaks[[p]] <- peaks[[p]] + alpha*dth[[p]]
      moved <- lapply(dth, `*`, alpha)
      N <- N + alpha*(Nn - N)
      N[N < 1e-12] <- 0
    }
    keep <- N > 0; peaks <- peaks[keep]; N <- N[keep]
  }
  cert <- price(m, R)
  list(theta = peaks, N = N, R = R, rounds = round, passes = passes,
       resident = count$resident, invader = count$invader, pricing = pricing,
       certificate = max(cert$phi))
}

## The one-shot route of field-cut.md: one resident run per step, Broyden on g,
## ln N by Newton predicted through F_theta. A step that more than doubles
## |F|^2 + |g|^2 is undone, the cap halved and Broyden restarted.
one_shot <- function(m, thetas, lnN, scale = 1, cap = 0.25, tol_F = 1e-10,
                     tol_g = 1e-8, max_it = 2000) {
  n <- length(thetas)*m$k; B <- -scale*diag(n); s <- NULL; gp <- NULL
  last <- NULL; cap_now <- cap
  for (it in seq_len(max_it)) {
    N <- exp(lnN); rec <- resident(m, thetas, N); g <- unlist(rec$g)
    if (max(abs(rec$F)) < tol_F && max(abs(g)) < tol_g) break
    merit <- sum(rec$F^2) + sum(g^2)
    if (!is.null(last) && merit > 2*last$merit) {
      thetas <- last$thetas; lnN <- last$lnN; rec <- last$rec; g <- unlist(rec$g)
      N <- exp(lnN); cap_now <- cap_now/2; B <- -scale*diag(n); s <- NULL
    } else {
      last <- list(thetas = thetas, lnN = lnN, rec = rec, merit = merit)
      cap_now <- min(cap, 1.5*cap_now)
    }
    mm <- length(thetas)
    Fb <- outer(seq_len(mm), seq_len(mm),
                Vectorize(function(i, j) sum(rec$S[[i]]*rec$C[, j])*N[j]))
    Fth <- matrix(0, mm, n)
    for (i in seq_len(mm)) for (j in seq_len(mm)) {
      cols <- (j - 1)*m$k + seq_len(m$k)
      Fth[i, cols] <- drop(rec$S[[i]] %*% rec$Eth[[j]]) + (i == j)*rec$g[[i]]
    }
    if (!is.null(s)) B <- B + outer(g - gp - drop(B %*% s), s)/sum(s^2)
    step <- tryCatch(-solve(B, g), error = function(e) -g)
    if (sum(step*g) <= 0) { B <- -scale*diag(n); step <- g/scale }
    step <- cap_step(step, cap_now)
    rhs <- rec$F + Fth %*% step
    db <- tryCatch(-solve(Fb, rhs),  # near-singular when two residents nearly coincide
                   error = function(e) -solve(crossprod(Fb) + 1e-10*diag(mm), t(Fb) %*% rhs))
    db <- cap_step(db, 1)
    for (j in seq_len(mm)) thetas[[j]] <- thetas[[j]] + step[(j - 1)*m$k + seq_len(m$k)]
    lnN <- lnN + drop(db); s <- step; gp <- g
  }
  list(theta = thetas, lnN = lnN, rec = rec, steps = it)
}

## regnans's FitMax: births in the residents' field, equilibrium by its Newton
## solver given the exact dF/d ln N (its default iteration, ln N <- ln N + F,
## oscillates here), to equilibrium_eps; species below 1e-8 dropped,
## residents not evolved. A birth needs phi > fit_eps and x at least 0.01 from every
## resident (both assumed; regnans's own rules not read).
fitmax <- function(m, eps = 1e-5, fit_eps = 1e-4, N0 = 1e-3, max_rounds = 20) {
  reset_counts(); thetas <- list(); N <- numeric(0); R <- m$K
  for (round in seq_len(max_rounds)) {
    pr <- price(m, R); b <- which.max(pr$phi)
    if (pr$phi[b] <= fit_eps) break
    copy <- any(vapply(thetas, function(t) abs(t[1] - pr$theta[[b]][1]) < 0.01, TRUE))
    if (copy) break  # a birth within 0.01 in x of a resident is refused
    thetas <- c(thetas, list(pr$theta[[b]])); N <- c(N, N0)
    for (i in 1:500) {
      rec <- resident(m, thetas, N); R <- rec$R
      if (max(abs(rec$F)) < eps) break
      Fb <- outer(seq_along(N), seq_along(N),
                  Vectorize(function(i, j) sum(rec$S[[i]]*rec$C[, j])*N[j]))
      step <- tryCatch(-solve(Fb, rec$F), error = function(e) rec$F)
      N <- N*exp(cap_step(step, 1)); alive <- N > 1e-8
      thetas <- thetas[alive]; N <- N[alive]
    }
  }
  list(theta = thetas, N = N, rounds = round, resident = count$resident,
       invader = count$invader,
       g = max(abs(unlist(lapply(thetas, function(t) fitness(m, t, R)$g)))))
}

schur <- function(A, i = 1) A[i, i] - A[i, -i] %*% solve(A[-i, -i], A[-i, i])

## ---- the symmetric two-resource case, by hand and by the three routes ----
m <- model(z = c(0, 1), K = c(2, 2), sigma = 0.4)
cat(sprintf("d = %d resources, k = %d traits, sigma = %.2f\n\n", m$d, m$k, sqrt(m$s2)))

a0 <- exp(-1/(8*m$s2)); v <- sqrt(2*m$mu/m$cc)
Rg <- m$cc*v/(2*a0); Ng <- (m$K[1] - Rg)/(v*a0)
Hxx <- v*Rg*2*a0*(1/(4*m$s2^2) - 1/m$s2); Mxx <- -Ng*v^2*a0^2/(2*m$s2^2)
xb <- uniroot(function(x) log(x/(1 - x)) + (1 - 2*x)/(2*m$s2), c(1e-6, 0.45), tol = 1e-14)$root
sb <- sum(uptake(m, xb)$a); Rp <- m$cc*v/sb; Np <- (m$K[1] - Rp)/(v*sb)
cat("By hand:\n")
cat(sprintf("  generalist x = 1/2, v = %.6f, R = %.6f, N = %.6f\n", v, Rg, Ng))
cat(sprintf("  its curvature in x: H = %.4f (field held), M = %.4f, J = H + M = %.4f\n",
            Hxx, Mxx, Hxx + Mxx))
cat(sprintf("  the pair: x = %.6f and %.6f, v = %.6f, R = %.6f, N = %.6f each\n\n",
            xb, 1 - xb, v, Rp, Np))

cat("Lean route, pass by pass (residents in brackets):\n")
L <- lean(m)
cat(sprintf(paste("  %d rounds, %d passes: %d resident runs; %d invader evaluations,",
                  "%d of them pricing; certificate max phi %.1e\n\n"),
            L$rounds, L$passes, L$resident, L$invader, L$pricing, L$certificate))

cat("One-shot route:\n")
reset_counts()
p0 <- price(m, m$K); first <- p0$theta[[which.max(p0$phi)]]
o1 <- one_shot(m, list(first), log(1))
cv <- curvature(m, o1$theta[[1]], o1$rec$R)
Fb <- sum(o1$rec$S[[1]]*o1$rec$C[, 1])*exp(o1$lnN)
Eth <- o1$rec$Eth[[1]]
Est <- Eth - outer(o1$rec$C[, 1]*exp(o1$lnN), drop(o1$rec$S[[1]] %*% Eth))/Fb
J <- cv$H + cv$G %*% Est
cat(sprintf("  monomorphic: %d steps to x = %.6f, v = %.6f, N = %.6f\n", o1$steps,
            o1$theta[[1]][1], o1$theta[[1]][2], exp(o1$lnN)))
cat(sprintf("  its curvature in x, w and v eliminated: H %.4f, J %.4f\n",
            schur(cv$H), schur(J)))
e <- eigen(cv$H, symmetric = TRUE); dir <- e$vectors[, 1]/e$vectors[1, 1]
pair <- list(o1$theta[[1]] + 0.1*dir, o1$theta[[1]] - 0.1*dir)  # x apart by 0.2
o2 <- one_shot(m, pair, rep(o1$lnN - log(2), 2))
cert <- price(m, o2$rec$R)
report("  pair:", o2$theta, exp(o2$lnN),
       sprintf("  after %d steps, |F| %.0e |g| %.0e", o2$steps, max(abs(o2$rec$F)),
               max(abs(unlist(o2$rec$g)))))
cat(sprintf("  %d resident runs, %d invader evaluations; certificate max phi %.1e\n\n",
            count$resident, count$invader, max(cert$phi)))

cat("regnans FitMax (Newton equilibrium, residents not evolved):\n")
fm <- fitmax(m)
report("  end:", fm$theta, fm$N)
cat(sprintf("  %d rounds, %d resident runs, %d invader evaluations; residents' max |g| %.1e\n\n",
            fm$rounds, fm$resident, fm$invader, fm$g))

cat("Lean against by hand: largest difference in x, v, N, R: ")
ord <- order(vapply(L$theta, `[`, 0, 1))
cat(sprintf("%.1e\n", max(abs(c(vapply(L$theta[ord], `[`, 0, 1) - c(xb, 1 - xb),
                                vapply(L$theta, `[`, 0, 2) - v, L$N - Np, L$R - Rp)))))
cat(sprintf("Slaved traits: largest |w - omega x| %.1e, |v - a(x).R/c| %.1e\n\n",
            max(abs(unlist(lapply(L$theta, function(t) t[-(1:2)] - m$om*t[1])))),
            max(abs(vapply(L$theta, function(t) t[2] - sum(uptake(m, t[1])$a*L$R)/m$cc, 0)))))

## ---- three resources, unequal supply, no symmetry ----
m3 <- model(z = c(0, 0.5, 1), K = c(2, 1.5, 1), sigma = 0.22)
cat(sprintf("d = %d, K = (%s), sigma = %.2f, k = %d\n", m3$d,
            paste(m3$K, collapse = ", "), sqrt(m3$s2), m3$k))
L3 <- lean(m3)
report("  lean end:", L3$theta, L3$N)
cat(sprintf(paste("  lean: %d rounds, %d passes, %d resident runs; %d invader evaluations,",
                  "%d of them pricing; certificate %.1e\n"),
            L3$rounds, L3$passes, L3$resident, L3$invader, L3$pricing, L3$certificate))
fm3 <- fitmax(m3)
report("  FitMax end:", fm3$theta, fm3$N)
cat(sprintf("  FitMax: %d rounds, %d resident runs, %d invader evaluations; max |g| %.1e\n",
            fm3$rounds, fm3$resident, fm3$invader, fm3$g))
