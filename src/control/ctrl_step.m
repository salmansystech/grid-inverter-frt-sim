function [s, y] = ctrl_step(s, meas, ref, c)
%CTRL_STEP One control period of the grid-following inverter controller.
%   [s, y] = CTRL_STEP(s, meas, ref, c)
%     s     controller state (see ctrl_init)
%     meas  sampled signals: i_ab [2x1] converter current [A],
%           v_ab [2x1] PCC voltage [V], vdc DC-link voltage [V]
%     ref   operator commands: q reactive power [var], enable (0/1)
%     c     parameters (default_params().ctrl)
%     y     outputs: m_ab [2x1] modulation index for the next PWM period,
%           plus internal signals for logging
%
%   Signal chain: DSOGI positive sequence -> SRF-PLL -> FRT detection ->
%   DC-link PI / reactive reference -> current limiter -> dq current PI
%   with decoupling and voltage feedforward -> delay-compensated inverse
%   Park. The function is self-contained and supports C code generation.
%#codegen

Ts = c.Ts;

%% Positive-sequence voltage: DSOGI, frequency-adaptive
kw = c.k_sogi*s.w;
s.va  = s.va  + Ts*(kw*(meas.v_ab(1) - s.va) - s.w*s.qva);
s.qva = s.qva + Ts*s.w*s.va;
s.vb  = s.vb  + Ts*(kw*(meas.v_ab(2) - s.vb) - s.w*s.qvb);
s.qvb = s.qvb + Ts*s.w*s.vb;
va_p = 0.5*(s.va - s.qvb);
vb_p = 0.5*(s.qva + s.vb);

%% SRF-PLL on the positive sequence (amplitude-normalised error)
theta = s.theta;
cs = cos(theta);
sn = sin(theta);
vd = va_p*cs + vb_p*sn;
vq = -va_p*sn + vb_p*cs;
vmag  = sqrt(vd^2 + vq^2);
u_pos = vmag/c.Vpk;
e_pll = vq/max(vmag, 0.1*c.Vpk);
% Lower bandwidth during FRT: at low voltage and high current a 20 Hz PLL
% interacts with a weak grid and loses lock
if s.frt > 0.5
    a = c.pll_frt_scale;
else
    a = 1;
end
s.pll_int = sat(s.pll_int + a^2*c.ki_pll*Ts*e_pll, c.dw_max);
s.w = c.wn + sat(a*c.kp_pll*e_pll + s.pll_int, c.dw_max);

%% Measurements in the PLL frame
id    = meas.i_ab(1)*cs + meas.i_ab(2)*sn;
iq    = -meas.i_ab(1)*sn + meas.i_ab(2)*cs;
vd_ff = meas.v_ab(1)*cs + meas.v_ab(2)*sn;
vq_ff = -meas.v_ab(1)*sn + meas.v_ab(2)*cs;

% Filtered voltage for the FRT curve, breaks the iq -> voltage -> iq loop
s.u_f = s.u_f + Ts/c.tau_u*(u_pos - s.u_f);

id_ref = 0;
iq_ref = 0;

if ref.enable > 0.5
    %% Fault ride-through detection with hysteresis
    if s.frt < 0.5 && u_pos < c.u_frt_on
        s.frt = 1;
    elseif s.frt > 0.5 && u_pos > c.u_frt_off
        s.frt = 0;
    end

    %% Current references [pu]
    if s.frt > 0.5
        % Reactive priority: capacitive current proportional to the dip
        iq_ref = -min(c.k_frt*max(c.u_frt_on - s.u_f, 0), c.i_max);
        id_max = sqrt(max(c.i_max^2 - iq_ref^2, 0));
    else
        id_max = c.i_max;
    end

    % DC-link PI -> active current, conditional-integration anti-windup
    e_dc   = meas.vdc - c.Vdc_ref;
    dc_int = s.dc_int + c.ki_dc*Ts*e_dc;
    id_dem = (c.kp_dc*e_dc + dc_int)/c.Ipk;
    id_cmd = sat(id_dem, id_max);
    if id_cmd == id_dem
        s.dc_int = dc_int;
    end
    % Rise-rate limit (active power recovery); decreases pass immediately
    id_ref = min(id_cmd, s.id_ref + c.did_max*Ts);
    s.id_ref = id_ref;

    if s.frt < 0.5
        % Active priority: reactive power command uses the remaining headroom
        iq_dem = -2*ref.q/(3*max(vd, 0.1*c.Vpk))/c.Ipk;
        iq_ref = sat(iq_dem, sqrt(max(c.i_max^2 - id_ref^2, 0)));
    end

    %% dq current PI with decoupling and PCC voltage feedforward
    ed = id_ref*c.Ipk - id;
    eq = iq_ref*c.Ipk - iq;
    wL = s.w*c.L1;
    int_d = s.int_d + c.ki_i*Ts*ed;
    int_q = s.int_q + c.ki_i*Ts*eq;
    vd_ref = vd_ff + c.kp_i*ed + int_d - wL*iq;
    vq_ref = vq_ff + c.kp_i*eq + int_q + wL*id;

    % Voltage limit (SVPWM linear range); integrate only when unsaturated
    vmax = c.m_max*max(meas.vdc, 1);
    vref_mag = sqrt(vd_ref^2 + vq_ref^2);
    if vref_mag > vmax
        vd_ref = vd_ref*vmax/vref_mag;
        vq_ref = vq_ref*vmax/vref_mag;
    else
        s.int_d = int_d;
        s.int_q = int_q;
    end
else
    % Disabled: follow the PCC voltage so no current flows, reset loops
    vd_ref = vd_ff;
    vq_ref = vq_ff;
    s.frt = 0;
    s.dc_int = 0;
    s.int_d = 0;
    s.int_q = 0;
    s.id_ref = 0;
end

%% Inverse Park, rotated forward by the 1.5*Ts PWM + computation delay
th_c = theta + 1.5*s.w*Ts;
vdc  = max(meas.vdc, 1);
m_ab = [vd_ref*cos(th_c) - vq_ref*sin(th_c);
        vd_ref*sin(th_c) + vq_ref*cos(th_c)]/vdc;

s.theta = mod(theta + s.w*Ts, 2*pi);

y.m_ab   = m_ab;
y.theta  = theta;
y.f      = s.w/(2*pi);
y.u_pos  = u_pos;
y.id     = id/c.Ipk;
y.iq     = iq/c.Ipk;
y.id_ref = id_ref;
y.iq_ref = iq_ref;
y.frt    = s.frt;
end

function y = sat(x, lim)
y = min(max(x, -lim), lim);
end
