function in = scenario_inputs(sc, t)
%SCENARIO_INPUTS Time-varying stimuli of a test scenario at time t.
%   in.Psrc    DC source power [W]
%   in.q       reactive power command [var]
%   in.enable  converter enable (0/1)
%   in.u_abc   per-phase grid source magnitude [pu]
%   in.phi     source phase offset [rad]
%   in.f       source frequency [Hz]
in.Psrc   = min(max(t - sc.t_P, 0)*sc.P_ramp, sc.P_set);
in.q      = sc.Q_set*(t >= sc.t_Q);
in.enable = double(t >= sc.t_enable);

if t >= sc.t_fault && t < sc.t_clear
    in.u_abc = sc.u_fault;
else
    in.u_abc = [1, 1, 1];
end

in.phi = deg2rad(sc.jump_deg)*(t >= sc.t_jump);

if t >= sc.t_fstep
    in.f = sc.f_step;
else
    in.f = 50;
end
end
