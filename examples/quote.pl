#!/usr/bin/env perl

use strict;
use warnings;

use lib qw(lib ../lib);
use WWW::LimerickDB;

@ARGV
    or die "Usage: perl $0 quote_number\n";

my $l = WWW::LimerickDB->new;

$l->get_limerick(shift)
    or die $l->error;

print $l . "\n";