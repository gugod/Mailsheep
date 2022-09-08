package Mailsheep::Analyzer;
use v5.36;

use List::MoreUtils qw(uniq);
use Unicode::UCD    qw(charscript);

our @EXPORT_OK = qw( reduced_mail_subject nskip_shingle normalize_whitespace );

sub reduced_mail_subject ($subject = "") {
    $subject =~ s/\P{L}/ /g;
    $subject =~ s/\d+/ /g;
    return normalize_whitespace($subject);
}

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
    return grep { !/\A\s*\z/u } @_;
}

sub by_script ($str) {
    my @chars = grep { defined($_) } split "", normalize_whitespace( $str );
    my @tokens;

    return () unless @chars;

    my $t = shift(@chars);
    my $s = charscript( ord($t) );
    while ( my $char = shift @chars ) {
        my $_s = charscript( ord($char) );
        if ( $_s eq $s ) {
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

sub standard ($str) {
    $str =~ s/\p{Punct}/ /g;
    map { /\p{Ideographic}/ ? ( split "" ) : $_ } by_script($str);
}

sub ngram ( $s, $gram_length ) {
    $gram_length ||= 1;

    my @t;
    my $l = length($s);
    while ( $l > $gram_length ) {
        push @t, substr( $s, 0, $gram_length );
        $s = substr( $s, 1 );
        $l = length($s);
    }
    return @t;
}

sub shingle( $size, @tokens ) {
    my @x;
    for ( 0 .. $#tokens + 1 - $size ) {
        push @x, join " ", @tokens[ $_ .. $_ + $size - 1 ];
    }
    return @x;
}

sub nskip_shingle ($skip, $tokens) {
    my @x;
    for ( 0 .. ( $#$tokens - $skip - 1 ) ) {
        push @x, join " ", @{$tokens}[ $_, ( $_ + $skip + 1 ) ];
    }
    return \@x;
}

sub standard_than_shingle2 ($str) {
    my @tokens   = standard( $str );
    my @shingles = shingle( 2, @tokens );
    return ( @tokens, @shingles );
}

sub standard_than_shingle3 ($str) {
    my @tokens   = standard( $str );
    my @shingles = shingle( 3, @tokens );
    return ( @tokens, @shingles );
}

sub standard_shingle2_shingle3 ($str) {
    my @tokens   = standard( $str );
    my @shingle2 = shingle( 2, @tokens );
    my @shingle3 = shingle( 3, @tokens );
    return ( @tokens, @shingle2, @shingle3 );
}

sub standard_with_multi_shingle ($str) {
    my @tokens = standard($str);
    my @extra;
    for ( 2 .. @tokens ) {
        push @extra, shingle( $_, @tokens );
    }
    for ( 1 .. $#tokens ) {
        push @extra, nskip_shingle( $_, @tokens );
    }
    return ( @tokens, @extra );
}

1;
