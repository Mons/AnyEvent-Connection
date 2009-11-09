use inc::Module::Install;

name     'AnyEvent-Connection';
all_from 'lib/AnyEvent/Connection.pm';
author   'Mons Anderson <mons@cpan.org>';
license  'perl';

build_requires 'Test::More';

requires 'Devel::Leak::Cb', '0.03';
requires 'common::sense', 2;

auto_install;

WriteAll;

