use strict;
use warnings;
package Dist::Zilla::Plugin::MetaData::BuiltWith;
BEGIN {
  $Dist::Zilla::Plugin::MetaData::BuiltWith::VERSION = '0.01000022';
}

# ABSTRACT: Report what versions of things your distribution was built against



use Moose;
with 'Dist::Zilla::Role::MetaProvider';


sub mvp_multivalue_args { qw( exclude include ) };

has exclude => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );
has include => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );


sub _get_prereq_modnames {
  my ( $self ) = @_;
  my %modnames;
  my $prereqs = $self->zilla->prereqs->as_string_hash;
  return [] unless defined $prereqs;
  for my $phase ( keys %{ $prereqs } ){
    next unless defined $prereqs->{$phase};
    for my $type ( keys %{ $prereqs->{$phase} } ){
      next unless defined $prereqs->{$phase}->{$type};
      for my $module ( keys %{ $prereqs->{$phase}->{$type} } ) {
          $modnames{$module} = 1;
      }
    }
  }
  return [ sort { $a cmp $b } keys %modnames ];
}

{ my $context = 0;

  sub _logonce {
    my ( $self, $module, $reason, $error ) = @_ ;
    my $message = "Possible Error: Module '$module' $reason.";
    if ( not $context and not $ENV{BUILTWITH_TRACE} ){
      $context++;
      $message .= "set BUILTWITH_TRACE=1 for details";
    }
    $self->zilla->log($message);
    if( $ENV{BUILTWITH_TRACE} ){
      $self->zilla->log('$@ : ' . $error->[0] );
      $self->zilla->log('$! : ' . $error->[1] );
    }
    return;
  }

}

sub _detect_installed {
  my ( $self, $module ) = @_;
  my $success = undef;
  eval "require $module; \$success = 1";
  my $lasterror = [ $@, $! ];
  if  ( not $success ){
    $self->_logonce( $module, 'did not load' , $lasterror );
    return "NA(possibly not installed)";
  }
  my $modver;
  $success = undef;
  eval "\$modver = $module->VERSION(); \$success = 1";
  $lasterror = [$@, $!];
  if ( not $success ){
    $self->_logonce( $module, ' died assessing its version', $lasterror );
    return "NA(version could not be resolved)";
  }
  if ( not defined $modver ){
    $self->_logonce( $module, ' reported an undefined version', $lasterror );
    return "NA(undef)";
  }
  return "$modver";
}


sub metadata {
  my ( $self )  = @_;

  my $report = $self->_get_prereq_modnames();
  my %modtable = map {
    $_ , $self->_detect_installed($_)
  } ( @{$report}, @{ $self->include } );
  for  my $badmodule ( @{ $self->exclude } ){
    delete $modtable{$badmodule} if exists $modtable{$badmodule};
  }

  return { x_BuiltWith => {
      modules   => \%modtable,
      perl      => $],
      platform  => $^O,
  }};
}

1;

__END__
=pod

=head1 NAME

Dist::Zilla::Plugin::MetaData::BuiltWith - Report what versions of things your distribution was built against

=head1 VERSION

version 0.01000022

=head1 SYNOPSIS

  [MetaData::BuiltWith]
  include = Some::Module::Thats::Not::In::Preq
  exclude = Some::Module::Youre::Ashamed::Of

=head1 DESCRIPTION

Often, distribution authors get module dependencies wrong. So in such cases,
its handy to be able to see what version of various packages they built with.

Some would prefer to demand everyone install the same version as they did,
but thats also not always nessecary.

Hopefully, the existance of the metadata provided by this module will help
users on thier end machines make intelligent choices about what modules to
install in the event of a problem.

=head1 METHODS

=head2 mvp_multivalue_args

This module can take, as parameters, any volume of 'exclude' or 'include' arguments.

=head2 metadata

This module scrapes together the name of all modules that exist in the "Prereq" section
that Dist::Zilla collects, and then works out what version of things you have,
applies the various include/exclude rules, and ships that data back to Dist::Zilla
via this method. See L<Dist::Zilla::Role::MetaProvider> for more details.

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

=head1 AUTHOR

  Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Kent Fredric <kentnl@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

