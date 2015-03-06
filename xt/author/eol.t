use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::EOL 0.17

use Test::More 0.88;
use Test::EOL;

my @files = (
    'lib/Dist/Zilla/Plugin/MetaData/BuiltWith.pm',
    'lib/Dist/Zilla/Plugin/MetaData/BuiltWith/All.pm',
    't/00-compile/lib_Dist_Zilla_Plugin_MetaData_BuiltWith_All_pm.t',
    't/00-compile/lib_Dist_Zilla_Plugin_MetaData_BuiltWith_pm.t',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/all.t',
    't/basic.t',
    't/missing.t',
    't/show_config.t',
    't/show_uname.t',
    't/yaml.t'
);

eol_unix_ok($_, { trailing_whitespace => 1 }) foreach @files;
done_testing;
