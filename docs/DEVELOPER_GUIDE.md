# Developer guide

How to set up, run, change and extend the project. For *why* it's built this way, see [ARCHITECTURE.md](ARCHITECTURE.md). For *how the gains are chosen*, see [CONTROL_DESIGN.md](CONTROL_DESIGN.md).

## 1. Setup

| Need | For |
|---|---|
| MATLAB R2020a or newer | Everything (uses `exportgraphics` and `sgtitle`) |
| MATLAB Coder | Only for `run_sil` (C code generation and SIL) |
| A C compiler (`mex -setup`) | Only for `run_sil`. MinGW-w64 is free on Windows. |

No other toolbox is needed. The plant is discretised with `expm`, which is in base MATLAB, so the project also runs on **MATLAB Online** and in the free GitHub Actions MATLAB runner.

```matlab
cd grid-inverter-frt-sim
addpath scripts          % entry points; they add src/ and tests/ themselves
```

## 2. Everyday commands

| Command | What it does | Time |
|---|---|---|
| `run_demo` | Runs `sym_dip_50`, prints metrics, opens the figure | ~5 s |
| `run_demo('weak_scr3_dip50')` | Any scenario by name | ~5 s |
| `run_test_matrix` | All scenarios, PNGs, `results/report.md`; errors on any failure | ~1–2 min |
| `run_test_matrix('only', {'q_step'}, 'plots', false)` | A subset, without plots | seconds |
| `run_sil` | Generate MEX and C library, check generated code matches the model | ~1 min |

To work with the raw signals:

```matlab
P   = default_params();
S   = scenarios();
sc  = S(strcmp({S.name}, 'asym_1ph_20'));
log = run_simulation(P, sc);
plot(log.t, log.ig_abc/P.Ipk)          % every logged field is listed in run_simulation.m
[checks, m] = evaluate_scenario(log, sc, P);
```

## 3. Code layout and rules

```
src/params    one place for every number           default_params.m
src/plant     physics only, no control logic        plant_*.m, grid_source.m
src/control   controller only, must stay codegen-safe   ctrl_init.m, ctrl_step.m
src/sim       wiring and timing                      run_simulation.m
src/analysis  metrics, plots, report
tests         scenarios and criteria (data)
scripts       entry points
```

Rules that keep the structure intact:

1. **The plant and the controller never call each other.** They meet only in `run_simulation`, through `meas` (sensor samples) and `m_ab` (modulation). This mirrors a HIL rig.
2. **`ctrl_step` stays code-generatable:**
   - no `persistent`, globals, variable-size arrays, cell arrays, strings or `fprintf`;
   - every state field is a double scalar that is created in `ctrl_init`;
   - every output field is assigned on every path;
   - keep `%#codegen` at the top. The MATLAB Code Analyzer then flags unsupported constructs while you type.
3. **No magic numbers in the controller.** New parameters go into `controller_gains` in `default_params.m`, with a comment giving the unit.
4. **Gains are derived, not typed.** Write a gain as a formula of plant values (for example `kp_i = alpha_c*L1`), so changing the hardware retunes the loop.
5. **Units:** SI inside the plant. In the controller, currents are converted to pu at the reference and limiter stage, and the conversion is commented.
6. **Style:** match the existing files: a one-line H1 comment, `%%` sections, aligned assignments for parameter blocks.

## 4. Common tasks

### Change a plant or controller parameter
Edit `default_params.m`, then run `run_test_matrix`. If a limit fails, the report shows which metric failed and by how much, and the PNG shows why.

### Add a test scenario
Add one `make_scenario` entry in `tests/scenarios.m`. See the example in [TEST_PLAN.md](TEST_PLAN.md#adding-a-scenario). You don't need to change any code unless the scenario needs a new kind of stimulus.

### Add a new kind of grid event (for example harmonics or a voltage swell)
1. Add the field and its default to `tests/make_scenario.m` (for example `h5_pu`).
2. Produce it in `src/sim/scenario_inputs.m`.
3. Apply it in `src/plant/grid_source.m`.
4. If the event time should be excluded from `i_sustained_pu`, add it to the `events` list in `evaluate_scenario.m`.

### Add a metric
1. Compute it in `evaluate_scenario.m` as `m.<name>`. Use `NaN` when the metric doesn't apply to a scenario.
2. Document it in the metrics table in `TEST_PLAN.md`.
3. Use it in criteria as `{'<name>', '<=', limit}`.

### Add a controller feature
1. Add its state to `ctrl_init.m` and its parameters to `controller_gains`.
2. Implement it in `ctrl_step.m`. If it's worth plotting, add an output to `y` and log it in `run_simulation.m`.
3. Run `run_test_matrix`, then `run_sil` to prove it still generates code and matches.
4. Explain the design in `CONTROL_DESIGN.md`.

### Debug a failing scenario
```matlab
log = run_demo('weak_scr3_dip50');     % figure plus metric table
```
Useful signals:
- `log.frt` shows when FRT is active.
- `log.u_pos` is the voltage the controller sees.
- `log.f` against `log.f_grid` shows PLL behaviour. A PLL stuck at ±5 Hz has lost lock.
- `log.chop` is the chopper duty.
- `log.id_ref` and `log.iq_ref` show what was requested, compared with `log.id` and `log.iq`.

For loop-stability questions, temporarily set `P.ctrl.<gain>` in the workspace and call `run_simulation` directly. There's no need to edit files while you experiment.

## 5. Simulation details worth knowing

- **Timing:** the plant runs at 10 µs with 10 sub-steps per 100 µs control period. Modulation is applied one control period late, as on a DSP. Changing `P.Ts` changes both the control rate and the delay compensation automatically.
- **Discretisation:** the LCL is linear, so `plant_init` builds an exact zero-order-hold model with `expm`, recalculated for each scenario's SCR. Only the DC link uses forward Euler, which is fine because its dynamics are slow compared with 10 µs.
- **Average model:** converter voltage = modulation × Vdc. There is no switching ripple, so THD isn't meaningful yet (see [FUTURE_WORK.md](FUTURE_WORK.md)).
- **Start-up:** the filter capacitor starts at the grid voltage, and the converter is disabled until 0.1 s so the DSOGI and PLL can settle.

## 6. Continuous integration

`.github/workflows/test-matrix.yml` runs on every push and pull request:

1. sets up MATLAB (free for public repositories, through `matlab-actions/setup-matlab`);
2. runs `run_test_matrix('plots', true)`, which fails the job if any scenario fails;
3. uploads `results/` (report and plots) as a build artifact, even when the job fails.

To see the plots from CI, open the run on GitHub and download **test-matrix-results**.

`run_sil` isn't part of CI, because MATLAB Coder isn't available there without a licence.

## 7. Git workflow

- `results/` and `codegen/` are git-ignored because they are generated. Commit plots only when you deliberately update the README.
- Keep each commit to one change, and run `run_test_matrix` before pushing.
- If a change moves a metric on purpose (for example after retuning), update the limit in `tests/scenarios.m` in the same commit, and say why in the commit message.
