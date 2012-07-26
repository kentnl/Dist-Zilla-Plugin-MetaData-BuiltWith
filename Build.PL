
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "File::Find" => 0,
    "File::Temp" => 0,
    "Module::Build" => "0.4001",
    "Test::More" => "0.98"
  },
  "configure_requires" => {
    "Module::Build" => "0.4001"
  },
  "dist_abstract" => "Report what versions of things your distribution was built against",
  "dist_author" => [
    "Kent Fredric <kentnl\@cpan.org>"
  ],
  "dist_name" => "Dist-Zilla-Plugin-MetaData-BuiltWith",
  "dist_version" => "0.02000101",
  "license" => "perl",
  "module_name" => "Dist::Zilla::Plugin::MetaData::BuiltWith",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Class::Load" => 0,
    "Dist::Zilla::Role::ConfigDumper" => "4.101540",
    "Dist::Zilla::Role::MetaProvider" => 0,
    "Dist::Zilla::Util::EmulatePhase" => "0.01000101",
    "Moose" => "2.0",
    "MooseX::Types::Moose" => 0,
    "Readonly" => 0,
    "namespace::autoclean" => 0,
    "perl" => "5.006",
    "strict" => 0,
    "warnings" => 0
  },
  "script_files" => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
