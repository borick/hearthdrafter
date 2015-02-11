package HearthModel::Card;
use Moo;
extends 'HearthModel::DbBase';
use Data::Dumper;
use Text::Autoformat;

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
    @data = map { $_->{_source}->{name} } @data;
    @data = map { my $res = autoformat($_, {case => 'highlight'}); } @data;
    chomp(@data);
    chomp(@data);
    return \@data;
}

1;