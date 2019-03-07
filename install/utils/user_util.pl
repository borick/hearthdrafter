#!/usr/bin/env perl

use strict;
use warnings;

use Encode;
use Getopt::Long;
use Search::Elasticsearch;
use Data::Dumper;
use Mail::Sendmail;

my $es = Search::Elasticsearch->new();
my $action='none';

GetOptions ("action=s" => \$action);

   my $scores_result = $es->search(
        index => 'hearthdrafter',
        type => 'user',
        size => 99999,
        body => {
              query => {
                match_all => {},
              }
        },
    );

if ($action =~ /^list_users/) {
    for my $score (@{$scores_result->{hits}->{hits}}) {          
        print $score->{_source}->{email}, "\n" if !exists($score->{_source}->{validation_code}) and $action !~ /unvalid/;
        print $score->{_source}->{email}, "\n" if $action =~ /unvalid/;
    }
}

