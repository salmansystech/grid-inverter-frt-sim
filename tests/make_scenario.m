function sc = make_scenario(name, varargin)
%MAKE_SCENARIO Scenario struct with defaults, overridden by name/value pairs.
%   Default: converter enables at 0.1 s, the DC source ramps to 10 kW from
%   0.15 s to 0.25 s, healthy stiff grid (SCR 20), no events.
sc.name        = name;
sc.description = '';
sc.Tend        = 0.6;
sc.SCR         = 20;
sc.t_enable    = 0.1;
sc.P_set       = 10e3;    % [W]
sc.t_P         = 0.15;    % [s]
sc.P_ramp      = 100e3;   % [W/s]
sc.Q_set       = 0;       % [var]
sc.t_Q         = inf;
sc.t_fault     = inf;     % fault applied at the grid source
sc.t_clear     = inf;
sc.u_fault     = [1, 1, 1];
sc.t_jump      = inf;
sc.jump_deg    = 0;
sc.t_fstep     = inf;
sc.f_step      = 50;
sc.criteria    = cell(0, 3);   % rows: {metric, '<=' or '>=', limit}

for k = 1:2:numel(varargin)
    if ~isfield(sc, varargin{k})
        error('make_scenario:unknownField', 'Unknown scenario field "%s".', varargin{k});
    end
    sc.(varargin{k}) = varargin{k + 1};
end
end
