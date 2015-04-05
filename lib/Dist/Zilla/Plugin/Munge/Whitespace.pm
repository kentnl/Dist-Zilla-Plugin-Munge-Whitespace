use 5.006;    # our
use strict;
use warnings;

package Dist::Zilla::Plugin::Munge::Whitespace;

our $VERSION = '0.001000';

# ABSTRACT: Strip superfluous spaces from pesky files.

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moose qw( has with around );
use Dist::Zilla::Role::FileMunger 1.000;    # munge_file
use Dist::Zilla::Util::ConfigDumper qw( config_dumper );

with 'Dist::Zilla::Role::FileMunger';

sub mvp_multivalue_args { return qw{ filename match } }

has 'preserve_trailing' => ( is => 'ro', isa => 'Bool',     lazy => 1, default => sub { undef } );
has 'preserve_cr'       => ( is => 'ro', isa => 'Bool',     lazy => 1, default => sub { undef } );
has 'filename'          => ( is => 'ro', isa => 'ArrayRef', lazy => 1, default => sub { [] } );
has 'match'             => ( is => 'ro', isa => 'ArrayRef', lazy => 1, default => sub { [] } );

has '_match_expr'    => ( is => 'ro', isa => 'RegexpRef', lazy_build => 1 );
has '_eol_kill_expr' => ( is => 'ro', isa => 'RegexpRef', lazy_build => 1 );

around dump_config => config_dumper( __PACKAGE__, { attrs => [qw( preserve_trailing preserve_cr filename match )] } );

__PACKAGE__->meta->make_immutable;
no Moose;

sub _build__match_expr {
  my ($self)    = @_;
  my (@matches) = @{ $self->match };
  if ( scalar @{ $self->filename } ) {
    unshift @matches, sprintf q[\A(?:%s)\z], join q[|], map { quotemeta } @{ $self->filename };
  }
  my $combined = join q[|], @matches;

  ## no critic (RegularExpressions::RequireDotMatchAnything)
  ## no critic (RegularExpressions::RequireLineBoundaryMatching)
  ## no critic (RegularExpressions::RequireExtendedFormatting)

  return qr/$combined/;
}

sub _build__eol_kill_expr {
  my ($self) = @_;

  ## no critic (RegularExpressions::RequireDotMatchAnything)
  ## no critic (RegularExpressions::RequireLineBoundaryMatching)
  ## no critic (RegularExpressions::RequireExtendedFormatting)

  my $bad_bits = qr//;
  my $end_line;
  if ( not $self->preserve_trailing ) {

    # Add horrible spaces to end
    $bad_bits = qr/[\x{20}\x{09}]+/;
  }
  if ( $self->preserve_cr ) {

    # preserve CR keeps the CR optional as part of the EOL lookahead.
    $end_line = qr/(?=\x{0D}?\x{0A}|\z)/;
  }
  else {
    # No-preserve CR swallows any CRs directly before the EOL lookahead.
    $end_line = qr/\x{0D}?(?=\x{0A}|\z)/;
  }

  return qr/${bad_bits}${end_line}/;
}

sub _munge_string {
  my ( $self, $name, $string ) = @_;
  $self->log_debug( [ 'Stripping trailing whitespace from %s', $name ] );

  if ( $self->preserve_cr and $self->preserve_trailing ) {

    # Noop, both EOL transformations
  }
  else {
    ## no critic (RegularExpressions::RequireDotMatchAnything)
    ## no critic (RegularExpressions::RequireLineBoundaryMatching)
    ## no critic (RegularExpressions::RequireExtendedFormatting)

    my $expr = $self->_eol_kill_expr;
    $string =~ s/$expr//g;
  }
  return $string;
}

sub _munge_from_code {
  my ( $self, $file ) = @_;
  if ( $file->can('code_return_type') and 'text' ne $file->code_return_type ) {
    $self->log_debug( [ 'Skipping %s: does not return text', $file->name ] );
    return;
  }
  $self->log_debug( [ 'Munging FromCode (prep): %s', $file->name ] );
  my $orig_coderef = $file->code();
  $file->code(
    sub {
      $self->log_debug( [ 'Munging FromCode (write): %s', $file->name ] );
      my $content = $file->$orig_coderef();
      return $self->_munge_string( $file->name, $content );
    },
  );
  return;
}

sub _munge_static {
  my ( $self, $file ) = @_;
  $self->log_debug( [ 'Munging Static file: %s', $file->name ] );
  my $content = $file->content;
  $file->content( $self->_munge_string( $file->name, $content ) );
  return;
}

sub munge_file {
  my ( $self, $file ) = @_;
  return unless $file->name =~ $self->_match_expr;
  if ( $file->isa('Dist::Zilla::File::FromCode') ) {
    return $self->_munge_from_code($file);
  }
  return $self->_munge_static($file);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::Munge::Whitespace - Strip superfluous spaces from pesky files.

=head1 VERSION

version 0.001000

=head1 DESCRIPTION

This plugin exists to remove white-space from selected files.

In its default mode of operation, it will strip trailing white-space from the selected files in the following forms:

=over 4

=item * C<0x20>: The literal space character

=item * C<0x9>: The literal tab character

=item * C<0xD>: The Carriage Return character, otherwise known as C<\r> ( But only immediately before a \n )

=back

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
