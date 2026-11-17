# Vision-Based Traffic Signal Optimisation (VBTSO)

A computer vision and data science project on traffic video. It detects vehicles (including local classes such as three-wheelers), then tracks and counts them, and analyses the counts. It also measures how a detector trained on Indian fixed-CCTV footage (BMD-45) transfers to Rabat streets. Every experiment is tracked in MLflow. This is a personal portfolio project.

**Status:** the scope was simplified on 2026-11-17. Next comes D1, data and EDA.

```
images/video -> detect -> track -> count -> traffic analytics
                  |                   |
                  +---- MLflow: experiments, metrics, model registry
```

| Milestone | Question |
|---|---|
| D1 Data and EDA | What do the datasets look like, and where are their problems? |
| D2 Detector and MLflow | Which training choices matter, and where does the model fail? |
| D3 Domain shift | How much accuracy is lost going from India to Rabat, and how much does fine-tuning recover? |
| D4 Tracking and counting | How accurate are the counts? |
| D5 Traffic analytics | What do the counts say about the traffic? |

- [Project plan](docs/PROJECT.md): goals, data, metrics, roadmap and decisions.
- [Developer guide](docs/DEVELOPER_GUIDE.md): setup and command cheat sheet.
- [Contributing](CONTRIBUTING.md): branch, commit and PR rules.

Formerly *GreenFlow Rabat*.

## Licence

AGPL-3.0, see [LICENSE](LICENSE). Copyright (c) 2026 Adam Daoudi.
