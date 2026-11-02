# Vision-Based Traffic Signal Optimisation (VBTSO)

Computer vision applied to traffic-signal optimisation: an edge pipeline that turns a fixed traffic camera into per-zone vehicle counts and advisory signal-timing recommendations, validated in simulation. Personal portfolio project; Rabat (Morocco) is the flagship case study, and the core is city-agnostic.

**Status:** foundations and review complete; implementation (P1 data pipeline) not started.

```
camera -> detect + track + count (edge) -> counts-only JSON -> signal-timing advisor -> operator
```

- [Functional specification](functional_spec.md): what and why.
- [Technical specification](technical_spec.md): how.
- [Contributing](CONTRIBUTING.md): branch, commit and PR rules.
- [Developer guide](docs/DEVELOPER_GUIDE.md): setup and command cheat sheet.
- [Project review](docs/review/README.md): critique and decisions before implementation.

Formerly *GreenFlow Rabat*.

## Licence

AGPL-3.0, see [LICENSE](LICENSE). Copyright (c) 2026 Adam Daoudi.
