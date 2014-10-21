use 5.008001;
use strict;
use warnings;

package Hash::Objectify;

# ABSTRACT: Create objects from hashes on the fly
our $VERSION = '0.002'; # VERSION

use Carp;
use Sub::Install;
use Scalar::Util qw/blessed/;

my %CACHE;
my $COUNTER = 0;

sub import {
    my ($class) = @_;
    my $caller = caller;

    Sub::Install::install_sub(
        {
            code => sub {
                my ( $ref, $package ) = @_;
                my $type = ref $ref;
                unless ( $type eq 'HASH' ) {
                    $type =
                        $type eq ''   ? "a scalar value"
                      : blessed($ref) ? "an object of class $type"
                      :                 "a reference of type $type";
                    croak "Error: Can't objectify $type";
                }
                if ( defined $package ) {
                    no strict 'refs';
                    @{ $package . '::ISA' } = 'Hash::Objectified'
                      unless $package->isa('Hash::Objectified');
                }
                else {
                    my ( $caller, undef, $line ) = caller;
                    my $cachekey = join "", keys %$ref;
                    if ( !defined $CACHE{$caller}{$line}{$cachekey} ) {
                        no strict 'refs';
                        $package = $CACHE{$caller}{$line}{$cachekey} = "Hash::Objectified$COUNTER";
                        $COUNTER++;
                        @{ $package . '::ISA' } = 'Hash::Objectified';
                    }
                    else {
                        $package = $CACHE{$caller}{$line}{$cachekey};
                    }
                }
                bless {%$ref}, $package;
            },
            into => $caller,
            as   => 'objectify',
        }
    );
}

package Hash::Objectified;

use Class::XSAccessor;

our $AUTOLOAD;

sub can {
    my ( $self, $key ) = @_;
    $self->$key; # install accessor if not installed
    return $self->SUPER::can($key);
}

sub AUTOLOAD {
    my $self   = shift;
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    if ( ref $self && exists $self->{$method} ) {
        Class::XSAccessor->import(
            accessors => { $method => $method },
            class     => ref $self
        );
    }
    else {
        my $class = ref $self || $self;
        die qq{Can't locate object method "$method" via package "$class"};
    }
    return $self->$method(@_);
}

sub DESTROY { } # because we AUTOLOAD, we need this too

1;


# vim: ts=4 sts=4 sw=4 et:

__END__

=pod

=encoding utf-8

=head1 NAME

Hash::Objectify - Create objects from hashes on the fly

=head1 VERSION

version 0.002

=head1 SYNOPSIS

  use Hash::Objectify;

  # turn a hash reference into an object with accessors

  $object = objectify { foo => 'bar', wibble => 'wobble' };
  print $object->foo;

  # objectify with a specific class name

  $object = objectify { foo => 'bar' }, "Foo::Response";
  print ref $object; # "Foo::Response"

=head1 DESCRIPTION

Hash::Objectify turns a hash reference into a simple object with accessors for each
of the keys.

One application of this module could be to create lightweight response objects
without the extra work of setting up an entire response class with the
framework of your choice.

Using Hash::Objectify is slower than accessing the keys of the hash directly, but
does provide "typo protection" since a misspelled method is an error.

=for Pod::Coverage method_names_here

=head1 USAGE

=head2 objectify

  $object = objectify $hashref
  $object = objectify $hashref, $classname;

  $object->$key;          # accessor
  $object->$key($value);  # mutator

The C<objectify> function copies the hash reference (shallow copy), and blesses
it into the given classname.  If no classname is given, a meaningless,
generated package name is used instead.  In either case, the object will
inherit from the Hash::Objectified class, which generates accessors on
demand for any key in the hash.

As an optimization, a generated classname will be the same for any given
C<objectify> call if the keys of the input are the same.  (This avoids
excessive accessor generation.)

The first time a method is called on the object, an accessor will be dynamically
generated if the key exists.  If the key does not exist, an exception is thrown.
Note: deleting a key I<after> calling it as an accessor will not cause subsequent
calls to throw an exception; the accessor will merely return undef.

Objectifying with a "real" classname that does anything other than inherit from
Hash::Objectified may lead to surprising behaviors from method name conflict.  You
probably don't want to do that.

Objectifying anything other than an unblessed hash reference is an error.  This
is true even for objects based on blessed hash references, since the correct
semantics are not universally obvious.  If you really want Hash::Objectify for
access to the keys of a blessed hash, you should make an explicit, shallow copy:

  my $copy = objectify {%$object};

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/dagolden/hash-objectify/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/dagolden/hash-objectify>

  git clone git://github.com/dagolden/hash-objectify.git

=head1 AUTHOR

David Golden <dagolden@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2012 by David Golden.

This is free software, licensed under:

  The Apache License, Version 2.0, January 2004

=cut
