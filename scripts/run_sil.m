function run_sil()
%RUN_SIL Software-in-the-loop check of the generated controller code.
%   1. Generates a MEX from ctrl_step with the parameters as compile-time
%      constants, and checks that it reproduces the MATLAB controller on
%      the fault scenarios (equivalence test).
%   2. Generates a standalone C library of ctrl_step under codegen/lib,
%      i.e. the code that would be flashed to the control card.
%   Requires MATLAB Coder.

if ~license('test', 'MATLAB_Coder')
    error('run_sil:license', 'run_sil needs MATLAB Coder.');
end

root = add_project_paths();
P = default_params();
c = P.ctrl;
outdir = fullfile(root, 'codegen');
if ~exist(outdir, 'dir')
    mkdir(outdir);
end

% Example inputs fix the types and sizes of the generated interface
s0    = ctrl_init(c);
meas0 = struct('i_ab', [0; 0], 'v_ab', [0; 0], 'vdc', 0);
ref0  = struct('q', 0, 'enable', 0);
args  = {s0, meas0, ref0, coder.Constant(c)};

% codegen writes into the current folder, so build inside codegen/
old_dir = cd(outdir);
restore = onCleanup(@() cd(old_dir)); %#ok<NASGU>

%% 1. MEX for the equivalence test
fprintf('Generating MEX ...\n');
codegen('ctrl_step', '-args', args, '-o', 'ctrl_step_mex', '-d', 'mex');
addpath(outdir);

S = scenarios();
names = {'steady_state', 'sym_dip_20', 'asym_1ph_20', 'weak_scr3_dip50'};
tol = 1e-6;   % compiled maths may differ from MATLAB in the last bits
all_ok = true;
for sc = S(ismember({S.name}, names))
    ref_log = run_simulation(P, sc, @ctrl_step);
    sil_log = run_simulation(P, sc, @ctrl_step_mex);
    d = max([max(abs(ref_log.ig_abc - sil_log.ig_abc), [], 'all')/P.Ipk, ...
             max(abs(ref_log.vdc - sil_log.vdc))/P.Vdc_ref, ...
             max(abs(ref_log.iq - sil_log.iq))]);
    ok = d <= tol;
    all_ok = all_ok && ok;
    fprintf('  %-18s max deviation %.2e pu  %s\n', sc.name, d, string(ok));
end

%% 2. Standalone C library
fprintf('Generating C library ...\n');
cfg = coder.config('lib');
cfg.GenerateReport = true;
cfg.TargetLang = 'C';
codegen('-config', cfg, 'ctrl_step', '-args', args, '-d', 'lib');
fprintf('C sources: %s\n', fullfile(outdir, 'lib'));

if ~all_ok
    error('run_sil:mismatch', 'Generated code deviates from the MATLAB controller.');
end
fprintf('SIL equivalence: PASS\n');
end
