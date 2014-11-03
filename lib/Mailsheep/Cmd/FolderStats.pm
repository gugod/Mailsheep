package Mailsheep::Cmd::FolderStats;
use v5.12;
use Moo; with('Mailsheep::Role::Cmd');
sub execute {
    my $self = shift;

    my $mgr = $self->mail_box_manager;
    my %folder;
    for my $folder (@{$self->config->{folders}}) {
        my $x = $folder->{name};
        $folder{$x} = $mgr->open("=${x}",  access => "r") or die "The mail box \"=$x\" cannot be opened.\n";
    }

    my @msgcount;
    for (values %folder) {

    }
    @msgcount = sort { $b->[1] <=> $a->[1] } @msgcount;


    my $histogram_interval = 7*86400;
    my %histograms;
    my $now = time;
    for my $box (values %folder) {
        my %hist;
        for my $message ($box->messages) {
            my $bucket = int(($now - $message->timestamp)/$histogram_interval);
            $hist{$bucket}++;
        }

        $histograms{"$box"} = join ",", map { $hist{$_} } sort { $a <=> $b } keys %hist;
        my @x = ("$box", 0+$box->messages, $histograms{"$box"});
        push @msgcount, \@x;
        # printf("%-20s\t%10d\t%20s\n", @x);
    }
    $mgr->closeAllFolders;

    printf("%-20s %10s %s\n","Folder", "Messages", "Histogram");
    printf(("="x30)."\n");
    for (@msgcount) {
        printf("%-20s %10d %s\n", $_->[0], $_->[1], $_->[2]);
    }
}
1;

