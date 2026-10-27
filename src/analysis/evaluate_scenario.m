function [res, m] = evaluate_scenario(log, sc, P)
%EVALUATE_SCENARIO Compute metrics from a simulation log and check criteria.
%   [res, m] = EVALUATE_SCENARIO(log, sc, P)
%     m    struct of metrics (NaN where a metric does not apply)
%     res  table-like struct array, one entry per criterion:
%          metric, op, limit, value, pass
%   Metric definitions are documented in docs/TEST_PLAN.md.

t   = log.t;
Sn  = P.Sn;
ig  = max(abs(log.ig_abc), [], 2)/P.Ipk;      % worst-phase grid current [pu]
on  = t >= sc.t_enable;
events = [sc.t_fault, sc.t_clear, sc.t_jump, sc.t_fstep, sc.t_Q];
events = events(isfinite(events));

%% Limits that apply to every scenario
m.i_peak_pu = max(ig(on));
quiet = on;
for te = events
    quiet = quiet & ~(t >= te & t < te + 0.01);
end
m.i_sustained_pu = max(ig(quiet));
m.vdc_max_pu = max(log.vdc(on))/P.Vdc_ref;
m.vdc_min_pu = min(log.vdc(on))/P.Vdc_ref;

%% Steady state before the first event and at the end
t_pre = min([events, sc.Tend]);
w = window(t, t_pre - 0.05, t_pre);
m.p_err_pre   = abs(mean(log.P(w)) - sc.P_set)/Sn;
m.vdc_err_pre = abs(mean(log.vdc(w)) - P.Vdc_ref)/P.Vdc_ref;

w = window(t, sc.Tend - 0.05, sc.Tend);
q_final = sc.Q_set*(sc.t_Q < sc.Tend);
m.p_err_final = abs(mean(log.P(w)) - sc.P_set)/Sn;
m.q_err_final = abs(mean(log.Q(w)) - q_final)/Sn;
m.p_osc       = std(log.P(window(t, sc.Tend - 0.1, sc.Tend)))/Sn;

%% Reactive power step
m.q_settle = NaN;
if isfinite(sc.t_Q)
    m.q_settle = settle_time(t, abs(log.Q - sc.Q_set)/Sn > 0.05, sc.t_Q);
end

%% Fault ride-through
m.iq_rise = NaN;  m.iq_track_err = NaN;  m.iq_inject = NaN;  m.p_recovery = NaN;
if isfinite(sc.t_fault)
    w = window(t, sc.t_fault + 0.04, sc.t_clear);
    iq_target = mean(log.iq_ref(w));
    m.iq_inject    = -mean(log.iq(w));
    m.iq_track_err = abs(mean(log.iq(w) - log.iq_ref(w)));
    m.iq_rise      = first_time(t, t >= sc.t_fault & log.iq <= 0.9*iq_target, sc.t_fault);
    m.p_recovery   = first_time(t, t >= sc.t_clear & log.P >= 0.9*sc.P_set, sc.t_clear);
end

%% PLL: phase jump and frequency step
m.pll_settle = NaN;
if isfinite(sc.t_jump)
    err = rad2deg(angle(exp(1j*(log.theta - log.theta_g))));
    % The PLL locks to the PCC, which sits a few degrees from the source
    % angle because of the grid impedance; compare against that offset.
    offset = mean(err(window(t, sc.t_jump - 0.05, sc.t_jump)));
    m.pll_settle = settle_time(t, abs(err - offset) > 2, sc.t_jump);
end
m.f_settle = NaN;  m.f_err_final = NaN;
if isfinite(sc.t_fstep)
    m.f_settle    = settle_time(t, abs(log.f - log.f_grid) > 0.05, sc.t_fstep);
    m.f_err_final = abs(mean(log.f(window(t, sc.Tend - 0.05, sc.Tend))) - sc.f_step);
end

%% Criteria
nc  = size(sc.criteria, 1);
res = struct('metric', cell(nc, 1), 'op', [], 'limit', [], 'value', [], 'pass', []);
for k = 1:nc
    [name, op, lim] = sc.criteria{k, :};
    v = m.(name);
    switch op
        case '<='
            ok = v <= lim;
        case '>='
            ok = v >= lim;
        otherwise
            error('evaluate_scenario:op', 'Unknown operator "%s".', op);
    end
    res(k) = struct('metric', name, 'op', op, 'limit', lim, 'value', v, 'pass', ok);
end
end

function w = window(t, a, b)
w = t >= a & t < b;
end

function d = first_time(t, cond, t0)
% Time from t0 until cond is first true; Inf if it never happens.
k = find(cond, 1, 'first');
if isempty(k)
    d = inf;
else
    d = t(k) - t0;
end
end

function d = settle_time(t, outside, t0)
% Time from t0 until the signal last leaves its tolerance band; Inf if it
% is still outside at the end of the run.
k = find(outside & t >= t0, 1, 'last');
if isempty(k)
    d = 0;
elseif k == numel(t)
    d = inf;
else
    d = t(k + 1) - t0;
end
end
