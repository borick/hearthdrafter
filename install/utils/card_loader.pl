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

my $card_data_file = 'data/AllSets.json';
my $card_data_text = read_file($card_data_file);
my $cards = decode_json $card_data_text;
my @sets_to_load = ('Basic', 'Classic', 'Curse of Naxxramas', 'Goblins vs Gnomes');
my $counter = 0;
for my $set (@sets_to_load) {
    for my $card (@{$cards->{$set}}) {
        if (($card->{'id'} =~ /^..._...$/ || $card->{'id'} =~ /^NEW1_...$/ || $card->{'id'} =~ /^tt_...$/) && $card->{'type'} ne 'Hero Power' && $card->{'collectible'}) {    
            print "Processing: ",$card->{'name'}, ' ', $card->{'id'}, ", #$counter\n";           
            my $query = $ds->prepare("INSERT INTO cards (id, card_name, cost, type, rarity, playerClass, attack, health, race) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")->get;
            $query->execute([$card->{'id'},
                             $card->{'name'},
                             $card->{'cost'},
                             $card->{'type'},
                             $card->{'rarity'},
                             $card->{'playerClass'},
                             defined($card->{'attack'}) ? $card->{'attack'} : -1,
                             defined($card->{'health'}) ? $card->{'health'} : -1,
                             $card->{'race'}])->get;
            my $mechanics = $card->{'mechanics'};
            if (defined($mechanics)) {
                my @mech = @$mechanics;
                my $cmd = "UPDATE cards SET mechanics = mechanics + ? WHERE card_name = ?";
                print $cmd,"\n";
                $query = $ds->prepare($cmd)->get;
                my $values = [];
                push($values, \@mech);
                push($values, $card->{'name'});
                $query->execute($values)->get;
            }
            $counter += 1;
        }
        
    }
}
print "Processed $counter results.\n";