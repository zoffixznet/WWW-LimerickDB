use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'WWW::LimerickDB',
    license             => 'perl',
    dist_author         => q|Zoffix <'zoffix@cpan.org'>|,
    dist_version_from   => 'lib/WWW/LimerickDB.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'LWP::UserAgent'           => 2.036,
        'HTML::TokeParser::Simple' => 3.15,
        'HTML::Entities'           => 1.35,
        'overload'                 => 1.04,
        'Class::Data::Accessor'    => 0.04001,
    },
    add_to_cleanup      => [ 'WWW-LimerickDB-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
