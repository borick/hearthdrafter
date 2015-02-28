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

#return card count so JS can easy update it.
sub confirm_card_choice {
    my ($self, $card_name, $arena_id) = @_;
    my $source = $self->continue_run($arena_id);
    my $next_index = $self->get_next_index($source);
    die('no card name specified') if !defined($card_name) or $card_name =~ /^\s*$/;
    #TODO: add user validation
    if ($next_index >= 29) {
        my $t = localtime;
        $source->{end_date} = $t->strftime();
    } 
    if ($next_index <= 29) {
        $source->{card_options}->[$next_index]->{card_chosen} = $card_name;
        print STDERR "Confirming choice card #" . ($next_index+1) . "\n";
        print STDERR Dumper($source);
        $self->es->index(
            index => 'hearthdrafter',
            type => 'arena_run',
            id => $arena_id,
            body => $source,
        );
    }
    $source = $self->continue_run($arena_id);
    return $source->{card_counts};
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
    my $card_options = $doc->{_source}->{card_options};
    my %card_counts;
    my @card_choices;
    for my $card_option (@$card_options) {
        if (exists($card_option->{card_chosen})) {
            next if !defined($card_option->{card_chosen});
            push(@card_choices, $card_option->{card_chosen});
            if (exists($card_counts{$card_option->{card_chosen}})) {
                $card_counts{$card_option->{card_chosen}} += 1;
            } else {
                $card_counts{$card_option->{card_chosen}} = 1;
            }
        }
    }
    $doc->{_source}->{card_choices} = \@card_choices;
    $doc->{_source}->{card_counts} = \%card_counts;
    return $doc->{_source};
}

sub list_open_runs {
    my ($self, $user_name, $size) = @_;
    my $out = [];
    my $results = $self->es->search(
        index => 'hearthdrafter',
        type => 'arena_run',
        size => 10,
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

sub list_runs_no_results {
    my ($self, $user_name) = @_;
    my $out = [];
    my $results = $self->es->search(
        index => 'hearthdrafter',
        type => 'arena_run',
        size => 10,
        body  => {
            query => {
                filtered => {
                    query => {
                        match => { user_name => $user_name }
                    },
                    filter => {
                        bool => {
                            must => {
                                missing => { field => 'results' }
                            },
                            must_not => {
                                missing => { field => 'end_date' },
                            },
                        }
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


sub provide_results {
    my ($self, $arena_id, $data) = @_;
    my $hash = $data->to_hash;
    delete($hash->{Submit});
    delete($hash->{rarity});
    delete($hash->{set});
    my $doc = $self->es->get(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
    );
    $doc->{_source}->{'results'} = $hash;
    my $results = $self->es->index(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
        body => $doc->{_source},
    );
    return 0; #success
}
1;