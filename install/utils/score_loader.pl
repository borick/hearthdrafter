#!/usr/bin/env perl

use strict;
use warnings;

use File::Slurp;
use JSON;
use Data::Dumper;
use Net::Async::CassandraCQL;
use Protocol::CassandraCQL qw( CONSISTENCY_ONE );
use IO::Async::Loop;

my $loop = IO::Async::Loop->new;
my $ds = Net::Async::CassandraCQL->new(
   host => "localhost",
   keyspace => "hearthdrafter",
   default_consistency => CONSISTENCY_ONE,
);
$loop->add($ds);
my $c = $ds->connect->get;
my $debug = 0;

my %class_ids = (1 => 'druid',
                 2 => 'hunter',
                 3 => 'mage',
                 4 => 'paladin',
                 5 => 'priest',
                 6 => 'rogue',
                 7 => 'shaman',
                 8 => 'warlock',
                 9 => 'warrior');
my %class_maps = ();

my $counter = 0;
my $ha_data_folder = 'ha_tier_data';
my @files = glob("$ha_data_folder/*.txt"); #json files
print "Processing...\n";
for my $file (@files) {
    if ($file =~ /ha_data_(\d)_.*.txt$/) {
        
        my $class_id = $1;
        $class_maps{$class_id} = {} if !exists($class_maps{$class_id});
        my $text = read_file($file);
        my $data = decode_json $text;
        for my $result (@{$data->{results}}) {
            print Dumper($result) if $debug;
            my $dat = $result->{card};                
            $class_maps{$class_id}->{$dat->{name}} = int($dat->{score}*100);
            $counter += 1;
        }
    }
}

for my $class_key (sort(keys(%class_maps))) {
    my $class_data = $class_maps{$class_key};
    print "Executing for: " . $class_ids{$class_key} . "\n";
    my $query = $ds->prepare("INSERT INTO class_card_score (class_name, card_score) values (?,?)")->get;
    my $result = $query->execute([$class_ids{$class_key}, $class_data])->get;    
}

print "Processed " . ($counter/9) . " results per class.\n";
