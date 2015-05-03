#!/usr/bin/env perl

use strict;
use warnings;

use CardLoader;
use CardScanner;
use Getopt::Long;

my $debug = 0;
GetOptions ("debug=i" => \$debug)
    or die ("Error");

print "Running...\n";
CardLoader::init(debug => $debug);
CardLoader::run();
CardScanner::init(debug => $debug, cards => \%CardLoader::all_cards);
CardScanner::load_tags();
CardScanner::load_synergies();
my $cmd = './score_util.pl -a=import_scores < data/scores.csv';
print "Reloading scores using command: $cmd\n";
system($cmd);
print "Done.\n";
