# Control design

This document covers how each loop is designed and tuned. All gains are calculated from the plant parameters in `default_params.m`, so changing the hardware (for example a larger inductor) changes the tuning automatically.

## 1. Per-unit system and conventions

| Base | Value |
|---|---|
| S_base | 10 kVA |
| V_base | 326.6 V (phase peak of 400 V line-to-line) |
| I_base | 20.41 A (phase peak), from S = 3/2 · V · I |
| Z_base | 16 Ω, L_base = 50.9 mH |

- **Clarke transform:** amplitude-invariant, so dq magnitudes equal phase peaks. Power is calculated as p = 3/2 (v_d i_d + v_q i_q) and q = 3/2 (v_q i_d − v_d i_q).
- **PLL alignment:** the PLL aligns the d axis with the positive-sequence PCC voltage, so v_q → 0. In this frame **i_d controls active power**, and **negative i_q injects reactive power** (capacitive, voltage supporting).

## 2. Plant

### LCL filter
Per α/β axis, with the series damping resistor Rd in the capacitor branch:

```
L1 di1/dt = v_inv − R1 i1 − v_x            v_x = vc + Rd (i1 − i2)   (PCC)
Cf dvc/dt = i1 − i2
L2 di2/dt = v_x − R2 i2 − v_s              L2, R2 include the grid impedance
```

| | L1 | Cf | L2 (filter) |
|---|---|---|---|
| Value | 5 mH | 10 µF | 2 mH |
| Per unit | 0.098 | 0.050 | 0.039 |

The resonance frequency depends on the grid impedance:

| Grid | L_grid | f_res |
|---|---|---|
| SCR 20 (stiff) | 2.53 mH | 1032 Hz |
| SCR 3 (weak) | 16.9 mH | 800 Hz |

Both values are below f_s/6 ≈ 1.67 kHz. In that region, converter-side current feedback with a delay is known to need damping, so a passive resistor is used: **Rd = 4 Ω**. The common guideline 1/(3·ω_res·Cf) gives 5–7 Ω for this filter; a slightly lower value cuts losses, and the stiff and weak grid scenarios confirm the damping is enough. Active damping would avoid its losses (about 6 W of fundamental-frequency loss here, more with switching ripple) and is on the roadmap.

### DC link
```
Cdc · dVdc/dt = (P_src − P_ac)/Vdc − d_ch · Vdc/Rch
```
The brake chopper's duty `d_ch` rises linearly from 0 at 1.08 pu to 1 at 1.12 pu. An early version used an on/off hysteresis chopper. In the weak-grid fault case its switching made the DC voltage oscillate, and that oscillation coupled into the PCC voltage. The PWM chopper behaves the way real ones do and removes the problem.

## 3. Positive-sequence extraction: DSOGI

Each α/β axis has a second-order generalised integrator (SOGI) that produces an in-phase output v′ and a 90°-lagging output qv′:

```
dv′/dt  = ω (k (v − v′) − qv′)        k = √2
dqv′/dt = ω v′
```

The positive sequence is then `v⁺α = ½(v′α − qv′β)`, `v⁺β = ½(qv′α + v′β)`. The SOGI uses the PLL frequency, so it adapts to frequency changes. Its settling time constant is 2/(kω) ≈ 4.5 ms.

**Why it's needed:** in unbalanced faults the negative sequence appears as a 100 Hz ripple in the dq frame. A plain SRF-PLL would pass that ripple into the angle and the FRT detection.

## 4. PLL: SRF-PLL, amplitude-normalised

The error is `e = v_q / |v⁺|`, so the loop gain doesn't fall during voltage dips. For small angle errors `e ≈ θ_grid − θ`, which gives a standard second-order loop:

```
kp = 2 ζ ωn,   ki = ωn²,   ωn = 2π·20 rad/s,   ζ = 0.707
```

The frequency deviation is clamped to ±5 Hz.

**Gain scheduling during FRT.** When the voltage is low and the converter injects up to 1.1 pu reactive current into a weak grid (SCR 3), the injected current changes the PCC angle the PLL is tracking. With the 20 Hz PLL this oscillated at about 18 Hz and hit the frequency clamp. During FRT the bandwidth is therefore cut to 25% (5 Hz): kp scales by a and ki by a². This is a common industrial fix. The trade-off is slower tracking of phase jumps that happen *during* a fault.

## 5. Current control

PI controllers in the dq frame, with cross-coupling decoupling and PCC voltage feedforward:

```
v_d* = v_d,pcc + PI(i_d* − i_d) − ω L1 i_q
v_q* = v_q,pcc + PI(i_q* − i_q) + ω L1 i_d
```

With feedforward the plant seen by the PI is approximately 1/(s·L1). Tuning for a crossover of α_c = 2π·500 Hz (f_s/20):

```
kp = α_c · L1 = 15.7 Ω,     ki = kp · α_c / 10 = 4935 Ω/s
```

The 1.5·Ts delay costs 1.5·Ts·α_c = 27° of phase at crossover, which, together with the −90° of the integrator plant and −6° from the PI zero, leaves about 57° of phase margin.

**Feedforward of the measured (not filtered) voltage.** This includes the negative sequence, so during unbalanced faults the converter follows it and negative-sequence current stays small (sustained 1.15 pu in the single-phase dip) without a dedicated negative-sequence controller.

**Voltage limit:** |v*| ≤ 0.98 · Vdc/√3 (the SVPWM linear range, 424 V at 750 V DC). When the output saturates, the integrators stop (conditional integration).

## 6. DC-link voltage control

Linearised around the operating point:

```
dVdc/dt ≈ −(3/2 · V_pk / (Cdc · Vdc)) · i_d = −G_dc · i_d,     G_dc = 327 V/(A·s)
```

Designed for a 15 Hz crossover:

```
kp = ω_dc / G_dc = 0.29 A/V,    ki = kp · ω_dc / 4 = 6.8 A/(V·s)
```

The loop is about 30× slower than the current loop, so the two are well separated. Anti-windup uses conditional integration against the current limit.

## 7. Fault ride-through

| Element | Implementation |
|---|---|
| Detection | Positive-sequence voltage below 0.90 pu; release above 0.92 pu |
| Reactive current | `i_q* = −min(K · (0.9 − u_f), I_max)`, K = 2 (typical of European grid codes) |
| Voltage filter | u_f is \|v⁺\| through a 4 ms low-pass. This breaks the fast loop iq → PCC voltage → iq reference in weak grids. |
| Current priority | Reactive first: `i_d,max = √(I_max² − i_q*²)` |
| Current limit | I_max = 1.1 pu (peak) |
| Energy balance | The surplus DC power goes into the brake chopper |
| Recovery | Active current rise limited to 20 pu/s; reductions pass immediately |

Example targets: a 50% dip gives K · (0.9 − 0.5) = 0.8 pu. The measured injection is lower (0.68 pu) because the injected current raises the PCC voltage back towards 0.56 pu, so the curve is evaluated at that voltage. This is what the curve is designed to do. Dips to 0.35 pu or below saturate at I_max.

## 8. Known limitations

These are honest gaps, and they are the basis of the roadmap:
- **Grid-following only.** The controller needs a grid voltage to lock to. Grid-forming control (droop or virtual synchronous machine) is the natural next step.
- **No explicit negative-sequence current control.** Voltage feedforward keeps it bounded, but a dual-sequence controller would let the converter inject negative-sequence reactive current, as newer grid codes require.
- **Average model.** It doesn't show switching ripple, dead-time effects or THD.
- **Ideal sensors.** There is no ADC quantisation, offset or anti-aliasing filter delay.
- **The fault transient peak** (up to 1.7 pu for under 2 ms at fault inception) is set by the delay and filter physics. On hardware it would be caught by the converter's fast overcurrent protection. The tests check it stays below 2 pu.
