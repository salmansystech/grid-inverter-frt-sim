function pl = plant_init(P, sc)
%PLANT_INIT Build the discretised LCL + grid plant and its initial state.
%   The AC side is linear, so each alpha/beta axis uses the same exact
%   zero-order-hold discretisation (expm of the augmented matrix) at the
%   plant step P.h. States per axis: x = [i1; vc; i2]
%     i1 converter-side current, vc capacitor voltage, i2 grid current.
%   Inputs per axis: u = [v_inv; v_s] converter and grid source voltages.

% Grid Thevenin impedance from the short-circuit ratio
Zg = P.Vll^2/(sc.SCR*P.Sn);
Rg = Zg/sqrt(1 + P.XR^2);
Lg = Rg*P.XR/P.wn;

L1 = P.L1;  R1 = P.R1;  C = P.Cf;  Rd = P.Rd;
L2 = P.L2 + Lg;
R2 = P.R2 + Rg;

A = [-(R1 + Rd)/L1, -1/L1,  Rd/L1;
      1/C,           0,    -1/C;
      Rd/L2,         1/L2, -(R2 + Rd)/L2];
B = [1/L1,  0;
     0,     0;
     0,    -1/L2];

M = expm([A, B; zeros(2, 5)]*P.h);
pl.Ad = M(1:3, 1:3);
pl.Bd = M(1:3, 4:5);

pl.Rd      = Rd;
pl.Lgrid   = Lg;
pl.x       = zeros(3, 2);          % columns: alpha, beta
pl.x(2, :) = [P.Vpk, 0];           % capacitor starts at grid voltage (theta_g = 0)
pl.vdc     = P.Vdc_ref;
pl.chop    = 0;                    % chopper duty (0..1)
end
