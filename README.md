Mailsheep
=========

Personal email automation.

## Pre-requesities

- offlineimap
- perl 5.14 or later

## Categorization

The implementation is Naive Bayes

    mailsheep-train.pl
    mailsheep-categorize.pl

## Book-keeping

    mailsheep-purge-old.pl

## Mail stats

## Config Example

{
    "maildir": "/home/gugod/Maildir",
    "index_dir": "/home/gugod/.config/mailsheep/index",
    "folders": [
        { "name": "Archive",       "retention": 0   },
        { "name": "Boring",        "retention": 60  },
        { "name": "DevPerl5",      "retention": 60  },
        { "name": "Junk",          "retention": 120 }
    ]
}
