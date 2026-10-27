function log = run_simulation(P, sc, ctrl_fcn)
%RUN_SIMULATION Closed-loop simulation of one scenario.
%   log = RUN_SIMULATION(P, sc) runs the plant at P.h and the controller at
%   P.Ts, the way a real-time HIL rig separates the simulated plant from
%   the controller under test. ctrl_fcn defaults to @ctrl_step; pass the
%   generated MEX (@ctrl_step_mex) to run the same scenario software-in-the-
%   loop. The controller output is applied one control period later, as on
%   a DSP that updates the PWM registers at the next period.

if nargin < 3
    ctrl_fcn = @ctrl_step;
end

c  = P.ctrl;
pl = plant_init(P, sc);
s  = ctrl_init(c);
N  = round(sc.Tend/P.Ts);

m_apply = [0; 0];
theta_src = 0;    % source angle without phase offset [rad]

log.t       = (0:N-1).'*P.Ts;
log.vdc     = zeros(N, 1);
log.chop    = zeros(N, 1);
log.v_abc   = zeros(N, 3);
log.ig_abc  = zeros(N, 3);
log.P       = zeros(N, 1);
log.Q       = zeros(N, 1);
log.theta   = zeros(N, 1);
log.theta_g = zeros(N, 1);
log.f       = zeros(N, 1);
log.f_grid  = zeros(N, 1);
log.u_pos   = zeros(N, 1);
log.id      = zeros(N, 1);
log.iq      = zeros(N, 1);
log.id_ref  = zeros(N, 1);
log.iq_ref  = zeros(N, 1);
log.frt     = zeros(N, 1);

for k = 1:N
    t  = log.t(k);
    in = scenario_inputs(sc, t);

    % Sample, then run the controller
    [v_ab, i1_ab, i2_ab] = plant_meas(pl);
    meas = struct('i_ab', i1_ab, 'v_ab', v_ab, 'vdc', pl.vdc);
    ref  = struct('q', in.q, 'enable', in.enable);
    [s, y] = ctrl_fcn(s, meas, ref, c);

    log.vdc(k)       = pl.vdc;
    log.chop(k)      = pl.chop;
    log.v_abc(k, :)  = inv_clarke(v_ab).';
    log.ig_abc(k, :) = inv_clarke(i2_ab).';
    log.P(k)         = 1.5*(v_ab(1)*i2_ab(1) + v_ab(2)*i2_ab(2));
    log.Q(k)         = 1.5*(v_ab(2)*i2_ab(1) - v_ab(1)*i2_ab(2));
    log.theta(k)     = y.theta;
    log.theta_g(k)   = theta_src + in.phi;
    log.f(k)         = y.f;
    log.f_grid(k)    = in.f;
    log.u_pos(k)     = y.u_pos;
    log.id(k)        = y.id;
    log.iq(k)        = y.iq;
    log.id_ref(k)    = y.id_ref;
    log.iq_ref(k)    = y.iq_ref;
    log.frt(k)       = y.frt;

    % Plant runs n_sub steps with the modulation computed one period earlier
    for j = 1:P.n_sub
        vs_ab = grid_source(P, in.u_abc, theta_src + in.phi);
        pl = plant_step(pl, P, m_apply, vs_ab, in.Psrc);
        theta_src = theta_src + 2*pi*in.f*P.h;
    end
    m_apply = y.m_ab;
end
end
