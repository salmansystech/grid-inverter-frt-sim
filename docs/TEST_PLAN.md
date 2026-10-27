# Test plan

The test matrix in `tests/scenarios.m` is the acceptance test for the controller. Each scenario applies one grid event and checks the response against limits written in the style of a grid code. `scripts/run_test_matrix.m` runs them all and writes `results/report.md`. The run fails if any limit is violated, which is how CI catches regressions.

## Common sequence

Every scenario follows the same timeline, so results are comparable:

| Time | Event |
|---|---|
| 0 – 0.1 s | Converter disabled. Controller tracks the PCC voltage and the PLL and DSOGI settle. |
| 0.1 s | Converter enabled; DC-link control active |
| 0.15 – 0.25 s | DC source ramps 0 → 10 kW (1 pu) |
| 0.45 s | **Scenario event** (fault, step or jump) |
| 0.60 s | Fault cleared (FRT scenarios) |
| 0.6 – 1.0 s | Recovery; end-of-run checks |

## Scenarios

| Scenario | Event | What it proves |
|---|---|---|
| `steady_state` | None | Start-up, power tracking, DC-link regulation |
| `q_step` | Q: 0 → 5 kvar at full P | Reactive power control and the current limiter (\|S\| = 1.12 pu) |
| `sym_dip_50` | 3-phase dip to 50%, 150 ms | FRT reactive current on the proportional part of the curve |
| `sym_dip_20` | 3-phase dip to 20%, 150 ms | FRT at the current limit, chopper absorbing surplus power |
| `sym_dip_05` | 3-phase dip to 5%, 150 ms | Near-zero voltage ride-through; PLL kept alive by amplitude normalisation |
| `asym_1ph_20` | Phase a to 20%, 150 ms | Unbalanced fault: DSOGI rejects the negative sequence, negative-sequence current stays bounded |
| `asym_2ph_50` | Phases b, c to 50%, 150 ms | Second unbalanced type |
| `phase_jump_20` | +20° phase jump | PLL dynamics |
| `freq_step` | 50 → 49.5 Hz | PLL frequency tracking, frequency-adaptive DSOGI |
| `weak_scr3` | Full power at SCR 3 | Small-signal stability on a weak grid |
| `weak_scr3_dip50` | 50% dip at SCR 3 | FRT on a weak grid, where PLL and voltage interaction is strongest |

## Metrics

All metrics are computed in `src/analysis/evaluate_scenario.m`. Currents are the **grid-side** current i2, worst phase, in pu of the rated peak. Powers are measured at the PCC.

| Metric | Definition |
|---|---|
| `i_peak_pu` | Maximum current after enable, including fault-inception spikes |
| `i_sustained_pu` | Maximum current excluding the first 10 ms after each event (what thermal limits and slow protection see) |
| `vdc_max_pu`, `vdc_min_pu` | DC-link extremes after enable |
| `p_err_pre`, `vdc_err_pre` | Mean P and Vdc error over the 50 ms before the event |
| `p_err_final`, `q_err_final` | Mean P and Q error over the last 50 ms |
| `p_osc` | Standard deviation of P over the last 100 ms (sustained oscillation detector) |
| `q_settle` | Time after the Q step until Q stays within ±5% of S_n |
| `iq_rise` | Time from fault inception until i_q reaches 90% of its steady-state FRT reference |
| `iq_track_err` | Mean \|i_q − i_q*\| during the fault, from 40 ms after inception to clearing |
| `p_recovery` | Time after fault clearing until P is back to 90% of its pre-fault value |
| `pll_settle` | Time after a phase jump until the PLL angle error stays within ±2° (relative to its pre-jump offset, which comes from the grid impedance) |
| `f_settle`, `f_err_final` | Frequency tracking time (±0.05 Hz band) and final error |

## Limits and rationale

| Metric | Limit | Rationale |
|---|---|---|
| `i_sustained_pu` | ≤ 1.20 (≤ 1.25 on weak grid) | Converter current is limited to 1.1 pu; the grid-side current also carries the filter capacitor current and some negative sequence in unbalanced faults |
| `i_peak_pu` | ≤ 2.0 | Typical fast overcurrent (desaturation) trip level. Spikes below this are tolerated by the hardware. |
| `vdc_max_pu` | ≤ 1.15 | Margin to DC-link capacitor and semiconductor ratings; the chopper must hold it |
| `vdc_min_pu` | ≥ 0.90 | Below this the converter runs out of voltage to control current |
| `iq_rise` | ≤ 30 ms (≤ 50 ms on weak grid) | Rise-time requirement in the style of European grid codes for fast fault current injection |
| `iq_track_err` | ≤ 0.05 pu | Injected current must match the curve |
| `p_recovery` | ≤ 100 ms | Fast active power recovery after clearing |
| `q_settle` | ≤ 20 ms | Reactive power response is bounded by the current loop, not by an outer loop |
| `pll_settle` | ≤ 100 ms | About five periods to re-lock after a 20° jump |
| `f_settle`, `f_err_final` | ≤ 150 ms, ≤ 0.01 Hz | The PI-type PLL must have zero steady-state frequency error |
| `p_err_*`, `q_err_final` | ≤ 2–3% of S_n | Filter losses and capacitor reactive power cause a small offset |
| `p_osc` | ≤ 1% of S_n | No sustained oscillation |

The grid-code references set the *style* of the limits (rise time, curve tracking, recovery). They are not a compliance claim for any specific grid code.

## Adding a scenario

Add one entry to `tests/scenarios.m`:

```matlab
S(end+1) = make_scenario('sym_dip_35_long', fault{:}, ...
    'description', 'Three-phase dip to 35 % for 400 ms', ...
    't_clear', 0.85, 'Tend', 1.3, ...
    'u_fault', [0.35, 0.35, 0.35], 'criteria', [base; frt]);
```

Available stimuli (`make_scenario`): `SCR`, `P_set`, `P_ramp`, `Q_set`/`t_Q`, `u_fault`/`t_fault`/`t_clear`, `jump_deg`/`t_jump`, `f_step`/`t_fstep`. Criteria are rows of `{metric, '<=' | '>=', limit}`.

## Software-in-the-loop

`scripts/run_sil.m` generates C code from `ctrl_step` and runs four scenarios (`steady_state`, `sym_dip_20`, `asym_1ph_20`, `weak_scr3_dip50`) twice: once with the MATLAB controller and once with the compiled one. It passes if grid current, DC voltage and i_q agree within 1e-6 pu at every sample. This shows the code that would run on the target is the code that was tested.
