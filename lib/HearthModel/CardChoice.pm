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

sub get_advice {
    my ($self, $arena_id, $card_1, $card_2, $card_3, $card_number) = @_;        
    
    my $max_score = 8500;
    
    my $c = $self->c();
    my $run = $c->model->arena->continue_run($arena_id);
    my $source = $run->{_source};
    #TODO: add more validation on checking card number matches expected sequence.
    return if $card_number >= 29;    
    #update the card choices we have
    $source->{card_options}->[$card_number] = {card_name => $card_1,
                                               card_name_2 => $card_2,
                                               card_name_3 => $card_3}; 
    #reindex
    $self->es->index(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
        body => $source,
    );
    
    my $class = $source->{class_name};
    
    my $out_data = {};
    
    
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
    
    #synergies    
    #mana curve
    
    return $out_data;
    
}

1;