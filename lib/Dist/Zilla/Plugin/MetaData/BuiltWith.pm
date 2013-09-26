use strict;
use warnings;

package Dist::Zilla::Plugin::MetaData::BuiltWith;
BEGIN {
  $Dist::Zilla::Plugin::MetaData::BuiltWith::AUTHORITY = 'cpan:KENTNL';
}
{
  $Dist::Zilla::Plugin::MetaData::BuiltWith::VERSION = '0.04000000';
}

# ABSTRACT: Report what versions of things your distribution was built against


use Dist::Zilla::Util::EmulatePhase;
use Readonly;
Readonly my $MIN_EMULATE_PHASE => '0.01000101';
use Moose 2.0;
use Class::Load qw( load_optional_class );
use MooseX::Types::Moose (qw( ArrayRef Bool Str ));
use namespace::autoclean;
with 'Dist::Zilla::Role::MetaProvider';


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
has _stash_key => ( is => 'ro', isa => Str, default => 'x_BuiltWith' );

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
  Class::Load::load_class('Config');
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

  if ( defined $Dist::Zilla::Util::EmulatePhase::VERSION ) {
    Dist::Zilla::Util::EmulatePhase->VERSION($MIN_EMULATE_PHASE);
  }
  my $prereqs = Dist::Zilla::Util::EmulatePhase::get_prereqs( { zilla => $self->zilla } )->as_string_hash;
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

sub _detect_installed {
  my ( $self, $module ) = @_;
  my $success = undef;
  if ( $module eq 'perl' ) {
    return [ undef, undef ];
  }
  require Module::Data;
  my $d = Module::Data->new($module);

  if ( not defined $d ) {
    return [ undef, 'failed to create a Module::Data wrapper' ];
  }

  if ( not -e -f $d->path ) {
    return [ undef, 'module was not found in INC' ];
  }

  my $v = $d->_version_emulate;

  if ( not $v ) {
    return [ undef, 'Module::MetaData could not parse a version from ' . $d->path ];
  }
  return [ $v, undef ];

}


sub metadata {
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
  return { $self->_stash_key, $result };
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__

=pod

=encoding utf-8

=head1 NAME

Dist::Zilla::Plugin::MetaData::BuiltWith - Report what versions of things your distribution was built against

=head1 VERSION

version 0.04000000

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

=head1 OPTIONS

=head2 exclude

Specify modules to exclude from version reporting

    exclude = Foo
    exclude = Bar

=head2 include

Specify additional modules to include the version of

    include = Foo
    include = Bar

=head2 show_config

Report "interesting" values from C<%Config::Config>

    show_config = 1 ; Boolean

=head2 show_uname

Report the output from C<uname>

    show_uname = 1 ; Boolean

=head2 uname_call

Specify what the system C<uname> function is called

    uname_call = uname ; String

=head2 uname_args

Specify arguments passed to the C<uname> call.

    uname_args = -a ; String

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

This software is copyright (c) 2013 by Kent Fredric <kentnl@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
