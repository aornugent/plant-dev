# Three pull requests to traitecoevo

One file each: the title, the body, and the first comment to post when the pull
request opens.

## Shape

Written to `traitecoevo/plant-meta/governance/commit-messages.md`, which is
stricter than either repository's template says. Every family repo squash-
merges, so the title and body **are** the commit message:

- Subject imperative, sentence case, no full stop, at most 50 characters as
  typed. GitHub appends ` (#NNN)`. No issue number in the title.
- Body at most 20 lines, wrapped at 72, two short paragraphs: why the change
  was needed, then what changed in observable behaviour.
- Measurements, alternatives, suite counts and stacking notes go in the **first
  comment**, posted when the pull request opens rather than at merge.

The commits already carry a `Co-Authored-By:` trailer, which GitHub aggregates
into the squashed message by itself.

## Order

Each names in its `Remotes:` field a tag the one before it must cut, so checks
stay red until the predecessor has merged and been tagged. That is the landing
order, not a fault.

| | base ← head | tag on merge |
|---|---|---|
| 1 | `odelia:master` ← `ad/V4-reverse-tf24` | `v0.5.0` |
| 2 | `phylloptim:master` ← `ad/V4-reverse-tf24` | `v0.9.0` |
| 3 | `plant:develop` ← `ad/V4-reverse-tf24` | — |

Write them to `STYLE.md`. Before opening any, clear `catalog.md`: it lists what
not reach a maintainer.

## Sources

The design claims in the comments come from `docs/design/`, which is the
authority. The ecological framing and the feedback measurements come from
reports 05 and 06, which were deleted at `5d49947` and are recoverable from
the history of this repository.
