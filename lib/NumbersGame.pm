package NumbersGame;
use strict;
use warnings;
use Carp;
use List::Util qw(shuffle);

our @BIG    = qw( 25 50 75 100 150 200 250 );
our @SMALL  = qw( 1 2 3 4 5 6 7 8 9 10 );
our @OP     = qw( + - * / + - * / + - * /);

sub draw {
    my ($want_big, $want_small) = @_;
    my @n;
    my @b = @BIG;
    my @s = @SMALL;
    
    for (1..$want_big) {
        my $offset = rand scalar @b;
        my $num = splice @b, $offset, 1;
        push @n, $num;
    }
    for (1..$want_small) {
        my $offset = rand scalar @s;
        my $num = splice @s, $offset, 1;
        push @n, $num;
    }
print "drew: ", join(" ",@n), "\n";
    @n;
}

sub target { int rand 1000 }

sub solve {
    my ($target, @nums) = @_;
    my %tried_cache;
    for (;;) {
        my $try = try(@nums);
        next if $tried_cache{$try}++;
        my $total = eval "$try";
        return $try if $total == $target;
    }
}

sub try {
    my (@nums) = @_;
    my @n = shuffle @nums;
    my @o = (shuffle @OP)[0..6];    
    my @terms = grep {defined} map { ($n[$_], $o[$_] )} 0..7;
    my $try = join(" ", @terms);
    $try;
}

unless (caller) {
    use Test::More qw(no_plan);
    
    ok(my @nums = draw(3,5), "draw 3,5");
    print join(" ", @nums), "\n";
    
    ok(my $t = target, "target acquired");
    print $t, "\n";
    
    ok(my @a = solve($t, @nums), "solution?");
    print $a[0], "\n";
}