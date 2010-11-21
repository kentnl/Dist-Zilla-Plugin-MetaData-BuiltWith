use strict;
use warnings;

package Dist::Zilla::Plugin::MetaData::BuiltWith;
BEGIN {
  $Dist::Zilla::Plugin::MetaData::BuiltWith::VERSION = '0.01016607';
}

# ABSTRACT: Report what versions of things your distribution was built against


use Hash::Merge::Simple;
use Dist::Zilla::Util::EmulatePhase 0.01000101 qw( get_prereqs );
use Moose::Autobox;
use Moose;
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

  my $config = $self->$orig();
  my $thisconfig = { show_uname => $self->show_uname, _stash_key => $self->_stash_key };

  if ( $self->show_uname ) {
    $thisconfig->put(
      uname => {
        uname_call => $self->uname_call,
        uname_args => $self->_uname_args,
      }
    );
  }

  if ( $self->exclude->flatten ) {
    $thisconfig->{exclude} = $self->exclude;
  }
  if ( $self->include->flatten ) {
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

    last unless open my $fh, q{-|}, $self->uname_call, $self->_uname_args->flatten;
    $str = <$fh>;
    last unless close $fh;
    chomp $str;
    return ( 'uname', $str );

  }
  ## no critic ( ProhibitPunctuationVars )

  $self->_my_log_fatal( 'Error calling uname:', $@, $! );

  return ();

}

sub _my_log_fatal {
  my ($self) = @_;
  ## no critic ( RequireInterpolationOfMetachars )
  $self->log_fatal( sprintf "%s\n   %s:%s\n   %s:%s", shift, q{$@}, shift, q{$!}, shift );
}

sub _build__uname_args {
  my $self = shift;
  ## no critic ( RequireDotMatchAnything RequireExtendedFormatting RequireLineBoundaryMatching )
  return [ grep { defined $_ && $_ ne q{} } split /\s+/, $self->uname_args ];
}

sub _get_prereq_modnames {
  my ($self) = @_;

  my $modnames = {};
  my $prereqs = get_prereqs( { zilla => $self->zilla } )->as_string_hash;
  if ( not $prereqs->flatten ) {
    $self->log("WARNING: No prereqs were found, probably a bug");
    return [];
  }
  $self->log_debug( ( scalar $prereqs->keys->flatten ) . ' phases defined: ' . join q{,}, $prereqs->keys->flatten );
  $prereqs->each(
    sub {
      my ( $phase_name, $phase_data ) = @_;
      return unless defined $phase_data;
      my $phase_deps = {};
      $phase_data->each(
        sub {
          my ( $type, $type_data ) = @_;
          return unless defined $type_data;
          $type_data->each(
            sub {
              my ( $module, $module_data ) = @_;
              $phase_deps->put( $module, 1 );
            }
          );
        }
      );
      $self->log_debug( "Prereqs for $phase_name: " . $phase_deps->keys->join(q{,}) );
      $modnames = $modnames->merge($phase_deps);
    }
  );
  return $modnames->keys->sort;
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
  $self->log_debug("Installed $module is $modver");
  return "$modver";
}


sub metadata {
  my ($self) = @_;
  $self->log_debug("Metadata called");
  my $report = $self->_get_prereq_modnames();
  $self->log_debug( 'Found mods: ' . scalar @{$report} );
  my %modtable = [ $report->flatten, $self->include->flatten ]->map(
    sub {
      ( $_, $self->_detect_installed($_) );
    }
  )->flatten;
  for my $badmodule ( $self->exclude->flatten ) {
    %modtable->delete($badmodule) if %modtable->exists($badmodule);
  }

  return {
    $self->_stash_key,
    {
      modules => \%modtable,
      ## no critic ( Variables::ProhibitPunctuationVars )
      perl     => {%{$^V}},
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

version 0.01016607

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

