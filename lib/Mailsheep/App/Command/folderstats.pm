package Mailsheep::App::Command::folderstats;
use v5.12;
use Mailsheep::App -command;

use Moo; with('Mailsheep::Role::Cmd');

sub opt_spec {
    return (
        [ "histogram=n",  "Comma-separated list of fields" ]
    );
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $mgr = $self->mail_box_manager;
    my %folder;
    for my $folder (@{$self->config->{folders}}) {
        my $x = $folder->{name};
        $folder{$x} = $mgr->open("=${x}",  access => "r") or die "The mail box \"=$x\" cannot be opened.\n";
    }

    my %stats;

    for (values %folder) {
        $stats{"$_"} = {
            total_messages => (0+$_->messages)
        };
    }

    my %histograms;
    my $histogram_interval = (defined($opt->{histogram}) ? ($opt->{histogram})*86400 : undef);
    my $now = time;
    for my $box (values %folder) {
        my %hist;
        my %label;
        for my $message ($box->messages) {
            if (defined($opt->{histogram})) {
                my $bucket = int(($now - $message->timestamp)/$histogram_interval);
                $hist{$bucket}++;
            }
            for my $x ($message->labels) {
                $label{$x}++ if $message->label($x);
            }
        }
        $stats{"$box"}{label} = \%label;
        if (defined($opt->{histogram})) {
            $stats{"$box"}{histogram} = join ",", map { $hist{$_} } sort { $a <=> $b } keys %hist;
        }
    }

    $mgr->closeAllFolders;

    printf("%-20s %10s\n","Folder", "Messages");
    printf(("="x30)."\n");
    for my $box (keys %stats) {
        printf("%-20s %10d %s %s\n",
               "$box",
               $stats{$box}{total_messages},
               join(",", map { "$_: " . $stats{$box}{label}{$_} } sort {$stats{$box}{label}{$b} <=> $stats{$box}{label}{$a}  } keys %{$stats{$box}{label}}),
               ($stats{$box}{histogram}||"")
           );
    }
}
1;

