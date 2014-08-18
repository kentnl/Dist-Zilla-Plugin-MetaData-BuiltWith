use strict;
use warnings;

use Test::More;
use Test::DZil;
use Path::Tiny;
use JSON::MaybeXS;

# ABSTRACT: Basic test

my $ini = simple_ini(
  [ 'GatherDir' => {} ],
  [
    'Prereqs',
    'Before' => {
      'Dist::Zilla' => 0,
      -phase        => 'runtime',
      -type         => 'requires',
    }
  ],
  [ 'MetaConfig'          => {} ],
  [ 'MetaData::BuiltWith' => {} ],
  [
    'Prereqs',
    'After' => {
      Moose  => 0,
      -phase => 'runtime',
      -type  => 'requires',
    }
  ],
  [ 'MetaJSON' => {} ],
  [ 'MetaYAML' => {} ],

);

my $root = Path::Tiny->tempdir;

$root->child('dist.ini')->spew_raw($ini);

my $dist = Builder->from_config(
  {
    dist_root => $root,
  }
);

$dist->build;

my $json = path( $dist->tempdir )->child( 'build', 'META.json' );

ok( -e $json,  'json file exists' );
ok( !-z $json, 'json file is nonzero' );

my $content = JSON::MaybeXS->new->decode( $json->slurp_raw );

ok( exists $content->{x_BuiltWith}, 'x_BuiltWith is there' );

my $xb = $content->{x_BuiltWith};

subtest 'platform' => sub {
  ok( exists $xb->{platform}, 'platform key exists' );
  ok( length $xb->{platform}, 'platform has length' );
};
subtest 'modules' => sub {
  return unless ok( exists $xb->{modules}, 'modules key exists' );
  for my $module (qw( Moose Dist::Zilla )) {
    ok( exists $xb->{modules}->{$module}, $module . ' is there' );
    like( $xb->{modules}->{$module}, qr/\d/, $module . ' has a number' );
  }
};
subtest 'perl' => sub {
  return unless ok( exists $xb->{perl}, 'perl key exists' );
  for my $field (qw( original qv version )) {
    ok( exists $xb->{perl}->{$field}, $field . ' is there' );
  }
};

done_testing;

