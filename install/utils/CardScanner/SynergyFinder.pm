package CardScanner::SynergyFinder;

use strict;
use warnings;

use Data::Dumper;
use Graph::Simple;
use Algorithm::Combinatorics qw(variations);

sub _has_tag { return CardScanner::_has_tag(@_) }

use constant MAX_MINION_SIZE_FOR_BUFF_SYNERGY             => 4;
use constant MIN_MINION_HEALTH_FOR_GET_TAUNT_SYNERGY      => 3;
use constant MIN_MINION_COST_FOR_INNERVATE_SYNERGY        => 4;
use constant MIN_SPELL_COST_COMBO_SYNERGY                 => 1;
use constant MIN_MINION_COST_ADJACENT_BUFF_SYNERGY        => 4;
use constant MIN_MINION_COST_FROSTWOLF_WARLORD_SYNERGY    => 3;
use constant MIN_MINION_COST_SEAGIANT_SYNERGY             => 3;

sub _update_reasons {
    my ($key,$reason,$reasons) = @_;
    push @{$reasons->{"$key"}}, $reason;
}

sub find_synergies {
    my %cards = %CardScanner::SynergyFinder::cards;
    my %tags = %CardScanner::tags;
    
    my $g = Graph::Simple->new ( is_directed => 0, is_weighted => 1);
    my %reasons = ();
    my $debug = $CardScanner::debug;
    
    my @keys = sort(keys(%cards));
    my $iter = variations(\@keys, 2);
    my $count = 0;
    
    while (my $c = $iter->next) {
        
        my $_name_x = $c->[0];
        my $_name_y = $c->[1];
        my $card_x = $cards{$_name_x};
        my $card_y = $cards{$_name_y};
        
        my ($name_x, $text_x, $type_x, $cost_x, $race_x, $attack_x, $health_x, $blizz_tags_x) = CardScanner::get_vars_from_card($card_x);
        my $tags_x = $tags{$name_x};
        
        my ($name_y, $text_y, $type_y, $cost_y, $race_y, $attack_y, $health_y, $blizz_tags_y) = CardScanner::get_vars_from_card($card_y);
        my $tags_y = $tags{$name_y};
        
        $count += 1;
        next if $name_x eq $name_y;
        next if (exists($card_x->{playerClass}) && exists($card_y->{playerClass}) && $card_x->{playerClass} ne $card_y->{playerClass});
        
        # spell power <> spell damange
        if (_has_tag($tags_x, 'has_spellpower', $card_y) && $text_y =~ /[\$](\d+)/) {
            $g->add_edge($name_x, $name_y, 1.00);
           _update_reasons("$name_x|$name_y",'The damage of these cards is increased by spell power.',\%reasons);
        }
        # buff <> minion -
        if (ref($tags_x->{'buff'}) eq 'ARRAY' # has a specific requirement
            && _has_tag($tags_x, 'buff', $card_y) && $type_y eq 'minion') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'This card meets special requirements for a buff.',\%reasons);
            
        }elsif (_has_tag($tags_x, 'buff', $card_y) && $type_y eq 'minion' && $cost_y <= MAX_MINION_SIZE_FOR_BUFF_SYNERGY) {            
            $g->add_edge($name_x, $name_y, (0.5));
            _update_reasons("$name_x|$name_y",'Buffs are ideal on smaller creatures.',\%reasons);   
        }
        
        # give taunt
        if (_has_tag($tags_x, 'gives_taunt', $card_y) && $name_y eq 'ancient watcher') {            
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Give Ancient Watcher taunt in order to make it useful.',\%reasons);
        }elsif (_has_tag($tags_x, 'gives_taunt', $card_y) && $type_y eq 'minion' && $health_y >= MIN_MINION_HEALTH_FOR_GET_TAUNT_SYNERGY && !_has_tag($tags_y, 'has_taunt', $card_x)) {            
            $g->add_edge($name_x, $name_y, ($health_y/6.0+0.10));
            _update_reasons("$name_x|$name_y",'The bigger the creature, the more valuable the taunt.',\%reasons);
        }
        
        #innvervate + cost
        if ($card_x eq 'innervate' && $type_y eq 'minion' && $cost_y >= MIN_MINION_COST_FOR_INNERVATE_SYNERGY) {            
            $g->add_edge($name_x, $name_y, ($cost_y/6.0+0.10));
            _update_reasons("$name_x|$name_y",'Use innervate to bring out big minions.',\%reasons);
        }
        
        # enrage <> pings
        if (_has_tag($tags_x, 'ping', $card_y) && _has_tag($tags_y, 'has_enrage', $card_x) && $type_y eq 'minion' && $health_y >= 2) {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Pings can be used to activate enrage.',\%reasons);
        }
        
        # ping + mech bear cat
        if (_has_tag($tags_x, 'ping', $card_y) && $name_y eq 'mech-bear cat') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Pings == more spare parts!',\%reasons);
        }
        
        # enrage <> health-buffs
        if (_has_tag($tags_x, 'buff_health', $card_y) && _has_tag($tags_y, 'has_enrage', $card_x) && $type_y eq 'minion') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'+Health increases the chance of successfully triggering enrage.',\%reasons);
        }
        # windfury <> attack-buffs
        if (_has_tag($tags_x, 'buff_friend_attack', $card_y) && _has_tag($tags_y, 'has_windfury', $card_x) && $type_y eq 'minion') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Windfury benefits twice as much from increased attack.',\%reasons);
        }
        # silence <> negative effects on own minions (i.e wailing soul..)
        if ((_has_tag($tags_x, 'silence', $card_y) || $name_x eq 'wailing soul') && _has_tag($tags_y, 'cursed', $card_x) && $type_y eq 'minion') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Use silence to get rid of negative effect on your own minions.',\%reasons);
        }
        # weapons & minions who benefit from weapons
        if ((_has_tag($tags_x, 'weapon_synergy', $card_y) && ($type_y eq 'weapon'||(_has_tag($tags_x, 'gives_weapon', $card_y))))) {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'These cards have a special synergy with weapons.',\%reasons);
        }
        # growing minions + taunt
        if ((_has_tag($tags_x, 'growth', $card_y) && ((_has_tag($tags_y, 'has_taunt', $card_x) || _has_tag($tags_y, 'gives_taunt', $card_x))))) {
            $g->add_edge($name_x, $name_y, 0.25);
            _update_reasons("$name_x|$name_y",'Use taunt to protect minions that can increase in stats over time.',\%reasons);
        }
        # alarm-o-bot, big drops
        if ((_has_tag($tags_x, 'drop_big', $card_y) || _has_tag($tags_x, 'drop_6', $card_y)) && ($name_y eq 'alarm-o-bot')) {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Use alarm-o-bot to bring in big drops!',\%reasons);
        }
        # alexstrasza, reach
        my $dmg_x = _has_tag($tags_x, 'direct_damage', $card_y);            
        if (defined($dmg_x) && $dmg_x >= 3 && ($name_y eq 'alexstrasza')) {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Alexstrasza + direct damage == opponent dead.',\%reasons);
        }
        # acolyte of pain + health-buff
        if (_has_tag($tags_x, 'buff_health', $card_y) && ($name_y eq 'acolyte of pain')) {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'More health means more pain...',\%reasons);
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
            _update_reasons("$name_x|$name_y",'Return these cards to your hand to double-up the battlecry effect.',\%reasons);
        }
        # charge and battlecry
        if (_has_tag($tags_x, 'panda', $card_y) && _has_tag($tags_y, 'has_charge', $card_x)) {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Return these cards to your hand for double the charge-damage.',\%reasons);
        }

        # anima golem + stealth
        if (_has_tag($tags_x, 'has_stealth', $card_y) && $name_y eq 'anima golem') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Stealth cards help keep Anima Golem alive.',\%reasons);
        }
        
        #demon synergy
        if (_has_tag($tags_x, 'demon_synergy', $card_y) && $race_y eq 'demon') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Certain cards have a special synergy with demons.',\%reasons);
        }
        
        #mech synergy
        if (_has_tag($tags_x, 'mech_synergy', $card_y) && ($race_y eq 'mech' || $name_y =~ /mech/)) {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Certain cards have a special synergy with mechs.',\%reasons);
        }

        #pirate synergy
        if (_has_tag($tags_x, 'pirate_synergy', $card_y) && $race_y eq 'pirate') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Certain cards have a special synergy with pirates.',\%reasons);
        }
        
        # lightspawn + priest/dbl health (divine spirit, inner fire
        if ($name_x eq 'divine spirit' && $name_y eq 'lightspawn') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Make lightspawn a 10/10.',\%reasons);
        }
        
        # priest dbl hearth + make attack = health
        if ($name_x eq 'divine spirit' && $name_y eq 'inner fire') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Give a minion huge health... and attack!',\%reasons);
        }
        
        # combo, small spells
        if (_has_tag($tags_x, 'has_combo', $card_y) && $cost_y <= MIN_SPELL_COST_COMBO_SYNERGY && $type_y eq 'spell') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Small-cost spells means combo-trigger likely.',\%reasons);
        }        
        
        # adjacent buff, minions
        if (_has_tag($tags_x, 'has_adjacentbuff', $card_y) && $cost_y <= MIN_MINION_COST_ADJACENT_BUFF_SYNERGY && $type_y eq 'minion' && !_has_tag($tags_y, 'cursed', $card_x)) { #avoid ancient watcher
            if (_has_tag($tags_y, 'has_windfury', $card_x)) {
                $g->add_edge($name_x, $name_y, 0.60); #more value if windfury
            } else {
                $g->add_edge($name_x, $name_y, 0.30);
            }
            _update_reasons("$name_x|$name_y",'Good size minions means extra damage from adjacent buff.',\%reasons);
        }
        
        # frostwolf, boardfill
        if (_has_tag($tags_x, 'boardfill', $card_y) && $name_y eq 'frostwolf warlord') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Frostwolf Warlord gets huge with cards that fill the board.',\%reasons); 
        }
        #frost wolf, low cost minion
        if ($cost_x <= MIN_MINION_COST_FROSTWOLF_WARLORD_SYNERGY && $type_x eq 'minion' && $name_y eq 'frostwolf warlord') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Frostwolf Warlord grows bigger if you have a lot of minions.',\%reasons);
        }
        # sea giant, minions, implosion
        if (_has_tag($tags_x, 'boardfill', $card_y) && $name_y eq 'sea giant') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Sea Giant can be more easily cast with cards that fill the board.',\%reasons);  
        }
        if ($cost_x <= MIN_MINION_COST_SEAGIANT_SYNERGY && $type_x eq 'minion' && $name_y eq 'sea giant') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Sea Giant costs less mana with more minions on board.',\%reasons);
        }
        
        # detahrattles and rebirth, but not cursed ones. or mostly useless ones.
        if (_has_tag($tags_x, 'has_deathrattle', $card_y) && $name_x ne 'feugen' && $name_x ne 'stalagg' && !_has_tag($tags_x, 'cursed', $card_y)
                && _has_tag($tags_y, 'rebirth', $card_x)) {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Return deathrattles to life for extra deathrattles!',\%reasons);
        }
        
        # secret synergy
        if (_has_tag($tags_x, 'secret_synergy', $card_y) && $text_y =~ 'secret:') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Certain cards have a special synergy with secrets.',\%reasons);
        }
        
        # shaman overload
        if (_has_tag($tags_x, 'overload', $card_y) && $name_y eq 'unbound elemental') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Unbound Elemental gets bigger with more overload!',\%reasons);   
        }
        
        # power of the wild, boardfill
        # SOJ, boardfill
        # knife jungler, board fill
        if (_has_tag($tags_x, 'boardfill', $card_y) && $name_y eq 'knife juggler') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Fill the board for more knives!',\%reasons);
        }
        
        if (_has_tag($tags_x, 'boardfill', $card_y) && ($name_y eq 'sword of justice' || $name_y eq 'power of the wild')) {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Lots of buffed minions!',\%reasons);
        }
        
        # power of the wild & violet teacher
        if ($name_x eq 'power of the wild' && $name_y eq 'violet teacher') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Strong students!',\%reasons);
        }
        # stormwind knight + crazed alch
        if ($name_x eq 'stormwind knight' && $name_y eq 'crazed alchemist') {
            $g->add_edge($name_x, $name_y, 1.00);
            _update_reasons("$name_x|$name_y",'Smash your knight into stuff',\%reasons);
        }
        
        
        
        
    }
    print "Finished > $count comparisons.\n" if $debug;

    my @vertices = $g->vertices;
    print Dumper(\%reasons) if $debug >= 2;
    print keys(%reasons) . " total synergies.\n" if $debug;
    
    return [$g, \%reasons];
}

return 1;