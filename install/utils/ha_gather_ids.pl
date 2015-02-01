#!/usr/bin/env perl

use strict;
use warnings;

use WWW::Selenium;
use Term::ReadKey;

my $timeout = 10000;
print "login: ";
my $login = <>;
chomp($login);
my $pw;
my $tempfile = $login . '.tmp';
if (!-f $tempfile) {
    ReadMode ('noecho');
    print "Enter Password: ";
    chomp($pw = <STDIN>);
    ReadMode ('restore');
}
    
#gather ids for scraping from HA, gather from each class
my $url = "http://www.heartharena.com";

print "\nConnecting to Selenium...\n";
my $sel = WWW::Selenium->new( host => "localhost",
                                port => 4444,
                                browser => "*firefox",
                                browser_url => $url);
$sel->start;
$sel->open("$url/login");
$sel->type("username", $login);
$sel->type("password", $pw);
$sel->click("_submit");
$sel->wait_for_page_to_load($timeout);

my @classes = ('warrior');# 'warlock', 'druid', 'hunter', 'paladin', 'priest', 'shaman', 'mage', 'rogue');
for my $class (@classes) {
    my $goto = $url.'/arena/'.$class;
    $sel->open("$goto");
    $sel->wait_for_page_to_load($timeout);
    
    $sel->run_script("alert(app.cards.models.length)")
    
} 

sleep 10;