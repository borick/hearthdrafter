package HearthModel::CardChoice;

use strict;
use warnings;

use Moo;
extends 'HearthModel::DbBase';

has c => (
    is => 'rw',
);

use Data::Dumper;

sub _process_card_name {
    my $name = shift;

    return $name;
}

sub get_card_number {
    my ($self,$arena_id) = @_;
    my $source = $self->c()->model->arena->continue_run($arena_id);
    return $self->get_next_index($source);
}

sub get_next_index {
    my ($self,$source) = @_;
    my $count = 0;
    for my $option (@{$source->{card_options}}) {
        last if !exists($option->{card_chosen});
        $count += 1;
    }
    return $count;
}

sub confirm_card_choice {
    my ($self, $arena_id, $card_name) = @_;
    
    my $source = $self->c()->model->arena->continue_run($arena_id);    
    my $next_index = $self->get_next_index($source);
    
    #TODO: add user validation
    $source->{card_options}->[$next_index]->{card_chosen} = $card_name;
    $self->es->index(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
        body => $source,
    );
}

sub get_advice {
    my ($self, $arena_id, $card_1, $card_2, $card_3) = @_;        
    
    my $max_score = 8500;
    
    my $c = $self->c();
    my $source = $c->model->arena->continue_run($arena_id);
    print STDERR "Arena run: " . Dumper($source) . "\n";
    my $next_index = $self->get_next_index($source);
    my $out_data = {};
    my $card_options = $source->{card_options};
    #update the card choices we have
    $card_options->[$next_index] = {card_name   => $card_1,
                                    card_name_2 => $card_2,
                                    card_name_3 => $card_3}; 
    #reindex
    $self->es->index(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
        body => $source,
    );
    #card number
    $out_data->{'card_number'} = $next_index;
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

    print STDERR "Cards chosen: " . Dumper(\@card_choices);
    
    #synergies    
    # find synergies between the existing card choices (@card_choices) and the currently available cards ($card_1, card_2, etc.)
    my $synergies = $self->es->search(
        index => 'hearthdrafter',
        type => 'card_synergy',
        size => 99999, #greater than max, hopefully
        body => {
            query => {
                filtered => {
                    query => {
                        match => { card_name_2 => $card_1 },
#                         terms => {
#                             card_name_2 => [$card_1, $card_2, $card_3],
#                         },
#                         minimum_should_match => 1,
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
    
    print 'Synergies' . Dumper($synergies);
    
    #mana curve
    #diminishing returns on cards
    return $out_data;
    
}

1;