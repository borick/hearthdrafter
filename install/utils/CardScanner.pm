#!/usr/bin/env perl

package CardScanner;

use strict;
use warnings;

use Data::Dumper;

my $debug = 0;
my %cards = ();
my %tags = ();

sub init {
    my (%data) = @_;
    $debug = $data{debug};
    %cards =  %{$data{cards}};
}

sub scan {
    my $counter = 0;
    for my $key (sort(keys(%cards))) {
        my $card = $cards{$key};
        print $counter, ' ', $key, "\n" if $debug;
        print Dumper($card) if $debug >= 2;
        my $text = $card->{text};
        my $name = $card->{name};
        $text = '' if !defined($text);
        $text = lc($text);
        $name = lc($name);
        
        if ($text =~ /(\d) damage to all/ && $text !~ /all minions with/) {
            my $amt = $1;
            $amt = '' if $amt >= 3;
            push(@{$tags{"aoe$amt"}}, $name);
        } elsif ($text =~ /(\d) damage/ && $text !~ /all minions with/) {
            print $name,":",$text,"\n";
        }
        if ($name eq 'cone of cold') {
            push(@{$tags{"aoe2"}}, $name);
        }
        if ($text =~ /freeze/) {
            push(@{$tags{"freeze"}}, $name);
        }
        $counter += 1;
    }
    print Dumper(\%tags);
}

1;