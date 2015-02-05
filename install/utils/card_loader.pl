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
my $debug = 2;

my $card_data_file = 'data/AllSets.json';
my $ha_data_folder = 'ha_tier_data';
my @files = glob("$ha_data_folder/*.txt"); #json files
my %class_maps = ();
my %class_ids = (1 => 'druid',
                 2 => 'hunter',
                 3 => 'mage',
                 4 => 'paladin',
                 5 => 'priest',
                 6 => 'rogue',
                 7 => 'shaman',
                 8 => 'warlock',
                 9 => 'warrior');
my $counter = 0;

# Load the card scores.
for my $file (@files) {
print "Processing $file...\n";
    if ($file =~ /ha_data_(\d)_.*.txt$/) {
        
        my $class_id = $1;
        $class_maps{$class_id} = {} if !exists($class_maps{$class_id});
        my $text = read_file($file);
        my $data = decode_json $text;
        for my $result (@{$data->{results}}) {
            print Dumper($result) if $debug >= 3;
            my $dat = $result->{card};
            $dat->{name} = lc($dat->{name});
            $class_maps{$class_id}->{$dat->{name}} = int($dat->{score}*100);
        }
    }
}

# Load the card data.
my $card_data_text = read_file($card_data_file);
my $cards = decode_json $card_data_text;

my @sets_to_load = ('Basic', 'Classic', 'Curse of Naxxramas', 'Goblins vs Gnomes');
for my $class_id (keys(%class_ids)) {

    my $class = $class_ids{$class_id};
    my @cards = ();
    
    for my $set (@sets_to_load) {
        for my $card (@{$cards->{$set}}) {
            if (($card->{'id'} =~ /^..._...$/ || $card->{'id'} =~ /^NEW1_...$/ || $card->{'id'} =~ /^tt_...$/) && $card->{'type'} ne 'Hero Power' && $card->{'collectible'}) {    
                print "Processing: ",$card->{'name'}, ' ', $card->{'id'}, ", #$counter\n";
                
                print 'Text: ' . $card->{text} . "\n" if exists($card->{text}) and $debug >= 3;
                print Dumper($card) if $debug >= 3;
                print Dumper($card->{mechanics}) if exists($card->{mechanics}) and $debug >= 3;            
                
                my $playerclass = exists($card->{'playerClass'}) ? lc($card->{'playerClass'}) : 'neutral';
                my $mechanics = $card->{'mechanics'};
                my @mech = ();
                if (defined($mechanics)) {
                    @mech = @$mechanics;
                    @mech = map { lc } @mech;
                }
                push (@cards, { name => lc($card->{'name'}),
                                id => uc($card->{'id'}),
                                cost => lc($card->{'cost'}),
                                type => lc($card->{'type'}),
                                rarity => lc($card->{'rarity'}),
                                attack => exists($card->{'attack'}) ? lc($card->{'attack'}) : -1,
                                health => exists($card->{'health'}) ? lc($card->{'health'}) : -1,
                                race => exists($card->{'race'}) ? lc($card->{'race'}) : 'n/a',
                                playerclass => $playerclass,
                                mechanics => \@mech,
                                synergy => {},
                                score => $class_maps{$class_id}->{lc($card->{'name'})},
                            }) if $playerclass eq $class or $playerclass eq 'neutral';
                $counter += 1;
            }
        }
    }
    
    my $cql = "INSERT INTO class_cards (class_name, cards) VALUES (?, " . _array_to_literal(\@cards) . ")";
    my $query = $ds->prepare($cql)->get;
    my $result = $query->execute([$class])->get;
}

sub _array_to_literal {
    my $arr = shift;
    my $result = '[';
    my @arr = @$arr;    
    for my $card_i (0 .. $#arr) {
        my $card = $arr[$card_i];
        
        $result .= '{';    
        my @keys = keys(%$card);
        for my $k (0.. $#keys) {
            my $key = $keys[$k];
            if (ref($card->{$key}) eq 'ARRAY') {
                my @tmp = @{$card->{$key}};
                @tmp = map { "'$_'" } @tmp;
                my $tmp = join(',', @tmp);
                $result .= "$key: [" . $tmp . ']';
            } elsif (ref($card->{$key}) eq 'HASH') {
                my $tmp = ''; #nothing
                $result .= "$key: {" . $tmp . '}';
            } else {
                $card->{$key} =~ s/'/''/g;
                
                if ($card->{$key} =~ /^-?\d+$/) {
                    $result .= "$key: " . $card->{$key};
                } else {
                    $result .= "$key: '" . $card->{$key} . '\'';
                }
            }
            $result .= ',' if $k != $#keys;
        }
        $result .= '}';
        $result .= ',' if $card_i != $#arr;
    }
    return $result .']';
}

print "Processed $counter results.\n";


