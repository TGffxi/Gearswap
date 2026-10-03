local a = require('tests.lib.assertions')
local b = require('tests.fixtures.baselines')
return function()
    a.equal(b.rahvin_version, '2.1.0')
    a.equal(b.rahvin_commit, 'f1cda1e41f567b16ec592e6598cda71bb04392d0')
    a.equal(b.fork_start_commit, '8bca6c48d437f93932ccf38313ae3d0a472b626e')
    a.equal(b.luashitacast_commit, '7ed398edd3ebbdc8af86a79e5d3427da42e3a34a')
    a.equal(b.ashita_v4_commit, '4171c74c8ddb2ca2a31654f199e6c1cee40d7256')
end
