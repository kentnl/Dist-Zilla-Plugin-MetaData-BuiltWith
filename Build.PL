
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.4007"
  },
  "configure_requires" => {
    "Module::Build" => "0.4007"
  },
  "dist_abstract" => "Report what versions of things your distribution was built against",
  "dist_author" => [
    "Kent Fredric <kentnl\@cpan.org>"
  ],
  "dist_name" => "Dist-Zilla-Plugin-MetaData-BuiltWith",
  "dist_version" => "0.03000101",
  "license" => "perl",
  "module_name" => "Dist::Zilla::Plugin::MetaData::BuiltWith",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
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
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => "0.98"
  }
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  my $tr = delete $module_build_args{test_requires};
  my $br = $module_build_args{build_requires};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
