function pl = plant_step(pl, P, m_ab, vs_ab, Psrc)
%PLANT_STEP Advance the plant by one plant step P.h.
%   m_ab   modulation index [alpha; beta] (phase peak / Vdc), average model
%   vs_ab  grid source voltage [alpha; beta]
%   Psrc   power delivered into the DC link by the source (PV/battery) [W]

v_inv = m_ab(:)*pl.vdc;

% AC power drawn from the DC link (amplitude-invariant Clarke)
Pac = 1.5*(v_inv(1)*pl.x(1, 1) + v_inv(2)*pl.x(1, 2));

pl.x = pl.Ad*pl.x + pl.Bd*[v_inv.'; vs_ab(:).'];

% PWM brake chopper: duty rises linearly between Vch_start and Vch_full
pl.chop = min(max((pl.vdc - P.Vch_start)/(P.Vch_full - P.Vch_start), 0), 1);

dvdc = ((Psrc - Pac)/pl.vdc - pl.chop*pl.vdc/P.Rch)/P.Cdc;
pl.vdc = max(pl.vdc + P.h*dvdc, 1);
end
