package Mailsheep::Cmd::FolderStats;
use v5.12;
use Moo; with('Mailsheep::Role::Cmd');

has histogram => (is => "ro");

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
        push @msgcount, [ "$_", 0+$_->messages ];
    }
    @msgcount = sort { $b->[1] <=> $a->[1] } @msgcount;

    my %histograms;
    if (defined($self->histogram)) {
        my $histogram_interval = ($self->histogram)*86400;
        my $now = time;
        for my $box (values %folder) {
            my %hist;
            for my $message ($box->messages) {
                my $bucket = int(($now - $message->timestamp)/$histogram_interval);
                $hist{$bucket}++;
            }

            $histograms{"$box"} = join ",", map { $hist{$_} } sort { $a <=> $b } keys %hist;
        }
    }

    $mgr->closeAllFolders;

    printf("%-20s %10s\n","Folder", "Messages");
    printf(("="x30)."\n");
    for (@msgcount) {
        my $box = $_->[0];
        printf("%-20s %10d %s\n", $_->[0], $_->[1], ($histograms{$box}||""));
    }
}
1;

