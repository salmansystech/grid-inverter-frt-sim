function results = run_test_matrix(varargin)
%RUN_TEST_MATRIX Run every scenario, check its criteria, write a report.
%   results = RUN_TEST_MATRIX() runs all scenarios in tests/scenarios.m,
%   saves one PNG per scenario and results/report.md, and throws an error
%   if any scenario fails (so CI marks the run red).
%
%   Options (name/value):
%     'plots'     true   save a PNG per scenario
%     'only'      {}     cell array of scenario names to run
%     'ctrl_fcn'  @ctrl_step  controller implementation (see run_sil)

root = add_project_paths();

opt = struct('plots', true, 'only', {{}}, 'ctrl_fcn', @ctrl_step);
for k = 1:2:numel(varargin)
    opt.(varargin{k}) = varargin{k + 1};
end

outdir = fullfile(root, 'results');
if ~exist(outdir, 'dir')
    mkdir(outdir);
end

P = default_params();
S = scenarios();
if ~isempty(opt.only)
    S = S(ismember({S.name}, opt.only));
end

results = struct('name', {}, 'description', {}, 'pass', {}, 'checks', {}, ...
                 'metrics', {}, 'plot', {});
for sc = S(:).'
    fprintf('%-18s ', sc.name);
    tic;
    log = run_simulation(P, sc, opt.ctrl_fcn);
    [checks, m] = evaluate_scenario(log, sc, P);
    ok = all([checks.pass]);

    png = '';
    if opt.plots
        try
            fig = plot_scenario(log, sc, P);
            png = [sc.name '.png'];
            exportgraphics(fig, fullfile(outdir, png), 'Resolution', 110);
            close(fig);
        catch err
            warning('run_test_matrix:plot', 'Plot for %s failed: %s', sc.name, err.message);
            png = '';
        end
    end

    results(end+1) = struct('name', sc.name, 'description', sc.description, ...
        'pass', ok, 'checks', checks, 'metrics', m, 'plot', png); %#ok<AGROW>

    if ok
        fprintf('PASS  (%.1f s)\n', toc);
    else
        failed = checks(~[checks.pass]);
        fprintf('FAIL  (%.1f s): %s\n', toc, strjoin({failed.metric}, ', '));
    end
end

write_report(results, fullfile(outdir, 'report.md'));
fprintf('\n%d/%d scenarios passed. Report: %s\n', sum([results.pass]), ...
    numel(results), fullfile(outdir, 'report.md'));

if ~all([results.pass])
    error('run_test_matrix:failed', 'One or more scenarios failed.');
end
end
