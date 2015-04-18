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
sub get_advice {
    my ($self, $card_1, $card_2, $card_3, $arena_id) = @_;        
    $card_1 =~ s/[.]//g;
    $card_2 =~ s/[.]//g;
    $card_3 =~ s/[.]//g;
    my $debug = $HearthModel::CardChoice::debug;
    $debug = '' if !defined($debug);
    my $c = $self->c();
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
    
    
    my $deck_type = "value";                          #0, 1, 2, 3, 4, 5, 6, 7 +              
    my $ideal_curves    = { value => {     minions => [0, 0, 5, 3, 5, 4, 3, 2],
                                           spells =>  [0, 0, 4, 1, 1, 1, 1, 0],
                                           drops =>   [0, 0, 4, 2, 3, 2, 1, 1], },
                                           
                            late_game => { minions => [0, 0, 6, 6, 2, 5, 5, 1], 
                                           spells =>  [0, 1, 2, 0, 1, 0, 0, 1],
                                           drops =>   [0, 0, 4, 2, 3, 2, 1, 1],},
                                           
                            aggro => {     minions => [0, 1, 9, 6, 4, 4, 0, 1],
                                           spells =>  [1, 2, 1, 0, 0, 0, 0, 1],
                                           drops =>   [0, 0, 6, 3, 2, 1, 1, 1],},
                                           
                            control => {   minions => [0, 3, 2, 4, 4, 4, 3, 2], 
                                           spells =>  [0, 4, 1, 1, 1, 0, 1, 0],
                                           drops =>   [0, 0, 4, 2, 4, 2, 1, 1],}};
                                           
    my $tags_wanted = { value => [ 'draw', 'aoe', 'removal', 'ping' ],
                        late_game => [ 'survivability', 'aoe', 'removal', 'ping'],
                        aggro => [ 'draw' ],
                        control => [ 'draw', 'removal', 'ping', 'aoe' ], };
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
    $self->es->index(
        index => 'hearthdrafter',
        type => 'arena_run', 
        id => $arena_id,
        body => $source,
    );
    
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
    my %tags_data = ();
    # build a "drop__" curve.
    my @drop_curve =    (0,0,0,0,0,0,0,0);
    my $num_drops = 0;
    my $total_drop_cost = 0;
    for my $card_name_key (keys(%$card_data_tags)) {
        for my $card_tag (keys(%{$card_data_tags->{$card_name_key}})) {
            $tags_data{$card_tag} += 1;
            if ($card_tag =~ /drop_(\d+)/) {
                $drop_curve[$1] += 1;
                $total_drop_cost += $card_data->{$card_name_key}->{cost};
                $num_drops += 1;
            }
        }
    }
    print STDERR "Tags: " . Dumper(\%tags_data),"\n" if $debug =~ 'tags';
    
    my $number_of_cards = scalar(@unique_cards);
    print STDERR "*" x 80, "\n" if $debug;
    print STDERR "Number of cards: $number_of_cards\n" if $debug;
    
    my %type_breakdown = ();
    my $average_drop = $total_drop_cost / $num_drops;
    my $total_cost = 0;
    for my $card (@unique_cards) {
        my $card_info = $card_data->{$card};
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
    ### not  synergies, currently.
    #$out_data->{synergy} = \%synergies;
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
    $best_card_before = _get_best_card(\%scores);
    $message .= "$best_card_before has the most value. ";
    
    #adjust for "missing drops"
    for my $card (sort(@$cards)) {
        my $original_score = $scores{$card};
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
        
        $best_card_after = _get_best_card(\%scores);
        
        if ($best_card_before ne $best_card_after) {
            $message .= "But $best_card_after fits the mana curve better. ";
        }
        #adjust for diminishing returns on duplicates, default for all cards.
        $best_card_before = _get_best_card(\%scores);
        my $count = $card_counts{$card} || 0;
        $scores{$card} = $scores{$card} - ($duplicate_constant * $count * $scores{$card});
        $best_card_after = _get_best_card(\%scores);
        
        if ($best_card_before ne $best_card_after) {
            $message .= "However, we already have $count of $best_card_before. It's better to have variety. ";
        }
        push($scores_hist{$card}, ['dups', $scores{$card}]);
    }
        
    $best_card_before = _get_best_card(\%scores);
    
    #adjust for missing tags.
    print STDERR "[deck type: $deck_type]\n" if $debug =~ 'deck';
    for my $card (sort(@$cards)) {
        for my $tag (@{$tags_wanted->{$deck_type}}) {
            if (exists($card_data_tags->{$card}->{$tag}) && ($tags_data{$tag}) <= 2) {
                my $original_score = $scores{$card};
                $scores{$card} = $scores{$card} + ($scores{$card} * ($tag_needed_mult*$complete));
                push($scores_hist{$card}, [$tag, $scores{$card}]);
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
    
#     #deck type...
#     if ($deck_type eq 'aggro') {
#     
#     } else {
#     
#     }
    
    ($best_card_after,$best_card_score)  = _get_best_card(\%scores, $out_data);
    if ($best_card_before ne $best_card_after) {
        $message .= "But $best_card_after has the most the synergy with the deck. ";
    }
    $message .= "Pick \"$best_card_after\"! ";
    $out_data->{message} = $message;
    #print STDERR 'Out data:' . Dumper($out_data);
    for my $card (@$cards) {
    print STDERR "[$card] " . Dumper($scores_hist{$card}), "\n" if $debug =~ 'score';
    }
    
    return $out_data;
}

sub _get_best_card {
    my $best_card_n = 'error';
    my $best_card_score = -100000000;
    
    my $scores = shift;
    my $out_data = shift;
    for my $card_name (keys(%$scores)) {
        my $score = $scores->{$card_name};
        if ($score > $best_card_score) {
            $best_card_n = $card_name;
            $best_card_score = $score;
        }
        if (defined($out_data)) {
            $out_data->{'scores'}->{$card_name} = $score;
        }
        #$out_data->{'math'}->{$card_name} = $math{$card_name};
    }
    $out_data->{'best_card'} = $best_card_n if defined($out_data);
    return [$best_card_n,$best_card_score];
}

1;