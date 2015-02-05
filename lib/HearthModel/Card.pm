package HearthModel::Card;

use Moo;

has cass => (
    is => 'rw',
);

sub get_cards_by_class {
    my ($self, $class) = @_;
    
    my $query = $self->cass->prepare("SELECT * FROM class_cards WHERE class_name = ?")->get;
    print STDERR "Getting cards for class: $class\n";
    my (undef, $result) = $query->execute([$class])->get;
    print STDERR "Count: " . scalar(@{$result->{rows}});
    return $result->{rows};
}

1;