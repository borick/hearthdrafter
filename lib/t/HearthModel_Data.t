#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use JSON;
use Data::Dumper;
use File::Slurp qw( :std ) ;

use_ok( 'HearthDrafter' );

my $hd = HearthDrafter->new();
my $hd_model = $hd->model();
$hd_model->connect($hd);

my $card_data_file = '../install/utils/data/AllSets.json';
my $card_data_text = read_file($card_data_file);
my $cards = decode_json $card_data_text;
my @names = ();
for my $card (@{$cards->{'Blackrock Mountain'}}) {
    if (($card->{'id'} =~ /^..._...$/ || $card->{'id'} =~ /^NEW1_...$/ || $card->{'id'} =~ /^tt_...$/) && $card->{'type'} ne 'Hero Power' && $card->{'collectible'}) {
        push(@names, lc($card->{name}));
        my $scores_result = $hd->model->es->search(
            index => 'hearthdrafter',
            type => 'card_score_by_class',
            body => {
                query => {
                    ids => {
                        type => 'card_score_by_class',
                        values => [ lc($card->{name}).'|'.(exists($card->{playerClass})?lc($card->{playerClass}):'mage') ],
                    },
                },
            },
        );
        ok($scores_result->{hits}->{hits}->[0]->{_source}->{score} != 0, "score exists for ".$card->{name}. " and non-zero");
    }
}
my $data = $hd_model->card->get_data(\@names);
for my $name (@names) {
    ok(exists($data->{$name}->{cost}), "cost exists for $name - [" . $data->{$name}->{id} . ']');
}

done_testing();
