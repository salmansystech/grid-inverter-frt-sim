function fig = plot_scenario(log, sc, P)
%PLOT_SCENARIO Six-panel overview of one scenario run (per-unit signals).
fig = figure('Visible', 'off', 'Position', [100, 100, 1100, 900], 'Color', 'w');
t = log.t*1e3;   % [ms]

ax(1) = subplot(3, 2, 1);
plot(t, log.v_abc/P.Vpk);
ylabel('PCC voltage [pu]'); title('PCC phase voltages'); legend('a', 'b', 'c');

ax(2) = subplot(3, 2, 2);
plot(t, log.ig_abc/P.Ipk);
ylabel('Grid current [pu]'); title('Grid phase currents'); legend('a', 'b', 'c');

ax(3) = subplot(3, 2, 3);
plot(t, log.id, 'b', t, log.id_ref, 'b--', t, log.iq, 'r', t, log.iq_ref, 'r--');
ylabel('Current [pu]'); title('dq currents (dashed: reference)');
legend('i_d', 'i_d^*', 'i_q', 'i_q^*');

ax(4) = subplot(3, 2, 4);
plot(t, log.P/P.Sn, t, log.Q/P.Sn, t, log.u_pos);
ylabel('[pu]'); title('Power at PCC and positive-sequence voltage');
legend('P', 'Q', '|v^+|');

ax(5) = subplot(3, 2, 5);
yyaxis left;  plot(t, log.vdc/P.Vdc_ref); ylabel('V_{dc} [pu]');
yyaxis right; plot(t, log.chop);          ylabel('Chopper duty');
xlabel('Time [ms]'); title('DC link');

ax(6) = subplot(3, 2, 6);
plot(t, log.f, t, log.f_grid, '--', t, 50 + log.frt, ':');
ylabel('[Hz]'); xlabel('Time [ms]'); title('PLL frequency (dotted: FRT active, offset +1)');
legend('PLL', 'grid', 'FRT');

for a = ax
    grid(a, 'on');
end
linkaxes(ax, 'x');
xlim(ax(1), [sc.t_enable, sc.Tend]*1e3);
sgtitle(sprintf('%s: %s', strrep(sc.name, '_', '\_'), sc.description));
end
