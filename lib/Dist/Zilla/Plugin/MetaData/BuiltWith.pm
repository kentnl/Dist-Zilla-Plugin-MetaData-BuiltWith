use strict;
use warnings;

package Dist::Zilla::Plugin::MetaData::BuiltWith;
BEGIN {
  $Dist::Zilla::Plugin::MetaData::BuiltWith::VERSION = '0.01005020';
}

# ABSTRACT: Report what versions of things your distribution was built against


use Moose;
use Carp qw( croak );
use namespace::autoclean;
with 'Dist::Zilla::Role::MetaProvider';


sub mvp_multivalue_args { return qw( exclude include ) }

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

  $config->{ q{} . __PACKAGE__ } = $thisconfig;
  return $config;
};

sub _uname {
  my $self = shift;
  return () unless $self->show_uname;
  {
    my $str;
    ## no critic ( ProhibitPunctuationVars )
    local $/ = undef;

    last unless open my $fh, q{-|}, $self->uname_call, @{ $self->_uname_args };
    $str = <$fh>;
    last unless close $fh;
    chomp $str;
    return ( 'uname', $str );

  }
  ## no critic ( ProhibitPunctuationVars )

  my ( $x, $y ) = ( $@, $! );
  $self->zilla->log('Error calling uname:');
  ## no critic ( RequireInterpolationOfMetachars )
  $self->zilla->log( '   $@ :' . $x );
  $self->zilla->log( '   $! :' . $y );
  return ();

}

sub _build__uname_args {
  my $self = shift;
  ## no critic ( RequireDotMatchAnything RequireExtendedFormatting RequireLineBoundaryMatching )
  return [ grep { defined $_ && $_ ne q{} } split /\s+/, $self->uname_args ];
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
      $message .= q{set BUILTWITH_TRACE=1 for details};
    }
    $self->zilla->log($message);
    if ( $ENV{BUILTWITH_TRACE} ) {
      ## no critic ( RequireInterpolationOfMetachars )
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
    return 'NA(skipped: perl)';
  }
  ## no critic ( ProhibitStringyEval )
  eval "require $module; \$success = 1" or do { $success = undef; };
  ## no critic ( Variables::ProhibitPunctuationVars )
  my $lasterror = [ $@, $! ];
  if ( not $success ) {
    $self->_logonce( $module, 'did not load', $lasterror );
    return 'NA(possibly not installed)';
  }
  my $modver;
  $success = undef;
  eval "\$modver = $module->VERSION(); \$success = 1" or do { $success = undef };
  $lasterror = [ $@, $! ];
  if ( not $success ) {
    $self->_logonce( $module, ' died assessing its version', $lasterror );
    return 'NA(version could not be resolved)';
  }
  if ( not defined $modver ) {
    $self->_logonce( $module, ' reported an undefined version', $lasterror );
    return 'NA(undef)';
  }
  return "$modver";
}


sub metadata {
  my ($self) = @_;

  my $report = $self->_get_prereq_modnames();
  my %modtable = map { ( $_, $self->_detect_installed($_) ) } ( @{$report}, @{ $self->include } );
  for my $badmodule ( @{ $self->exclude } ) {
    delete $modtable{$badmodule} if exists $modtable{$badmodule};
  }

  return {
    $self->_stash_key,
    {
      modules => \%modtable,
      ## no critic ( Variables::ProhibitPunctuationVars )
      perl     => $],
      platform => $^O,
      $self->_uname(),
    }
  };
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Dist::Zilla::Plugin::MetaData::BuiltWith - Report what versions of things your distribution was built against

=head1 VERSION

version 0.01005020

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
but that's also not always necessary.

Hopefully, the existence of the metadata provided by this module will help
users on their end machines make intelligent choices about what modules to
install in the event of a problem.

=head1 METHODS

=head2 mvp_multivalue_args

This module can take, as parameters, any volume of 'exclude' or 'include' arguments.

=head2 metadata

This module scrapes together the name of all modules that exist in the "C<Prereqs>" section
that Dist::Zilla collects, and then works out what version of things you have,
applies the various include/exclude rules, and ships that data back to Dist::Zilla
via this method. See L<< C<Dist::Zilla>'s C<MetaProvider> role|Dist::Zilla::Role::MetaProvider >> for more details.

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

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Kent Fredric <kentnl@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

