package AnyEvent::Connection::Raw;

use strict;
use warnings;
use Object::Event 1.101;
use base 'Object::Event';
use AnyEvent::Handle;
use AnyEvent::cb;
use Scalar::Util qw(weaken);
BEGIN { eval { require Sub::Name; Sub::Name->import(); 1 } or *subname = sub { $_[1] } }

our $NL = "\015\012";
our $QRNL = qr<\015?\012>;

sub new {
	my $pkg = shift;
	my $self = $pkg->SUPER::new(@_);
	$self->{nl} = $NL unless defined $self->{nl};
	$self->{debug} = 1;
	$self->{cb}{eof} = subname 'conn.cb.eof' => sb {
		local *__ANON__ = 'conn.cb.eof';
		warn "[\U$self->{side}\E] Eof on handle";
		delete $self->{h};
		for my $k (keys %{ $self->{waitingcb} }) {
			if ($self->{waitingcb}{$k}) {
				$self->{waitingcb}{$k}->(undef, "eof from client");
			}
			delete $self->{waitingcb}{$k};
		}
		$self->event('disconnect');
	} ;
	$self->{cb}{err} = subname 'conn.cb.err' => sb {
		local *__ANON__ = 'conn.cb.err';
		my $e = "$!";
		if ( $self->{destroying} ) {
			warn "err on destroy";
			$e = "Connection closed";
		} else {
			#warn "[\U$self->{side}\E] Error on handle: $e"; # TODO: uncomment
		}
		delete $self->{h};
		for my $k (keys %{ $self->{waitingcb} }) {
			if ($self->{waitingcb}{$k}) {
				$self->{waitingcb}{$k}->(undef, "$e");
			}
			delete $self->{waitingcb}{$k};
		}
		$self->event( disconnect => "Error: $e" );
	};
	$self->{timeout} ||= 30;
	$self->{h} = AnyEvent::Handle->new(
		fh       => $self->{fh},
		autocork => 1,
		on_eof   => $self->{cb}{eof},
		on_error => $self->{cb}{err},
	);
	$self;
}

sub close {
	my $self = shift;
	delete $self->{fh};
	$self->{h} and $self->{h}->destroy;
	delete $self->{h};
	%$self = ();
	$self->{destroying} = 1;
	return;
}

sub DESTROY {
	my $self = shift;
	warn "(".int($self).") Destroying conn";
	$self->close;
	%$self = ();
	return;
}


sub push_write {
	my $self = shift;
	$self->{h} or return;
	$self->{h}->push_write(@_);
	warn ">> @_  " if $self->{debug};
}

sub push_read {
	my $self = shift;
	my $cb = pop;
	$self->{h} or return;
	$self->{h}->timeout($self->{timeout});
	$self->{h}->push_read(@_,sb {
		shift->timeout(); # disable timeout and remove handle from @_
		#$self->{h}->timeout();
		$cb->($self,@_);
		undef $cb;
	});
}

sub unshift_read {
	my $self = shift;
	$self->{h} or return;
	$self->{h}->push_read(@_);
}

sub say {
	my $self = shift;
	$self->{h} or return;
	$self->{h}->push_write("@_$self->{nl}");
	warn ">> @_  " if $self->{debug};
	return;
}
*reply = \&say;

# Serverside feature
sub want_command {
	my $self = shift;
	$self->{h} or return;
	$self->{h}->push_read( regex => $QRNL, sb {
		local *__ANON__ = 'conn.want_command.read';
		shift;
		for (@_) {
			chomp;
			substr($_,-1,1) = '' if substr($_, -1,1) eq "\015";
		}
		$self->event( command => @_ );
		$self->want_command;
	});
}

sub recv {
	my ($self,$bytes,%args) = @_;
	$args{cb}  or return $self->event( error => "no cb for command at @{[ (caller)[1,2] ]}" );
	$self->{h} or return $args{cb}(undef,"Not connected");
	warn "<+ read $bytes " if $self->{debug};
	$self->{waitingcb}{int $args{cb}} = $args{cb};
	$self->{h}->unshift_read( chunk => $bytes, sb {
		local *__ANON__ = 'conn.recv.read';
		# Also eat CRLF or LF from read buffer
		substr( $self->{h}{rbuf}, 0, 1 ) = '' if substr( $self->{h}{rbuf}, 0, 1 ) eq "\015";
		substr( $self->{h}{rbuf}, 0, 1 ) = '' if substr( $self->{h}{rbuf}, 0, 1 ) eq "\012";
		delete $self->{waitingcb}{int $args{cb}};
		shift; (delete $args{cb})->(@_);
		%args = ();
	} );
}

1;
