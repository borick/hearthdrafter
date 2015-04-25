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
        #print STDERR "Confirming choice card #" . ($next_index+1) . "\n";
        #print STDERR Dumper($source);
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

sub confirm_card_choice_by_num {
    my ($self, $index, $arena_id) = @_;
    my $source = $self->continue_run($arena_id);
    my $next_index = $self->get_next_index($source);
    die('none or bad index specified') if !defined($index) or ($index != 0 && $index != 1 && $index != 2);
    #TODO: add user validation
    if ($next_index >= 29) {
        my $t = localtime;
        $source->{end_date} = $t->strftime();
    } 
    if ($next_index <= 29) {
        my $tag = 'card_name';
        $tag .= '_' . ($index+1) if ($index == 1 || $index == 2);
        $source->{card_options}->[$next_index]->{card_chosen} = $source->{card_options}->[$next_index]->{$tag};
        print STDERR "Confirming choice card #" . ($next_index+1) .' '  .  $source->{card_options}->[$next_index]->{card_chosen} .  "\n";
        print STDERR Dumper($source->{card_options}->[$next_index]);
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
    my ($self, $arena_id, $user) = @_;
    my $doc = $self->es->get(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
    );
    die 'not your arena' if $user ne $doc->{_source}->{user_name};
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

sub list_runs_completed {
    my ($self, $user_name, $from, $size) = @_;
    my $out = [];
    $size = 10 if !$size;
    $from = 0 if !$from;    
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
                        bool => {
                            must_not => {
                                missing => { field => 'results' },
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
    print STDERR "Providing results: " . Dumper($hash);
    my $results = $self->es->index(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
        body => $doc->{_source},
    );
    return 0; #success
}

sub undo_last_card {
    my ($self, $arena_id, $user) = @_;
    my $doc = $self->es->get(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
    );
    die 'not your arena' if $user ne $doc->{_source}->{user_name};
    shift(@{$doc->{_source}->{card_options}});
    $self->es->index(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
        body => $doc->{_source},
    );
    my $source = $self->continue_run($arena_id);
    return $source->{card_counts};
}

sub set_region {
    my ($self, $arena_id, $user, $region) = @_;
    my $doc = $self->es->get(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
    );
    my $region_map = { 'americas' => 1,
                       'europe' => 1,
                       'asia' => 1 };
    die 'not your arena' if $user ne $doc->{_source}->{user_name};
    die 'invalid region' if !exists($region_map->{$region});
    $doc->{_source}->{region} = $region;
    $self->es->index(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
        body => $doc->{_source},
    );
}

1;
