#!/usr/bin/env perl

package CardScanner;

#Builds additional card tags & card synergies.

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

sub create_custom_tags {
    my $counter = 0;
    for my $key (sort(keys(%cards))) {
        my $card = $cards{$key};
        print 'Scanning:' . $counter, ' ', $key, "\n" if $debug >= 2;
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
        my $cost_tag = $cost;#$cost > 6 ? 'big' : $cost;
        my $drop_tag = $cost_tag . 'drop';
        my $mechanics = $card->{mechanics};
        my %blizz_tags = ();
        if (defined($mechanics)) {
            for my $mech (@$mechanics) {
                $blizz_tags{lc($mech)} = 1;
            }
        }
        #AOE Damage/Board Clears.
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
        $tags{$name}->{mech} = 1 if ($text =~ /mech/);
        #Murlocs
        $tags{$name}->{murloc} = 1 if ($text =~ /murloc/);
        #demons
        $tags{$name}->{demon} = 1 if ($text =~ /demon/);
        #pirates
        $tags{$name}->{pirate} = 1 if ($text =~ /pirate/);
        #race
        $tags{$name}->{"race_$race"} = 1 if ($type eq 'minion') and $race ne '';
        #deathrattle
        $tags{$name}->{deathrattle} = 1 if ($name eq 'undertaker');
        
        #deathrattle,etc -> has_deathrattle.
        if ($type eq 'minion') {
            for my $give_tag (keys(%blizz_tags)) {
                $tags{$name}->{"has_$give_tag"} = 1;
            }
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
            if ($type eq 'minion' && exists($blizz_tags{'charge'}) && $cost <= 3) {
                $tags{$name}->{'smallremoval'} = 1.0; 
            }
            if ($type eq 'minion' && exists($blizz_tags{'stealth'}) && $cost <= 4) {
                $tags{$name}->{'removal'} = 1.0; 
            }
        }
        #buffs
        if ($text =~ /[+](\d+)\/[+](\d+)/ && $type ne 'weapon'
                && $name ne 'blood knight'
                && $name ne 'frostwolf warlord'
                && $name ne 'hungry crab'
                && $name ne 'lil\' exorcist'
                && $name ne 'power overwhelming'
                && $name ne 'captain greenskin'
                && $name ne 'ethereal arcanist'
                && $name ne 'floating watcher'
                && $name ne 'gruul'
                && $name ne 'hobgoblin'
                && $name ne 'undertaker'
                ) {
            $tags{$name}->{'buff'} = 1.0;
        }
        $tags{$name}->{'buff'} = ['race:demon',  3.0] if ($name eq 'demonheart');
        $tags{$name}->{'buff'} = ['race:beast',  2.0] if ($name eq 'houndmaster');
        $tags{$name}->{'buff'} = ['race:mech',   2.0] if ($name eq 'iron sensei');
        $tags{$name}->{'buff'} = ['race:mech',   2.0] if ($name eq 'junkbot');
        $tags{$name}->{'buff'} = ['race:demon',  2.0] if ($name eq 'mal\'ganis'); 
        $tags{$name}->{'buff'} = ['race:murloc', 2.0] if ($name eq 'murloc warleader'); 
        
        #growing minions
        if ($text =~ /[+](\d+)/ && $type eq 'minion' && ($text =~ /each turn/ || $text =~ /whenever/)) {
            $tags{$name}->{'growth'} = 1.0;
            
        }

        #pings
        if ($text =~ /\s.?1 damage/ && $text !~ /armor/ && $text !~ /\s.?1 damage to this minion/) {
            $tags{$name}->{'ping'} = 1.0;
        }
        #survivability
        ## heals
        if ($text =~ /restore .?(\d+)/
                && $text !~ /now deal damage instead/
                && $text !~ /restore .\d+ health to all minions/
                && $text !~ /to the enemy hero/ ) {
            $tags{$name}->{'survivability'} = $1 / 8;
            $tags{$name}->{'heal'} = $1;
        }
        ## taunts
        if ($text =~ /taunt/ && $name ne 'black knight' && $name ne 'hex') {
            if ($type eq 'minion' && $name !~ /enhance-o/) {
                $tags{$name}->{'survivability'} = $health / 5;
                $tags{$name}->{'survivability'} += 0.4 if ($text =~ /divine shield/);
            } else {
                $tags{$name}->{'survivability'} = 0.4;
            }
            if (!exists($tags{$name}->{'has_taunt'}) && $text !~ /choose/ && $text !~ /summon/) {
                $tags{$name}->{'gives_taunt'} = 1.0;
                $tags{$name}->{'gives_taunt'} = ['race:beast',  1.0] if ($name eq 'houndmaster');
            } else {
                $tags{$name}->{'has_taunt'} = 1.0;
            }
        }
        #Card Draw
        if ($text =~ /draws? .?(\d+)/) {
            $tags{$name}->{'draw'} = $1 / 2;  
        }
        if ($text =~ /draw a card/) {
            $tags{$name}->{'draw'} = 0.5;  
        }
        if ($text =~ /silence/ && $name ne 'wailing soul') {
            $tags{$name}->{'silence'} = 1;  
        }
        #Shroud
        if ($text =~ /can\'t be targeted/) {
            $tags{$name}->{'shroud'} = 1;
        }
        #Enrage
        if ($text =~ /enrage/) {
            $tags{$name}->{'enrage'} = 1;
        }
        #panda
        if ($text =~ /return a( random)? friendly minion/) {
            my $rnd = $1;
            $tags{$name}->{'panda'} = $rnd ? 0.5 : 1.0;
        }
        
        if ($text =~ /spell damage/ && !exists($blizz_tags{'spellpower'})) {
            $tags{$name}->{'has_spellpower'} =  1.0;
        }
        
        #customizations.
        $tags{$name}->{'aoe'}          = 0.75      if ($name eq 'cone of cold');
        $tags{$name}->{'bigdrop'}      = 1.00      if ($name =~ /^edwin/);
        $tags{$name}->{'removal'}      = 1.00      if ($name eq 'bite');
        $tags{$name}->{'aoe'}          = 1.25      if ($name eq 'blade flurry');
        $tags{$name}->{'reach'}        = 0.55      if ($name eq 'blade flurry');
        $tags{$name}->{'reach'}        = 1.00      if ($name eq 'blessed champion');
        $tags{$name}->{'reach'}        = 5.00/4.00 if ($name eq 'blessing of kings');
        $tags{$name}->{'reach'}        = 5.00/3.00 if ($name eq 'blessing of might');
        $tags{$name}->{'reach'}        = 1.00      if ($name eq 'bloodlust');
        $tags{$name}->{'aoe'}          = 1.50      if ($name eq 'brawl');
        $tags{$name}->{'aoe'}          = 0.75      if ($name eq 'circle of healing');
        $tags{$name}->{'reach'}        = 5.00/4.00 if ($name eq 'cold blood');
        $tags{$name}->{'removal'}      = 1.00      if ($name eq 'crackle');
        $tags{$name}->{'smallremoval'} = 1.00      if ($name eq 'crackle');
        $tags{$name}->{'bigremoval'}   = 1.00      if ($name eq 'crackle');
        $tags{$name}->{'reach'}        = 1.00      if ($name eq 'crackle');
        $tags{$name}->{'smallremoval'} = 1.00      if ($name eq 'claw');
        $tags{$name}->{'reach'}        = 3.00/4.00 if ($name eq 'claw');
        $tags{$name}->{'smallremoval'} = 1.00      if ($name eq 'deadly poison');
        $tags{$name}->{'reach'}        = 3.00/4.00 if ($name eq 'deadly poison');
        $tags{$name}->{'bigremoval'}   = 1.00      if ($name eq 'deadly shot');
        $tags{$name}->{'removal'}      = 1.00      if ($name eq 'deadly shot');
        $tags{$name}->{'draw'}         = 1.00      if ($name eq 'divine favor');
        $tags{$name}->{'draw'}         = 1.00      if ($name eq 'echo of medivh');
        $tags{$name}->{'bigremoval'}   = 1.00      if ($name eq 'equality');
        $tags{$name}->{'bigremoval'}   = 1.00      if ($name eq 'execute');
        $tags{$name}->{'reach'}        = 4.00/4.00 if ($name eq 'heroic strike');
        $tags{$name}->{'bigremoval'}   = 0.50      if ($name eq 'humility');
        $tags{$name}->{'bigremoval'}   = 0.50      if ($name eq 'hunter\'s mark');
        $tags{$name}->{'aoe'}          = 1.00      if ($name eq 'lightbomb');
        $tags{$name}->{'bigremoval'}   = 1.00      if ($name eq 'mind control');
        $tags{$name}->{'1drop'}        = 1.00      if ($name eq 'mind vision');
        $tags{$name}->{'4drop'}        = 1.00      if ($name eq 'mind games');
        $tags{$name}->{'reach'}        = 4.00/4.00 if ($name eq 'power overwhelming');
        $tags{$name}->{'reach'}        = 3.00/4.00 if ($name eq 'rockbiter weapon');
        $tags{$name}->{'smallremoval'} = 1.00      if ($name eq 'rockbiter weapon');
        $tags{$name}->{'reach'}        = 1.00      if ($name eq 'savage roar');
        $tags{$name}->{'reach'}        = 1.00      if ($name eq 'tinker\'s sharpsword oil');
        $tags{$name}->{'draw'}         = 0.33      if ($name eq 'tracking');
        $tags{$name}->{'aoe'}          = 1.00      if ($name eq 'shadowflame');
        $tags{$name}->{'aoe'}          = 1.00      if ($name eq 'twisting nether');
        $tags{$name}->{'draw'}         = 1.00      if ($name eq 'thoughtsteal');
        $tags{$name}->{'survivability'}= 1.00      if ($name eq 'tree of life');
        $tags{$name}->{'enrage'}       = 1.00      if ($name eq 'gurubashi berserker');
        $tags{$name}->{'survivability'}= 1.00      if ($name eq 'alexstrasza');
        $tags{$name}->{'reach'}        = 1.00      if ($name eq 'alexstrasza');
        $tags{$name}->{'reach'}        = 2.00/4.00 if ($name eq 'abusive sergeant');
        $tags{$name}->{'bigremoval'}   = 0.50      if ($name eq 'aldor peacekeeper');
        #board fill
        $tags{$name}->{'boardfill'}    = 1.00     if ($name eq 'imp master');
        $tags{$name}->{'boardfill'}    = 0.50     if ($name eq 'dragonling mechanic');
        $tags{$name}->{'boardfill'}    = 0.50     if ($name eq 'dragonling mechanic');
        $tags{$name}->{'boardfill'}    = 0.50     if ($name eq 'murloc tidehunter');
        $tags{$name}->{'boardfill'}    = 1.00     if ($name eq 'hogger');
        $tags{$name}->{'boardfill'}    = 0.50     if ($name eq 'razorfen hunter');
        $tags{$name}->{'boardfill'}    = 1.00     if ($name eq 'unleash the hounds');
        $tags{$name}->{'boardfill'}    = 0.50     if ($name eq 'silverhand knight');
        $tags{$name}->{'boardfill'}    = 0.50     if ($name eq 'defias ringleader');
        
        $counter += 1;
    }
    
    if ($debug) {
        for my $tag (sort(keys(%tags))) {
            my $hash = $tags{$tag};
            my $data =  join(', ', map { if (ref $hash->{$_} eq 'ARRAY') {
                                            sprintf("%s => [%s,%0.2f]", $_, $hash->{$_}->[0], $hash->{$_}->[1]);
                                        } else { sprintf("%s => %0.2f", $_, $hash->{$_}); } } keys(%$hash) );
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
}

my %synergies = ();

sub find_synergies {
    # spell power <> spell damange
    # buff <> minion
    # minion+reach =>
    # enrage <> pings
    # enrage <> buffs
    # windfury <> buffs
    # silence <> negative effects on own minions (i.e wailing soul..)
    # bonus weapon damage <> weapons
    # bonus attack damage <> weapons
    # weapons & minions who benefit from weapons
    # growing minions + taunt
    # acidic swamp ooze, kills weapaons
    # alarm-o-bot, big drops
    # alexstrasza, reach
    # acolyte of pain + health-buff
    # brewmaster and battle cry
    # anima golem + stealth
    # demon card + demon, murloc + murloc, etc.
    # lightspawn + priest/dbl health
    # priest dbl hearth + make attack = health
    # combo, small spells
    # adjacent buff, minions
    # frostwolf, minions
    # molten giant, damage
    # sea giant, minions, implosion
    # detahrattles and rebirth, secret, shaman...
    # power of the wild, boardfill
    # SOJ, boardfill
    # knife jungler, board fill
}

1;