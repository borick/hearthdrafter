package CardScanner::DbLoader;

use strict;
use warnings;

use Graph::Simple;
use Data::Dumper;

use Search::Elasticsearch;
my $e = Search::Elasticsearch->new();

sub load_synergies {
    my ($g, $reasons) = @_;
    my $debug = $CardScanner::debug;
    print "Loading synergies...\n" if $debug;
    for my $key (keys(%$reasons)) {
        print "Processing: $key\n" if $debug >= 2;
        
        my @values = split(/[|]/, $key);
        die 'error, keys should contain "|"' if @values < 2;
        my $reason = $reasons->{$key};
        
        $e->index(
            index   => 'hearthdrafter',
            type    => 'card_synergy',
            body    => {
                card_name   => $values[0],
                card_name_2 => $values[1],
                reason      => $reason
            }
        );
    }
}

1;