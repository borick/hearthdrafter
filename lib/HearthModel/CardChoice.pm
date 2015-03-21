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
    
    my $max_score = 8500;
    
    my $c = $self->c();
    my $source = $c->model->arena->continue_run($arena_id);
    print STDERR "Arena run: " . Dumper($source) . "\n";
    my @card_choices = @{$source->{card_choices}};
    my %card_counts = %{$source->{card_counts}};
    my $next_index = $self->get_next_index($source);
    return undef if $next_index >= 30;
    my $out_data = {};
    my $card_options = $source->{card_options};
    #update the card choices we have
    $card_options->[$next_index] = {card_name   => $card_1,
                                    card_name_2 => $card_2,
                                    card_name_3 => $card_3};
    print STDERR "Updating card selection for Card #".($next_index+1) . "\n";
    #reindex
    $self->es->index(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
        body => $source,
    );
    
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
    
    #mana curve
    #diminishing returns on cards
    #other?
    
    #get tier score for each card.
    my $class = $source->{class_name};
    my $scores = $self->es->search(
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
    $scores = $scores->{hits}->{hits};
    die 'bad cards' if (@$scores <= 0);
    #build a hashmap of names to scores
    my %scores = ();
    my %new_scores = ();
    my %math = ();
    my @unique_cards = keys(%card_counts);
    ##### GET LIST OF CARDS FOR MANA.....
    
    for my $score (@$scores) {
        $scores{$score->{'_source'}->{'card_name'}} = $score->{'_source'}->{'score'};
        #divide by $max_score throughout so we hide our internal scoring system a bit.
        $out_data->{'old_scores'}->{$score->{'_source'}->{'card_name'}} = $score->{'_source'}->{'score'} / $max_score;
    }
    
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
        }
        my $original_score = $scores{$card_name}*100;#to avoid descreasing negative numbers
        #each 1 PT synergy weight increase card value by 10%.
        my $synergy_modifier = (1+($cumul_weight/10));
        my $new_score = ($synergy_modifier*$original_score)/100;
        $new_scores{$card_name} = $new_score / $max_score;
        $math{$card_name} = [$synergy_modifier,'*',$new_score / $max_score];
    }
    
    for my $card_name (keys(%new_scores)) {
        my $score = $new_scores{$card_name};
        $out_data->{'scores'}->{$card_name} = $score;
        $out_data->{'math'}->{$card_name} = $math{$card_name};
    }
    
    print STDERR 'Out data:' . Dumper($out_data);
    return $out_data;
}

1;