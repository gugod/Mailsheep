package Mailsheep::Analyzer;
use v5.12;
use strict;
use List::MoreUtils qw(uniq);
use Unicode::UCD qw(charscript);

sub filter_characters {
    local $_ = $_[0];
    s/\b/ /g;
    s/\A\s+//g;
    s/\s+\z//g;
    s/\s+/ /g;
    return lc($_);
}

sub normalize_whitespace {
    local $_ = $_[0];
    s/[\t ]+/ /g;
    s/\A\s+//;
    s/\s+\z//;
    return $_;
}

sub remove_spaces {
    return grep { ! /\A\s*\z/u } @_;
}

sub by_script($) {
    my $str = normalize_whitespace($_[0]);
    my @tokens;
    my @chars = grep { defined($_) } split "", $str;
    return () unless @chars;

    my $t = shift(@chars);
    my $s = charscript(ord($t));
    while(my $char = shift @chars) {
        my $_s = charscript(ord($char));
        if ($_s eq $s) {
            $t .= $char;
        }
        else {
            push @tokens, $t;
            $s = $_s;
            $t = $char;
        }
    }
    push @tokens, $t;
    return remove_spaces map { $_ = normalize_whitespace($_) } @tokens;
}

sub standard {
    my $str = $_[0];
    $str =~ s/\p{Punct}/ /g;
    map { /\p{Ideographic}/ ? (split "") : $_ } by_script($str);
}

sub ngram {
    my ($s, $gram_length) = @_;
    $gram_length ||= 1;

    my @t;
    my $l = length($s);
    while($l > $gram_length) {
        push @t, substr($s, 0, $gram_length);
        $s = substr($s, 1);
        $l = length($s);
    }
    return @t;
}

sub shingle($@) {
    my ($size, @t) = @_;
    my @x;
    for (0..$#t-$size) {
        push @x, join " ", @t[$_ .. $_+$size-1];
    }
    return @x;
}

sub sorted_shingle($@) {
    my ($size, @t) = @_;
    my @x;
    for (0..$#t-$size) {
        push @x, join " ", uniq(sort @t[$_ .. $_+$size-1]);
    }
    return @x;
}

sub nskip_shingle {
    my ($skip, $tokens) = @_;
    my @x;
    for (0..($#$tokens-$skip-1)) {
        push @x, join " ", @{$tokens}[$_, ($_+$skip+1)];
    }
    return \@x;
}

sub standard_than_shingle2 {
    my @tokens = standard($_[0]);
    my @shingles = shingle(2, @tokens);
    return (@tokens, @shingles);
}

sub standard_than_shingle3 {
    my @tokens = standard($_[0]);
    my @shingles = shingle(3, @tokens);
    return (@tokens, @shingles);
}

sub standard_shingle2_shingle3 {
    my @tokens = standard($_[0]);
    my @shingle2 = shingle(2, @tokens);
    my @shingle3 = shingle(3, @tokens);
    return (@tokens, @shingle2, @shingle3);
}

sub standard_with_multi_shingle {
    my $str = shift;
    my @tokens = standard($str);
    my @extra;
    for (2 .. @tokens) {
        push @extra, shingle($_, @tokens);
    }
    for (1 .. $#tokens) {
        push @extra, @{nskip_shingle($_, \@tokens)};
    }
    return [ @tokens, @extra ]
}


1;
