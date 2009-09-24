use inc::Module::Install;

name     'AnyEvent-Connection';
all_from 'lib/AnyEvent/Connection.pm';
author   'Mons Anderson <mons@cpan.org>';
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

