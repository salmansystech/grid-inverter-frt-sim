# Future work

The current version is a validated grid-following inverter with fault ride-through, tested at model level (MIL) and with generated code (SIL). The items below are ordered roughly by how much they add relative to effort. Each one says what to build, why it matters, and how to tell when it's done.

## Near term

### 1. Simulink and Simscape harness
- **What:** a Simulink model with `ctrl_step` inside a *MATLAB Function* block running at 10 kHz, and the plant in Simscape Electrical: an average-value converter first, then IGBT switching with SVPWM.
- **Why:** most industrial teams, including RTDS users who build test benches in Simulink, work in Simulink. It also makes a switching model straightforward to add.
- **Done when:** the Simulink run of `sym_dip_50` matches `run_simulation` within a few percent on every metric.

### 2. Switching model and power quality
- **What:** a switched converter at 10 kHz, dead-time, and THD/TDD of the grid current calculated over whole cycles.
- **Why:** the LCL filter exists because of switching ripple. Showing THD below 5% (in the spirit of IEEE 519) proves the filter design.
- **Done when:** a `thd_pct` metric is added to the test matrix and passes on `steady_state` and `weak_scr3`.

### 3. Active damping of the LCL
- **What:** capacitor-current feedback (or a notch filter) instead of the 4 Ω resistor.
- **Why:** it removes damping losses, and it's the standard industrial solution. It also shows how the resonance frequency moves relative to f_s/6 as the grid changes.
- **Done when:** all scenarios pass with `Rd = 0`, across SCR 2 to 50.

### 4. Sensor and ADC realism
- **What:** ADC quantisation (12-bit), offset and gain errors, anti-aliasing filter delay, and measurement noise.
- **Why:** these are the effects that make controllers that work in simulation fail on hardware.
- **Done when:** the test matrix still passes with realistic sensor errors switched on.

## Medium term

### 5. Dual-sequence current control
- **What:** separate positive- and negative-sequence current controllers (DDSRF or PR in αβ), with negative-sequence reactive current injection during unbalanced faults.
- **Why:** newer grid codes ask for negative-sequence injection. It also reduces the 100 Hz ripple on the DC link and in active power.
- **Done when:** new metrics `i2_neg_pu` (negative-sequence current) and `p_ripple_100hz` are added, with limits, to both asymmetric scenarios.

### 6. Grid-forming control
- **What:** droop control or a virtual synchronous machine (VSM), with virtual impedance for current limiting, compared side by side with the grid-following controller.
- **Why:** this is the main research and industry topic in converter-dominated grids. Grid-forming converters provide inertia and work in very weak or islanded grids, where grid-following control fails.
- **Done when:** the converter rides through an SCR 1.5 scenario and an islanding scenario, and the comparison is written up.

### 7. Impedance-based stability analysis
- **What:** derive or measure (by frequency sweep) the converter output impedance in dq, and check it against the grid impedance using the generalised Nyquist criterion.
- **Why:** it predicts weak-grid instabilities like the PLL issue found in this project, *before* running a time-domain simulation.
- **Done when:** a stability map over SCR and X/R predicts which simulated scenarios oscillate.

### 8. Fault and protection coverage
- **What:** longer and repeated dips, phase-angle jumps during faults, voltage swells (HVRT), RoCoF events, and anti-islanding detection.
- **Why:** this makes the test matrix closer to a full grid-code compliance plan.
- **Done when:** around 25 scenarios run in CI.

## Long term

### 9. Processor-in-the-loop (PIL)
- **What:** run the generated C library on an STM32 (for example a Nucleo-G474, which has a high-resolution timer for PWM). The plant runs in MATLAB and exchanges samples with the board each period over serial or USB.
- **Why:** it measures real execution time and memory on the target and proves the code works with fixed hardware resources.
- **Done when:** PIL results match SIL, and the worst-case execution time is under 50% of the 100 µs period.

### 10. Fixed-point implementation
- **What:** convert `ctrl_step` with Fixed-Point Designer and measure the error compared with floating point.
- **Why:** many control cards (FPGAs, low-cost DSPs) have no FPU.
- **Done when:** the fixed-point controller passes the test matrix.

### 11. Real-time HIL
- **What:** move the plant onto a real-time simulator (OPAL-RT, Typhoon HIL, or RTDS/RSCAD) and run the controller on the MCU from item 9, connected through analogue and PWM I/O.
- **Why:** this is the full industrial validation loop, the setup used in grid-technology labs.
- **Done when:** the same scenarios run in real time with the same pass/fail report.

### 12. Larger systems
- **What:** multiple inverters at one PCC, a STATCOM variant (reactive power only, voltage control mode), and an MMC/HVDC average model.
- **Why:** these scale the methods to the grid-level products that NPI and simulation teams work on.

## Housekeeping

- [ ] Commit selected plots from CI to the README
- [ ] Unit tests for the transforms, the plant discretisation (against an analytical step response) and the FRT curve, using `matlab.unittest`
- [ ] Parameter sweep script (SCR × dip depth × X/R) with a heat-map of pass/fail
- [ ] Code coverage report for `ctrl_step` in CI
