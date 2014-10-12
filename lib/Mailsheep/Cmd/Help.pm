package Mailsheep::Cmd::Help;
use v5.12;
use Moo; with('Mailsheep::Role::Cmd');
sub execute {
    say "I can't help you";
}
1;

