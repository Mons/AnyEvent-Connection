use lib::abs '../lib';
use AnyEvent::cb;

( cb { warn "test 1" } )[1]->();
( sb { warn "test 2" } )->();
