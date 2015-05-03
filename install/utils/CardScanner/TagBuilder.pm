package CardScanner::TagBuilder;

use strict;
use warnings;

use Data::Dumper;
use Term::ReadKey;

my %tags = ();

my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();

use constant MAX_BIG_DROP                                 => 7;
use constant MIN_COST_MINION_GROWTH_TAG                   => 3;

sub CardScanner::TagBuilder::create_custom_tags {
    my $counter = 0;
    my %cards = %CardScanner::TagBuilder::cards;
    my $debug = $CardScanner::debug;
    
    for my $key (sort(keys(%cards))) {
        my $card = $cards{$key};

        print 'Scanning:' . $counter, ' ', $key, "\n" if $debug >= 2;
        print Dumper($card) if $debug >= 2;
        
        my ($name, $text, $type, $cost, $race, $attack, $health, $blizz_tag_ref) = CardScanner::get_vars_from_card($card);
        $text =~ s/<b>//g;
        $text =~ s/<\/b>//g;
        my $cost_tag = $cost >= MAX_BIG_DROP ? 'big' : $cost;
        my $drop_tag = 'drop_' . $cost_tag;
        my %blizz_tags = %{$blizz_tag_ref};
        #AOE Damage/Board Clears.
        if ($text =~ /(\d+) damage to all/ && $text !~ /all minions with/) {
            my $total_amt = 3;
            my $sub_amt = $1;
            my $amt = $sub_amt / $total_amt;
            $tags{$name}->{'aoe'} = $amt;
        }        
        #Freeze
        if ($text =~ /freeze/) {
            $tags{$name}->{'freeze'} = 0.5;
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
                $give_tag =~ s/ /_/g;
                $tags{$name}->{"has_$give_tag"} = 1;
            }
        }
        
        #removals
        ##large/big
        if (!exists($tags{$name}) || !exists($tags{$name}->{'aoe'})) {
            if ($text =~ /transform a minion/ || $text =~ /destroy an? ?(?:enemy)? minion/) { #sheep & hex
                $tags{$name}->{'removalbig'} = 1.0;
                $tags{$name}->{'removal'} = 1.0;
            }
            ##more removals
            if ($text =~ /deal .?(\d+) damage (?!to your hero)/) {
                my $dmg = $1;
                $tags{$name}->{'removal'} = 1.0;
                if ($dmg <= 3) {
                    $tags{$name}->{'removalsmall'} = 1.0;
                }
                $tags{$name}->{'reach'} = $1/2;
            }
            if (($text =~ /deal .?(\d+) damage (?:instead)?\./) && ($text !~ /minion/) && ($text !~ /to your hero/)) {
                $tags{$name}->{'direct_damage'} = $1;
            }
            ##wpns
            if ($type eq 'weapon') {
                my $dmg = $attack;
                $tags{$name}->{'removal'} = 1.0;
                if ($dmg <= 3) {
                    $tags{$name}->{'removalsmall'} = 1.0;
                } elsif ($dmg >= 6) {
                    $tags{$name}->{'removalbig'} = 1.0;
                }
            }
            if ($text =~ /its damage to the minions next to it/) {
                $tags{$name}->{'removal'} = 1.0; #betrayal
            }
            if ($type eq 'minion' && exists($blizz_tags{'charge'}) && $cost <= 3) {
                $tags{$name}->{'removalsmall'} = 1.0; 
            }
            if ($type eq 'minion' && exists($blizz_tags{'stealth'}) && $cost <= 4) {
                $tags{$name}->{'removal'} = 1.0; 
            }
        }
        #buffs
        if ( ($text =~ /give a friendly minion [+](\d+)\/[+](\d+)/ || $text =~ /give a minion [+](\d+)\/[+](\d+)/)
             && $text !~ /dies. horribly/
                ) {
            $tags{$name}->{'buff'} = (0.5 * ($1+$2)/2);
        } elsif ($text =~ /give a(?:nother)? (?:random)? ?(?:friendly)? ?minion [+](\d+) health/) {
            $tags{$name}->{'buff_health'} = (0.25 * ($1)/2);
        } elsif ($text =~ /give a(?:nother)? ?(?:random)? ?(friendly)? ?minion [+](\d+) attack/) {
            my $friend = $1;
            my $amt = $2;
            if (defined($friend) && $friend ne '') {
                $tags{$name}->{'buff_friend_attack'} = (0.5 * ($amt));
                $tags{$name}->{'buff_attack'} = (0.5 * ($amt));
            } else {
                $tags{$name}->{'buff_enemy_attack'} = (0.5 * ($amt));
                $tags{$name}->{'buff_attack'} = (0.5 * ($amt));
            }
        }
        #weapon synergy
        if ( ($text =~ /your weapon/) ) {
            $tags{$name}->{'weapon_synergy'} = 1.0;
        } 
        #demon synergy, dont include demon buffs here as they are already covered under conditional buffs by race.
        my @demon_synergy_strings = (
                'Your other Demons have (.*)\.',
                'Put 2 random Demons from your deck into your hand\.',
                'Put a random Demon from your hand into the battlefield\.');
        @demon_synergy_strings = map { lc } @demon_synergy_strings;
        for my $str (@demon_synergy_strings) {
            if ($text =~ /$str/) {
                $tags{$name}->{'demon_synergy'} = 1.0;
            }
        }
        
        #mech synergy
        if ($text =~ /mech/ && $name ne 'dragonling mechanic' && $name ne 'gazlowe') {
            $tags{$name}->{'mech_synergy'} = 1.0;
        }
        
        #pirate synergy
        if ($text =~ /pirate/) {
            $tags{$name}->{'pirate_synergy'} = 1.0;
        }
        
        #gives weapon
        if ( ($text =~ /equip a (\d+)\/(\d+) weapon/) && $type eq 'minion' ) {
            $tags{$name}->{'gives_weapon'} = 1.0;
        }
        
        $tags{$name}->{'buff'}   = ['race:demon',  1.0] if ($name eq 'demonheart');
        $tags{$name}->{'buff'}   = ['race:demon',  0.5] if ($name eq 'demonfire');
        $tags{$name}->{'buff'}   = ['race:beast',  0.5] if ($name eq 'houndmaster');
        $tags{$name}->{'buff'}   = ['race:mech',   0.5] if ($name eq 'iron sensei');
        $tags{$name}->{'buff'}   = ['race:demon',  0.5] if ($name eq 'mal\'ganis'); 
        $tags{$name}->{'buff'}   = ['race:murloc', 0.5] if ($name eq 'murloc warleader'); 
        $tags{$name}->{'buff'}   = ['race:beast',  0.5] if ($name eq 'cenarius'); 
        $tags{$name}->{'buff'}   = ['attack:1',    0.5] if ($name eq 'hobgoblin'); 
        $tags{$name}->{'buff'}   =                 0.25 if ($name eq 'stormwind champion'); 
        $tags{$name}->{'growth'} = ['race:mech',   0.25] if ($name eq 'junkbot');
        $tags{$name}->{'growth'} = ['race:beast',  0.25] if ($name eq 'scavenging hyena');
        $tags{$name}->{'growth'} = ['secret',      0.25]if ($name eq 'secretkeeper');
        
        #growing minions
        if ($text =~ /[+](\d+)/ && $type eq 'minion' && ($text =~ /each turn/ || $text =~ /whenever/) && $cost <= MIN_COST_MINION_GROWTH_TAG
                && $name !~ /bolvar/ && $name ne 'hobgoblin' && $text !~ /this turn./) {
                
            $tags{$name}->{'growth'} = 0.25;
            
        }
        #pings
        if (($text =~ /\s.?1 damage to an?y? minion/ || $text =~ /\s.?1 damage\./) && $text !~ /armor/ && $text !~ /\s.?1 damage to this minion/) {
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
        if ($text =~ /taunt/ && $name ne 'the black knight' && $name ne 'hex') {
            if ($type eq 'minion' && $name !~ /enhance-o/) {
                $tags{$name}->{'survivability'} = $health / 5;
                $tags{$name}->{'survivability'} += 0.4 if ($text =~ /divine shield/);
            } else {
                $tags{$name}->{'survivability'} = 0.4;
            }
            if (($name eq 'sunfury protector') || (!exists($tags{$name}->{'has_taunt'}) && $text !~ /choose/ && $text !~ /summon/)) {
                $tags{$name}->{'gives_taunt'} = 0.5;
                $tags{$name}->{'gives_taunt'} = ['race:beast',  0.5] if ($name eq 'houndmaster');
            } else {
                $tags{$name}->{'has_taunt'} = 0.5;
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
        #i.e. ancient mage
        if ($text =~ /spell damage/ && !exists($blizz_tags{'spellpower'})) {
            $tags{$name}->{'has_spellpower'} =  0.75;
        }
        #rebirth
        if ($text =~ /return it to life/) {
            $tags{$name}->{'rebirth'} = 0.50;
        }
        #secret_synergy
        if ($text =~ /(?<!^)secret/ && $name ne 'flare' && $name ne 'kezan mystic') {
            $tags{$name}->{'secret_synergy'} = 1.00;
        }
        #overload
        if ($text =~ /overload:/) {
            $tags{$name}->{'overload'} = 1.00;
        }
        #card by card changes.
        $tags{$name}->{'aoe'}          = 0.75      if ($name eq 'cone of cold');
        $tags{$name}->{'bigdrop'}      = 1.00      if ($name =~ /^edwin/);
        $tags{$name}->{'removal'}      = 1.00      if ($name eq 'bite');
        $tags{$name}->{'aoe'}          = 1.25      if ($name eq 'blade flurry');
        $tags{$name}->{'reach'}        = 0.55      if ($name eq 'blade flurry');
        $tags{$name}->{'reach'}        = 1.00      if ($name eq 'blessed champion');
        $tags{$name}->{'reach'}        = 1.00      if ($name eq 'blessing of kings');
        $tags{$name}->{'reach'}        = 1.00      if ($name eq 'blessing of might');
        $tags{$name}->{'reach'}        = 1.00      if ($name eq 'bloodlust');
        $tags{$name}->{'aoe'}          = 1.50      if ($name eq 'brawl');
        $tags{$name}->{'aoe'}          = 0.75      if ($name eq 'circle of healing');
        $tags{$name}->{'reach'}        = 1.00      if ($name eq 'cold blood');
        $tags{$name}->{'removal'}      = 1.00      if ($name eq 'crackle');
        $tags{$name}->{'removalsmall'} = 1.00      if ($name eq 'crackle');
        $tags{$name}->{'removalbig'}   = 1.00      if ($name eq 'crackle');
        $tags{$name}->{'reach'}        = 1.00      if ($name eq 'crackle');
        $tags{$name}->{'removalsmall'} = 1.00      if ($name eq 'claw');
        $tags{$name}->{'reach'}        = 1.00      if ($name eq 'claw');
        $tags{$name}->{'removalsmall'} = 1.00      if ($name eq 'deadly poison');
        $tags{$name}->{'reach'}        = 1.00      if ($name eq 'deadly poison');
        $tags{$name}->{'removalbig'}   = 1.00      if ($name eq 'deadly shot');
        $tags{$name}->{'removal'}      = 1.00      if ($name eq 'deadly shot');
        $tags{$name}->{'draw'}         = 1.00      if ($name eq 'divine favor');
        $tags{$name}->{'draw'}         = 1.00      if ($name eq 'echo of medivh');
        $tags{$name}->{'removalbig'}   = 1.00      if ($name eq 'equality');
        $tags{$name}->{'removalbig'}   = 1.00      if ($name eq 'execute');
        $tags{$name}->{'reach'}        = 1.00 if ($name eq 'heroic strike');
        $tags{$name}->{'removalbig'}   = 0.50      if ($name eq 'humility');
        $tags{$name}->{'removalbig'}   = 0.50      if ($name eq 'hunter\'s mark');
        $tags{$name}->{'aoe'}          = 1.00      if ($name eq 'lightbomb');
        $tags{$name}->{'removalbig'}   = 1.00      if ($name eq 'mind control');
        $tags{$name}->{'drop_1'}       = 1.00      if ($name eq 'mind vision');
        $tags{$name}->{'drop_4'}       = 1.00      if ($name eq 'mind games');
        $tags{$name}->{'reach'}        = 1.00 if ($name eq 'power overwhelming');
        $tags{$name}->{'reach'}        = 1.00 if ($name eq 'rockbiter weapon');
        $tags{$name}->{'removal'}      = 1.00      if ($name eq 'rockbiter weapon');
        $tags{$name}->{'removalsmall'} = 1.00      if ($name eq 'rockbiter weapon');
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
        $tags{$name}->{'reach'}        = 0.500 if ($name eq 'abusive sergeant');
        $tags{$name}->{'removalbig'}   = 0.50      if ($name eq 'aldor peacekeeper');
        #board fill
        $tags{$name}->{'boardfill'}    = 1.00      if ($name eq 'imp master');
        $tags{$name}->{'boardfill'}    = 1.00      if ($name eq 'implosion');
        $tags{$name}->{'boardfill'}    = 0.50      if ($name eq 'dragonling mechanic');
        $tags{$name}->{'boardfill'}    = 0.50      if ($name eq 'muster for battle');
        $tags{$name}->{'boardfill'}    = 0.50      if ($name eq 'murloc tidehunter');
        $tags{$name}->{'boardfill'}    = 0.50      if ($name eq 'razorfen hunter');
        $tags{$name}->{'boardfill'}    = 1.00      if ($name eq 'unleash the hounds');
        $tags{$name}->{'boardfill'}    = 0.50      if ($name eq 'silverhand knight');
        $tags{$name}->{'boardfill'}    = 0.50      if ($name eq 'defias ringleader');
        $tags{$name}->{'boardfill'}    = ['spell', 1.00] if ($name eq 'violet teacher');
        $tags{$name}->{'cursed'}       = 1.00      if ($name eq 'ancient watcher');
        $tags{$name}->{'cursed'}       = 1.00      if ($name eq 'fel reaver');
        $tags{$name}->{'cursed'}       = 1.00      if ($name eq 'zombie chow');
        $tags{$name}->{'cursed'}       = 1.00      if ($name eq 'dancing swords');
        $tags{$name}->{'cursed'}       = 1.00      if ($name eq 'zombie chow');
        $tags{$name}->{'cursed'}       = 1.00      if ($name eq 'deathlord');
        
        # todo make sense of buffs
        $counter += 1;
    }
    my %_all_tags = ();
    if ($debug) {
        for my $card_name (sort(keys(%tags))) {
            my $hash = $tags{$card_name};
            for my $tag (keys(%$hash)) {
                $_all_tags{$tag} = 1;
            }
            my $data =  join(', ', map { if (ref $hash->{$_} eq 'ARRAY') {
                                            sprintf("%s => [%s,%0.2f]", $_, $hash->{$_}->[0], $hash->{$_}->[1]);
                                        } else { sprintf("%s => %0.2f", $_, $hash->{$_}); } } keys(%$hash) );            
            printf("%-30s %-40s\n", $card_name, $data);
        }
        my $count_tags = scalar(keys(%tags));
        my $count_all = scalar(keys(%cards));
        #print STDERR Dumper(\%tags);
        print '*'x$wchar,"\n";
        print "Total cards tagged: " . $count_tags . "\n";
        print "Total cards: " . $count_all . "\n";
        printf("Coverage: %0.2f%%\n", $count_tags / $count_all * 100);
        print '*'x$wchar,"\n";
        #Tags
        print "Tags: " . keys(%_all_tags) . "\n";
        print Text::Format->new({bodyIndent => 4, columns => $wchar})->format(join(', ', sort(keys(%_all_tags))));
        #Cards
        print "Uncovered cards: " . ($count_all-$count_tags) . "\n";
        my %uncovered_cards = ();
        for my $card (sort(keys(%cards))) {;
            if (!exists($tags{lc($card)})) {
                $uncovered_cards{$card} = 1;
            }
        }
        print Text::Format->new({bodyIndent => 4, columns => $wchar})->format(join(', ', sort(keys(%uncovered_cards))));
    }
    
    %CardScanner::tags = %tags;
    return \%tags;
}

return 1;
