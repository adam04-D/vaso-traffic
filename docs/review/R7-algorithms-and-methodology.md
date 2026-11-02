# Review R7: Control algorithms, simulation and working method

Status: **decided** (2026-11-02): fairness rules approved; junction proposed from OpenStreetMap during P4 and confirmed by the owner (T-028).

## 1. Verdict

The tiers (C0 to C3) are right, but three details would make the comparison unfair or untestable as currently written:
1. **The fixed-time baseline must be tuned.** Comparing adaptive control against a badly timed fixed plan flatters the adaptive method. C0 has to be the Webster-optimal fixed plan for the scenario's average demand.
2. **Max-pressure needs downstream queues.** One camera sees only the approaches. At an isolated intersection with free-flowing exits, max-pressure reduces to "serve the phase with the largest weighted queue". We say so, and simulate both the ideal case (downstream known) and the camera-only case.
3. **Safety constraints are missing:** minimum and maximum green, amber and all-red, and pedestrian minimums. Every controller has to respect them, otherwise delays aren't comparable.

## 2. Controllers

| Tier | Method | Inputs (what a camera can give) | Notes |
|---|---|---|---|
| C0 | Fixed-time, **Webster-tuned**: cycle `C = (1.5 L + 5) / (1 - Y)`, greens proportional to flow ratios `y_i` | Average flows (offline) | Fair baseline, retuned per demand scenario |
| C1 | Adaptive Webster / queue-proportional split, recomputed each cycle | Counts per approach over the last window | Explainable, cheap |
| C2 | Max-pressure (Varaiya), phase chosen each step within min/max green | Queues per approach (and downstream if known) | Strong classical baseline in RESCO |
| C3 (stretch) | RL (DQN or PPO) via sumo-rl | Same state as C2 | Only counted as a win if it beats C2 under noisy sensing |

C0 to C2 live in `vbtso.control` as **pure functions** (state in, decision out), unit-tested without SUMO. A thin TraCI adapter connects them to the simulator. The same functions back the API's `/v1/advice`.

## 3. Simulation set-up

- **Tools:** Eclipse SUMO with TraCI (or `libsumo` for speed); **sumo-rl** (MIT licence) for the RL environment and for the **RESCO single-intersection networks**, used as a sanity check against published baselines before our own network. RESCO itself ships Fixed-time, Greedy and Max-pressure baselines.
- **Network:** one real Rabat signalised junction, imported from OpenStreetMap with `netconvert`. Signal timings and demand aren't public, so the demand is synthetic: **4 scenarios** (low, medium, high, unbalanced) with ranges informed by counts from the Rabat footage. This is stated as an assumption.
- **Sensing models:**
  - (a) ideal: SUMO lane-area detectors give true queues and counts;
  - (b) camera-only: approaches only, no downstream;
  - (c) noisy: errors drawn from the measured P3 count error (bias, variance, more misses at night).
- **Metrics:** mean delay per vehicle, mean and maximum queue, throughput, stops per vehicle. **10 seeds per scenario**, reported as mean and 95% confidence interval. One warm-up period discarded.
- **Main result to show:** a table of controller × sensing model × demand, plus a plot of delay against perception error. It answers how good the camera must be for adaptive control to pay off.

## 4. "Optimal transport"

Confirmed: not used. The problem is signal control (queueing and flow optimisation). The term stays out of the project unless a real optimal-transport component is added, such as origin-destination estimation.

## 5. Working method review

What works: specs as living documents, decision logs, issues and milestones, one PR per issue, CI gates.

Improvements:
- **Definition of done per issue:** code + tests + spec/guide updated + decision row if needed. Add it to the PR template (it is mostly there).
- **Time-box per P milestone,** written in the milestone description. When a time-box runs out, cut stretch items, don't extend.
- **Release tags:** `v0.1` after P1, then `v0.2` and so on, and `v1.0` = the MVP (R1). Each tag gets a short changelog.
- **Experiments are issues** with hypothesis, metric and result. Negative results are kept and reported.
- **Commit and PR commands:** always fill issue numbers before running. A Claude-side rule now ensures commands are given without placeholders.

## 6. Decisions requested
1. **Which Rabat junction to simulate.** Pick one you know, or let me propose one from OpenStreetMap with a signalised 4-way layout.
2. Approve the fairness rules: Webster-tuned C0, constraints for all controllers, 10 seeds, three sensing models.

## Sources
- sumo-rl (MIT, includes RESCO networks), [PyPI](https://pypi.org/project/sumo-rl); RESCO baselines, [GitHub](https://github.com/UnivOfAlabama-BittleResearchGroup/RESCO)
- LibSignal, [arXiv 2211.10649](https://ar5iv.labs.arxiv.org/html/2211.10649)
