use strict;
use warnings;
package Dist::Zilla::Plugin::MetaData::BuiltWith::All;
BEGIN {
  $Dist::Zilla::Plugin::MetaData::BuiltWith::All::VERSION = '0.01000216';
}

# ABSTRACT: Go overkill and report everything in all namespaces.

use Moose;
use namespace::autoclean;
extends 'Dist::Zilla::Plugin::MetaData::BuiltWith';


has 'show_undef' => ( is => 'ro', isa => 'Bool', default => 0 );

sub _versions_of {
  my $self    = shift;
  my $package = shift;
  my $ns = do { no strict 'refs' ;  \%{$package . "::" } };
  my %outhash;
  for ( keys  %{$ns} ){
    if ( $_ =~ /^(.*)::$/ ){
      $outhash{$1} = { children => {} , version => undef };
    }
  }
  for ( keys %outhash ){
    my $xsn = $_;
    $xsn = $package . '::' . $_ unless $package eq q{};
#    warn "$xsn -> VERSION\n";
    eval {
      $outhash{$_}->{version} = $xsn->VERSION();
    }
  }
  for ( keys %outhash ){
   next if $_ eq 'main';
    my $xsn = $_;
    $xsn = $package . '::' . $_ unless $package eq q{};
    $outhash{$_}->{children} = $self->_versions_of( $xsn );
  }
  return \%outhash;
}

sub _flatten {
    my $self = shift;
    my $tree = shift;
    my $path = shift || '';
    my %outhash;
    for ( keys %{$tree} ){
      $outhash{$path . $_} = $tree->{$_}->{version};
    }
    for ( keys %{$tree} ){
      %outhash = ( %outhash, $self->_flatten( $tree->{$_}->{children} , $path . $_ . '::' ) );
    }
    return %outhash;
}
sub _filter {
  my $self = shift;
  my %in = @_;
  my %out;
  for ( keys %in ){
    if ( not defined $in{$_} ){
        next unless $self->show_undef;
    }
    $out{$_} = $in{$_}
  }
  \%out;
}


override 'metadata' => sub {
  my $self = shift;
  my $stash = super();
  $stash->{x_BuiltWith}->{allmodules} = $self->_filter($self->_flatten( $self->_versions_of('') ) );
  return $stash;
};


__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Dist::Zilla::Plugin::MetaData::BuiltWith::All - Go overkill and report everything in all namespaces.

=head1 VERSION

version 0.01000216

=head1 SYNOPSIS

  [MetaData::BuiltWith::All]
  show_undef = 1

This module is otherwise identical to L<Dist::Zilla::Plugin::MetaData::BuiltWith::All>.

=head1 DESCRIPTION

This further extends the verbosity of the information reported by the BuiltWith plugin,
by recursively rooting around in the namespaces and reporting every version of everything it finds.

Only recommended for the most extreme of situations where you find your code breaking all over the show between different versions of things, or for personal amusement.

=head1 WARNING

At present this code does no recursion prevention, apart from excluding the 'main' namespace.

If it sees other namespaces which recurse into themself indefinately ( like main does ), then it may not terminate normally.

Also, using this module will likely add 1000 lines to META.yml, so please for the love of sanity don't use this too often.

=head1 AUTHOR

  Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Kent Fredric <kentnl@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

