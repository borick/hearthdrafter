package HearthModel::Arena;

use strict;
use warnings;

use Moo;
extends 'HearthModel::DbBase';
use Data::Dumper;
use Time::Piece;

sub begin_arena {
    my ($self, $class, $user_name) = @_;
    
    my $t = localtime;
    
    my $results = $self->es->index(
        index => 'hearthdrafter',
        type => 'arena_run',
        body => { 
            class_name => $class,
            start_date => $t->strftime(),
            user_name => $user_name,
        },
    );
    return $results;
}

sub get_card_number {
    my ($self, $arena_id) = @_;
    my $source = $self->continue_run($arena_id);
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
    my ($self, $card_name, $arena_id) = @_;
    my $source = $self->continue_run($arena_id);
    my $next_index = $self->get_next_index($source);
    
    #TODO: add user validation
    $source->{card_options}->[$next_index]->{card_chosen} = $card_name;
    if ($next_index >= 29) {
        my $t = localtime;
        $source->{end_date} = $t->strftime();
    }
    $self->es->index(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
        body => $source,
    );
}

sub abandon_run {
    my ($self, $arena_id) = @_;
    $self->es->delete(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
    );
    return;
}

sub continue_run {
    my ($self, $arena_id) = @_;
    my $doc = $self->es->get(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
    );
    $doc->{_source}->{_id} = $doc->{_id};
    return $doc->{_source};
}

sub list_open_runs {
    my ($self, $user_name, $from, $size) = @_;
    my $out = [];
    my $results = $self->es->search(
        index => 'hearthdrafter',
        type => 'arena_run',
        size => $size,
        from => $from,
        body  => {
            query => {
                filtered => {
                    query => {
                        match => { user_name => $user_name }
                    },
                    filter => {
                        missing => { field => 'end_date' }
                    }
                }
            }
        }
    );
    
    for my $result (@{$results->{hits}->{hits}}) {
        $result->{_source}->{_id} = $result->{_id};
        push(@$out, $result->{_source});
    }
    return $out;
}

1;