package HearthModel::Card;

use strict;
use warnings;

use Moo;
extends 'HearthModel::DbBase';
use Data::Dumper;

sub get_cards_by_class {
    my ($self, $class) = @_;
        
    #print STDERR "Searching for: $class\n";
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
    return \@data;
}

sub get_data {
    my ($self, $unique_cards) = @_;
    my $result = $self->es->search(
            index => 'hearthdrafter',
            type => 'card',
            size => 9999,
            body => {
                filter => {
                    terms => {
                        name => $unique_cards,
                    },
                },   
            },
        );
    my %cards = ();
    for my $res (@{$result->{hits}->{hits}}) { 
        $cards{$res->{_id}} = $res->{_source};
    }
    return \%cards;
}

sub get_cards {
    my ($self, $array) = @_;
    my $results = $self->es->search(
        index => 'hearthdrafter',
        type => 'card',
        size => 9999, 
        body => {
            query => {
                terms => {
                    card_name => $array,
                    minimum_should_match => 1,
                }
             }
        },
    );
    my @data = @{$results->{hits}->{hits}};
    @data = map { $_->{_source} } @data;
    return \@data;
}

sub get_tags {
    my ($self, $array) = @_;
    #print STDERR "Get tags: " . Dumper($array) . "\n";
    my $results = $self->es->search(
        index => 'hearthdrafter',
        type => 'card_tag',
        size => 99999, 
        body => {
            query => {
                terms => {
                    card_name => $array,
                    minimum_should_match => 1,
                }
            }
        },
    );

    my @data = @{$results->{hits}->{hits}};
    my $data_hash = {};
    for my $data (@data) {
        #print Dumper($data);
        $data_hash->{$data->{_source}->{card_name}} = $data->{_source}->{tags};
    }
    return $data_hash;
    
}
    

1;