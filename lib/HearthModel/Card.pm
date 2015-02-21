package HearthModel::Card;

use strict;
use warnings;

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
        body => {
            query => {
                terms => {
                    playerclass => [$class, 'neutral'],
                    minimum_should_match => 1,
                }
            }
        },
    );

    my @data = @{$results->{hits}->{hits}};
    @data = map { $_->{_source} } @data;
    for my $datum (@data) {
        $datum->{name} =~ s/([\w']+)/\u\L$1/g; #title case
    }
    return \@data;
}

1;