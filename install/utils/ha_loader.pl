#!/usr/bin/env perl

use strict;
use warnings;

use File::Slurp;
use JSON;
use Data::Dumper;

my $ha_data_folder = 'ha_tier_data';
my @files = glob("$ha_data_folder/*.txt"); #json files
for my $file (@files) {
    my $text = read_file($file);
    my $data = decode_json $text;
    for my $result (@{$data->{results}}) {
        my $dat = $result->{card};
         
        print "Processing: " . $dat->{image} . "\n";
        
    }
}