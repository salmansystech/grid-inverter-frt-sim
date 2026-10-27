function s = ctrl_init(c)
%CTRL_INIT Initial controller state. All fields are double scalars so the
%   state struct has a fixed type for code generation.
%#codegen
s.va     = 0;      % DSOGI alpha: in-phase output
s.qva    = 0;      % DSOGI alpha: quadrature output
s.vb     = 0;      % DSOGI beta: in-phase output
s.qvb    = 0;      % DSOGI beta: quadrature output
s.theta  = 0;      % PLL angle [rad]
s.w      = c.wn;   % PLL frequency [rad/s]
s.pll_int = 0;     % PLL integrator [rad/s]
s.dc_int = 0;      % DC-link PI integrator [A]
s.int_d  = 0;      % d-axis current PI integrator [V]
s.int_q  = 0;      % q-axis current PI integrator [V]
s.id_ref = 0;      % rate-limited active current reference [pu]
s.frt    = 0;      % 1 while fault ride-through is active
s.u_f    = 1;      % filtered positive-sequence voltage [pu]
end
