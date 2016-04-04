package Mailsheep::App::Command::features;
use v5.14;
use strict;
use warnings;

use Mailsheep::App -command;

use Moo; with(
    'Mailsheep::Role::Cmd',
    'Mailsheep::MailMessageConvertor'
);

use JSON;
use POSIX qw(floor);

sub min {
    my ($a,$b) = @_;
    return ($a < $b) ? $a : $b;
}

sub opt_spec {
    return (
        [ "folder=s",  "The folder." ],
        [ "threshold=n",  "Threshold", { default => 0.9 } ],
    );
}

my $JSON = JSON->new->pretty;

sub build_feature_index {
    my ($self) = @_;
    my $mgr = $self->mail_box_manager;

    my %features;
    for (@{$self->config->{folders}}) {
        my $name = $_->{name};
        my $folder;
        if ( $name eq $self->{opt}{folder}) {
            $folder = $self->{folder}
        } else {
            $folder = $mgr->open("=${name}", access => "ro", remove_when_empty => 0) or die "$name does not exists\n";
        }
        my $count_message = $folder->messages;
        for (my $i = 0; $i < $count_message; $i++) {
            my $message = $folder->message($i);
            my $doc = $self->convert_mail_message_to_analyzed_document( $message );
            for my $k (keys %$doc) {
                for my $v (@{ $doc->{$k} }) {
                    my $fk = "$k\t=\t$v";
                    $features{$fk}{total}++;
                    $features{$fk}{by_folder}{$name}++;
                }
            }
        }
    }
    $self->{features} = \%features;
}

sub print_common_features {
    my ($self) = @_;
    my $opt = $self->{opt};

    my $count_message = $self->{folder}->messages;
    my $features = $self->{features};

    my $folder_name = $self->{folder_name};

    my $threshold = ($opt->{threshold} > 1) ? $opt->{threshold} : ($count_message * $opt->{threshold});
    my @fk = sort { $features->{$b}{by_folder}{$folder_name} <=> $features->{$a}{by_folder}{$folder_name} } grep { $features->{$_}{total} > 2 && $features->{$_}{by_folder}{$folder_name} } keys %$features;

    my $bound= 0;
    while ($features->{$fk[$bound]}{by_folder}{$folder_name} >= $threshold) {
        $bound++;
    }
    if ( $bound == 0 ) {
        $bound = min(0.1*@fk, 25);
    }

    print "# Common Features\n";
    for (my $i = 0; $i < $bound; $i++) {
        my $k = $fk[$i];
        my $f = $features->{$k}{by_folder}{$folder_name};
        printf("%2.2f\t%d\t%d\t\t%s\n", $f / $count_message, $f, $count_message, $k);
    }
    print "\n";
}

sub print_noise_features {
    my ($self) = @_;

    my $features = $self->{features};

    my $threshold = int(@{$self->config->{folders}} * 0.5);

    print "# Noise Features\n";

    for my $fk (keys %$features) {
        my $f = $features->{$fk}{total};
        my $c = keys %{$features->{$fk}{by_folder}};
        next unless ($c >= $threshold);
        printf("%2.2f\t%d\t%d\t\t%s\n", $f / $c, $f, $c, $fk);
    }
    print "\n";
}

sub print_distinct_features {
    my ($self) = @_;

    my $features = $self->{features};
    my $count_message = $self->{folder}->messages;
    my $folder_name = $self->{folder_name};

    print "# Distinct Features\n";

    for my $fk (keys %$features) {
        my $f = $features->{$fk}{total};
        next unless $f > 2 && $features->{$fk}{by_folder}{$folder_name} && $features->{$fk}{by_folder}{$folder_name} == $f;
        printf("%2.2f\t%d\t%d\t\t%s\n", $f / $count_message, $f, $count_message, $fk);
    }
    print "\n";
}

sub execute {
    my ($self, $opt) = @_;
    my ($folder_name);
    unless (defined($folder_name = $opt->{folder})) {
        die "folder is required";
    }
    $self->{folder} = $self->mail_box_manager->open("=${folder_name}", access => "ro", remove_when_empty => 0) or die "$folder_name does not exists\n";
    
    $self->{opt} = $opt;
    $self->{folder_name} = $folder_name;

    $self->build_feature_index();
    $self->print_common_features();
    $self->print_distinct_features();
    $self->print_noise_features();
}

1;
