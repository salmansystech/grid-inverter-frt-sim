function log = run_demo(name)
%RUN_DEMO Run one scenario and show its plot. Default: 'sym_dip_50'.
%   log = RUN_DEMO('asym_1ph_20') runs that scenario from tests/scenarios.m,
%   prints its metrics and opens the six-panel figure.
if nargin < 1
    name = 'sym_dip_50';
end
add_project_paths();

P = default_params();
S = scenarios();
sc = S(strcmp({S.name}, name));
if isempty(sc)
    error('run_demo:unknown', 'Unknown scenario "%s". Available: %s', ...
        name, strjoin({S.name}, ', '));
end

log = run_simulation(P, sc);
[checks, m] = evaluate_scenario(log, sc, P);
disp(m);
for c = checks(:).'
    fprintf('%-16s %s %-6g -> %-8.4g %s\n', c.metric, c.op, c.limit, c.value, ...
        string(c.pass));
end

fig = plot_scenario(log, sc, P);
fig.Visible = 'on';
end
