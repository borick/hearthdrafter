#!/usr/bin/env perl

package CardLoader;

use strict;
use warnings;

use JSON;
use File::Slurp qw( :std ) ;
use Data::Dumper;

use Getopt::Long;

#init
use Search::Elasticsearch;
my $e = Search::Elasticsearch->new();
my $bulk = $e->bulk_helper(
    index   => 'hearthdrafter',
    type    => 'card'
);

my %class_maps = ();
%CardLoader::all_cards  = ();
my $card_data_file = 'data/AllSets.json';
my $ha_data_folder = 'ha_tier_data';
my @files = glob("$ha_data_folder/ha_data*.txt"); #json files
my %score = ();
my $counter = 0;
my $debug = 0;

sub init {
    my %data = @_;
    $debug = $data{debug};
}
sub run {
    load_scores();
    load_cards();
}

sub load_scores {

    # Load the card scores.
    for my $file (@files) {
    print "Processing $file...\n" if $debug >= 2;
        if ($file =~ /ha_data_(\d)_.*.txt$/) {
            my $text = read_file($file);
            my $data = decode_json $text;
            for my $result (@{$data->{results}}) {
                print Dumper($result) if $debug >= 4;
                my $dat = $result->{card};
                $dat->{name} = lc($dat->{name});
                $score{$dat->{name}} = int($dat->{score}*100);
            }
        }
    }

}

sub load_cards {

    # Load the card data.
    my $card_data_text = read_file($card_data_file);
    my $cards = decode_json $card_data_text;

    my @sets_to_load = ('Basic', 'Classic', 'Curse of Naxxramas', 'Goblins vs Gnomes');
    # save all the cards

    for my $set (@sets_to_load) {
        for my $card (@{$cards->{$set}}) {
            if (($card->{'id'} =~ /^..._...$/ || $card->{'id'} =~ /^NEW1_...$/ || $card->{'id'} =~ /^tt_...$/) && $card->{'type'} ne 'Hero Power' && $card->{'collectible'}) {    
                print "Processing: ",$card->{'name'}, ' ', $card->{'id'}, ", #$counter\n" if $debug >= 1;
                
                print 'Text: ' . $card->{text} . "\n" if exists($card->{text}) and $debug >= 2;
                print Dumper($card) if $debug >= 3;
                print Dumper($card->{mechanics}) if exists($card->{mechanics}) and $debug >= 3;            
                
                my $playerclass = exists($card->{'playerClass'}) ? lc($card->{'playerClass'}) : 'neutral';
                my $mechanics = $card->{'mechanics'};
                my $card_name = lc($card->{'name'});
                my @mech = ();
                my @mechs = ();
                if (defined($mechanics) && scalar(@$mechanics) > 0) {
                    @mech = @$mechanics;
                    @mech = map { lc } @mech;
                    for my $mech (@mech) {
                        push (@mechs, { name => $mech });
                    }
                }
                my %data = (
                    'name' => $card_name,
                    'id' => uc($card->{'id'}),
                    'cost' => lc($card->{'cost'}),
                    'type' => lc($card->{'type'}),
                    'rarity' => lc($card->{'rarity'}),
                    'playerclass' => $playerclass,
                    'attack' => $card->{'attack'},
                    'health' => $card->{'health'},
                    'race' => $card->{'race'},
                    'score' => $score{$card_name},
                    'mechanics' => \@mechs,
                );
                        
                my $result = $bulk->index({
                    id => $card_name,
                    source  => \%data
                });

                $class_maps{$playerclass} = {} if !exists($class_maps{$playerclass});
                $class_maps{$playerclass}->{$card_name} = \%data;
                $CardLoader::all_cards{$card_name} = $card;
                
                $counter += 1;
            }
        }
    }
    $bulk->flush;
    print "Loaded $counter cards.\n" if $debug;
}

1;