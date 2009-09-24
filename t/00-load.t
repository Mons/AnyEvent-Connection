#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'AnyEvent::Connection' );
}

diag( "Testing AnyEvent::Connection $AnyEvent::Connection::VERSION, Perl $], $^X" );
