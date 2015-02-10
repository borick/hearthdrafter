#!/usr/bin/env perl

package CardScanner;

#Builds additional card tags & card synergies.

use strict;
use warnings;

use Data::Dumper;
use Text::Format;
use CardScanner::TagBuilder;
use CardScanner::SynergyFinder;
use CardScanner::DbLoader;

#get term size!

$CardScanner::debug = 0;
%CardScanner::cards = ();
my $debug = 0;

sub init {
    my (%data) = @_;
    $CardScanner::debug = $data{debug};
    %CardScanner::TagBuilder::cards =  %{$data{cards}};
    %CardScanner::SynergyFinder::cards =  %{$data{cards}};
    $debug = $CardScanner::debug;
}

sub get_vars_from_card {
    my $card = shift;
    
    my $text = $card->{text};
    $text = '' if !defined($text);
    $text = lc($text);
    my $name = lc($card->{name});
    my $type = lc($card->{type});
    my $cost = $card->{cost};
    my $race = $card->{race};
    $race = '' if !defined($race);
    $race = lc($race);
    my $attack = $card->{attack};
    my $health = $card->{health};
    my $mechanics = $card->{mechanics};
    my %blizz_tags = ();
    if (defined($mechanics)) {
        for my $mech (@$mechanics) {
            $blizz_tags{lc($mech)} = 1;
        }
    }
    return ($name,
            $text,
            $type,
            $cost,
            $race,
            $attack,
            $health,       
            \%blizz_tags);
}

sub create_custom_tags {
    return CardScanner::TagBuilder::create_custom_tags();
}

sub find_synergies {
    return CardScanner::SynergyFinder::find_synergies();
}

sub load_synergies {
    create_custom_tags();
    my $ref = find_synergies();
    my $g = $ref->[0];
    my $reasons = $ref->[1];
    return CardScanner::DbLoader::load_synergies($g, $reasons);
}

sub CardScanner::_has_tag {
    my ($hash_with_tag, $tag, $card) = @_;
    
    my $value = $hash_with_tag->{$tag};
    if (defined($value) && ref($value) eq 'ARRAY') {
        my $req = $value->[0];
        my @tokens = split(/:/, $req);
        if ($tokens[0] eq 'race') {
            if (exists($card->{race}) && lc($card->{race}) eq $tokens[1]) {
                return $value;
            }
        }
    } elsif (defined($value)) {
        return $value;
    }
    return undef;
}

1;