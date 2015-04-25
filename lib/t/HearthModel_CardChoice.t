#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'once';

use Test::More;
use JSON;
use Data::Dumper;
use File::Slurp qw( :std ) ;
use Getopt::Long;
my $debug = undef;
my $class = 'unknown';
GetOptions ("debug=s" => \$debug,
            "class=s" => \$class,) or die('error with params');

use_ok( 'HearthDrafter' );

my $hd = HearthDrafter->new();
my $hd_model = $hd->model();
$HearthModel::CardChoice::debug = $debug;
$hd_model->connect($hd);
my @classes = ($class);
if ($class eq 'unknown') {
   @classes = (
               #'rogue',
               #'shaman',
               #'warlock',
               #'hunter'
               );
}   
for my $class (@classes) {
    my $arena = $hd_model->arena->begin_arena($class, 'test');
    my $id = $arena->{_id};
    my $file = 't/'.$class.'_run.txt';
    print "Reading: $file\n";
    my $file_text = read_file($file);
    my @lines = split(/\n/, $file_text);

    my $choices = scalar(@lines) / 9;
    print "Number of choices: $choices\n";
    for (my $i = 0; $i < $choices; $i++) {
        my $card_1 = lc($lines[$i*9+1]);
        my $score_1 = $lines[$i*9+2];
        my $card_2 = lc($lines[$i*9+4]);
        my $score_2 = $lines[$i*9+5];
        my $card_3 = lc($lines[$i*9+7]);
        my $score_3 = $lines[$i*9+8];
        my $card = undef;
        if ($score_1 > $score_2 && $score_1 > $score_3) {
            $card = $card_1;
        } elsif ($score_2 > $score_3 && $score_2 > $score_1) {
            $card = $card_2;
        } else {
            $card = $card_3;
        }
        $card =~ s/[.]//g;
        my $results = $hd_model->card_choice->get_advice($card_1,$card_2,$card_3,$id);
        ok($results->{best_card} eq lc($card), "cards should match [$card =? $results->{best_card}]\n");
        #$hd_model->arena->confirm_card_choice($card,$id);
        $hd_model->arena->confirm_card_choice($results->{best_card},$id);
    }
    $hd_model->arena->abandon_run($id, 'test');
}

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
                        values => [ lc($card->{name}).'|'.(exists($card->{playerClass})?lc($card->{playerClass}):'warrior') ],
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

# use to get data.
# hxnormalize -l 240 -x /mnt/ntfs1/Users/Boris/Documents/Hearthstone/file.html | hxselect -s '\n' -c 'span'