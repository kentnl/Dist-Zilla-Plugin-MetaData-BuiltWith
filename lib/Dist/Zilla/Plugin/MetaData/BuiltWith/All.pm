use strict;
use warnings;

package Dist::Zilla::Plugin::MetaData::BuiltWith::All;
BEGIN {
  $Dist::Zilla::Plugin::MetaData::BuiltWith::All::AUTHORITY = 'cpan:KENTNL';
}
{
  $Dist::Zilla::Plugin::MetaData::BuiltWith::All::VERSION = '0.02000000';
}

# ABSTRACT: Go overkill and report everything in all name-spaces.

use Moose;
use namespace::autoclean;
extends 'Dist::Zilla::Plugin::MetaData::BuiltWith';


has 'show_undef' => ( is => 'ro', isa => 'Bool', default => 0 );

around dump_config => sub {
  my ( $orig, $self ) = @_;
  my $config = $self->$orig();
  $config->{ q{} . __PACKAGE__ }->{show_undef} = $self->show_undef;
  return $config;
};

sub _versions_of {
  my $self    = shift;
  my $package = shift;
  my $ns      = do {
    ## no critic ( TestingAndDebugging::ProhibitNoStrict )
    no strict 'refs';
    \%{ $package . q{::} };
  };
  my %outhash;
  for ( keys %{$ns} ) {
    ## no critic ( RequireDotMatchAnything RequireExtendedFormatting RequireLineBoundaryMatching )
    if ( $_ =~ /^(.*)::$/ ) {
      $outhash{$1} = { children => {}, version => undef };
    }
  }
  for ( keys %outhash ) {
    my $xsn = $_;
    $xsn = $package . q{::} . $_ unless $package eq q{};

    #    warn "$xsn -> VERSION\n";
    eval { $outhash{$_}->{version} = $xsn->VERSION(); } or do {
      1;
    };
  }
  for ( keys %outhash ) {
    next if $_ eq 'main';
    my $xsn = $_;
    $xsn = $package . q{::} . $_ unless $package eq q{};
    $outhash{$_}->{children} = $self->_versions_of($xsn);
  }
  return \%outhash;
}

sub _flatten {
  my $self = shift;
  my $tree = shift;
  my $path = shift || q{};
  my %outhash;
  for ( keys %{$tree} ) {
    $outhash{ $path . $_ } = $tree->{$_}->{version};
  }
  for ( keys %{$tree} ) {
    %outhash = ( %outhash, $self->_flatten( $tree->{$_}->{children}, $path . $_ . q{::} ) );
  }
  return %outhash;
}

sub _filter {
  my ( $self, %in ) = @_;
  my %out;
  for ( keys %in ) {
    if ( not defined $in{$_} ) {
      next unless $self->show_undef;
    }
    $out{$_} = $in{$_};
  }
  return \%out;
}

override 'metadata' => sub {
  my $self  = shift;
  my $stash = super();
  $stash->{ $self->_stash_key }->{allmodules} = $self->_filter( $self->_flatten( $self->_versions_of(q{}) ) );
  return $stash;
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=encoding utf-8

=head1 NAME

Dist::Zilla::Plugin::MetaData::BuiltWith::All - Go overkill and report everything in all name-spaces.

=head1 VERSION

version 0.02000000

=head1 SYNOPSIS

  [MetaData::BuiltWith::All]
  show_undef = 1

This module is otherwise identical to L<< C<MetaData::BuiltWith>|Dist::Zilla::Plugin::MetaData::BuiltWith >>.

=head1 DESCRIPTION

This further extends the verbosity of the information reported by the L<< C<BuiltWith>|Dist::Zilla::Plugin::MetaData::BuiltWith >> plug-in,
by recursively rooting around in the name-spaces and reporting every version of everything it finds.

Only recommended for the most extreme of situations where you find your code breaking all over the show between different versions of things, or for personal amusement.

=head1 WARNING

At present this code does no recursion prevention, apart from excluding the C<main> name-space.

If it sees other name-spaces which recur into their self indefinitely ( like main does ), then it may not terminate normally.

Also, using this module will likely add 1000 lines to C<META.yml>, so please for the love of sanity don't use this too often.

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Kent Fredric <kentnl@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

