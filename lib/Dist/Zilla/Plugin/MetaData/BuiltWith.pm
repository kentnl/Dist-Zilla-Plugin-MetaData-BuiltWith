use strict;
use warnings;

package Dist::Zilla::Plugin::MetaData::BuiltWith;

# ABSTRACT: Report what versions of things your distribution was built against

=head1 SYNOPSIS

  [MetaData::BuiltWith]
  include = Some::Module::Thats::Not::In::Preq
  exclude = Some::Module::Youre::Ashamed::Of
  show_uname = 1           ; default is 0
  uname_call = uname        ; the default
  uname_args = -s -r -m -p  ; the default is -a


=head1 DESCRIPTION

Often, distribution authors get module dependencies wrong. So in such cases,
its handy to be able to see what version of various packages they built with.

Some would prefer to demand everyone install the same version as they did,
but thats also not always nessecary.

Hopefully, the existance of the metadata provided by this module will help
users on thier end machines make intelligent choices about what modules to
install in the event of a problem.



=head1 EXAMPLE OUTPUT ( META.json )

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

use Moose;
use Carp qw( croak );
use namespace::autoclean;
with 'Dist::Zilla::Role::MetaProvider';

=method mvp_multivalue_args

This module can take, as parameters, any volume of 'exclude' or 'include' arguments.

=cut

sub mvp_multivalue_args { qw( exclude include ) }

has exclude => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );
has include => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );
has show_uname  => ( is       => 'ro',  isa => 'Bool', default => 0 );
has uname_call  => ( is       => 'ro',  isa => 'Str',  default => 'uname' );
has uname_args  => ( is       => 'ro',  isa => 'Str',  default => '-a' );
has _uname_args => ( init_arg => undef, is  => 'ro',   isa     => 'ArrayRef', lazy_build => 1 );
has _stash_key  => ( is       => 'ro',  isa => 'Str',  default => 'x_BuiltWith' );

around dump_config => sub {
  my ( $orig, $self ) = @_;
  my $config      = $self->$orig();
  my $thisconfig  = { show_uname => $self->show_uname, _stash_key => $self->_stash_key };
  my $unameconfig = {};
  if ( $self->show_uname ) {
    $unameconfig->{uname_call} = $self->uname_call;
    $unameconfig->{uname_args} = $self->_uname_args;
    $thisconfig->{uname}       = $unameconfig;
  }
  if ( @{ $self->exclude } ) {
    $thisconfig->{exclude} = $self->exclude;
  }
  if ( @{ $self->include } ) {
    $thisconfig->{include} = $self->include;
  }

  $config->{ '' . __PACKAGE__ } = $thisconfig;
  return $config;
};

sub _uname {
  my $self = $_[0];
  return () unless $self->show_uname;
  if ( open my $fh, '-|', $self->uname_call, @{ $self->_uname_args } ) {
    my $str;
    {
      local $/ = undef;
      $str = <$fh>;
    }
    chomp $str;

    return ( 'uname', $str );
  }
  else {
    my ( $x, $y ) = ( $@, $! );
    $self->zilla->log('Error calling uname:');
    $self->zilla->log( '   $@ :' . $x );
    $self->zilla->log( '   $! :' . $y );
    return ();
  }
}

sub _build__uname_args {
  my $self = $_[0];
  return [ grep { defined $_ && $_ ne '' } split /\s+/, $self->uname_args ];
}

sub _get_prereq_modnames {
  my ($self) = @_;
  my %modnames;
  my $prereqs = $self->zilla->prereqs->as_string_hash;
  return [] unless defined $prereqs;
  for my $phase ( keys %{$prereqs} ) {
    next unless defined $prereqs->{$phase};
    for my $type ( keys %{ $prereqs->{$phase} } ) {
      next unless defined $prereqs->{$phase}->{$type};
      for my $module ( keys %{ $prereqs->{$phase}->{$type} } ) {
        $modnames{$module} = 1;
      }
    }
  }
  return [ sort { $a cmp $b } keys %modnames ];
}

{
  my $context = 0;

  sub _logonce {
    my ( $self, $module, $reason, $error ) = @_;
    my $message = "Possible Error: Module '$module' $reason.";
    if ( not $context and not $ENV{BUILTWITH_TRACE} ) {
      $context++;
      $message .= "set BUILTWITH_TRACE=1 for details";
    }
    $self->zilla->log($message);
    if ( $ENV{BUILTWITH_TRACE} ) {
      $self->zilla->log( '$@ : ' . $error->[0] );
      $self->zilla->log( '$! : ' . $error->[1] );
    }
    return;
  }

}

sub _detect_installed {
  my ( $self, $module ) = @_;
  my $success = undef;
  if ( $module eq 'perl' ) {
    return "NA(skipped: perl)";
  }
  eval "require $module; \$success = 1";
  my $lasterror = [ $@, $! ];
  if ( not $success ) {
    $self->_logonce( $module, 'did not load', $lasterror );
    return "NA(possibly not installed)";
  }
  my $modver;
  $success = undef;
  eval "\$modver = $module->VERSION(); \$success = 1";
  $lasterror = [ $@, $! ];
  if ( not $success ) {
    $self->_logonce( $module, ' died assessing its version', $lasterror );
    return "NA(version could not be resolved)";
  }
  if ( not defined $modver ) {
    $self->_logonce( $module, ' reported an undefined version', $lasterror );
    return "NA(undef)";
  }
  return "$modver";
}

=method metadata

This module scrapes together the name of all modules that exist in the "Prereq" section
that Dist::Zilla collects, and then works out what version of things you have,
applies the various include/exclude rules, and ships that data back to Dist::Zilla
via this method. See L<Dist::Zilla::Role::MetaProvider> for more details.

=cut

sub metadata {
  my ($self) = @_;

  my $report = $self->_get_prereq_modnames();
  my %modtable = map { $_, $self->_detect_installed($_) } ( @{$report}, @{ $self->include } );
  for my $badmodule ( @{ $self->exclude } ) {
    delete $modtable{$badmodule} if exists $modtable{$badmodule};
  }

  return {
    $self->_stash_key,
    {
      modules  => \%modtable,
      perl     => $],
      platform => $^O,
      $self->_uname(),
    }
  };
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
