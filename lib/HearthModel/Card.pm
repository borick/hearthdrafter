package HearthModel::Card;

use Moo;
use Data::Dumper;
use Text::Autoformat;
has cass => (
    is => 'rw',
);

sub get_cards_by_class {
    my ($self, $class) = @_;
    
    my $query = $self->cass->prepare("SELECT cards FROM cards_by_class WHERE class_name = ?")->get;
    print STDERR "Getting cards for class: $class\n";
    my (undef, $result) = $query->execute([$class])->get;
    
    my @data = @{$result->{rows}->[0]->[0]};
    @data = map { my $res = autoformat($_, {case => 'highlight'}); } @data;
    chomp(@data);
    chomp(@data);
    return \@data;
}

1;