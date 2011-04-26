use strict;
use warnings;
use Anagram;
use Test::More tests => 18;

our $CACHE = './words_tree_temp';
if (-e $CACHE) {
    unlink($CACHE);
}

for (0..1) {
    ok(my $t = Anagram->new({cache => $CACHE, verbose => 1}), "constructor returns");
    is(ref $t, 'Anagram', " ... an Anagram object");

    ok(my @matches = $t->match("letters"), "match returns");
    is(scalar @matches, 4, " ... 4 matches");

    my @expected = qw( letters settler sterlet trestle );
    my @sorted = sort @matches;
    is_deeply(\@sorted, \@expected, " ... 'letters' -> letters settler sterlet trestle");   
    
    ok(my @no_matches = $t->match("zzzzz"), "attempt match for failure");
    is(scalar @no_matches, 0, " ... returns no matches");
    
    ok(my @partials = $t->match_all("letters"), "partial match returns");
    is(scalar @partials, 67, " ... 67 matches");
}