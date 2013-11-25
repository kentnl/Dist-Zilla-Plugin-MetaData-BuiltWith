
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.4202"
  },
  "configure_requires" => {
    "Module::Build" => "0.4202"
  },
  "dist_abstract" => "Report what versions of things your distribution was built against",
  "dist_author" => [
    "Kent Fredric <kentnl\@cpan.org>"
  ],
  "dist_name" => "Dist-Zilla-Plugin-MetaData-BuiltWith",
  "dist_version" => "0.04000002",
  "license" => "perl",
  "module_name" => "Dist::Zilla::Plugin::MetaData::BuiltWith",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Carp" => 0,
    "Class::Load" => 0,
    "Dist::Zilla::Role::ConfigDumper" => "4.101540",
    "Dist::Zilla::Role::MetaProvider" => 0,
    "Dist::Zilla::Util::EmulatePhase" => "0.01000101",
    "Module::Data" => 0,
    "Moose" => "2.0",
    "MooseX::Types::Moose" => 0,
    "Readonly" => 0,
    "namespace::autoclean" => 0,
    "perl" => "5.006",
    "strict" => 0,
    "warnings" => 0
  },
  "script_files" => [],
  "test_requires" => {
    "Test::More" => "1.001002"
  }
);


my %fallback_build_requires = (
  "Module::Build" => "0.4202",
  "Test::More" => "1.001002"
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
