#!/usr/bin/env perl

use strict;
use warnings;

use LWP::Simple;
use JSON;
use Data::Dumper;

my $data_dir = 'ha_tier_data';
my $url_prefix = "http://draft.heartharena.com/arena/option-multi-score/1/-/";
my $id_file = 'list_ha_ids.txt';
my $text;
open my $idf, '<', $id_file or die "can't open id file";
my @ids = <$idf>;
my @sorted_ids = map { s/\s//g; $_ } @ids;
close $idf;

# get data and put it in a file
sub get_data {
    my ($suffix,$out_file_name) = @_;
    if (-f $out_file_name) {
        return;
    }
    my $get_url = $url_prefix.$suffix;
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

while (@sorted_ids) {
    my $val1 = shift @sorted_ids;
    my $val2 = shift @sorted_ids || $val1;
    my $val3 = shift @sorted_ids || $val2;
    
    my $suffix = $val1.'-'.($val2).'-'.($val3);
    my $out_file_name = "$data_dir/ha_data_$suffix.txt";
    if (-f $out_file_name) {
        next;
    }
    $text = get_data($suffix, $out_file_name);
    sleep 1;
}
