package HearthModel::CardChoice;

use strict;
use warnings;

use Moo;
extends 'HearthModel::DbBase';

has c => (
    is => 'rw',
);

use Time::Piece;
use Data::Dumper;

sub get_next_index {
    my ($self,$source) = @_;
    return $self->c()->model->arena->get_next_index($source);
}

sub get_advice {
    my ($self, $card_1, $card_2, $card_3, $arena_id) = @_;        
    
    my $max_score  = 8500; #for visual display only.
    
    my $syn_const  = 5000.00; #the power of synergies....
    my $mana_const = 7.50; #percentage increase per "mana diff" point
    my $duplicate_constant = 0.05; #percent amount decrease
                         #0,1,2,3,4,5,6,7+
    #my @min_drops      = (0,0,4,3,2,1,1,1);
    #my @max_drops      = (2,3,8,5,5,4,3,2);
    my @ideal_curve    = (1,2,7,3,4,3,2,2);
    
    my $c = $self->c();
    my $source = $c->model->arena->continue_run($arena_id);
    #print STDERR "Arena run: " . Dumper($source) . "\n";
    my @card_choices = @{$source->{card_choices}};
    my $card_number = scalar(@card_choices) + 1;
    my $complete = $card_number/30; #out of 1
    my %card_counts = %{$source->{card_counts}};
    my $next_index = $self->get_next_index($source);
    return undef if $next_index >= 30;
    my $out_data = {};
    my $card_options = $source->{card_options};
    #update the card choices we have
    $card_options->[$next_index] = {card_name   => $card_1,
                                    card_name_2 => $card_2,
                                    card_name_3 => $card_3};
    #print STDERR "Updating card selection for Card #".($next_index+1) . "\n";
    #reindex
    $self->es->index(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
        body => $source,
    );
    
    my $message_flag = "";
    my $message_default = "We'll base this solely on card value ratings.";
    my $message = "";
    my $best_card_before;
    my $best_card_after;
    
    #build a hashmap of names to scores
    my %scores = ();
    #my %math = ();
    my @unique_cards = keys(%card_counts);
    my @data_for = @unique_cards;
    push(@data_for, $card_1, $card_2, $card_3);
    my $card_data = $c->model->card->get_data(\@data_for);
    # build a mana curve...
    my %our_curve_hash = ();
    for my $card (keys(%$card_data)) {
        my $card_info = $card_data->{$card};
        $our_curve_hash{$card_info->{cost}} += 1;
    }
    my $total_cost = 0;
    my $number_of_cards = scalar(@unique_cards);
    for my $card (@unique_cards) {
        my $card_info = $card_data->{$card};
        $total_cost += $card_info->{cost};
    }
    my $average_cost = ($number_of_cards > 0) ? ($total_cost / $number_of_cards) : 0; 
    my @diff_curve = ();
    for my $key (0..7) {
        if (exists($our_curve_hash{$key})) {
            $diff_curve[$key] = ($ideal_curve[$key]*$complete) - $our_curve_hash{$key}; 
        } else {
            $diff_curve[$key] = ($ideal_curve[$key]*$complete);
        }
    }
    #print STDERR Dumper(\@diff_curve);
    #print STDERR Dumper(\%our_curve_hash);
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
        #divide by $max_score throughout so we hide our internal scoring system
        $out_data->{'scores'}->{$score->{'_source'}->{'card_name'}} = $score->{'_source'}->{'score'} / $max_score;
    }
    $best_card_before = _get_best_card(\%scores);
    $message .= "$best_card_before has the most value. ";
    
    #adjust for mana curve.
    for my $card (@$cards) {
        my $type = $card_data->{$card}->{type};
        my $cost = $card_data->{$card}->{cost};
        print STDERR "Cost for $card is $cost\n";
        
        my $original_score = $scores{$card};
        $cost = 7 if ($cost > 7);
        my $new_score = $original_score + ($original_score * ($mana_const * $diff_curve[$cost] / 100));
        #print "Old: " . $scores{$card} . ", New: " . $new_score . "\n";
        $scores{$card} = $new_score;
        
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
        
    }
    
    $best_card_before = _get_best_card(\%scores);
    
    my $i = 0;
    #calculate final score
    for my $card_name (keys(%synergies)) {
        my $synergy_array = $synergies{$card_name};
        my $cumul_weight = 0;
        for my $synergy (@$synergy_array) {
            my $card_name_2 = $synergy->{card_name};
            my $weight = $synergy->{weight};
            my $count = $card_counts{$card_name_2};
            my $total_weight = $weight * $count;
            $cumul_weight += $total_weight;
            #print STDERR "Adjusting for $card_name, $card_name_2, $weight.\n";
        }
        my $original_score = $scores{$card_name};#to avoid decreasing negative number;
        #print STDERR "Original score: [$card_name] $scores{$card_name}\n";
        #each 1 PT synergy weight increase card value by 10% by soem const value in syn const.
        my $synergy_modifier = (1+($cumul_weight/10));
        my $new_score = $original_score + ($synergy_modifier*$syn_const)/100;
        $scores{$card_name} = $new_score;
        print STDERR "Final score: [$card_name] $scores{$card_name}\n";
        #$math{$card_name} = [$synergy_modifier,'*',$new_score / $max_score];
        $i += 1;
    }
    
    $best_card_after = _get_best_card(\%scores, $out_data);
    if ($best_card_before ne $best_card_after) {
        $message .= "But $best_card_after has the most the synergy with the deck. ";
    }
    $message .= "Pick \"$best_card_after\"! ";
    $out_data->{message} = $message;
    print STDERR 'Out data:' . Dumper($out_data);
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
    return $best_card_n;
}

1;