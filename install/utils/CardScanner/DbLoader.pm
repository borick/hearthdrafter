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

sub load_synergies {
    my ($g, $reasons) = @_;
    my $debug = $CardScanner::debug;
    print "Loading synergies...\n" if $debug;
    for my $key (keys(%$reasons)) {
        print "Processing: $key\n" if $debug >= 2;
        
        my @values = split(/[|]/, $key);
        die 'error, keys should contain "|"' if @values < 2;
        my $reason = $reasons->{$key};
        
        $bulk->index({
            id => $values[0].'|'.$values[1],
            source => {
                card_name   => $values[0],
                card_name_2 => $values[1],
                reason      => $reason
            }
        });
        $bulk->index({
            id => $values[1].'|'.$values[0],
            source => {
                card_name_2 => $values[0],
                card_name   => $values[1],
                reason      => $reason
            }
        });
    }
    $bulk->flush;
}

1;