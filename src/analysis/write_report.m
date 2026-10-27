function write_report(results, file)
%WRITE_REPORT Write the test-matrix results as a Markdown report.
%   results is the struct array returned by run_test_matrix.
fid = fopen(file, 'w');
if fid < 0
    error('write_report:open', 'Cannot open %s for writing.', file);
end
cleanup = onCleanup(@() fclose(fid));

n_pass = sum([results.pass]);
fprintf(fid, '# Test matrix report\n\n');
fprintf(fid, 'Generated %s with MATLAB %s. **%d of %d scenarios passed.**\n\n', ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')), version('-release'), ...
    n_pass, numel(results));

fprintf(fid, '| Scenario | Description | Result |\n|---|---|---|\n');
for r = results(:).'
    fprintf(fid, '| [%s](#%s) | %s | %s |\n', r.name, r.name, r.description, verdict(r.pass));
end

for r = results(:).'
    fprintf(fid, '\n<a id="%s"></a>\n## %s\n\n%s\n\n', r.name, r.name, r.description);
    fprintf(fid, '| Metric | Limit | Value | Result |\n|---|---|---|---|\n');
    for c = r.checks(:).'
        fprintf(fid, '| `%s` | %s %g | %.4g | %s |\n', c.metric, c.op, c.limit, c.value, verdict(c.pass));
    end
    if ~isempty(r.plot)
        fprintf(fid, '\n![%s](%s)\n', r.name, r.plot);
    end
end
end

function s = verdict(ok)
if ok
    s = 'PASS';
else
    s = '**FAIL**';
end
end
