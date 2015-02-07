#!/usr/bin/env perl

use strict;
use warnings;

use CardLoader;
use CardScanner;
use Getopt::Long;

my $debug = 0;
GetOptions ("debug+" => \$debug)
    or die ("Error");
    
CardLoader::init(debug => $debug);
CardLoader::run();
CardScanner::init(debug => $debug, cards => \%CardLoader::all_cards);
CardScanner::scan();

