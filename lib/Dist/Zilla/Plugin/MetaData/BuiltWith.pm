use strict;
use warnings;
package Dist::Zilla::Plugin::MetaData::BuiltWith;

# ABSTRACT: Report what versions of things your distribution was built against

=head1 DESCRIPTION

Often, distribution authors get module dependencies wrong. So in such cases, 
its handy to be able to see what version of various packages they built with.

Some would prefer to demand everyone install the same version as they did, 
but thats also not always nessecary.

Hopefully, the existance of the metadata provided by this module will help 
users on thier end machines make intelligent choices about what modules to 
install in the event of a problem.

=cut

use Moose;
with 'Dist::Zilla::Role::MetaProvider';
use Carp qw( carp );

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
    $self->_logonce( $module, 'did not load' , $error );
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
  } @$report;

  return { x_BuiltWith => \%modtable };  
}

1;
