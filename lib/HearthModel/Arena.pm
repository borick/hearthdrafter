package HearthModel::Arena;
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
            start_date => $t->datetime,
            user_name => $user_name,
        },
    );
    return $results;
}

sub continue_run {
    my ($self, $arena_id) = @_;
    my $doc = $self->es->get(
        index => 'hearthdrafter',
        type => 'arena_run',
        id => $arena_id,
    );
    return $doc;
}

sub list_open_arenas {
    my ($self, $class) = @_;
    
}

1;