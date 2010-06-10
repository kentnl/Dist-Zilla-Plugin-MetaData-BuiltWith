use strict;
use warnings;
package Dist::Zilla::Plugin::BuiltWith;

# ABSTRACT: Report what versions of things your distribution was built against

=head1 DESCRIPTION

Often, distribution authors get module dependencies wrong. So in such cases, its handy to be able to see what version of various packages they built with.

Some would prefer to demand everyone install the same version as they did, but thats also not always nessecary.

Hopefully, the existance of the metadata provided by this module will help users on thier end machines make intelligent choices about what modules to install in the event of a problem.

=cut

1;
