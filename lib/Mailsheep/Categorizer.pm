package Mailsheep::Categorizer;
use v5.14;
use warnings;

use Moo;
use Sereal::Encoder;
use Sereal::Decoder;
use Hash::Flatten qw(flatten unflatten);

use File::Basename qw(basename);
use Encode 'encode_utf8';
use List::Util qw(sum max);
use List::MoreUtils qw(uniq);

has store => (
    is => "ro",
    required => 1,
    isa => sub { -d $_[0] }
);

has idx => (
    is => "lazy"
);

sub _build_idx {
    my $self = shift;
    my $idxf = {};
    my $idx = {};
    my $store = $self->store;
    my $sereal = Sereal::Decoder->new;
    for my $fn (<$store/*.merged.sereal>) {
        next unless basename($fn) =~ m/\A (?<boxname>.+) \. merged \.sereal$/x;
        my $boxname = $+{boxname};
        next if lc($boxname) eq 'inbox';
        open my $fh, "<", $fn;
        local $/ = undef;
        my $x = <$fh>;
        $idx->{$boxname} = $sereal->decode($x);
        close($fh);
    }
    return $idx;
}

sub train {
    my ($self, $category, $documents) = @_;

    my $idx = {};
    for my $document (@$documents) {
        $idx->{df}++;
        for my $field (keys %$document) {
            next unless defined $document->{$field};

            my $fidx = $idx->{field}{$field} ||= {};
            my @tokens = @{$document->{$field}};
            $fidx->{tf} += @tokens;
            $idx->{tf}  += @tokens;

            my %seen;
            for my $token (@tokens) {
                $fidx->{token}{$token}{tf}++;
                $seen{$token}++;
            }
            $fidx->{count_utoken} += keys %seen;
            for my $token (keys %seen) {
                $fidx->{token}{$token}{df}++;
            }
        }
    }

    for my $field (keys %{$idx->{field}}) {
        my $fidx = $idx->{field}{$field};
        for my $t (keys %{$fidx->{token}}) {
            if ($fidx->{token}{$t}{df} < 3) {
                delete $fidx->{token}{$t};
            }
        }
    }

    my $ts = time();

    my $sereal = Sereal::Encoder->new;
    open my $fh, ">", File::Spec->catdir($self->store, "${category}.${ts}.sereal");
    print $fh $sereal->encode($idx);
    close($fh);

    $self->merge_idx($category, $idx);
}

sub merge_idx {
    my ($self, $category, $latest_idx) = @_;

    my $idxf = {};
    my $idx = {};
    my $store = $self->store;
    my $sereal = Sereal::Decoder->new;

    my $current_merged_idx = File::Spec->catdir($self->store, "${category}.merged.sereal");

    if (-f $current_merged_idx) {
        my $w = 0.9;

        open my $fh, "<", $current_merged_idx;
        local $/ = undef;
        my $merged_idx = $sereal->decode(<$fh>);
        close($fh);

        __merge_idx($idx, $latest_idx, 1);
        __merge_idx($idx, $merged_idx, $w);
    } else {
        for my $fn (<$store/*.sereal>) {
            next unless basename($fn) =~ m/\A ${category} \. (?<ts>[0-9]+) \.sereal$/x;
            $idxf->{$+{ts}} = $fn;
        }
        my @all_idx_t = sort { $b <=> $a } keys %$idxf;
        shift @all_idx_t;

        __merge_idx($idx, $latest_idx, 1);

        my $w = 0.9;
        for my $t (@all_idx_t) {
            my $fn = $idxf->{$t};
            open my $fh, "<", $fn;
            local $/ = undef;
            my $x = $sereal->decode(<$fh>);
            __merge_idx($idx, $x, $w);
            $w = $w * 0.9;
            close($fh);
        }
    }

    $sereal = Sereal::Encoder->new;
    open my $fh, ">", $current_merged_idx;
    print $fh $sereal->encode($idx);
    close($fh);
}

sub __merge_idx {
    my ($x1, $x2, $w) = @_;
    my $y1 = flatten($x1);
    my $y2 = flatten($x2);
    my $y0 = {};
    for (keys %$y1) {
        $y0->{$_} = $y1->{$_} + $w * ( delete($y2->{$_}) // 0);
    }
    for (keys %$y2) {
        $y0->{$_} = $w * ( delete($y2->{$_}) // 0);
    }
    %$x1 = %{ unflatten($y0) };
}

sub classify {
    my ($self, $doc) = @_;

    my $idx = {%{$self->idx}};
    for (keys %$idx) {
        delete $idx->{$_} unless keys %{ $idx->{$_} };
    }
    my $total_docs = sum(map { $_->{df} } values %$idx);

    my %guess;
    my %category_p;
    for my $category (keys %$idx) {
        $category_p{$category} = $idx->{$category}{df} / $total_docs;
    }

    for my $field (keys %$doc) {
        next if !defined($doc->{$field}) || $doc->{$field} eq '';

        my $category;
        my @tokens = @{$doc->{$field}} or next;

        my %p;
        for $category (keys %$idx) {
            for my $token (@tokens) {
                my $f = $idx->{$category}{field}{$field};
                if ( ($f->{tf} ||0) > 0) {
                    $p{$token}{$category} = ($f->{token}{$token}{tf} ||0) / $f->{tf};
                } else {
                    $p{$token}{$category} = 0;
                }
            }
        }

        my %score;
        for $category (keys %$idx) {
            my $score = $category_p{$category};
            for (@tokens) {
                $score *= $p{$_}{$category};
            }
            $score{$category} = $score;
        }

        my @c = sort { $score{$b} <=> $score{$a} } keys %score;

        $guess{$field} = {
            field => $field,
            maxscore => $score{$c[0]},
            fieldLength => 0+@tokens,
            category   => $c[0],
            confidence => $score{$c[0]} / (sum(values %score) ||1),
            score => \%score,
            tokens => \@tokens,
            token_p => \%p,
        };
    }

    my @guess = sort { $b->{maxscore} <=> $a->{maxscore} } values %guess;

    if (@guess) {
        return {
            score => $guess[0]{maxscore},
            guess => \@guess,
            category => ($guess[0]{maxscore} == 0 ? undef : $guess[0]{category}),
            category_p => \%category_p
        };
    } else {
        return {
            score => 0,
            guess => \@guess,
            category => undef,
            category_p => \%category_p
        };
    }
}

1;
