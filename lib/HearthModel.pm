package HearthModel;

use strict;
use warnings;

use Moo;

use Search::Elasticsearch;
use HearthModel::Card;
use HearthModel::Class;
use HearthModel::User;
use HearthModel::Arena;
use HearthModel::CardChoice;

has es => (
    is => 'rw',
);
has user => (
    is => 'rw',
);
has class => (
    is => 'rw',
);
has card => (
    is => 'rw',
);
has arena => (
    is => 'rw',
);
has card_choice => (
    is => 'rw',
);

sub connect {
    my ($self,$c) = @_;
    my $es = Search::Elasticsearch->new(trace_to => 'Stderr');
    $self->es($es);
    $self->user(HearthModel::User->new(es=>$es));
    $self->class(HearthModel::Class->new(es=>$es));
    $self->card(HearthModel::Card->new(es=>$es));
    $self->arena(HearthModel::Arena->new(es=>$es));
    $self->card_choice(HearthModel::CardChoice->new(es=>$es,c=>$c));
}

1;