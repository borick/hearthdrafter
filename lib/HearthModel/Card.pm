package HearthModel::Card;

use Moo;
use Data::Dumper;

has cass => (
    is => 'rw',
);

sub get_cards_by_class {
    my ($self, $class) = @_;
    
    my $query = $self->cass->prepare("SELECT cards FROM cards_by_class WHERE class_name = ?")->get;
    print STDERR "Getting cards for class: $class\n";
    my (undef, $result) = $query->execute([$class])->get;
    return $result->{rows}->[0]->[0];
}

1;