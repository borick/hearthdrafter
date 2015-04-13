#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use_ok( 'HearthModel::Arena' );
use_ok( 'HearthModel::CardChoice' );

my $hm_arena = HearthModel::Arena->new();
my $hm_cardchoice = HearthModel::CardChoice->new();

$hm_arena->begin_arena('shaman', 'test_');

done_testing();