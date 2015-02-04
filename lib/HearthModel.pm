package HearthModel;

use Moo;

use Net::Async::CassandraCQL;
use Protocol::CassandraCQL qw( CONSISTENCY_ONE );
use IO::Async::Loop;
use HearthModel::User;

has cass => (
    is => 'rw',
);

has user => (
    is => 'rw',
);

sub connect {
    my ($self) = @_;
    my $loop = IO::Async::Loop->new;
    my $cass = Net::Async::CassandraCQL->new(
        host => "localhost",
        keyspace => "hearthdrafter",
        default_consistency => CONSISTENCY_ONE,
    );
    $loop->add($cass);
    $cass->connect->get;
    $self->cass($cass);
    $self->user(HearthModel::User->new(cass=>$cass));
}

1;