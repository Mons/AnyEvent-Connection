package AnyEvent::cb;

use strict;
use warnings;
use Scalar::Util qw(weaken);

our %DEF;

BEGIN {
	if ($ENV{CB_DEBUG}) {
		*DEBUG = sub () { 1 };
	} else {
		*DEBUG = sub () { 0 };
	}
}
BEGIN {
	sub sb(&);
	sub cb(&;@);
	if (DEBUG) {
		eval { require Sub::Identify; Sub::Identify->import('sub_fullname'); 1 } or *sub_fullname = sub { return };
		eval { require Devel::Refcount; Devel::Refcount->import('refcount'); 1 } or *refcount = sub { 1 };
		eval { require Devel::FindRef; *findref = \&Devel::FindRef::track;   1 } or *findref  = sub { "No Devel::FindRef installed\n" };
		*sb = sub (&) {
			$DEF{int $_[0]} = [ join(' ',(caller())[1,2]), $_[0] ];weaken($DEF{int $_[0]}[1]);
			#local $_ = int $_[0];
			#warn "create: $_ defined $DEF{$_}[0]\n";
			return bless shift,'__callback__';
		};
		*cb = sub (&;@) {
			$DEF{int $_[0]} = [ join(' ',(caller())[1,2]), $_[0] ];weaken($DEF{int $_[0]}[1]);
			return cb => bless( shift,'__callback__'), @_;
		};
		*__callback__::DESTROY = sub {
			#local $_ = int $_[0];
			#my $name = sub_fullname($DEF{$_}[1]);
			#warn "destroy: $_ ".($name ? $name : 'ANON')." defined $DEF{$_}[0]\n";#.findref($DEF{$_}[1]);
			delete($DEF{int $_[0]});
		};
		*COUNT = sub {
			for (keys %DEF) {
				$DEF{$_}[1] or next;
				my $name = sub_fullname($DEF{$_}[1]);
				warn "Not destroyed: $_ ".($name ? $name : 'ANON')." (".refcount($DEF{$_}[1]).") defined $DEF{$_}[0]\n";#.findref($DEF{$_}[1]);
			}
		};
	} else {
		*sub_fullname = sub {};
		*refcount = sub { 1 };
		*findref = sub {};
		*sb = sub (&) { $_[0] };
		*cb = sub (&;@) { cb => shift, @_ };
		*COUNT = sub {};
	}
}


sub import {
	no strict 'refs';
	for (qw(sb cb)) {
		*{ caller().'::'.$_ } = \&$_;
	}
}

END {
	COUNT() if DEBUG;
}

1;
