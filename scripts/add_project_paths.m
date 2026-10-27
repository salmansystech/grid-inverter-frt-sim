function root = add_project_paths()
%ADD_PROJECT_PATHS Put src/ and tests/ on the MATLAB path; return repo root.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root, 'src')), fullfile(root, 'tests'));
end
