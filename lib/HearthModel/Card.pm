package HearthModel::Card;
use Moo;
extends 'HearthModel::DbBase';
use Data::Dumper;

sub get_cards_by_class {
    my ($self, $class) = @_;
        
    print STDERR "Searching for: $class\n";
    my $results = $self->es->search(
        index => 'hearthdrafter',
        type => 'card',
        size => 531,
        body => { query => { match => { playerclass => "$class" } } },
    );

    my @data = @{$results->{hits}->{hits}};
    @data = map { $_->{_source} } @data;
    return \@data;
}

1;