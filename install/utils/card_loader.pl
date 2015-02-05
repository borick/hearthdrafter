#!/usr/bin/env perl

use strict;
use warnings;

use JSON;
use File::Slurp qw( :std ) ;
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
my $debug = 1;

my $card_data_file = 'data/AllSets.json';
my $ha_data_folder = 'ha_tier_data';
my @files = glob("$ha_data_folder/ha_data*.txt"); #json files
my %score = ();
my $counter = 0;

# Load the card scores.
for my $file (@files) {
print "Processing $file...\n" if $debug;
    if ($file =~ /ha_data_(\d)_.*.txt$/) {
        my $text = read_file($file);
        my $data = decode_json $text;
        for my $result (@{$data->{results}}) {
            print Dumper($result) if $debug >= 3;
            my $dat = $result->{card};
            $dat->{name} = lc($dat->{name});
            $score{$dat->{name}} = int($dat->{score}*100);
        }
    }
}

# Load the card data.
my $card_data_text = read_file($card_data_file);
my $cards = decode_json $card_data_text;

my @sets_to_load = ('Basic', 'Classic', 'Curse of Naxxramas', 'Goblins vs Gnomes');

for my $set (@sets_to_load) {
    for my $card (@{$cards->{$set}}) {
        if (($card->{'id'} =~ /^..._...$/ || $card->{'id'} =~ /^NEW1_...$/ || $card->{'id'} =~ /^tt_...$/) && $card->{'type'} ne 'Hero Power' && $card->{'collectible'}) {    
            print "Processing: ",$card->{'name'}, ' ', $card->{'id'}, ", #$counter\n" if $debug;
            
            print 'Text: ' . $card->{text} . "\n" if exists($card->{text}) and $debug >= 3;
            print Dumper($card) if $debug >= 3;
            print Dumper($card->{mechanics}) if exists($card->{mechanics}) and $debug >= 3;            
            
            my $playerclass = exists($card->{'playerClass'}) ? lc($card->{'playerClass'}) : 'neutral';
            my $mechanics = $card->{'mechanics'};
            my $card_name = lc($card->{'name'});
            my $cql = 'INSERT INTO cards (name, id, cost, type, rarity, playerclass, attack, health, race, score) VALUES (?,?,?,?,?,?,?,?,?,?)';
            my $query = $ds->prepare($cql)->get;
            my @values = ( $card_name,
                           uc($card->{'id'}),
                           lc($card->{'cost'}),
                           lc($card->{'type'}),
                           lc($card->{'rarity'}),
                           $playerclass,
                           exists($card->{'attack'}) ? lc($card->{'attack'}) : -1,
                           exists($card->{'health'}) ? lc($card->{'health'}) : -1,
                           exists($card->{'race'}) ? lc($card->{'race'}) : 'n/a',
                           $score{$card_name},
                         );
            my $result = $query->execute(\@values)->get;
            if (defined($mechanics) && scalar(@$mechanics) > 0) {
                my @mech = @$mechanics;
                @mech = map { lc } @mech;
                $cql = 'UPDATE cards SET mechanics = mechanics + ? WHERE name = ?';
                $query = $ds->prepare($cql)->get;
                $result = $query->execute([\@mech, $card_name])->get;
            }
            $counter += 1;
        }
    }
}
    
print "Processed $counter results.\n";


