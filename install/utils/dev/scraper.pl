#!/usr/bin/env perl

use strict;
use warnings;

use LWP::Simple;
use JSON;
use Data::Dumper;

my $data_dir = '../ha_tier_data';
                                                                       # class - card 1 - card 2 - card 3
my $url_prefix = "http://draft.heartharena.com/arena/option-multi-score/";#/-/#-#-#
my $id_file = 'list_ha_ids.txt';
my $text;
open my $idf, '<', $id_file or die "can't open id file";
my @ids = <$idf>;
close $idf;

my @sorted_ids = map { s/\s//g; $_ } @ids;
print STDERR join(', ', @sorted_ids);

my @unique = do { my %seen; grep { !$seen{$_}++ } @sorted_ids };
@unique = sort {$a <=> $b} @unique;
my @copy = @unique;

# get data and put it in a file
sub get_data {
    my ($class, $suffix,$out_file_name) = @_;
    if (-f $out_file_name) {
        return;
    }
    my $get_url = $url_prefix.$class.'/-/'.$suffix;
    print "Getting $get_url\n";
    $text = get($get_url);
    $text = '' if !defined($text);
    print "Got: $text\n";        
    print "Writing to $out_file_name\n";
    open my $file_out, '>', "$out_file_name" or die "can't open file to write";
    print $file_out $text;
    close $file_out;
    return $text;
}

for my $x (1..9) {
    while (@unique) {
        my $val1 = shift @unique;
        my $val2 = shift @unique || $val1;
        my $val3 = shift @unique || $val2;
        
        my $suffix = $val1.'-'.($val2).'-'.($val3);
        my $out_file_name = "$data_dir/ha_data_".$x."_"."$suffix".".txt";
        $text = get_data($x, $suffix, $out_file_name);
        #sleep 1;
    }
    @unique = @copy;
}
