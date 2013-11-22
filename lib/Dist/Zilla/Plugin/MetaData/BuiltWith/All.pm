use strict;
use warnings;

package Dist::Zilla::Plugin::MetaData::BuiltWith::All;
BEGIN {
  $Dist::Zilla::Plugin::MetaData::BuiltWith::All::AUTHORITY = 'cpan:KENTNL';
}
{
  $Dist::Zilla::Plugin::MetaData::BuiltWith::All::VERSION = '0.04000001';
}

# ABSTRACT: Go overkill and report everything in all name-spaces.

use Moose;
use namespace::autoclean;
extends 'Dist::Zilla::Plugin::MetaData::BuiltWith';


has 'show_failures' => ( is => 'ro', isa => 'Bool', default => 0 );

around dump_config => sub {
  my ( $orig, $self ) = @_;
  my $config = $self->$orig();
  $config->{ q{} . __PACKAGE__ }->{show_failures} = $self->show_failures;
  return $config;
};

sub _list_modules_in_memory {
  my ( $self, $package ) = @_;
  my (@out);
  if ( $package eq 'main' or $package =~ /\Amain::/msx ) {
    return $package;
  }
  if ($package) {
    push @out, $package;
  }
  my $ns = do {
    ## no critic (ProhibitNoStrict)
    no strict 'refs';
    \%{ $package . q{::} };
  };
  my (@child_namespaces);
  for my $child ( keys %{$ns} ) {
    if ( $child =~ /\A(.*)::$/msx ) {
      my $child_pkg = $1;
      $child_pkg = $package . q[::] . $child_pkg if $package;
      push @child_namespaces, $child_pkg;
    }
  }
  for my $child (@child_namespaces) {
    push @out, $self->_list_modules_in_memory($child);
  }
  return (@out);
}

sub _get_all {
  my ($self) = @_;
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

  my (@modules) = $self->_list_modules_in_memory(q{});
  for my $module (@modules) {
    $record_module->($module);
  }

  for my $module ( $self->include ) {
    $record_module->($module);
  }
  for my $badmodule ( $self->exclude ) {
    $forget_module->($badmodule);
  }
  my $rval = { allmodules => \%modtable };
  $rval->{allfailures} = \%failures if keys %failures and $self->show_failures;
  return $rval;
}

around 'metadata' => sub {
  my ( $orig, $self, @args ) = @_;
  my $stash = $self->$orig(@args);
  $stash->{ $self->_stash_key } = { %{ $stash->{ $self->_stash_key } }, %{ $self->_get_all() } };
  return $stash;
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::MetaData::BuiltWith::All - Go overkill and report everything in all name-spaces.

=head1 VERSION

version 0.04000001

=head1 SYNOPSIS

  [MetaData::BuiltWith::All]
  show_failures = 1 ; Not recommended

This module is otherwise identical to L<< C<MetaData::BuiltWith>|Dist::Zilla::Plugin::MetaData::BuiltWith >>.

=head1 DESCRIPTION

This further extends the verbosity of the information reported by the L<< C<BuiltWith>|Dist::Zilla::Plugin::MetaData::BuiltWith >> plug-in,
by recursively rooting around in the name-spaces and reporting every version of everything it finds.

Only recommended for the most extreme of situations where you find your code breaking all over the show between different versions of things, or for personal amusement.

=head1 OPTIONS

=head2 show_failures

Because this module reports B<ALL> C<namespaces>, it will likely report very many C<namespaces>
which simply do not exist on disk as a distinct file, and as a result, are unlikely to have C<$VERSION> data.

As a result, enabling this option will drop a mother load of failures into a hash somewhere in C<x_BuiltWith>.

For instance, there's one for every single package in C<B::>

And there's one for every single instance of C<Eval::Closure::Sandbox> named C<Eval::Closure::Sandbox_.*>

There's one for every instance of C<Module::Metadata> ( I spotted about 80 myself )

And there's one for each and every thing that uses C<__ANON__::>

You get the idea?

B<Do not turn this option on>

You have been warned.

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

=head1 WARNING

At present this code does no recursion prevention, apart from excluding the C<main> name-space.

If it sees other name-spaces which recur into their self indefinitely ( like main does ), then it may not terminate normally.

Also, using this module will likely add 1000 lines to C<META.yml>, so please for the love of sanity don't use this too often.

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Kent Fredric <kentnl@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
