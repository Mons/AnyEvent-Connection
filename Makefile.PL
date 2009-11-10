use inc::Module::Install;

name     'AnyEvent-Connection';
all_from 'lib/AnyEvent/Connection.pm';
version   my $v = '0.04';
author   'Mons Anderson <mons@cpan.org>';
license  'perl';

build_requires 'Test::More';
build_requires 'Test::NoWarnings';
build_requires 'Test::TCP', '0.14';
build_requires 'lib::abs',  '0.90';

requires 'common::sense',    2;
requires 'Devel::Leak::Cb', '0.03';
requires 'AnyEvent',         5;
requires 'Object::Event',   '1.101';

provides 'AnyEvent::Connection' => {
	version => $v,
	file    => 'lib/AnyEvent/Connection.pm',
};

auto_install;

WriteAll;

