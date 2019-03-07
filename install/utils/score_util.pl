#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;
use Data::Dumper;

use constant MAX_CARDS => 99999;

my $es = Search::Elasticsearch->new();
my $bulk = $es->bulk_helper(
    index     => 'hearthdrafter',
    type      => 'card_score_by_class',
    on_error  => sub { warn Dumper(@_) },
);

my $action='none';
GetOptions ("action=s" => \$action);
if ($action eq 'export_scores') {
    my $scores_result = $es->search(
        index => 'hearthdrafter',
        type => 'card_score_by_class',
        size => MAX_CARDS,
        body => {
            query => {
                match_all => {},
            },
        },
    );
    for my $entry (@{$scores_result->{hits}->{hits}}) {
        my $source = $entry->{_source};
        print $source->{score}, ",", $source->{card_name}, ",", $source->{class_name}, "\n";
    }
} elsif ($action eq 'import_scores') {
    my @lines = <>;
    for my $line (@lines) {
        chomp($line);
        my ($score,$card_name,$class_name) = split(',', $line);
        #print STDERR "Indexing: $score, $card_name, $class_name\n";
        $bulk->index({
            id => $card_name.'|'.$class_name,
            source => {
                card_name   => $card_name,
                class_name => $class_name,
                score => $score,
            }
        });
    }
    $bulk->flush;
}