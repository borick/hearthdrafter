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
my $counter = 0;
my $debug = 0;

sub init {
    my %data = @_;
    $debug = $data{debug};
}
sub run {
    load_cards();
}

sub load_cards {

    # Load the card data.
    my $card_data_text = read_file($card_data_file);
    my $cards = decode_json $card_data_text;

    my @sets_to_load = ('Basic', 'Classic', 'Curse of Naxxramas', 'Goblins vs Gnomes', 'Blackrock Mountain');
    # save all the cards

    for my $set (@sets_to_load) {
        for my $card (@{$cards->{$set}}) {
            if (($card->{'id'} =~ /^..._...$/ || $card->{'id'} =~ /^NEW1_...$/ || $card->{'id'} =~ /^tt_...$/) && $card->{'type'} ne 'Hero Power' && $card->{'collectible'}) {    
                $card->{'name'} =~ s/[.]//g; #period breaks shit like venture co.
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
                
                #print $card->{'id'},"\n";
                #cards to tag...
                #print '"',lc($card->{'name'}),'":"',$card->{'id'},"\",\n"; #The cards we need to get images for. and the names used for building the js.
                #not sure...
                #print '{"',$card->{'id'},'":"',lc($card->{'name'}),"\"},\n"; 
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
                    id => lc($card_name),
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

1;

