#!/usr/bin/env perl -w

package main;
use strict;
use lib::abs '../lib', '../../Queue-PQ/lib';
use AnyEvent::Impl::Perl;
#use AnyEvent::Impl::EV;
use AnyEvent::Connection;
use Time::HiRes qw(time);
use Devel::FindRef;sub findref;*findref = \&Devel::FindRef::track;
use Scalar::Util qw(weaken);
use Devel::Refcount qw( refcount );
use R::Dump;
use AnyEvent::cb;

{
	my $cv = AnyEvent->condvar;
	$cv->begin(sub {$cv->send});
	my $run;
	$SIG{INT} = sub { $cv->send; };
	$0 = "test-pmq - connect";
for (1..1) {
	$cv->begin;
	my $client;
	my $see =
	$client = AnyEvent::Connection->new(
		timeout => 1,
		host => 'localhost',
		#port => $port,
		#port => '11311',
		port => '12321',
	);
	weaken($see);
	$client->reg_cb(
		error => sub {
			#$client;
			warn "Error cb @_";
		},
		connected => sb {
			warn "Connected cb";
=for rem
			$client->push_write("stats\r\n");
			$client->push_read(line => sb {
				warn "Got @_";
				undef $client;
				$cv->end;
			} 'read');
			return;
=cut
			my $count = 0;
			$client->after(0.5,sb {
				warn "Stopping";
				$client->disconnect;
				undef $client;
				$cv->end;
			});
			$client->periodic(0.1,sb {
				warn "Periodic";
				$client->periodic_stop if ++$count > 3;
			});
			return;
		},
		connfail => sb {
			warn "Connfail cb @_";
			return;
			$client->{_}{rtimer} = AnyEvent->timer(
				after=> 0.1,
				cb {
					delete $client->{_}{rtimer};
					warn "Reconnecting";
					$client->connect;
				}
			);
		},
		disconnect => sub {
			warn "Disonnected cb";
		},
	);
	$client->connect;
}
	$cv->end;
	$cv->recv;
	#undef $client;
	warn "Ending...";
	#$see and warn findref $see;
	exit 0;

}

END {
	warn "main::end";
}

__END__




#my $inverval = 0.001;
my $inverval = 0.01;
my $rate = 10;
#my $rate = 3;
my $reload = 1;
#my @queues = qw(test1 test2 test3);
my @queues = qw(test1);
my @range = 1..30;
#my @range = 1..1;
#our %history;
our %taken;
our %seen;
our $port = 12345;
our ($server,$loader,$client);

sub mem () {
	my $ps = (split /\n/,`ps auxwp $$`)[1];
	my ($mem) = $ps =~ /\w+\s+\d+\s+\S+\s+\S+\s+(\d+)\s+(\d+)/;
	return $mem;
}
our $cmem = 0;
sub measure ($) {
	my $op = shift;
	my $mem = mem;
	my $delta = $mem - $cmem;
	if ($delta != 0) {
		$cmem = $mem;
		warn sprintf "%s: %+d\n",$op,$delta;
		#warn Dump $cl;
	}
}

unless ($server = fork) {
	exit 0;
	my $cv = AnyEvent->condvar;
	$SIG{INT} = sub { $cv->send };
	$0 = "test-pmq - server";
	my $server = AnyEvent::Queue::Server::PMQ->new(
			port         => $port,
			devel        => 0,
		#debug_proto  => 1,
		#debug_engine => 1,
	);
	$server->start;
	$cv->recv;
	exit 0;
}

unless ($loader = fork) {
	exit 0;
	my $cv = AnyEvent->condvar;
	$SIG{INT} = sub { $cv->send };
	$cv->begin(sub { $cv->send });
	$0 = "test-pmq - loader";
	my $c = AnyEvent::Queue::Client::PMQ->new(
		servers => ['localhost:'.$port],
		#sync => 1,
		reconnect => 0,
		debug => 0,
	);
	$cv->begin;
	$c->connect(cb {
		warn "Loader client connected: @_";
		for my $dst (@queues) {
			for my $id (@range) {
				$cv->begin;
				$c->put(
					dst => $dst,
					id  => $id,
					data => { x => 'x'x10 },
					cb => sub {
						#push @{$history{$id}},"insert: $! ".( @_ > 1 ? "$_[1]" :'').( $taken{$id} ? ' +taken' : '' );
						shift or $!{EEXIST} or warn "create $dst.$id failed: @_";
						$cv->end;
					},
				);
			}
		}
		undef $c;
		$cv->end;
	});
	$cv->end;
	$cv->recv;
	exit 0;
}

#if (0) {
unless ($client = fork) {
	my $cv = AnyEvent->condvar;
	$SIG{INT} = sub { $cv->send };
	$0 = "test-pmq - connect";
	my $client = Connector->new(
		host => 'localhost',
		#port => $port,
		port => '11311',
	);
	$client->reg_cb(
		connected => sub {
			warn "Connected cb";
		},
		disconnected => sub {
			warn "Disonnected cb";
		},
	);
	$client->connect;
=for rem
	my $con; $con = sub {
		warn "Connecting";
		measure('connect begin');
		my $g;$g = AnyEvent::Socket::tcp_connect 'localhost', $port, sub {
			pop;
			undef $g;
			warn "Connected @_";
			my $fh = shift or warn("$!"),return @_ = ();
			my $cnn = AnyEvent::Queue::Conn->new(
				fh => $fh,
			);
			
			@_ = ();
			measure('connected');
			after { $con->() } 1;
		}, sub { 0.9 };
		measure('connect end');
	};
	$con->();
=cut
	$cv->recv;
	exit 0;
}

if (0) {
#unless ($client = fork) {
	my $cv = AnyEvent->condvar;
	$SIG{INT} = sub { $cv->send };
	$0 = "test-pmq - client";
	measure('start');
	my $c2 = AnyEvent::Queue::Client::PMQ->new(
		servers => ['localhost:12345'],
		reconnect => 1,
		timeout => 1,
	);
	measure('client');


	our %watchers;
	our %see;

	$c2->connect(cb {
		warn "Client connected @_";
		measure('connect');
		my $statscb;$statscb = sub {
			my $stats = shift;
			#warn("Got stats $stats->{queue}{test1}{taken} $stats->{queue}{test2}{taken} $stats->{queue}{test3}{taken}");
			measure('stats');
			$c2->queues(cb {
				my $q = shift or return warn("queues failed: @_");
				measure('queues');
				warn("Got stats ".join(' ',map { $stats->{queue}{$_}{taken} } @$q ));
				#warn "Source have queues: [@$q]";
				for my $sv (@$q) {
					my $key;
					if( $watchers{$sv} ) {
						#warn "Watcher: $watchers{$sv}";
						#warn "Watcher: taken @{[ %{$watchers{$sv}{taken}} ]}";
						#warn "Watcher have taken: $watchers{$sv}{taken}{count} ".$watchers{$sv}->taken_keys;
						if ($watchers{$sv}{taken}{count} == 0) {
							warn Dump $c2->{taken};
							#$cv->send if %{ $c2->{taken} };
						}
						#warn Dump $watchers{$sv};
						#print Devel::FindRef::track $watchers{$sv};
						#$cv->send;
						#weaken($see{ $key = int $watchers{$sv} } = $watchers{$sv});
					};
					weaken( my $wx = $watchers{$sv} );
					warn "Restart with taken: ".Dump $c2->{taken};
					measure('begin create watcher');
					$watchers{$sv} = $c2->watcher(
						src      => $sv,
						prefetch => $rate,
						#rate     => $rate,
						job => sub {
							my $w = shift;
							my ($job,$err) = @_;
							measure('job');
							if ($job) {
								$seen{$job->{id}}++;
								if ($taken{$sv}{$job->{id}}++) {
									warn "$sv.$job->{id} already taken but have one more\n";
									#$cv->send;
								}
								#warn "$w ++$job->{id}";
								#return;
								$see{int $w}++;
								#after {
										#warn "End timer $w / ".refcount($w);
										#$w->requeue(job => $job);return;
										$w->requeue(job => $job, cb => sub {
											#shift or warn "@_";
											delete $taken{$sv}{$job->{id}};
										});
										$see{int $w}--;
								#} 0.1;
							} else {
								warn "WTF @_?";
							}
						},
						nomore => sub {
							#warn("No more items for $sv");
						},
					);
					measure('watcher');
					after {
						if ($wx) {
							warn "Not cleaned watcher ".eval{ refcount($wx) };
							warn "See: ".$see{int $wx};
							print findref $wx;
							#$cv->send;
							die "FTW";
						} else {
							warn "Cleaned";
						}
						measure('timer end');
					} 3;
					measure('timer');
					#warn "(".int($watchers{$sv})." : ".refcount($watchers{$sv}).") New watcher";
					#print #Devel::FindRef::track $see{$key} if $key and $see{$key};
				}
			});
			measure('call queues');
			my $t;$t = AnyEvent->timer(
				cb {
					undef $t;
					measure('invoke fullstats');
					$c2->fullstats(cb => $statscb)
				}
				after => $reload,
			);
			measure('delay fullstats');
		};
		$c2->fullstats(cb => $statscb);return;
		my $sv = $queues[0];
		my $neww = sub {
			$watchers{$sv} = $c2->watcher(
				src      => $sv,
				prefetch => $rate,
				rate     => $rate,
				job => sub {
					#shift->requeue(job => shift);
					my ($w,$job) = @_;
					warn "$w ++$job->{id}";
					after {
						$w->requeue(job => $job, cb => sub {
							#warn "
							
						});
					} 0.1;
					#%watchers;
				},
				nomore => sub {
					#%watchers;
				},
			);
		};
		after {
			warn "Starting watcher";
			$neww->();
		} 0.1;
		my $p;$p = periodic {
			$p;
			weaken( my $w = $watchers{$sv} );
			warn "Cleaning watcher ".refcount($w);
			delete $watchers{$sv};
			after {
				if ($w) {
					warn "Not cleaned watcher ".refcount($w);
					print findref $w, 20;
				} else {
					warn "Cleaned";
					$neww->();
				}
			} 1;
			
		} 3;
		return;
		after {
			weaken( my $w = $watchers{$sv} );
			warn "Cleaning watcher ".refcount($w);
			delete $watchers{$sv};
			after {
				if ($w) {
					warn "Not cleaned watcher ".refcount($w);
					print findref $w, 20;
				} else {
					warn "Cleaned";
				}
			} 1;
		} 0.5;
	});
	$cv->recv;
	#warn Dump \%watchers,\%see, $c2;
	exit 0;
}
$0 = "test-pmq - terminal";
$SIG{INT} = sub { kill INT => $server,$loader,$client };

waitpid($server,0) if $server;
waitpid($loader,0) if $loader;
waitpid($client,0);

END {
	kill KILL => -$$ if $server and $client and $loader;
}

__END__


my $start = time;
my ($ins,$upd,$del) = (0)x3;
$| = 1;

$c1->connect(cb {
	warn "Connected: @_";
	#my $w;$w = AnyEvent->timer(interval => $inverval, cb => sub {
	my $w;$w = AnyEvent->timer(after => $inverval, cb => sub {
		undef $w;
		for my $dst (@queues) {
			for my $id (@range) {
				$c1->put(
					dst => $dst,
					id  => $id,
					data => { x => 'x'x10 },
					cb => sub {
						#push @{$history{$id}},"insert: $! ".( @_ > 1 ? "$_[1]" :'').( $taken{$id} ? ' +taken' : '' );
						shift or $!{EEXIST} or warn "create $dst.$id failed: @_";
					},
				);
			}
		}
		return;

		for my $dst (@queues) {
			my $id = $range[ int rand $#range ];
			#warn "Timer $dst $id";
			#$history{$id} ||= [];
			$c1->peek( $dst, $id, cb {
				if (my $j = shift) {
					#warn "Peeked ". Dump $j;
					if (rand > 0.8) {
					#if (rand > 0.2) {
						$del++;
						$c1->delete(
							cb {
								#push @{$history{$id}},"delete: $! ".( @_ > 1 ? "$_[1]" :'').( $taken{$id} ? ' +taken' : '' );
								shift or $!{ENOENT} or warn "Delete failed: @_";
							}
							job => $j,
						);
					} else {
						$upd++;
						$c1->update(
							cb {
								#push @{$history{$id}},"update: $! ".( @_ > 1 ? "$_[1]" :'').( $taken{$id} ? ' +taken' : '' );
								shift or $!{ENOENT} or warn "Update failed: @_ / $!";
							}
							job => $j,
							pri => int rand 100,
							data => { y => 'y'x100 },
						);
					}
				} else {
					$ins++;
					#warn "No job, create";
					$c1->put(
						dst => $dst,
						id  => $id,
						data => { x => 'x'x100 },
						cb => sub {
							#push @{$history{$id}},"insert: $! ".( @_ > 1 ? "$_[1]" :'').( $taken{$id} ? ' +taken' : '' );
							shift or $!{EEXIST} or warn "create $dst.$id failed: @_";
						},
					);
				}
				my $int = time - $start;
				#printf "\r".(" "x40)."\rins: %0.2f/s, upd: %0.2f/s del %0.1f/s  ", $ins/$int, $upd/$int, $del/$int;
			} );
		}
		return;
		#$rc or $self->log->error("Can't update job $exists_job->{src}.$exists_job->{id} in queue: $e");
		#	my ($rc,$e) = 
		#$rc or warn("Can't create job in queue: $e");
	});
});

$cv->recv;
warn Dump \%seen;
