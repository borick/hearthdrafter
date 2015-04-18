package CardScanner::DbLoader;

use strict;
use warnings;

use Graph::Simple;
use Data::Dumper;

use Search::Elasticsearch;
my $e = Search::Elasticsearch->new();
my $bulk = $e->bulk_helper(
    index     => 'hearthdrafter',
    type      => 'card_synergy',
    on_error  => sub { warn Dumper(@_) },
);
my $bulk_tag = $e->bulk_helper(
    index     => 'hearthdrafter',
    type      => 'card_tag',
    on_error  => sub { warn Dumper(@_) },
);

sub load_synergies {
    my ($g, $reasons) = @_;
    eval {
        $e->indices->delete(index=>'card_synergy');
    };
    my $debug = $CardScanner::debug;
    print "Loading synergies...\n" if $debug;
    for my $key (keys(%$reasons)) {
        print "Processing: $key\n" if $debug >= 3;
        my @values = split(/[|]/, $key);
        die 'error, keys should contain "|"' if @values < 2;
        my $reason = $reasons->{$key};
        my $weight = $g->weight($values[0], $values[1]);
        $bulk->index({
            id => $values[0].'|'.$values[1],
            source => {
                card_name   => $values[0],
                card_name_2 => $values[1],
                reason      => $reason,
                weight      => $weight,
            }
        });
        $bulk->index({
            id => $values[1].'|'.$values[0],
            source => {
                card_name_2 => $values[0],
                card_name   => $values[1],
                reason      => $reason,
                weight      => $weight,
            }
        });
    }
    $bulk->flush;
}

sub load_tags {
    my ($ref) = @_;
    eval {
        $e->indices->delete(index=>'card_tag');
    };
    for my $card_name (keys(%$ref)) {
    
        my $inner_ref = $ref->{$card_name};
        my $tags = {};
        for my $mech_name (keys(%$inner_ref)) {
            my $weight = $inner_ref->{$mech_name};
            if (ref($weight) eq 'ARRAY') {
                $weight = -1.0;
            }
            $tags->{$mech_name} = $weight;            
        }
        $bulk_tag->index({
            id => $card_name,
            source => {
                card_name => $card_name,
                tags => $tags,
            }
        });
    }
    $bulk_tag->flush;
}

1;