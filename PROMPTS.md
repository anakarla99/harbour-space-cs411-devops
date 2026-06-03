# PROMPTS.md

## Stretch: Tag the instance with the cohort id

One concrete reason a real cloud team tags every resource at creation time:

Without tags, no one knows who owns a resource or what project it belongs to.
In a shared AWS account with many instances, an untagged EC2 becomes mystery
infrastructure. No one knows if it is safe to delete or who is paying for it.
Tags make cost attribution and cleanup possible from day one.

## Stretch: Lock down the Security Group

Failure mode of 0.0.0.0/0 on port 22:

Anyone on the internet can attempt to brute-force SSH into your instance.
Bots scan all public IPs continuously and an open port 22 gets attacked
within minutes of the instance launching.

Inconvenience of the narrower rule:

If your laptop IP changes (new network, VPN, coffee shop) you get locked out
and must update the Security Group rule from the AWS console before you can
SSH in again.