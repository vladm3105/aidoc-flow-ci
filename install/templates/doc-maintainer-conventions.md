# Documentation maintenance conventions

- Update documentation only when the merged PR changes behavior, interfaces,
  configuration, operations, architecture, governance, or release-visible facts.
- Preserve the repository's existing voice and document ownership boundaries.
- Use `CHANGELOG.md` for concise user-visible changes, `README.md` for stable
  entry-point guidance, and `docs/` for detailed operational or technical material.
- Treat decisions, roadmaps, governance records, and handoffs as high-risk; propose
  the required change for a human instead of rewriting intent autonomously.
- Never infer dates, versions, commitments, compatibility, or completion status
  that the PR evidence does not establish.
