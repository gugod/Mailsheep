Mailsheep
=========

Personal email automation.

## Pre-requesities

- offlineimap
- perl 5.14 or later

## Categorization

The implementation is Naive Bayes

    mailsheep train
    mailsheep categorize

## LLM-based Categorization with ollama

    mailsheep categorize --with-ollama

## House-keeping

    mailsheep readall
    mailsheep purgeold

## Mail stats

## Config Example

```json
{
  "maildir": "/home/gugod/Maildir",
  "index_dir": "/home/gugod/.config/mailsheep/index",
  "folders": [
    {
      "name": "Archive",
      "auto": false,
      "retention": 0
    },
    {
      "name": "DevPerl5",
      "description": "All mailing list related the develoument and use of Perl programming language.",
      "auto": true,
      "retention": 0
    },
    {
      "name": "News",
      "description": "Mails from public media about current events, political changes, updates from technical companies, etc.",
      "auto": true,
      "retention": 60
    },
    {
      "name": "Junk",
      "description": "scams or phishing mails",
      "auto": true,
      "retention": 120
    }
  ]
}
```
