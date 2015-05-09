package HearthModel::CardChoice;

use strict;
use warnings;

use Moo;
extends 'HearthModel::DbBase';

has c => (
    is => 'rw',
);

$HearthModel::CardChoice::debug = 0;

use Time::Piece;
use Data::Dumper;
#$Data::Dumper::Indent = 0;
use List::Util qw(sum);

sub get_next_index {
    my ($self,$source) = @_;
    return $self->c()->model->arena->get_next_index($source);
}

sub _print_scores {
    my $scores = shift;
    for my $name (keys(%$scores)) {
        print $name ," |";
    }
    print "\n";
}


my $syn_const          = 200.00; #the power of synergies....
my $mana_const_minions = 5.00; #percentage increase per "mana diff" point for minions in general.
my $mana_const_spells  = 3.00; #spells in general.
my $missing_drop_const = 250.00; #just drops. const
my $duplicate_constant = 0.05; #percent amount decrease / 1
my $tag_needed_mult    = 0.10; #percent amt dmt increase / 1
my $control_vs_tempo_threshold = 0.15;
                        #0,1,2,3,4,5,6,7+
my $max_cost       = 7; #for the last column

#my @max_drops      = (2,3,8,5,5,4,3,2);

# bunch of global stuff

my $deck_type = "value";                           #0, 1, 2, 3, 4, 5, 6, 7 +              
my $ideal_curves    = { value => {      minions => [0, 0, 5, 3, 5, 4, 3, 2],
                                        spells =>  [0, 0, 4, 1, 1, 1, 1, 0],
                                        drops =>   [0, 0, 4, 2, 3, 2, 1, 1],},
                                        
                        late_game => {  minions => [0, 0, 6, 6, 2, 5, 5, 1], 
                                        spells =>  [0, 1, 2, 0, 1, 0, 0, 1],
                                        drops =>   [0, 0, 4, 2, 3, 2, 1, 1],},
                                        
                        aggro => {      minions => [0, 1, 9, 6, 4, 4, 0, 1],
                                        spells =>  [1, 2, 1, 0, 0, 0, 0, 1],
                                        drops =>   [0, 0, 6, 3, 2, 1, 1, 1],},
                                        
                        control => {    minions => [0, 3, 2, 4, 4, 4, 3, 2], 
                                        spells =>  [0, 4, 1, 1, 1, 0, 1, 0],
                                        drops =>   [0, 0, 4, 2, 4, 2, 1, 1],},};
                                        
my $tags_wanted = { value => [ 'draw', 'aoe', 'removal', 'ping' ],
                    late_game => [ 'survivability', 'aoe', 'removal', 'ping'],
                    aggro => [ 'draw' ],
                    control => [ 'draw', 'removal', 'ping', 'aoe' ], };
                    
my %all_tags_hash = ();
my @all_tags = undef;
for my $key (%$tags_wanted) {
    for my $tag (@{$tags_wanted->{$key}}) {
        $all_tags_hash{$tag} = 1;
    }
}
@all_tags = keys(%all_tags_hash);

# bunch of global stuff

sub get_advice {
    my ($self, $card_1, $card_2, $card_3, $arena_id) = @_;        
    $card_1 =~ s/[.]//g;
    $card_2 =~ s/[.]//g;
    $card_3 =~ s/[.]//g;
    my $debug = $HearthModel::CardChoice::debug;
    $debug = '' if !defined($debug);
    my $c = $self->c();
    my $source = $c->model->arena->continue_run($arena_id);
    my $next_index = $self->get_next_index($source);
    return undef if $next_index >= 30;
    
    my @card_choices = @{$source->{card_choices}};
    my %card_counts = %{$source->{card_counts}};
    my $card_number = scalar(@card_choices) + 1;
    my $complete = $card_number/25; #out of 1
    my $out_data = {};
    my $card_options = $source->{card_options};    
    #update the card choices we have
    $card_options->[$next_index] = {card_name   => $card_1,
                                    card_name_2 => $card_2,
                                    card_name_3 => $card_3};
    
    my $message_flag = "";
    my $message = "";
    my $best_card_before;
    my $best_card_after;
    my $best_card_score;
    
    my %scores_hist = ();
    #build a hashmap of names to scores
    my %scores = ();
    #my %math = ();
    my @unique_cards = keys(%card_counts);
    my @data_for = @unique_cards;
    push(@data_for, $card_1, $card_2, $card_3);
    my $card_data = $c->model->card->get_data(\@data_for);
    # {name => {tag => value, tag2 => value}}
    my $card_data_tags = $c->model->card->get_tags(\@data_for);
    #print STDERR Dumper($card_data_tags);
    #die "bad card specified $card_1, $card_2, $card_3" if !exists($card_data_tags->{$card_1}) || !exists($card_data_tags->{$card_2}) || !exists($card_data_tags->{$card_3});
    
    
    my %tags_data = ();
    # build a "drop__" curve.
    my @drop_curve =    (0,0,0,0,0,0,0,0);
    my $num_drops = 0;#one,meh,soit doesn't illegal by zero?
    my $total_drop_cost = 0;
    for my $card_name_key (keys(%card_counts)) {
        my $count = $card_counts{$card_name_key};
        for my $card_tag (keys(%{$card_data_tags->{$card_name_key}})) {
            $tags_data{$card_tag} += 1;
            if ($card_tag =~ /drop_(\d+)/) {
                $drop_curve[$1] += $count;
                $total_drop_cost += $card_data->{$card_name_key}->{cost} * $count;
                $num_drops += $count;
            }
        }
    }
    print STDERR "Tags: " . Dumper(\%tags_data),"\n" if $debug =~ 'tags';
    
    my $number_of_cards = scalar(@unique_cards);
    print STDERR "*" x 80, "\n" if $debug;
    print STDERR "Number of cards: $number_of_cards\n" if $debug;
    
    my %type_breakdown = ();
    my $average_drop = $num_drops == 0 ? 0 : $total_drop_cost / $num_drops;
    my $total_cost = 0;
    for my $card (@unique_cards) {
        my $card_info = $card_data->{$card};
        next if !exists($card_info->{cost});
        $total_cost += $card_info->{cost};
        $type_breakdown{$card_info->{type}} += 1;
    }
    if ($average_drop <= 2.5) {
        $deck_type = 'aggro';
    } elsif ($average_drop >= 4.0) {
        $deck_type = 'late_game';
    } elsif ($number_of_cards > 5) {
        my $spells_count = exists($type_breakdown{spell}) ? $type_breakdown{spell} : 0;
        my $ratio = $spells_count / $number_of_cards;
        if ($ratio <= $control_vs_tempo_threshold) {
            $deck_type = 'value';
        } else {
            $deck_type = 'control';
        }
    }
    #print STDERR "deck type: $deck_type, $average_drop, $num_drops, $total_drop_cost\n";
    my $average_cost = ($number_of_cards > 0) ? ($total_cost / $number_of_cards) : 0; 
    my @min_drops = @{$ideal_curves->{$deck_type}->{drops}};
    print STDERR "Average cost of cards: $average_cost\n" if $debug =~ 'average';
    print STDERR "Average drop: $average_drop\n"  if $debug =~ 'average';
    print STDERR "drops " . join('.', @drop_curve) . "\n" if $debug =~ 'drops';
    # build a mana curve...
    my %our_curve_hash = ();
    for my $card (keys(%$card_data)) {
        my $card_info = $card_data->{$card};
        $our_curve_hash{$card_info->{type}}->{$card_info->{cost}} += 1;
    }
    my @ideal_curve_minions = @{$ideal_curves->{$deck_type}->{minions}};
    my @ideal_curve_spells = @{$ideal_curves->{$deck_type}->{spells}};
    my @diff_curve_minions = ();
    my @diff_curve_spells= ();
    for my $key (0..7) {
        if (exists($our_curve_hash{minion}->{$key})) {
            $diff_curve_minions[$key] = - $ideal_curve_minions[$key] + $our_curve_hash{'minion'}->{$key}; 
        } else {
            $diff_curve_minions[$key] = - $ideal_curve_minions[$key];
        }
    }
    for my $key (0..7) {
        if (exists($our_curve_hash{spell}->{$key})) {
            $diff_curve_spells[$key] = - $ideal_curve_spells[$key] + $our_curve_hash{'spell'}->{$key}; 
        } else {
            $diff_curve_spells[$key] = - $ideal_curve_spells[$key];
        }
    }
    #create a min drops diff curve to adjust for missing drops below.
    my @drop_diff_min = (0,0,0,0,0,0,0,0);
    for my $key (0..7) {
        $drop_diff_min[$key] = $drop_curve[$key] - $min_drops[$key];
    }
    if ($debug =~ 'curve') {
        print STDERR 'drop diff min ' . join('|', @drop_diff_min),"\n";
        print STDERR 'ideal curve for minions ' . join('|',@ideal_curve_minions),"\n";
        print STDERR 'diff curve for minions ' . join('|',@diff_curve_minions),"\n";
        print STDERR 'ideal curve for minions ' . join('|',@ideal_curve_spells),"\n";
        print STDERR 'diff curve for spells ' . join('|', @diff_curve_spells),"\n";   
        print STDERR 'our curve minion key ';
        for my $key(sort(keys(%{$our_curve_hash{minion}}))) {
            print STDERR $key . '|';
        }
        print STDERR "\nour curve minion     ";
        for my $key(sort(keys(%{$our_curve_hash{minion}}))) {
            print STDERR $our_curve_hash{minion}->{$key} . '|';
        }
        print STDERR "\n";
        print STDERR 'our curve spell key ';
        for my $key(sort(keys(%{$our_curve_hash{spell}}))) {
            print STDERR $key . '|';
        }
        print STDERR "\nour curve spell     ";
        for my $key(sort(keys(%{$our_curve_hash{spell}}))) {
            print STDERR $our_curve_hash{spell}->{$key} . '|';
        }
        print STDERR "\n";
    }
    if ($debug =~ 'curve') {
        for my $key (keys(%our_curve_hash)) {
            print $key, ' ';
            for my $mana (sort(keys(%{$our_curve_hash{$key}}))) {
                print $mana, ".";
            }
            print "\n";
            print ' ' x length($key), ' ';
            for my $mana (sort(keys(%{$our_curve_hash{$key}}))) {
                print $our_curve_hash{$key}->{$mana},".";
            }
            print "\n";
        }
    }
    #synergies    
    # find synergies between the existing card choices (@card_choices) and the currently available cards ($card_1, card_2, etc.)
    my $cards = [$card_1,$card_2,$card_3];
    my %synergies = ();
    for my $card (@$cards) {
        my $synergies_tmp = $self->es->search(
            index => 'hearthdrafter',
            type => 'card_synergy',
            size => 9999,
            body => {
                query => {
                    filtered => {
                        query => {
                            match => { card_name_2 => $card },
                        },
                        filter => {
                            terms => {
                                card_name => \@card_choices,
                            },
                        },   
                    },
                },
            },
        );
        $synergies{$card} = [];
        for my $synergy (@{$synergies_tmp->{hits}->{hits}}) {
            $synergy = $synergy->{_source};
            delete($synergy->{card_name_2}); 
            push($synergies{$card}, $synergy);
        }
    }
    $out_data->{synergy} = \%synergies;
    $out_data->{card_choices} = \@card_choices;
    $out_data->{card_counts} = \%card_counts;
    $out_data->{current_cards} = $cards; 
    
    #get tier score for each card.
    my $class = $source->{class_name};
    my $scores_result = $self->es->search(
        index => 'hearthdrafter',
        type => 'card_score_by_class',
        body => {
            query => {
                ids => {
                    type => 'card_score_by_class',
                    values => [ "$card_1|$class",  "$card_2|$class",  "$card_3|$class", ],
                },
            },
        },
    );
    $scores_result = $scores_result->{hits}->{hits};
    die 'bad cards' if (@$scores_result <= 0);
    for my $score (@$scores_result) {
        $scores{$score->{'_source'}->{'card_name'}} = $score->{'_source'}->{'score'};
        $scores_hist{$score->{'_source'}->{'card_name'}} = [];
        push($scores_hist{$score->{'_source'}->{'card_name'}}, ['original', $score->{'_source'}->{'score'}]);
    }
    
    #adjust for "missing drops"
    for my $card (sort(@$cards)) {
        my $original_score = $scores{$card};
        if (!exists($card_data->{$card}->{cost})) {
            warn "$card cost not found!\n";
        }
        my $cost = ($card_data->{$card}->{cost} < $max_cost) ? $card_data->{$card}->{cost} : $max_cost;
        my $diff = $drop_diff_min[$cost];
        my $is_drop = 0;
        for my $key (keys(%{$card_data_tags->{$card}})) {
            if ($key =~ /^drop_/) {
                $is_drop = 1;
                last;
            } 
        }
        if ($is_drop && $diff < 0) {
            $scores{$card} = $original_score + (($diff*-1) * ($missing_drop_const*$complete));
        }
        push($scores_hist{$card}, ['missing_drops', $scores{$card}]);
    }
    
    #adjust for mana curve.
    for my $card (sort(@$cards)) {
        my $type = $card_data->{$card}->{type};
        my $cost = $card_data->{$card}->{cost};
        #print STDERR "Cost for $card is $cost, type is $type\n";
        my $original_score = $scores{$card};
        $cost = $max_cost if ($cost > $max_cost);
        my $new_score = undef;
        if ($type eq 'minion'){
            $new_score = $original_score + ($original_score * ($complete * $mana_const_minions * ($diff_curve_minions[$cost]*-1) / 100));
        } elsif ($type eq 'spell') {
            $new_score = $original_score + ($original_score * ($complete * $mana_const_spells * ($diff_curve_spells[$cost]*-1) / 100));
        } else {
            $new_score = $original_score;
        }
        $scores{$card} = $new_score;
        push($scores_hist{$card}, ['mana', $scores{$card}]);
        
        #adjust for diminishing returns on duplicates, default for all cards.
        my $count = $card_counts{$card} || 0;
        #print STDERR "Score before [$card]: " . $scores{$card} . "\n"; 
        $scores{$card} = $scores{$card} - ($duplicate_constant * $count * $scores{$card});
        #print STDERR "Score after [$card]: " . $scores{$card} . "\n";
        push($scores_hist{$card}, ['dups', $scores{$card}]);
    }
    
    #adjust for missing tags.
    #print STDERR "[deck type: $deck_type]\n";
    my %tags_done = ();
    for my $card (sort(@$cards)) {
        for my $tag (@{$tags_wanted->{$deck_type}}) {
            if (exists($card_data_tags->{$card}->{$tag}) && (exists($tags_data{$tag}) && $tags_data{$tag}) <= 2) {
                my $original_score = $scores{$card};
                $scores{$card} = $scores{$card} + ($scores{$card} * ($tag_needed_mult*$complete));
                push($scores_hist{$card}, [$tag, $scores{$card}]);
                $tags_done{$card} = [] if !exists($tags_done{$card});
                $tag = uc($tag) if $tag eq 'aoe';
                push($tags_done{$card}, $tag);
            }
        }
        push($scores_hist{$card}, ['tags_done', $scores{$card}]);
        
    }
    
    my $i = 0;
    #synergies
    for my $card_name (sort(keys(%synergies))) {
        my $synergy_array = $synergies{$card_name};
        my $cumul_weight = 0;
        for my $synergy (@$synergy_array) {
            my $card_name_2 = $synergy->{card_name};
            my $weight = $synergy->{weight};
            my $count = $card_counts{$card_name_2};
            my $total_weight = $weight * $count;
            $cumul_weight += $total_weight;
            print STDERR "synergy between $card_name and $card_name_2 with weight $weight\n" if $debug =~ 'synerg';
        }
        my $original_score = $scores{$card_name};
        my $synergy_modifier = ($cumul_weight);
        my $new_score = $original_score + ($synergy_modifier*$syn_const);
        $scores{$card_name} = $new_score;
        push($scores_hist{$card_name}, ['synergy', $scores{$card_name}]);
        $i += 1;
    }
    
    $source->{deck_type} = $deck_type;
    my $data_out = _get_best_card(\%scores, $out_data);
    $best_card_after = $data_out->[0];
    $best_card_score = $data_out->[1];
      
    $out_data->{message} = _build_message($best_card_after,$best_card_score,\%scores_hist, $card_data, $deck_type, \%tags_done, $number_of_cards);    
    if (!exists($source->{total_score}) || !defined($source->{total_score})) {
        $source->{total_score} = 0;
    }
    $source->{total_score} += $best_card_score;
    my $total_score = $source->{total_score};
    my $grade = 'F';
    if ($total_score > 260000) {
        $grade = 'A+';
    } elsif ($total_score > 230000) {
        $grade = 'A';
    } elsif ($total_score > 170000) {
        $grade = 'B';
    } elsif ($total_score > 125000) {
        $grade = 'C';
    } elsif ($total_score > 80000) {
        $grade = 'D';
    }
    $source->{deck_grade} = $grade;    
    $self->es->index(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
        body => $source,
    );
    #print STDERR Dumper(\%scores);
    for my $card (@$cards) {
        print STDERR "[$card] " . Dumper($scores_hist{$card}), "\n" if $debug =~ 'score';
    }
    return $out_data;
}
sub _capitalize {
    my $blah = shift;
    my $result = '';
    my @tokens = split(/ /,$blah);
    for my $token (@tokens) {
        $result .= ucfirst($token);
        $result .= ' ' if $token ne $tokens[scalar(@tokens)-1];
    }
    return $result;
}
#from http://mkweb.bcgsc.ca/intranet/perlbook/cookbook/ch04_03.htm
sub _commify_series {
    (@_ == 0) ? ''                                      :
    (@_ == 1) ? $_[0]                                   :
    (@_ == 2) ? join(" and ", @_)                       :
                join(", ", @_[0 .. ($#_-1)], "and $_[-1]");
}

sub _get_score_msg {
    my ($best_n, $best_s) = @_;
    my $term = '';
    if ($best_s > 9000) {
        $term = 'an incredible';
    } elsif ($best_s > 8000) {
        $term = 'an amazing';
    } elsif ($best_s > 7000) {
        $term = 'a great';
    } elsif ($best_s > 5000) {
        $term = 'a very strong';
    } elsif ($best_s > 4000) {
        $term = 'a strong';
    } elsif ($best_s > 3000) {
        $term = 'an above average';
    } elsif ($best_s > 2000) {
        $term = 'an average';
    } elsif ($best_s > 1000) {
        $term = 'a weak';
    } else { #elsif ($best_s > 0000) {
        $term = 'poor';
    } 
    my $tmp_message = "has $term grade";
    #print STDERR "_get_score_msg: $tmp_message, $best_n, $best_s\n";
    return $tmp_message;
}

sub _build_message {
    my ($best_n,$best_s, $scores_hist, $card_data, $deck_type, $tags_done, $number) = @_;
    my $message = '';
    #print STDERR Dumper($scores_hist);
    my @cards = keys(%$scores_hist);
    my $card_info = {};
    my $scores = {};
    for my $card (@cards) {
        for my $ref (@{$scores_hist->{$card}}) {
            my $new_score = $ref->[1];
            my $key = $ref->[0];
            if (!exists($scores->{$card}) || $new_score != $scores->{$card}) {
                #print STDERR "Key: $new_score, $key, $card\n";
                #print STDERR "Old: $scores->{$card}, $card\n" if exists($scores->{$card});
                my $tmp_message = '';
                if ($key eq 'missing_drops' && (!exists($scores->{$card}) || $new_score > $scores->{$card})) {
                
                    $tmp_message = 'is a ' . $card_data->{$card}->{cost} . ' drop';
                    $scores->{$card} = $new_score;
                    
                } elsif ($key eq 'mana' && (!exists($scores->{$card}) || $new_score != $scores->{$card})) {
                    #nothing
                    #$tmp_message =  'fits the mana-curve of our deck';
                    $scores->{$card} = $new_score;
                    
                } elsif ($key eq 'dups' && (exists($scores->{$card}) && $new_score < $scores->{$card})) {
                
                    print STDERR "Yes, $new_score < $scores->{$card} for $card, $key\n";
                    $tmp_message = 'we dont want too many of';
                    $scores->{$card} = $new_score;
                    
                } elsif ($key eq 'tags_done' && (!exists($scores->{$card}) || $new_score > $scores->{$card})) {
                
                    $tmp_message = 'gives us: ' . _commify_series(@{$tags_done->{$card}});
                    $scores->{$card} = $new_score;
                    
                } elsif ($key eq 'synergy' && (!exists($scores->{$card}) || $new_score > $scores->{$card})) {
                
                    $tmp_message = 'has good synergy';
                    $scores->{$card} = $new_score;
                    
                } elsif ($key eq 'original' && (!exists($scores->{$card}) || $new_score > $scores->{$card})) {
                
                    $tmp_message = _get_score_msg($card, $new_score);
                    $scores->{$card} = $new_score;
                }
                
                #print STDERR "Setting score for $card to $scores->{$card}.\n";
                $card_info->{$card}->{$tmp_message} = 1 if $tmp_message ne '';
            }
        }
    }
    #print STDERR Dumper($card_info);
    if (keys(%$card_info) == 1 ) {
        $message = _capitalize($best_n) . ' ' . _commify_series(keys(%{$card_info->{$best_n}}));
    } elsif (keys(%$card_info) == 2 ) {
        for my $key (keys(%$card_info)) {
            if ($key ne $best_n) {
                $message .= _capitalize($key) . ' ' . _commify_series(keys(%{$card_info->{$key}}));
            }
        }
        $message .= ', but ' . _capitalize($best_n) . ' ' . _commify_series(keys(%{$card_info->{$best_n}}));
    } elsif (keys(%$card_info) == 3 ) {
        #if ($card_info{$cards[0]}
        for my $key (keys(%$card_info)) {
            if ($key ne $best_n) {
                $message .= _capitalize($key) . ' ' . _commify_series(keys(%{$card_info->{$key}}));
                $message .= ', ';
            }
        }
        my @final_set = keys(%{$card_info->{$best_n}});
        #push(@final_set, 'is our final pick!');
        $message .= 'but ' . _capitalize($best_n) . ' ' . _commify_series(@final_set);
    }
    $message .= ". We recommend you pick " . _capitalize($best_n) . ".";
    #print STDERR "Message: $message\n";
    return $message;
}

sub _get_best_card {
    my $scores = shift;
    my $out_data = shift;
    my $best_card_n = 'error';
    my $best_card_score = -100000000;
    for my $card_name (keys(%$scores)) {
        my $score = $scores->{$card_name};
        if ($score > $best_card_score) {
            $best_card_n = $card_name;
            $best_card_score = $score;
        }
        if (defined($out_data)) {
            $out_data->{'scores'}->{$card_name} = $score*1.234;
        }
        #$out_data->{'math'}->{$card_name} = $math{$card_name};heroin
    }
    $out_data->{'best_card'} = $best_card_n if defined($out_data);
    my $return_data = [$best_card_n,$best_card_score];
    #print STDERR "Return data: " . Dumper($return_data) . "\n";
    return $return_data;
}

1;
