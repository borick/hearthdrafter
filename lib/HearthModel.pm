package HearthModel;

use Moo;

use Search::Elasticsearch;
use HearthModel::Card;
use HearthModel::Class;
use HearthModel::User;
use HearthModel::Arena;

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

sub connect {
    my ($self) = @_;
    my $es = Search::Elasticsearch->new();
    $self->es($es);
    $self->user(HearthModel::User->new(es=>$es));
    $self->class(HearthModel::Class->new(es=>$es));
    $self->card(HearthModel::Card->new(es=>$es));
    $self->arena(HearthModel::Arena->new(es=>$es));
}

1;