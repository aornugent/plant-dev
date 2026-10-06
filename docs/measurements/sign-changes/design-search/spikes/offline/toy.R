# Toy: N "nodes" whose growth reads net production P through TF24's smooth
# positive part (eta = 1e-4), coupled through one fast "soil" state W that relaxes
# to a pulsed rain and binds the steps around pulses, as TF24's soil does.
# Cash-Karp on a frozen mesh (the mesh from a plain adaptive run at tol). Three
# treatments of a node step whose P changes sign or comes near zero:
#   plain  - nothing;
#   sub(m) - the node's components again over the step in m equal sub-steps at
#            fixed fractions, reading W from the step's dense output (no location,
#            no implicit function);
#   cut    - the node's components in pieces between the zeros of P located on
#            the step's dense output, relocated at every theta: the incumbent's
#            map, whose derivative its implicit-function sweep returns.
# A gradient is a central difference on the frozen mesh: the map's own
# derivative, which an exact sweep returns.

eta <- 1e-4
sig <- function(P) 0.5 * (P + sqrt(P * P + eta * eta))

N <- 24
set.seed(7)
a_node <- exp(seq(log(0.6), log(1.6), length.out = N))
r_node <- exp(runif(N, log(0.8), log(1.25)))
w_node <- exp(-seq(0, 2, length.out = N))
Tend <- 8
n_pulse <- 36
pulse_t <- sort(runif(n_pulse, 0.2, Tend - 0.2))
pulse_w <- runif(n_pulse, 0.03, 0.12)
pulse_a <- runif(n_pulse, 1.5, 4)
# HF_AMP adds a fast ripple to the rain, so the soil binds most steps and the
# crossings fall in a few percent of the node steps, as in TF24.
hf_amp <- as.numeric(Sys.getenv("HF_AMP", "0"))
hf_freq <- as.numeric(Sys.getenv("HF_FREQ", "40"))
rain <- function(t) {
  0.15 + hf_amp * (1 + sin(2 * pi * hf_freq * t)) +
    colSums(pulse_a * exp(-0.5 * (outer(pulse_t, t, "-") / pulse_w)^2))
}
kW <- 20   # the soil relaxes to the rain at rate kW

# State: (M_1..M_N, F_1..F_N, W). Theta multiplies respiration (an lma-like cost).
P_of <- function(M, W, th, idx = seq_len(N)) {
  a_node[idx] * W * pmax(M, 1e-12)^0.75 - th * r_node[idx] * M
}
node_rates <- function(M, W, th, idx) {
  s <- sig(P_of(M, W, th, idx))
  c(s - 0.3 * M, s * sqrt(pmax(M, 0)))
}
rates <- function(y, t, th) {
  M <- y[1:N]; W <- y[2 * N + 1]
  c(node_rates(M, W, th, seq_len(N)), kW * (rain(t) - W) - 0.01 * sum(M) * W)
}
Jof <- function(y) sum(w_node * y[N + seq_len(N)])
blk <- function(i) c(i, N + i)
iW <- 2 * N + 1

# Cash-Karp tableau (GSL's) and the incumbent's fourth-order dense output.
ah <- c(1/5, 3/10, 3/5, 1, 7/8)
A <- list(c(1/5), c(3/40, 9/40), c(3/10, -9/10, 6/5),
          c(-11/54, 5/2, -70/27, 35/27),
          c(1631/55296, 175/512, 575/13824, 44275/110592, 253/4096))
cb <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)
ec <- c(37/378 - 2825/27648, 0, 250/621 - 18575/48384, 125/594 - 13525/55296,
        -277/14336, 512/1771 - 0.25)
dw <- rbind(
  c(1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
  c(-156473/57792, 0.0, 1159825/332304, 14725/60544, 5301/38528, -202836/76153, 3/2),
  c(729889/260064, 0.0, -8030425/1495368, 290425/817344, -5301/19264, 493736/76153, -4),
  c(-24797/24768, 0.0, 2275475/996912, -19225/49536, 5301/38528, -3492/989, 5/2))
dense_w <- function(u) {
  W <- sapply(1:7, function(j) ((((dw[4, j] * u + dw[3, j]) * u + dw[2, j]) * u +
                                 dw[1, j]) * u))
  matrix(W, nrow = length(u))
}

# One Cash-Karp step of f(y, c) from y over h, c the fraction of the step.
ck_step <- function(f, y, h) {
  k <- vector("list", 6)
  st <- vector("list", 6)
  st[[1]] <- y
  k[[1]] <- f(y, 0)
  for (i in 2:6) {
    yi <- y
    for (j in seq_len(i - 1)) yi <- yi + h * A[[i - 1]][j] * k[[j]]
    st[[i]] <- yi
    k[[i]] <- f(yi, ah[i - 1])
  }
  yend <- y + h * (cb[1] * k[[1]] + cb[3] * k[[3]] + cb[4] * k[[4]] + cb[6] * k[[6]])
  err <- h * (ec[1] * k[[1]] + ec[3] * k[[3]] + ec[4] * k[[4]] + ec[5] * k[[5]] +
              ec[6] * k[[6]])
  list(y = yend, err = err, k = k, stages = st)
}

adaptive_mesh <- function(tol, th = 1) {
  y <- c(rep(0.05, N), rep(0, N), 0.15); t <- 0; h <- 1e-3
  times <- 0; sizes <- numeric(0)
  while (t < Tend - 1e-14) {
    if (t + h > Tend) h <- Tend - t
    t0 <- t
    st <- ck_step(function(z, c) rates(z, t0 + c * h, th), y, h)
    e <- max(abs(st$err) / (tol * 1e-4 + tol * abs(y)))
    if (e <= 1) {
      t <- if (t + h > Tend - 1e-14) Tend else t + h
      y <- st$y
      times <- c(times, t); sizes <- c(sizes, h)
      h <- h * min(5, max(0.2, 0.9 * e^(-1/5)))
    } else {
      h <- h * max(0.2, 0.9 * e^(-1/4))
    }
  }
  list(times = times, sizes = sizes)
}

# Replay on a frozen mesh with one treatment.
replay <- function(mesh, th, arm = "plain", m = 3, tau = 0.02, log_flips = FALSE,
                   stop_at = 0L) {
  y <- c(rep(0.05, N), rep(0, N), 0.15); t <- 0
  treated <- 0L; extra <- 0L; ncuts <- 0L; sign_steps <- 0L
  trig <- if (log_flips) integer(0) else NULL
  for (s in seq_along(mesh$sizes)) {
    h <- mesh$sizes[s]
    if (s == stop_at) return(list(y = y, t = t, h = h))
    t0 <- t
    st <- ck_step(function(z, c) rates(z, t0 + c * h, th), y, h)
    yend <- st$y
    if (arm != "plain") {
      kend <- rates(yend, t0 + h, th)
      Pst <- sapply(1:6, function(j) P_of(st$stages[[j]][1:N], st$stages[[j]][iW], th))
      Pend <- P_of(yend[1:N], yend[iW], th)
      # The soil on the step's dense output, which a treated node reads.
      kW_v <- c(vapply(st$k, `[`, 0, iW), kend[iW])
      W_at <- function(u) y[iW] + h * as.vector(dense_w(u) %*% kW_v)
      for (i in seq_len(N)) {
        rd <- c(Pst[i, ], Pend[i])
        s0 <- if (rd[1] < 0) -1 else 1
        near <- min(s0 * rd) <= tau * (max(rd) - min(rd))
        if (rd[7] * rd[1] < 0) sign_steps <- sign_steps + 1L
        if (arm == "sub") {
          if (!near) next
          if (log_flips) trig <- c(trig, s * 1000L + i)
          treated <- treated + 1L
          z <- y[blk(i)]; hs <- h / m
          for (q in 0:(m - 1)) {
            f <- function(zz, c) node_rates(zz[1], W_at((q + c) / m), th, i)
            z <- ck_step(f, z, hs)$y
          }
          extra <- extra + 6L * m - 1L
          yend[blk(i)] <- z
        } else if (arm == "cut") {
          if (min(s0 * rd) > 0.25 * (max(rd) - min(rd))) next
          kv <- c(vapply(st$k, `[`, 0, i), kend[i])
          Pu <- function(u) {
            Mu <- y[i] + h * as.vector(dense_w(u) %*% kv)
            P_of(Mu, W_at(u), th, idx = i)
          }
          us <- seq(0, 1, length.out = 33)
          pv <- Pu(us)
          pv[1] <- rd[1]; pv[33] <- rd[7]
          ch <- which(sign(pv[-1]) != sign(pv[-33]))
          if (length(ch) == 0) next
          if (log_flips) trig <- c(trig, s * 1000L + i)
          treated <- treated + 1L
          cuts <- vapply(ch, function(j) uniroot(Pu, c(us[j], us[j + 1]),
                                                 tol = 1e-15)$root, 0)
          ncuts <- ncuts + length(cuts)
          z <- y[blk(i)]; from <- 0
          for (to in c(cuts, 1)) {
            if (to > from) {
              f <- function(zz, c) node_rates(zz[1], W_at(from + c * (to - from)), th, i)
              z <- ck_step(f, z, (to - from) * h)$y
            }
            from <- to
          }
          extra <- extra + 6L * (length(cuts) + 1L) - 1L
          yend[blk(i)] <- z
        }
      }
    }
    y <- yend
    t <- mesh$times[s + 1]
  }
  list(J = Jof(y), treated = treated, extra = extra, ncuts = ncuts,
       sign_steps = sign_steps, node_steps = N * length(mesh$sizes), trig = trig)
}

# The refinement as part of the mesh: each step of a plain replay at th in which
# some node's net production has readings of both signs (its start, five stages
# and end) is replaced by m equal steps. Every later pass replays the refined mesh
# as an ordinary one, so nothing is decided after this.
refine_mesh <- function(mesh, th, m) {
  y <- c(rep(0.05, N), rep(0, N), 0.15); t <- 0
  times <- 0; sizes <- numeric(0); refined <- 0L
  for (s in seq_along(mesh$sizes)) {
    h <- mesh$sizes[s]; t0 <- t
    st <- ck_step(function(z, c) rates(z, t0 + c * h, th), y, h)
    Pst <- sapply(1:6, function(j) P_of(st$stages[[j]][1:N], st$stages[[j]][iW], th))
    Pend <- P_of(st$y[1:N], st$y[iW], th)
    rd <- cbind(Pst, Pend)
    both <- any(apply(rd, 1, function(v) any(v < 0) && any(v >= 0)))
    t1 <- mesh$times[s + 1]
    if (both) {
      refined <- refined + 1L
      for (q in 1:m) {
        tq <- if (q == m) t1 else t0 + q * h / m
        z0 <- y; hq <- tq - (if (q == 1) t0 else times[length(times)])
        sizes <- c(sizes, hq); times <- c(times, tq)
      }
      # Advance the state along the refined steps.
      for (q in 1:m) {
        hq <- sizes[length(sizes) - m + q]; tq0 <- times[length(times) - m + q - 1]
        y <- ck_step(function(z, c) rates(z, tq0 + c * hq, th), y, hq)$y
      }
    } else {
      sizes <- c(sizes, h); times <- c(times, t1); y <- st$y
    }
    t <- t1
  }
  list(times = times, sizes = sizes, refined = refined)
}
