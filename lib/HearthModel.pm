package HearthModel;

use Moo;

use Search::Elasticsearch;
use HearthModel::Card;
use HearthModel::Class;
use HearthModel::User;

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

sub connect {
    my ($self) = @_;
    my $es = Search::Elasticsearch->new();
    $self->es($es);
    $self->user(HearthModel::User->new(es=>$es));
    $self->class(HearthModel::Class->new(es=>$es));
    $self->card(HearthModel::Card->new(es=>$es));
}

1;