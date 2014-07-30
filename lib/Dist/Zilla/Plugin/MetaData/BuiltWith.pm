use 5.008;    #  utf8
use strict;
use warnings;
use utf8;

package Dist::Zilla::Plugin::MetaData::BuiltWith;

our $VERSION = '1.001000';

# ABSTRACT: Report what versions of things your distribution was built against

# AUTHORITY

=head1 SYNOPSIS

  [MetaData::BuiltWith]
  include = Some::Module::Thats::Not::In::Preq
  exclude = Some::Module::Youre::Ashamed::Of
  show_uname = 1           ; default is 0
  show_config = 1          ; default is 0
  uname_call = uname        ; the default
  uname_args = -s -r -m -p  ; the default is -a


=head1 DESCRIPTION

Often, distribution authors get module dependencies wrong. So in such cases,
its handy to be able to see what version of various packages they built with.

Some would prefer to demand everyone install the same version as they did,
but that's also not always necessary.

Hopefully, the existence of the metadata provided by this module will help
users on their end machines make intelligent choices about what modules to
install in the event of a problem.



=head1 EXAMPLE OUTPUT ( C<META.json> )

    "x_BuiltWith" : {
       "modules" : {
          "Dist::Zilla::Role::MetaProvider" : "4.101612",
          "File::Find" : "1.15",
          "File::Temp" : "0.22",
          "Module::Build" : "0.3607",
          "Moose" : "1.07",
          "Test::More" : "0.94"
       },
       "perl" : "5.012000",
       "platform" : "MSWin32"
    },

=cut

use Moose 2.0;
use Carp qw( carp croak );
use Config qw();
use Moose qw( with has around );
use MooseX::Types::Moose qw( ArrayRef Bool Str );
use namespace::autoclean;
with 'Dist::Zilla::Role::FileMunger';

=method mvp_multivalue_args

This module can take, as parameters, any volume of 'exclude' or 'include' arguments.

=cut

sub mvp_multivalue_args { return qw( exclude include ) }

has _exclude => (
  init_arg => 'exclude',
  is       => 'ro',
  isa      => ArrayRef,
  default  => sub { [] },
  traits   => [qw( Array )],
  handles  => { exclude => 'elements', },
);

has _include => (
  init_arg => 'include',
  is       => 'ro',
  isa      => ArrayRef,
  default  => sub { [] },
  traits   => [qw( Array )],
  handles  => { include => 'elements', },

);

=option exclude

Specify modules to exclude from version reporting

    exclude = Foo
    exclude = Bar

=option include

Specify additional modules to include the version of

    include = Foo
    include = Bar

=option show_config

Report "interesting" values from C<%Config::Config>

    show_config = 1 ; Boolean

=option show_uname

Report the output from C<uname>

    show_uname = 1 ; Boolean

=option uname_call

Specify what the system C<uname> function is called

    uname_call = uname ; String

=option uname_args

Specify arguments passed to the C<uname> call.

    uname_args = -a ; String

=cut

has show_config => ( is => 'ro', isa => 'Bool', default => 0 );
has show_uname => ( is => 'ro', isa => Bool, default => 0 );
has uname_call => ( is => 'ro', isa => Str,  default => 'uname' );
has uname_args => ( is => 'ro', isa => Str,  default => '-a' );
has _uname_args => (
  init_arg   => undef,
  is         => 'ro',
  isa        => ArrayRef,
  lazy_build => 1,
  traits     => [qw( Array )],
  handles    => { _all_uname_args => 'elements', },
);
has _stash_key   => ( is => 'ro', isa => Str,  default => 'x_BuiltWith' );
has do_meta_json => ( is => 'ro', isa => Bool, default => 1 );
has do_meta_yaml => ( is => 'ro', isa => Bool, default => 1 );

around dump_config => sub {
  my ( $orig, $self ) = @_;

  my $config = $self->$orig();
  my $thisconfig = { show_uname => $self->show_uname, _stash_key => $self->_stash_key, show_config => $self->show_config };

  if ( $self->show_uname ) {
    $thisconfig->{'uname'} = {
      uname_call => $self->uname_call,
      uname_args => $self->_uname_args,
    };
  }

  if ( $self->exclude ) {
    $thisconfig->{exclude} = [ $self->exclude ];
  }
  if ( $self->include ) {
    $thisconfig->{include} = [ $self->include ];
  }

  $config->{ q{} . __PACKAGE__ } = $thisconfig;
  return $config;
};

sub _config {
  my $self = shift;
  return () unless $self->show_config;
  my @interesting = qw( git_describe git_commit_id git_commit_date myarchname gccversion osname osver );
  my $interested  = {};
  for my $key (@interesting) {
    ## no critic (ProhibitPackageVars)
    if ( defined $Config::Config{$key} and $Config::Config{$key} ne q{} ) {
      $interested->{$key} = $Config::Config{$key};
    }
  }
  return ( 'perl-config', $interested );
}

sub _uname {
  my $self = shift;
  return () unless $self->show_uname;
  {
    my $str;
    last unless open my $fh, q{-|}, $self->uname_call, $self->_all_uname_args;
    while ( my $line = <$fh> ) {
      chomp $line;
      $str .= $line;
    }
    last unless close $fh;
    return ( 'uname', $str );

  }
  ## no critic ( ProhibitPunctuationVars )

  $self->_my_log_fatal( 'Error calling uname:', $@, $! );

  return ();

}

sub _my_log_fatal {
  my ($self) = @_;
  ## no critic ( RequireInterpolationOfMetachars )
  return $self->log_fatal( [ "%s\n   %s:%s\n   %s:%s", shift, q{$@}, shift, q{$!}, shift ] );
}

sub _build__uname_args {
  my $self = shift;
  ## no critic ( RequireDotMatchAnything RequireExtendedFormatting RequireLineBoundaryMatching )
  return [ grep { defined $_ && $_ ne q{} } split /\s+/, $self->uname_args ];
}

sub _get_prereq_modnames {
  my ($self) = @_;

  my $modnames = {};

  my $prereqs = $self->zilla->prereqs->as_string_hash;
  ## use critic
  if ( not %{$prereqs} ) {
    $self->log(q{WARNING: No prereqs were found, probably a bug});
    return [];
  }
  $self->log_debug( [ '%s phases defined: %s ', scalar keys %{$prereqs}, ( join q{,}, keys %{$prereqs} ) ] );

  for my $phase_name ( keys %{$prereqs} ) {
    my $phase_data = $prereqs->{$phase_name};
    next unless defined $phase_data;
    my $phase_deps = {};
    for my $type ( keys %{$phase_data} ) {
      my $type_data = $phase_data->{$type};
      next unless defined $type_data;
      for my $module ( keys %{$type_data} ) {
        $phase_deps->{$module} = 1;
      }
    }
    $self->log_debug( [ 'Prereqs for %s: %s', $phase_name, join q{,}, keys %{$phase_deps} ] );
    $modnames = { %{$modnames}, %{$phase_deps} };

  }
  return [ sort keys %{$modnames} ];
}

{
  my $context = 0;

  sub _logonce {
    my ( $self, $module, $reason, $error ) = @_;
    my $message = "Possible Error: Module '$module' $reason.";
    if ( not $context ) {
      $context++;
      $message .= q{see "dzil build -v" for details};
    }
    $self->log($message);
    ## no critic ( RequireInterpolationOfMetachars )
    $self->log_debug( '$@ : ' . $error->[0] );
    $self->log_debug( '$! : ' . $error->[1] );
    return;
  }

}

my $module_cache = {};

sub _detect_installed {
  my ( $self, $module ) = @_;
  return $module_cache->{$module} if exists $module_cache->{$module};
  return ( $module_cache->{$module} = $self->_detect_installed_lookup($module) );
}

sub _detect_installed_lookup {
  my ( undef, $module ) = @_;
  if ( not defined $module ) {
    Carp::croak('Cannot determine a version if module=undef');
  }
  if ( 'perl' eq $module ) {
    return [ undef, undef ];
  }
  require Module::Data;
  my $d = Module::Data->new($module);

  if ( not defined $d ) {
    return [ undef, 'failed to create a Module::Data wrapper' ];
  }
  if ( not defined $d->path or not -e $d->path or -d $d->path ) {
    return [ undef, 'module was not found in INC' ];
  }

  my $v = $d->_version_emulate;

  if ( not $v ) {
    return [ undef, 'Module::MetaData could not parse a version from ' . $d->path ];
  }
  return [ $v, undef ];

}

=method metadata

This module scrapes together the name of all modules that exist in the "C<Prereqs>" section
that Dist::Zilla collects, and then works out what version of things you have,
applies the various include/exclude rules, and ships that data back to Dist::Zilla
via this method. See L<< C<Dist::Zilla>'s C<MetaProvider> role|Dist::Zilla::Role::MetaProvider >> for more details.

=cut

sub _gen_meta {
  my ($self) = @_;

  $self->log_debug(q{Metadata called});
  my $report = $self->_get_prereq_modnames();
  $self->log_debug( 'Found mods: ' . scalar @{$report} );
  my %modtable;
  my %failures;

  my $record_module = sub {
    my ($module) = @_;
    my $result = $self->_detect_installed($module);
    if ( defined $result->[0] ) {
      $modtable{$module} = $result->[0];
    }
    if ( defined $result->[1] ) {
      $failures{$module} = $result->[1];
    }
  };
  my $forget_module = sub {
    my ($badmodule) = @_;
    delete $modtable{$badmodule} if exists $modtable{$badmodule};
    delete $failures{$badmodule} if exists $failures{$badmodule};
  };

  for my $module ( @{$report} ) {
    $record_module->($module);
  }

  for my $module ( $self->include ) {
    $record_module->($module);
  }
  for my $badmodule ( $self->exclude ) {
    $forget_module->($badmodule);
  }
  my $result = {
    modules => \%modtable,
    ## no critic ( Variables::ProhibitPunctuationVars )
    perl     => { %{$^V} },
    platform => $^O,
    $self->_uname(),
    $self->_config(),
  };
  if ( keys %failures ) {
    $result->{failures} = \%failures;
  }
  return $result;
}

sub inject_package {
  my ( $self, $hash ) = @_;
  $hash->{ $self->_stash_key } = $self->_gen_meta;
  return CPAN::Meta::Converter->new($hash)->convert( version => $hash->{'meta-spec'}->{version} );
}

sub munge_meta_json {
  my ($self) = @_;

  my ($found_file) = grep { 'META.json' eq $_->name } @{ $self->zilla->files };

  croak 'META.json not found' unless $found_file;

  require JSON;
  require CPAN::Meta::Converter;
  my $old  = $found_file->code;
  my $json = JSON->new()->pretty->canonical(1);

  $found_file->code( sub { return $json->encode( $self->inject_package( $json->decode( $old->() ) ) ) } );
  return 1;
}

sub munge_meta_yaml {
  my ($self) = @_;

  my ($found_file) = grep { 'META.yml' eq $_->name } @{ $self->zilla->files };

  croak 'META.yml not found' unless $found_file;

  require YAML::Tiny;
  require CPAN::Meta::Converter;
  my $old = $found_file->code;
  $found_file->code( sub { return YAML::Tiny::Dump( $self->inject_package( YAML::Tiny::Load( $old->() ) ) ) } );
  return 1;
}

sub munge_files {
  my ($self) = @_;
  $self->munge_meta_json if $self->do_meta_json;
  $self->munge_meta_yaml if $self->do_meta_yaml;
  return;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
