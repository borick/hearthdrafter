package CardScanner::DbLoader;

use strict;
use warnings;

use Graph::Simple;
use Data::Dumper;

use Net::Async::CassandraCQL;
use Protocol::CassandraCQL qw( CONSISTENCY_QUORUM CONSISTENCY_ONE );
use IO::Async::Loop;
my $loop = IO::Async::Loop->new;
my $cass = Net::Async::CassandraCQL->new(
    host => "localhost",
    keyspace => "hearthdrafter",
    default_consistency => CONSISTENCY_ONE,
);
$loop->add($cass);
$cass->connect->get;

sub load_synergies {
    my ($g, $reasons) = @_;
    my $debug = $CardScanner::debug;
    print "Loading synergies...\n" if $debug;
    for my $key (keys(%$reasons)) {
        print "Processing: $key\n" if $debug >= 2;
        
        # Schema, for reference.        
        # CREATE TABLE IF NOT EXISTS card_synergy (
        #   card_name TEXT PRIMARY KEY,
        #   card_name_has_synergy TEXT,
        #   reason TEXT
        # );
        my $cql = 'INSERT INTO  card_synergy(card_name, card_name_has_synergy, reason) VALUES (?,?,?)';
        my $query = $cass->prepare($cql)->get;
        my @values = split(/[|]/, $key);
        die 'error, keys should contain "|"' if @values < 2;
        my $reason = $reasons->{$key};
        my $result = $query->execute([$values[0], $values[1], $reason])->get;    
    }
}

1;