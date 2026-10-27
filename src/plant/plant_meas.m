function [v_ab, i1_ab, i2_ab] = plant_meas(pl)
%PLANT_MEAS Signals a real controller would sample.
%   v_ab   filter capacitor-branch voltage (the converter's PCC) [alpha; beta]
%   i1_ab  converter-side current (controlled current) [alpha; beta]
%   i2_ab  grid-side current [alpha; beta]
i1_ab = pl.x(1, :).';
i2_ab = pl.x(3, :).';
v_ab  = pl.x(2, :).' + pl.Rd*(i1_ab - i2_ab);
end
