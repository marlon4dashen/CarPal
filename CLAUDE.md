# CarPal Project Instructions

## Codebase Hygiene

- Clean up obsolete code and assets as part of every change. Remove unreachable
  branches, unused types, functions, files, compatibility paths, and superseded
  image assets instead of leaving them for a later pass.
- Before deleting an asset, verify direct references, dynamically resolved asset
  names, tests, and paired resources. Runtime vehicle rendering requires both a
  full-detail base image and its matching paint mask; neither file replaces the
  other.
- Keep tests and documentation aligned with cleanup work. Do not preserve stale
  references to removed behavior or assets.
- Do not remove code or assets solely because a text search finds no literal
  reference; confirm runtime catalog and build-system usage first.
