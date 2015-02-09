package CardScanner::SynergyFinder;

use strict;
use warnings;

use Data::Dumper;

sub _has_tag { return CardScanner::_has_tag(@_) }

use constant MAX_MINION_SIZE_FOR_BUFF_SYNERGY             => 0;
use constant MIN_MINION_HEALTH_FOR_GET_TAUNT_SYNERGY      => 3;

sub CardScanner::SynergyFinder::find_synergies {
    my %cards = %CardScanner::SynergyFinder::cards;
    my %tags = %CardScanner::tags;
    
    print "Running...\n";
    my $g = Graph::Simple->new ( is_directed => 0, is_weighted => 1);
    my %reasons = ();
    my $debug = $CardScanner::debug;
    
    my $count = 0;
    for my $card_key_x (keys(%cards)) {
        my $card_x = $cards{$card_key_x};
        my ($name_x,
            $text_x,
            $type_x,
            $cost_x,
            $race_x,
            $attack_x,
            $health_x,       
            $blizz_tags_x) = CardScanner::_get_vars_from_card($card_x);
        my $tags_x = $tags{$name_x};
        
        for my $card_key_y (keys(%cards)) {
            my $card_y = $cards{$card_key_y};
            my ($name_y,
                $text_y,
                $type_y,
                $cost_y,
                $race_y,
                $attack_y,
                $health_y,       
                $blizz_tags_y) = CardScanner::_get_vars_from_card($card_y);
            my $tags_y = $tags{$name_y};
            
            # code here.
            $count += 1;
            next if $name_x eq $name_y;
            next if (exists($card_x->{playerClass}) && exists($card_y->{playerClass}) && $card_x->{playerClass} ne $card_y->{playerClass});
            
            # spell power <> spell damange
            if (_has_tag($tags_x, 'has_spellpower', $card_y) && $text_y =~ /[\$](\d+)/) {
                $g->add_edge($name_x, $name_y, 1.00);
                $reasons{"$name_x|$name_y"} = 'The damage of these cards is increased by spell power.';
            }
            # buff <> minion -
            if (ref($tags_x->{'buff'}) eq 'ARRAY' # has a specific requirement
                && _has_tag($tags_x, 'buff', $card_y) && $type_y eq 'minion') {
                $g->add_edge($name_x, $name_y, 1.00);
                $reasons{"$name_x|$name_y"} = 'This card meets special requirements for a buff.';
                
            }elsif (_has_tag($tags_x, 'buff', $card_y) && $type_y eq 'minion' && $cost_y <= MAX_MINION_SIZE_FOR_BUFF_SYNERGY) {            
                $g->add_edge($name_x, $name_y, (3.0/($cost_y+0.10)));
                $reasons{"$name_x|$name_y"} = 'Buffs are ideal on smaller creatures.';
                
            }elsif (_has_tag($tags_x, 'gives_taunt', $card_y) && $type_y eq 'minion' && $health_y >= MIN_MINION_HEALTH_FOR_GET_TAUNT_SYNERGY) {            
                $g->add_edge($name_x, $name_y, ($health_y/6.0+0.10));
                $reasons{"$name_x|$name_y"} = 'The bigger the creature, the more valuable the taunt.';
            }
            # enrage <> pings
            if (_has_tag($tags_x, 'ping', $card_y) && _has_tag($tags_y, 'has_enrage', $card_x) && $type_y eq 'minion' && $health_y >= 2) {
                $g->add_edge($name_x, $name_y, 1.00);
                $reasons{"$name_x|$name_y"} = 'Pings can be used to activate enrage.';
            }
            # enrage <> health-buffs
            if (_has_tag($tags_x, 'buff_health', $card_y) && _has_tag($tags_y, 'has_enrage', $card_x) && $type_y eq 'minion') {
                $g->add_edge($name_x, $name_y, 1.00);
                $reasons{"$name_x|$name_y"} = '+Health increases the chance of successfully triggering enrage.';   
            }
            # windfury <> attack-buffs
            if (_has_tag($tags_x, 'buff_friend_attack', $card_y) && _has_tag($tags_y, 'has_windfury', $card_x) && $type_y eq 'minion') {
                $g->add_edge($name_x, $name_y, 1.00);
                $reasons{"$name_x|$name_y"} = 'Windfury benefits twice as much from increased attack.';   
            }
            # silence <> negative effects on own minions (i.e wailing soul..)
            if ((_has_tag($tags_x, 'silence', $card_y) || $name_x eq 'wailing soul') && _has_tag($tags_y, 'cursed', $card_x) && $type_y eq 'minion') {
                $g->add_edge($name_x, $name_y, 1.00);
                $reasons{"$name_x|$name_y"} = 'Use silence to get rid of negative effect on your own minions.';   
            }
            # weapons & minions who benefit from weapons
            if ((_has_tag($tags_x, 'weapon_synergy', $card_y) && ($type_y eq 'weapon'||(_has_tag($tags_x, 'gives_weapon', $card_y))))) {
                $g->add_edge($name_x, $name_y, 1.00);
                $reasons{"$name_x|$name_y"} = 'These cards have a special synergy with weapons.';   
            }
            # growing minions + taunt
            if ((_has_tag($tags_x, 'growth', $card_y) && ((_has_tag($tags_y, 'has_taunt', $card_x) || _has_tag($tags_y, 'gives_taunt', $card_x))))) {
                $g->add_edge($name_x, $name_y, 1.00);
                $reasons{"$name_x|$name_y"} = 'Use taunt to protect minions that can grow out of control.';   
            }
            # alarm-o-bot, big drops
            if (_has_tag($tags_x, 'drop_big', $card_y) && ($name_y eq 'alarm-o-bot')) {
                $g->add_edge($name_x, $name_y, 1.00);
                $reasons{"$name_x|$name_y"} = 'Use alarm-o-bot to bring in big drops!';   
            }
            # alexstrasza, reach
            my $dmg_x = _has_tag($tags_x, 'direct_damage', $card_y);            
            if (defined($dmg_x) && $dmg_x >= 3 && ($name_y eq 'alexstrasza')) {
                $g->add_edge($name_x, $name_y, 1.00);
                $reasons{"$name_x|$name_y"} = 'Alexstrasza + direct damage == opponent dead.';   
            }
            # acolyte of pain + health-buff
            if (_has_tag($tags_x, 'buff_health', $card_y) && ($name_y eq 'acolyte of pain')) {
                $g->add_edge($name_x, $name_y, 1.00);
                $reasons{"$name_x|$name_y"} = 'More health means more pain...';   
            }            
            # brewmaster and battle cry
            if ((_has_tag($tags_x, 'panda', $card_y) && ((_has_tag($tags_y, 'has_battlecry', $card_x))))
                    && $name_y !~ 'millhouse'
                    && $name_y !~ 'faceless manip'
                    && $name_y ne 'doomguard'
                    && $name_y ne 'king mukla'
                    && $name_y !~ 'jaraxxus'
                    && $name_y !~ 'twilight drake'
                    && $name_y !~ 'void terror'
                    && $name_y !~ 'arcane golem'
                    && $name_y !~ 'flame imp'
                    && $name_y !~ 'felguard') {
                $g->add_edge($name_x, $name_y, 1.00);
                $reasons{"$name_x|$name_y"} = 'Return these cards to your hand to double-up the battlecry effect.';   
            }
            
            # charge and battlecry
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
            # has adjacentbuff, small minions.
            # overload and the shaman thing.
            
        }
    }
    print "Finished > $count comparisons.\n";

    my @vertices = $g->vertices;
    print Dumper(\%reasons) if $debug >= 2;
    print keys(%reasons) . " total synergies.\n";
}

return 1;