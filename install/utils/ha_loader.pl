#!/usr/bin/env perl

use strict;
use warnings;

use File::Slurp;
use JSON;
use Data::Dumper;
use Net::Async::CassandraCQL;
use Protocol::CassandraCQL qw( CONSISTENCY_QUORUM CONSISTENCY_ONE );
use IO::Async::Loop;


my $loop = IO::Async::Loop->new;
my $ds = Net::Async::CassandraCQL->new(
   host => "localhost",
   keyspace => "hearthdrafter",
   default_consistency => CONSISTENCY_ONE,
);
$loop->add($ds);
$ds->connect->get;
my $counter = 0;
my $ha_data_folder = 'ha_tier_data';
my @files = glob("$ha_data_folder/*.txt"); #json files
for my $file (@files) {
    my $text = read_file($file);
    my $data = decode_json $text;
    for my $result (@{$data->{results}}) {
        my $dat = $result->{card};
        print "Processing: " . $dat->{image} . " with score: " . $dat->{score}*100 . "\n";
        my $query = $ds->prepare("UPDATE cards SET score = ? WHERE id = ?")->get;
        $query->execute([int($dat->{score}*100), $dat->{image}])->get;
        $counter += 1;
    }
}

print "Processed $counter results.\n";