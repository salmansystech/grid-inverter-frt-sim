function P = default_params()
%DEFAULT_PARAMS Nominal parameters for the 10 kVA grid-connected inverter.
%   P = DEFAULT_PARAMS() returns a struct with ratings, plant parameters,
%   simulation timing and controller gains. Controller gains are derived
%   from the plant values, see docs/CONTROL_DESIGN.md.

%% Ratings and per-unit base
P.Sn  = 10e3;                  % rated apparent power [VA]
P.Vll = 400;                   % grid line-to-line voltage [V rms]
P.fn  = 50;                    % nominal grid frequency [Hz]
P.wn  = 2*pi*P.fn;             % [rad/s]
P.Vpk = P.Vll*sqrt(2/3);       % phase voltage peak = 1 pu voltage [V]
P.Ipk = 2*P.Sn/(3*P.Vpk);      % phase current peak = 1 pu current [A]

%% LCL filter
P.L1 = 5e-3;   P.R1 = 0.05;    % converter-side inductor [H], ESR [Ohm]
P.Cf = 10e-6;  P.Rd = 4;       % filter capacitor [F], series damping resistor [Ohm]
P.L2 = 2e-3;   P.R2 = 0.05;    % grid-side inductor [H], ESR [Ohm]

%% Grid Thevenin impedance (scenarios override the SCR)
P.SCR = 20;                    % short-circuit ratio
P.XR  = 10;                    % X/R ratio of the grid impedance

%% DC link with brake chopper
P.Vdc_ref = 750;               % [V]
P.Cdc     = 2e-3;              % [F]
P.Rch       = 40;              % chopper resistor [Ohm]
P.Vch_start = 1.08*P.Vdc_ref;  % chopper duty starts rising [V]
P.Vch_full  = 1.12*P.Vdc_ref;  % chopper duty reaches 100 % [V]

%% Timing
P.Ts    = 1e-4;                % control period, 10 kHz [s]
P.n_sub = 10;                  % plant sub-steps per control period
P.h     = P.Ts/P.n_sub;        % plant step [s]

P.ctrl = controller_gains(P);
end

function c = controller_gains(P)
% Everything the controller needs, as numeric scalars so ctrl_step can be
% compiled with the parameters as compile-time constants.
c.Ts      = P.Ts;
c.wn      = P.wn;
c.Vpk     = P.Vpk;
c.Ipk     = P.Ipk;
c.L1      = P.L1;
c.Vdc_ref = P.Vdc_ref;
c.m_max   = 0.98/sqrt(3);      % SVPWM linear range, phase peak / Vdc

% DSOGI positive-sequence extraction
c.k_sogi = sqrt(2);

% SRF-PLL, amplitude-normalised -> 2nd-order loop wn_pll, zeta_pll
wn_pll   = 2*pi*20;
zeta_pll = 0.707;
c.kp_pll = 2*zeta_pll*wn_pll;
c.ki_pll = wn_pll^2;
c.dw_max = 2*pi*5;             % frequency deviation clamp [rad/s]
c.pll_frt_scale = 0.25;        % PLL bandwidth factor during FRT (weak-grid stability)

% Current loop: PI on L1 with crossover alpha_c
alpha_c = 2*pi*500;
c.kp_i  = alpha_c*P.L1;
c.ki_i  = c.kp_i*alpha_c/10;

% DC-link voltage loop: small-signal plant dVdc/d(id) = G_dc/s
G_dc    = 1.5*P.Vpk/(P.Cdc*P.Vdc_ref);
w_dc    = 2*pi*15;
c.kp_dc = w_dc/G_dc;
c.ki_dc = c.kp_dc*w_dc/4;

% Current limit and fault ride-through
c.i_max     = 1.1;             % peak current limit [pu]
c.u_frt_on  = 0.90;            % enter FRT below this positive-sequence voltage [pu]
c.u_frt_off = 0.92;            % leave FRT above this voltage [pu]
c.k_frt     = 2;               % reactive current gain dIq/dU [pu/pu]
c.tau_u     = 0.004;           % low-pass on the voltage feeding the FRT curve [s]
c.did_max   = 20;              % active current rise-rate limit [pu/s]
end
