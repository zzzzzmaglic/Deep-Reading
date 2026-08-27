# UnionTabView source provenance

- Upstream repository: `https://github.com/unionst/union-tab-view`
- Upstream tag: `1.2.0`
- Pinned commit: `abf9afc364b315d1d058975c6ebbfabde6be06ea`
- Retrieved: 2026-08-25
- Vendored sources: `GlassTabBar.swift`, `BlurFadeModifier.swift`

The uncommitted A/B diagnostic additionally contains `UnionTabView.swift` from
commit `7f901757c7b6e4cca62cf637f8e005ea366b4c7d`. It is not used by the
production tab bar and must not change the pinned production provenance above
unless the diagnostic is explicitly adopted.

The source files are copied from the pinned upstream commit rather than linked
through Swift Package Manager. `UPSTREAM_README.md` preserves the README from
that revision.

The upstream README declares the project as MIT licensed, but tag `1.2.0` does
not contain a standalone license file. Confirm the upstream licensing text
before commercial distribution.
