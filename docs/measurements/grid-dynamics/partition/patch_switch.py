p = "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/split_stepper.R"
s = open(p).read()


def sub(a, b):
    global s
    assert s.count(a) == 1, a[:70]
    s = s.replace(a, b)


sub("""      } else if (ctl$shrank) {
        n$rejected_inaccurate <- n$rejected_inaccurate + 1
      } else if (!(ctl$ratio <= 1.1)) {
        n$accepted_at_minimum <- n$accepted_at_minimum + 1
      } else {
        n$accepted <- n$accepted + 1
      }
    }
    if (ctl$shrank) {
      if (hn < h && t0 + hn > t0) {
        h <- hn
        next
      }
      stop(sprintf("Cannot achieve the desired accuracy at t = %.17g", t0))
    }
    sv$t <- if (final) target else t0 + h
    if (!final) sv$h_last <- hn
    sub$h <- a$h_sub""", """      } else if (ctl$shrank) {
        n$rejected_inaccurate <- n$rejected_inaccurate + 1
      } else if (h > DELTA && t0 < SWITCH_UNTIL &&
                 any((sign(a$P) != sign(sv$P))[times[seq_along(a$P)] < SWITCH_BORN])) {
        # The driver's SWITCH_DAYS refusal: no step longer than that across a
        # member's net production changing sign.
        hn <- max(h / 2, DELTA)
        ctl$shrank <- TRUE
        n$rejected_switch <- n$rejected_switch + 1
      } else if (!(ctl$ratio <= 1.1)) {
        n$accepted_at_minimum <- n$accepted_at_minimum + 1
      } else {
        n$accepted <- n$accepted + 1
      }
    }
    if (ctl$shrank) {
      if (hn < h && t0 + hn > t0) {
        h <- hn
        next
      }
      stop(sprintf("Cannot achieve the desired accuracy at t = %.17g", t0))
    }
    sv$t <- if (final) target else t0 + h
    if (!final) sv$h_last <- hn
    sub$h <- a$h_sub""")

sub("""  att <- vapply(c("accepted", "accepted_at_minimum", "rejected_inaccurate",
                  "rejected_thrown", "rejected_refused"), function(x) n[[x]], 0)""",
    """  att <- vapply(c("accepted", "accepted_at_minimum", "rejected_inaccurate",
                  "rejected_thrown", "rejected_refused", "rejected_switch"), function(x) n[[x]], 0)""")

sub("""# HMAX caps the member step at that many days.""",
    """# SWITCH_DAYS (with the driver's SWITCH_BORN and SWITCH_UNTIL) refuses a member
# step longer than that across which a member's net production changes sign.
# HMAX caps the member step at that many days.""")
open(p, "w").write(s)
print("ok")
