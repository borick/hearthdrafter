#!/usr/bin/env perl

package CardScanner;

use strict;
use warnings;

use Data::Dumper;
use Text::Format;
use Term::ReadKey;
#get term size!
my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();

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
        my $cost_tag = $cost > 6 ? 'big' : $cost;
        my $drop_tag = $cost_tag . 'drop';
        
        #AOE Damage
        if ($text =~ /(\d+) damage to all/ && $text !~ /all minions with/) {
            my $total_amt = 3;
            my $sub_amt = $1;
            my $amt = $sub_amt / $total_amt;
            $tags{$name}->{'aoe'} = $amt;
        }        
        #Freeze
        if ($text =~ /freeze/) {
            $tags{$name}->{'freeze'} = 1.0;
        }
        
        #Drops
        if ($type eq 'minion') {
            my $cost_tag = $cost > 6 ? 'big' : $cost;
            my $drop_tag = $cost_tag . 'drop';
            next if $cost <= 0;
            $tags{$name}->{$drop_tag} = 1;
        }
        #Other drops
        if ($type eq 'spell' && $text =~ /summon/
                && $text !~ /destroy/
                && $text !~ /heal/
                && $text !~ /deathrattle/
                && $text !~ /secret/) {
            next if $cost <= 0;
            $tags{$name}->{$drop_tag} = 1;
        }
        if ($type eq 'spell' && $text =~ /secret/) {
            next if $cost <= 0;
            $tags{$name}->{$drop_tag} = 1;
        }

        #Mechs
        if ($text =~ /mech/ || $race eq 'mech') {
            $tags{$name}->{mech} = 1;
        }
        #removals
        ##large/big
        if (!exists($tags{$name}) || !exists($tags{$name}->{'aoe'})) {
            if ($text =~ /transform a minion/ || $text =~ /destroy an? ?(?:enemy)? minion/) { #sheep & hex
                $tags{$name}->{'bigremoval'} = 1.0;
                $tags{$name}->{'removal'} = 1.0;
            }
            ##more removals
            if ($text =~ /deal .?(\d+) damage/) {
                my $dmg = $1;
                $tags{$name}->{'removal'} = 1.0;
                if ($dmg <= 3) {
                    $tags{$name}->{'smallremoval'} = 1.0;
                }
                $tags{$name}->{'reach'} = $1/2;
            }
            ##wpns
            if ($type eq 'weapon') {
                my $dmg = $attack;
                $tags{$name}->{'removal'} = 1.0;
                if ($dmg <= 3) {
                    $tags{$name}->{'smallremoval'} = 1.0;
                } elsif ($dmg >= 6) {
                    $tags{$name}->{'bigremoval'} = 1.0;
                }
            }
            if ($text =~ /its damage to the minions next to it/) {
                $tags{$name}->{'removal'} = 1.0; #betrayal
            }
            if ($type eq 'minion' && $text =~ /charge/ && $cost <= 3) {
                $tags{$name}->{'smallremoval'} = 1.0; 
            }
            if ($type eq 'minion' && $text =~ /stealth/ && $cost <= 4) {
                $tags{$name}->{'removal'} = 1.0; 
            }
        }
        
        #pings
        if ($text =~ /\s1 damage/ && $text =~ /armor/) {
            $tags{$name}->{'ping'} = 1.0;
        }
        #survivability
        ## heals
        if ($text =~ /restore .?(\d+)/ && $text !~ /now deal damage instead/ && $text !~ /restore .\d+ health to all minions/) {
            $tags{$name}->{'survivability'} = $1 / 8;
        }
        ## taunts
        if ($text =~ /taunt/) {
            if ($type eq 'minion' && $name !~ /enhance-o/) {
                $tags{$name}->{'survivability'} = $health / 5;
                $tags{$name}->{'survivability'} += 0.4 if ($text =~ /divine shield/);
            } else {
                $tags{$name}->{'survivability'} = 0.4;
            }
        }
        #Card Draw
        if ($text =~ /draw .?(\d+)/) {
            $tags{$name}->{'draw'} = $1 / 2;  
        }
        if ($text =~ /draw a card/) {
            $tags{$name}->{'draw'} = 0.5;  
        }
        if ($text =~ /silence/ && $name ne 'wailing soul') {
            $tags{$name}->{'silence'} = 1;  
        }
        
        #Special cards.
        $tags{$name}->{'aoe'}          = 0.75 if ($name eq 'cone of cold');
        $tags{$name}->{'bigdrop'}      = 1.00 if ($name =~ /^edwin/);
        $tags{$name}->{'removal'}      = 1.00 if ($name eq 'bite');
        $tags{$name}->{'aoe'}          = 1.25 if ($name eq 'blade flurry');
        $tags{$name}->{'reach'}        = 0.55 if ($name eq 'blade flurry');
        $tags{$name}->{'reach'}        = 1.00 if ($name eq 'blessed champion');
        $tags{$name}->{'reach'}        = 5.0/4.0 if ($name eq 'blessing of kings');
        $tags{$name}->{'reach'}        = 5.0/3.0 if ($name eq 'blessing of might');
        $tags{$name}->{'reach'}        = 1.00 if ($name eq 'bloodlust');
        $tags{$name}->{'aoe'}          = 1.50 if ($name eq 'brawl');
        $tags{$name}->{'aoe'}          = 0.75 if ($name eq 'circle of healing');
        $tags{$name}->{'reach'}        = 5.0/4.0 if ($name eq 'cold blood');
        $tags{$name}->{'removal'}      = 1.0 if ($name eq 'crackle');
        $tags{$name}->{'smallremoval'} = 1.0 if ($name eq 'crackle');
        $tags{$name}->{'bigremoval'}   = 1.0 if ($name eq 'crackle');
        $tags{$name}->{'reach'}        = 1.0 if ($name eq 'crackle');
        $tags{$name}->{'smallremoval'} = 1.0 if ($name eq 'claw');
        $tags{$name}->{'reach'}        = 3.0/4.0 if ($name eq 'claw');
        $tags{$name}->{'smallremoval'} = 1.0 if ($name eq 'deadly poison');
        $tags{$name}->{'reach'}        = 3.0/4.0 if ($name eq 'deadly poison');
        $tags{$name}->{'bigremoval'}   = 1.0 if ($name eq 'deadly shot');
        $tags{$name}->{'removal'}      = 1.0 if ($name eq 'deadly shot');
        $tags{$name}->{'draw'}         = 1.0 if ($name eq 'divine favor');
        $tags{$name}->{'draw'}         = 1.0 if ($name eq 'echo of medivh');
        $tags{$name}->{'bigremoval'}   = 1.0 if ($name eq 'equality');
        $tags{$name}->{'bigremoval'}   = 1.0 if ($name eq 'execute');
        $tags{$name}->{'reach'}        = 4.0/4.0 if ($name eq 'heroic strike');
        $tags{$name}->{'bigremoval'}   = 0.5 if ($name eq 'humility');
        $tags{$name}->{'bigremoval'}   = 0.5 if ($name eq 'hunter\'s mark');
        $tags{$name}->{'aoe'}          = 1.00 if ($name eq 'lightbomb');
        $tags{$name}->{'bigremoval'}   = 1.0 if ($name eq 'mind control');
        $tags{$name}->{'1drop'}        = 1.0 if ($name eq 'mind vision');
        $tags{$name}->{'4drop'}        = 1.0 if ($name eq 'mind games');
        $tags{$name}->{'reach'}        = 4.0/4.0 if ($name eq 'power overwhelming');
        $tags{$name}->{'reach'}        = 3.0/4.0 if ($name eq 'rockbiter weapon');
        $tags{$name}->{'smallremoval'} = 1.0 if ($name eq 'rockbiter weapon');
        $tags{$name}->{'reach'}        = 1.0 if ($name eq 'savage roar');
        $tags{$name}->{'reach'}        = 1.0 if ($name eq 'tinker\'s sharpsword oil');
        $tags{$name}->{'draw'}         = 0.33 if ($name eq 'tracking');
        $tags{$name}->{'aoe'}          = 1.0 if ($name eq 'shadowflame');
        $tags{$name}->{'aoe'}          = 1.0 if ($name eq 'twisting nether');
        $tags{$name}->{'draw'}         = 1.0 if ($name eq 'thoughtsteal');
        $tags{$name}->{'survivability'}= 1.0 if ($name eq 'tree of life');
        $counter += 1;
    }
    
    for my $tag (sort(keys(%tags))) {
        my $hash = $tags{$tag};
        my $data =  join(', ', map { sprintf("%s => %0.2f", $_, $hash->{$_}) } keys(%$hash) );
        printf("%-30s %-40s\n", $tag, $data);
    }
    my $count_tags = scalar(keys(%tags));
    my $count_all = scalar(keys(%cards));
    print '*'x$wchar,"\n";
    print "Total tags: " . $count_tags . "\n";
    print "Total cards: " . $count_all . "\n";
    printf("Coverage: %0.2f\n", $count_tags / $count_all * 100); 
    print '*'x$wchar,"\n";
    print "Uncovered cards: " . ($count_all-$count_tags) . "\n";
    my %uncovered_cards = ();
    for my $card (sort(keys(%cards))) {
        if (!exists($tags{$card})) {
            $uncovered_cards{$card} = 1;
        }
    }
    print Text::Format->new({bodyIndent => 4, columns => $wchar})->format(join(', ', sort(keys(%uncovered_cards))));
}

1;