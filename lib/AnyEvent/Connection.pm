package AnyEvent::Connection;

use strict;
use warnings;
use Object::Event 1.101;
use base 'Object::Event';

use AnyEvent;
use AnyEvent::Socket;

use Carp;

use Scalar::Util qw(weaken);
BEGIN { eval { require Sub::Name; Sub::Name->import(); 1 } or *subname = sub { $_[1] }; }
BEGIN { eval { require Devel::FindRef; *findref = \&Devel::FindRef::track;   1 } or *findref  = sub { "No Devel::FindRef installed\n" }; }
use AnyEvent::Connection::Raw;
use AnyEvent::cb;
use strict;

use R::Dump;

=head1 NAME

AnyEvent::Connection - The great new AnyEvent::Connection!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use AnyEvent::Connection;

    my $foo = AnyEvent::Connection->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.


=head1 METHODS

=over 4

=item new
=item connect
=item disconnect
=item reconnect
=item after
=item periodic
=item periodic_stop

=back

=head1 EVENTS

=over 4

=item connected
=item connfail
=item disconnect

=back

=item

=cut

sub new {
	my $self = shift->SUPER::new(@_);
	$self->init(@_);
	return $self;
}

sub init {
	my $self = shift;
	$self->{debug}   ||= 0;
	$self->{connected} = 0;
	$self->{reconnect} = 1 unless defined $self->{reconnect};
	$self->{timeout} ||= 3;
	$self->{timers}    = {};
	#warn "Init $self";
}

sub connected {
	warn "Connected";
	shift->event(connected => ());
}

sub connect {
	my $self = shift;
	weaken $self;
	croak "Only client can connect but have $self->{type}" if $self->{type} and $self->{type} ne 'client';
	$self->{type} = 'client';
	
	warn "Connecting to $self->{host}:$self->{port}...";
	$self->{_}{con}{cb} = sub { #subname 'connect.cb' => sub {
		pop;
		delete $self->{_}{con};
			if (my $fh = shift) {
				warn "Connected @_";
				$self->{con} = AnyEvent::Connection::Raw->new(
					fh      => $fh,
					timeout => $self->{timeout},
					debug   => $self->{debug},
				);
				$self->{con}->reg_cb(
					disconnect => sub {
						warn "Disconnected $self->{host}:$self->{port} @_";
						$self->event( disconnect => @_ );
						$self->disconnect;
						$self->_reconnect_after();
					},
				);
				$self->{connected} = 1;
				#warn "Send connected event";
				$self->event(connected => $self->{con}, @_);
			} else {
				warn "Not connected $self->{host}:$self->{port}: $!";
				$self->event(connfail => "$!");
				$self->_reconnect_after();
			}
	};
	$self->{_}{con}{pre} = sub { $self->{timeout} };
	$self->{_}{con}{grd} =
		AnyEvent::Socket::tcp_connect
			$self->{host}, $self->{port},
			$self->{_}{con}{cb}, $self->{_}{con}{pre}
	;
}

sub accept {
	croak "TODO";
}

sub push_write {
	my $self = shift;
	$self->{connected} or return $self->event( error => "Not connected for push_write" );
	$self->{con}->push_write(@_);
}
sub push_read {
	my $self = shift;
	$self->{connected} or return $self->event( error => "Not connected for push_read" );
	$self->{con}->push_read(@_);
}
sub unshift_read {
	my $self = shift;
	$self->{connected} or return $self->event( error => "Not connected for unshift_read" );
	$self->{con}->unshift_read(@_);
}

sub say {
	my $self = shift;
	eval{ $self->{con}->say(@_); };
	return;
}

sub _reconnect_after {
	weaken( my $self = shift );
	$self->{reconnect} or return;
	$self->{timers}{reconnect} = AnyEvent->timer(
		after => $self->{reconnect},
		cb => sub {
			$self or return;
			delete $self->{timers}{reconnect};
			#warn "Reconnecting";
			$self->connect;
		}
	);
}

sub periodic_stop;
sub periodic {
	weaken( my $self = shift );
	my $interval = shift;
	my $cb = shift;
	#warn "Create periodic $interval";
	$self->{timers}{int $cb} = AnyEvent->timer(
		after => $interval,
		interval => $interval,
		cb => sub {
			local *periodic_stop = sub {
				warn "Stopping periodic ".int $cb;
				delete $self->{timers}{int $cb}; undef $cb
			};
			$self or return;
			$cb->();
		},
	);
	defined wantarray and return AnyEvent::Util::guard(sub {
		delete $self->{timers}{int $cb};
		undef $cb;
	});
	return;
}

sub after {
	weaken( my $self = shift );
	my $interval = shift;
	my $cb = shift;
	#warn "Create after $interval";
	$self->{timers}{int $cb} = AnyEvent->timer(
		after => $interval,
		cb => sub {
			$self or return;
			delete $self->{timers}{int $cb};
			$cb->();
			undef $cb;
		},
	);
	defined wantarray and return AnyEvent::Util::guard(sub {
		delete $self->{timers}{int $cb};
		undef $cb;
	});
	return;
}

sub reconnect {
	my $self = shift;
	$self->disconnect;
	$self->connect;
}

sub disconnect {
	my $self = shift;
	#$self->{con} or return;
	#warn "Disconnecting";
	ref $self->{con} eq 'HASH' and warn Dump($self->{con});
	$self->{con} and eval{ $self->{con}->close; };
	warn if $@;
	delete $self->{con};
	$self->{connected} = 0;
	$self->event('disconnect');
	return;
}

sub AnyEvent::Connection::destroyed::AUTOLOAD {}

sub destroy {
	my ($self) = @_;
	$self->DESTROY;
	bless $self, "AnyEvent::Connection::destroyed";
}

sub DESTROY {
	my $self = shift;
	warn "(".int($self).") Destroying client";
	$self->disconnect;
	%$self = ();
}

=head1 AUTHOR

Mons Anderson, C<< <mons at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-anyevent-connection at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=AnyEvent-Connection>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AnyEvent::Connection


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=AnyEvent-Connection>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/AnyEvent-Connection>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/AnyEvent-Connection>

=item * Search CPAN

L<http://search.cpan.org/dist/AnyEvent-Connection/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Mons Anderson, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of AnyEvent::Connection
