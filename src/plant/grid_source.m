function [vs_ab, vs_abc] = grid_source(P, u_abc, theta)
%GRID_SOURCE Three-phase grid source voltage behind the grid impedance.
%   u_abc  per-phase residual magnitude [pu] (1 = healthy, <1 = fault)
%   theta  source angle including any phase jump [rad]
vs_abc = P.Vpk*u_abc(:).*cos(theta + [0; -2*pi/3; 2*pi/3]);
vs_ab  = clarke(vs_abc);
end
