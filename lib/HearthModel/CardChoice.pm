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
    #card number
    my $class = $source->{class_name};        
    print STDERR "Searching for: " . Dumper($card_1, $card_2, $card_3);
    
    #tier score
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
    for my $score (@$scores) {
        my $source = $score->{'_source'};
        $out_data->{'scores'}->{$source->{'card_name'}} = $source->{'score'} / $max_score;
    }
    
    my @card_choices;
    for my $card_option (@$card_options) {
        push(@card_choices, $card_option->{card_chosen}) if exists($card_option->{card_chosen});
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
    $out_data->{cards_already_chosen} = \@card_choices;
    #mana curve
    #diminishing returns on cards
    #other?
    print STDERR Dumper($out_data);
    return $out_data;
    
}

1;