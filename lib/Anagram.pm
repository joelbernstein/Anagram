package Anagram;

use strict;
use warnings;
use Storable;
use Carp;

our $CACHE_FILE_DEFAULT         = '/tmp/wordstree';
our $DICTIONARY_FILE_DEFAULT    = '/usr/share/dict/words';

unless (caller) {
	unless (@ARGV) {
		print STDERR "syntax: $0 letters [/path/to/dictionary]\n";
		exit 1;
	}

	my $letters  = shift @ARGV;
	my $wordfile = shift @ARGV;
	my $t = __PACKAGE__->new({dictionary => $wordfile, verbose => 1});
	print "Now matching '$letters'...\n";
	print "$_\n" for $t->match($letters);
}

# return matches against the letters - we can give complete matches (ie, all letters used) or 
# partial and complete matches (ie, some/all letters used)
sub match {
	my ($self, $letters, $partials) = @_;
	$partials ||= 0;
	my $l;
	for my $x (split //, $letters) {
		$l->{$x}++
	}
	_match($partials, $self->_tree, $l);
}

sub match_all {
    my ($self, $letters) = @_;
    $self->match($letters, 1);
}

sub match_anagram {
    my ($self, $letters) = @_;
    $self->match($letters, 0);
}

sub _tree {
	my ($self, $tree) = @_;
	if (defined $tree) {
		$self->{tree} = $tree;
	}
	$self->{tree};
}

sub _load_words {
	my ($self, $dict) = @_;
	my $cache = $self->cache_file;
	my $verbose = $self->_verbose;
	my $tree = _load_t($cache, $dict, $verbose);
	$self->_tree($tree);
}

sub cache_file { shift->{cache} }

sub new {
	my ($class, $args) = @_;
	my $dict 	= delete $args->{dictionary}    || $DICTIONARY_FILE_DEFAULT;
	my $cache 	= delete $args->{cache}         || $CACHE_FILE_DEFAULT;
	my $verbose = delete $args->{verbose};
	
	my $self = bless { cache => $cache, verbose => $verbose }, $class;
	$self->_load_words($dict);
	$self;
}

sub _verbose { defined shift->{verbose} }

# retrieve a previously saved tree from disk, or create a new one from the dictionary
sub _load_t {
	my ($cache_file, $wordfile, $verbose) = @_;
	$verbose ||= 0;
	my $t;

	if ( -e $cache_file ) {
		$t = retrieve($cache_file);
	} else {
		print "Creating word tree - will be cached for future use..."
			if $verbose;
		my @w = do { open F, $wordfile or croak "couldn't load $wordfile: $!"; <F> }; 
		while (my $w = shift @w) {
			chop $w;
			$w =~ s/\W//g;
			my ($head, $rest)  = ($w =~ m{ \A (.) (.*) \z }xms);
			$head = lc $head;

			if (defined $t->{$head} && $t->{$head}->{rest}) {
				_descend($t->{$head});
				$t->{$head}->{rest} = $rest;
			} else {
				print "." if $verbose;
				$t->{$head} = { rest => $rest };
			}
		}

		for (values %$t) {
			_descend($_);
		}

		store $t, $cache_file;
		print " Done.\n" if $verbose;
	}
	$t;
}

# recursively copy an arbitrarily nested hashref structure
sub _deep_copy {
	my $in = shift;
	my $out = {};
	for (keys %$in) {
		if (ref $in->{$_}) {
			$out->{$_} = _deep_copy($in->{$_});
		} else {
			$out->{$_} = $in->{$_}
		}
	}
	$out;
}

# attempt to find complete word paths using our letters (but not necessarily *all* our letters)
{ 
	our %match_cache;
	sub _match {
		my ($partials, $t, $letters, $matchhead) = @_;
		$matchhead ||= "";
		return unless keys %$t;

		$t = _prune_t($t, $letters, 1);

		my @found;
		for (sort keys %$t) {
			if ($_ eq 'tail') {
					push @found, $matchhead;
					next;
			}
		
			my $l = _deep_copy($letters);
			$l->{$_}--;
			my $have_l_left = !! (grep { $_ >= 1 } values %$l);

			if (exists $t->{$_}) {
				my $t2 = $t->{$_};
				if ($partials) {
					if (ref $t2 eq 'HASH' && exists $t2->{tail} && !$have_l_left) { 
						my $word = $matchhead . $_;
						if ($match_cache{$word}++ <= 0) {
							push @found, $word;
						}
					}
				} else {
					if (ref $t2 eq 'HASH' && exists $t2->{tail}) { 
						my $word = $matchhead . $_;
						if ($match_cache{$word}++ <= 0 && !$have_l_left) {
							push @found, $word;
						}
					}
				}

			}

			my $pruned_sub_t = _prune_t($t->{$_}, $l);
	
			if (grep { $_ < 0 } values %$l) {
				next if $matchhead;
				return;
			}
		
			if (keys %$pruned_sub_t) {
				next unless $have_l_left;
				my @matches = grep { $_ } _match($partials, $pruned_sub_t, $l, $matchhead . $_);
				if (@matches) {
					push @found, @matches;
				} else { 
					$l->{$_}++;
				}
			} else {
				next if $have_l_left && !$partials;
				my $word = $matchhead . $_;
				unless ($match_cache{$word}++ > 0) {
					push @found, $word;
				}
			}
		}
		@found;
	}
}

# select only the initial nodes through which our letters could form a word path
sub _prune_t {
	my ($t, $l) = @_;
	return unless ref $t && $l;
	return {} unless keys %$t && keys %$l;

	my @pruned_t_keys = grep { $_ and exists $l->{$_} } keys %$t;
	my $pruned_t = { map { $_ => $t->{$_} } @pruned_t_keys };
	$pruned_t;
}

# take a depth-first walk down the tree, expanding any non-normalised word tails we find or create
sub _descend {
	my $t = shift;
	return unless ref $t eq 'HASH' && defined $t->{rest};
    my $w = $t->{rest};

    my ($head, $rest) = ($w =~ m{ \A (.) (.*) \z }xms) || return;
    if (defined $rest && $rest) {
        if (defined $t->{$head}) {
            if (ref $t->{$head}) {
                $t->{$head}{rest} = $rest;
            } else {
                # previously, this node was a word tail
                $t->{$head} = { rest => $rest, tail => 1 };
            }
        } else {
            $t->{$head} = { rest => $rest };
        }
    } else {
        $t->{$head} = 1;
    }
    delete $t->{rest};
    for (values %$t) {
        _descend($_);
    }
}

1;
