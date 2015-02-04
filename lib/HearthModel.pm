package HearthModel;

use Moo;

use Net::Async::CassandraCQL;
use Protocol::CassandraCQL qw( CONSISTENCY_ONE );
use IO::Async::Loop;

use HearthModel::User;

has user => (
    is => 'rw',
    default => sub { HearthModel::User->new() },
);

sub connect {
    my $loop = IO::Async::Loop->new;
    my $cass = Net::Async::CassandraCQL->new(
        host => "localhost",
        keyspace => "hearthdrafter",
        default_consistency => CONSISTENCY_ONE,
    );
    $loop->add($cass);
    $cass->connect->get;    
}

1;