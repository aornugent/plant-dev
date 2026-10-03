import sys
f = sys.argv[1]
s = open(f).read()


def rep(old, new, count=1):
    global s
    assert s.count(old) == count, (old[:80], s.count(old))
    s = s.replace(old, new)


rep('#include <algorithm>\n', '#include <algorithm>\n#include <numeric>\n')

# self-probe remnants out
rep('''  // Each node's panel as the birth-date field holds it, for the self probe.
  std::vector<probe::twin_panel> twin_panels(double area) const;

''', '')
i0 = s.index('template <typename T, typename E>\nstd::vector<probe::twin_panel> Species<T,E>::twin_panels')
i1 = s.index('template <typename T, typename E>\nvoid Species<T,E>::compute_rates')
s = s[:i0] + s[i1:]
rep('''  long index = 0;
  for (auto& c : nodes) {
    probe::current() = index++;
    c.compute_rates(environment, pr_patch_survival);
  }
  probe::current() = -1;
''', '''  for (auto& c : nodes) {
    c.compute_rates(environment, pr_patch_survival);
  }
''')

# declarations
rep('''  void spread_field_splits(const std::vector<value_type>& heights,
                           std::vector<competition_split>& out) const;
''', '''  void spread_field_splits(const std::vector<value_type>& heights,
                           std::vector<competition_split>& out, bool sort) const;
  // Tallies a birth-date field build by its ordering, and says whether the
  // order probe takes the prefix pass although the heights are out of order.
  bool prefix_despite_order(bool ordered, bool spread) const;
''')

# field_splits head
rep('''  const bool ordered = scan.decreasing &&
                       (!spread || new_node.height() <= nodes.back().height());
  if (!ordered || n_moments == 0) {
    for (std::size_t k = 0; k < heights.size(); ++k) {
      out[k] = compute_competition_and_slope_split(heights[k]);
    }
    return;
  }
  if (spread) {
    spread_field_splits(heights, out);
    return;
  }
''', '''  const bool ordered = scan.decreasing &&
                       (!spread || new_node.height() <= nodes.back().height());
  const bool despite = control().node_density_in_birth_date && n_moments > 0 &&
                       prefix_despite_order(ordered, spread);
  if ((!ordered && !despite) || n_moments == 0) {
    for (std::size_t k = 0; k < heights.size(); ++k) {
      out[k] = compute_competition_and_slope_split(heights[k]);
    }
    return;
  }
  const bool sort = despite && probe::order_mode() == 2;
  if (spread) {
    spread_field_splits(heights, out, sort);
    return;
  }
''')

# lumped birth-date prefix: sorted variant ahead of the committed one
rep('''  if (control().node_density_in_birth_date) {
    // Each node weighted once, and a height reads the prefix of the nodes that
    // reach it: below its own height a node contributes an exact zero, and the
    // heights decrease along the list. prefix[i] sums the first i nodes.
''', '''  if (control().node_density_in_birth_date && sort) {
    // The order probe's sort: the same prefix, over the nodes tallest first.
    std::vector<value_type> w(n);
    {
      std::size_t i = 0;
      for_each_establishment_weight([&](const node_type&, const value_type& wi) {
        w[i++] = wi;
      });
    }
    std::vector<std::size_t> order(n);
    std::iota(order.begin(), order.end(), std::size_t(0));
    std::stable_sort(order.begin(), order.end(), [&](std::size_t a, std::size_t b) {
      return odelia::util::to_passive(nodes[a].height()) >
             odelia::util::to_passive(nodes[b].height());
    });
    std::vector<moments> prefix(n + 1);
    for (std::size_t j = 0; j < n_moments; ++j) {
      prefix[0][j] = value_type(0.0);
    }
    for (std::size_t i = 0; i < n; ++i) {
      const std::size_t o = order[i];
      for (std::size_t j = 0; j < n_moments; ++j) {
        prefix[i + 1][j] = prefix[i][j] + w[o] * scale[o] * mom[o][j];
      }
    }
    std::size_t reach = n;
    for (std::size_t k = 0; k < heights.size(); ++k) {
      const value_type& height = heights[k];
      if (scan.h_max < height) {
        continue;
      }
      while (reach > 0 && nodes[order[reach - 1]].height() < height) {
        --reach;
      }
      strategy->canopy_shape.height_weights(height, weight);
      strategy->canopy_shape.height_weight_slopes(height, weight_slope);
      competition_split& c = out[k];
      for (std::size_t j = 0; j < n_moments; ++j) {
        c.without_boundary.value += weight[j] * prefix[reach][j];
        c.without_boundary.slope += weight_slope[j] * prefix[reach][j];
      }
      c.closes = true;
    }
    return;
  }

  if (control().node_density_in_birth_date) {
    // Each node weighted once, and a height reads the prefix of the nodes that
    // reach it: below its own height a node contributes an exact zero, and the
    // heights decrease along the list. prefix[i] sums the first i nodes.
''')

# spread_field_splits: signature and a sorted variant
rep('''void Species<T,E>::spread_field_splits(const std::vector<value_type>& heights,
                                       std::vector<competition_split>& out) const {
  using moments = std::array<value_type, CanopyShape<value_type>::max_moments>;
  const std::size_t n_moments = strategy->canopy_shape.n_moments();
  const int M = probe::spread();
  const std::size_t n = size();
''', '''void Species<T,E>::spread_field_splits(const std::vector<value_type>& heights,
                                       std::vector<competition_split>& out,
                                       bool sort) const {
  using moments = std::array<value_type, CanopyShape<value_type>::max_moments>;
  const std::size_t n_moments = strategy->canopy_shape.n_moments();
  const int M = probe::spread();
  const std::size_t n = size();
  if (sort) {
    // The order probe's sort: every point crown first, then the prefix over
    // them tallest first.
    std::vector<value_type> top, weight_c;
    std::vector<moments> raw_of;
    top.reserve(n * M);
    weight_c.reserve(n * M);
    raw_of.reserve(n * M);
    for (std::size_t i = 0; i < n; ++i) {
      const node_type& end = i + 1 < n ? nodes[i + 1] : new_node;
      const auto share = nodes[i].interval_shares(
        end.introduction_time() - nodes[i].introduction_time());
      const value_type c_upper = share.first * nodes[i].compute_competition(0.0);
      const value_type c_lower = i + 1 < n
        ? value_type(share.second * end.compute_competition(0.0))
        : value_type(0.0);
      if (!util::is_finite(c_upper) || !util::is_finite(c_lower)) {
        util::stop("Detected non-finite contribution");
      }
      const value_type h0 = nodes[i].height();
      const value_type h1 = end.height();
      for (int s = 0; s < M; ++s) {
        const double lambda = (s + 0.5) / M;
        const value_type h_s = h0 + lambda * (h1 - h0);
        moments raw;
        strategy->canopy_shape.crown_moments(1.0 / h_s, raw);
        top.push_back(h_s);
        weight_c.push_back(c_upper * (2.0 * (1.0 - lambda) / M) +
                           c_lower * (2.0 * lambda / M));
        raw_of.push_back(raw);
      }
    }
    std::vector<std::size_t> order(top.size());
    std::iota(order.begin(), order.end(), std::size_t(0));
    std::stable_sort(order.begin(), order.end(), [&](std::size_t a, std::size_t b) {
      return odelia::util::to_passive(top[a]) > odelia::util::to_passive(top[b]);
    });
    std::vector<moments> prefix(top.size() + 1);
    for (std::size_t j = 0; j < n_moments; ++j) {
      prefix[0][j] = value_type(0.0);
    }
    for (std::size_t p = 0; p < top.size(); ++p) {
      const std::size_t o = order[p];
      for (std::size_t j = 0; j < n_moments; ++j) {
        prefix[p + 1][j] = prefix[p][j] + weight_c[o] * raw_of[o][j];
      }
    }
    const HeightScan& scan = scan_heights();
    moments weight, weight_slope;
    std::size_t reach = top.size();
    for (std::size_t k = 0; k < heights.size(); ++k) {
      const value_type& height = heights[k];
      if (scan.h_max < height) {
        continue;
      }
      while (reach > 0 && top[order[reach - 1]] < height) {
        --reach;
      }
      strategy->canopy_shape.height_weights(height, weight);
      strategy->canopy_shape.height_weight_slopes(height, weight_slope);
      competition_split& c = out[k];
      for (std::size_t j = 0; j < n_moments; ++j) {
        c.without_boundary.value += weight[j] * prefix[reach][j];
        c.without_boundary.slope += weight_slope[j] * prefix[reach][j];
      }
      c.closes = true;
    }
    return;
  }
''')

# the tally, ahead of spread_field
rep('''template <typename T, typename E>
with_slope<typename Species<T,E>::value_type>
Species<T,E>::spread_field(const value_type& height) const {''', '''template <typename T, typename E>
bool Species<T,E>::prefix_despite_order(bool ordered, bool spread) const {
  using odelia::util::to_passive;
  probe::order_tally& t = probe::tally(!std::is_same_v<value_type, double>);
  ++t.builds;
  if (ordered) {
    ++t.ordered;
    return false;
  }
  double node_inversion = 0.0;
  long pairs = 0;
  for (std::size_t i = 1; i < size(); ++i) {
    const double up = to_passive(nodes[i].height()) - to_passive(nodes[i - 1].height());
    if (up > 0.0) {
      ++pairs;
      node_inversion = std::max(node_inversion, up);
    }
  }
  const double boundary_inversion = spread
    ? std::max(0.0, to_passive(new_node.height()) - to_passive(nodes.back().height()))
    : 0.0;
  if (pairs > 0) {
    ++t.node_disorder;
    ++t.node_hist[probe::decade_bin(node_inversion)];
  }
  if (boundary_inversion > 0.0) {
    ++t.boundary_disorder;
    ++t.boundary_hist[probe::decade_bin(boundary_inversion)];
  }
  t.most_pairs = std::max(t.most_pairs, pairs);
  t.max_node_inversion = std::max(t.max_node_inversion, node_inversion);
  t.max_boundary_inversion = std::max(t.max_boundary_inversion, boundary_inversion);
  const double time = new_node.introduction_time();
  t.first_time = std::min(t.first_time, time);
  t.last_time = std::max(t.last_time, time);
  const int mode = probe::order_mode();
  const bool prefix = mode == 2 ||
    (mode == 1 && node_inversion <= probe::order_tol() &&
     boundary_inversion <= probe::order_tol());
  ++(prefix ? t.fixed : t.walked);
  return prefix;
}

template <typename T, typename E>
with_slope<typename Species<T,E>::value_type>
Species<T,E>::spread_field(const value_type& height) const {''')
open(f, 'w').write(s)
print("ok")
