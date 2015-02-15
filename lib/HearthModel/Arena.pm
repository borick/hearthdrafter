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
    return $doc;
}

sub list_open_runs {
    my ($self, $user_name, $from, $size) = @_;
        
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

    return $results->{hits}->{hits};
}

1;