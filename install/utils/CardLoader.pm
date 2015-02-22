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
my $bulk2 = $e->bulk_helper(
    index   => 'hearthdrafter',
    type    => 'card_score_by_class'
);

my $max_score = -1;
my $score_total = 0;
my $score_count = 0;
my %class_maps = ();
%CardLoader::all_cards  = ();
my $card_data_file = 'data/AllSets.json';
my $ha_data_folder = 'ha_tier_data';
my @files = glob("$ha_data_folder/ha_data*.txt"); #json files
my %score = ();
my $counter = 0;
my $debug = 0;
my $class_name_to_id= { 'druid'    => 1,
                        'hunter'   => 2,
                        'mage'     => 3,
                        'paladin'  => 4,
                        'priest'   => 5,
                        'rogue'    => 6,
                        'shaman'   => 7,
                        'warlock'  => 8,
                        'warrior'  => 9,
                        };
my %class_id_to_name= reverse %{$class_name_to_id};

sub init {
    my %data = @_;
    $debug = $data{debug};
}
sub run {
    load_cards();
    load_scores();    
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
                my $card_name = $card->{'name'};
                $card_name =~ s/([\w']+)/\u\L$1/g;
                my @mech = ();
                my @mechs = ();
                if (defined($mechanics) && scalar(@$mechanics) > 0) {
                    @mech = @$mechanics;
                    @mech = map { lc } @mech;
                    for my $mech (@mech) {
                        push (@mechs, { name => $mech });
                    }
                }
                #print $card->{'id'},"\n"; The cards we need to get images for :D
                my %data = (
                    'name' => lc($card_name),
                    'id' => $card->{'id'},
                    'cost' => lc($card->{'cost'}),
                    'type' => lc($card->{'type'}),
                    'rarity' => lc($card->{'rarity'}),
                    'playerclass' => $playerclass,
                    'attack' => $card->{'attack'},
                    'health' => $card->{'health'},
                    'race' => $card->{'race'},
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
    
    print "Indexed $counter new documents.\n" if $debug;
}

sub load_scores {

    # Load the card scores.
    for my $file (@files) {
    print "Processing $file...\n" if $debug >= 2;
        if ($file =~ /ha_data_(\d)_.*.txt$/) {
            my $class_num = $1;
            my $class_name = $class_id_to_name{$class_num};
            my $text = read_file($file);
            my $data = decode_json $text;
            for my $result (@{$data->{results}}) {
                print Dumper($result) if $debug >= 4;
                my $dat = $result->{card};
                $dat->{name} = $dat->{name};
                $score{$class_name}->{$dat->{name}} = int($dat->{score}*100);
            }
        }
    }
    
    for my $class_name (sort(keys(%score))) {
        my $ref = $score{$class_name};
        for my $card_name (sort(keys(%$ref))) {            
            my $score = $ref->{$card_name};
            $max_score = $score if ($score > $max_score);
            $score_total += $score;
            my $id = $card_name.'|'.$class_name;
            my $result = $bulk2->index({
                id => lc($id),
                source  => {
                    card_name => lc($card_name),
                    class_name => $class_name,
                    score => $score 
                },
            });
            $counter += 1;
            $score_count += 1;
        }
    }
    
    $bulk2->flush;
    print "max score is: $max_score\n";
    print "average score is: ".($score_total/$score_count)."\n";
}

1;

