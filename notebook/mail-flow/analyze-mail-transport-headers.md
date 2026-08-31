# Exchange Online / Exclaimer Transport Path Analysis

## Problem

A user could receive mail but outbound external messages failed with `554 5.4.14 Hop count exceeded`, and other outbound and forwarded mail intermittently behaved incorrectly. The environment routed messages through Microsoft 365 and Exclaimer Cloud for signature processing, so the visible NDR alone could not identify where the path went wrong. Troubleshooting required proving the actual SMTP path rather than assuming Exchange Online was the only transport hop.

## Investigation

Full RFC message headers were the evidence source: `Received`, `Authentication-Results`, and Exclaimer-specific processing headers. The recovered production headers show Exchange Online handing an outbound message to Exclaimer, Exclaimer processing it, and the message returning to Microsoft 365 protection. SPF and DMARC passed in the captured example, which separated authentication health from transport-routing health: the problem class was connector and routing behavior, not authentication.

## Fix

The troubleshooting method reconstructed the transport chain hop by hop, correlated sender IPs and HELO values, and identified Exclaimer processing markers to establish where a routing loop or connector mismatch could occur.

The accompanying script packages that method. It parses an `.eml` file and:

- unfolds RFC header continuations;
- extracts each `Received` hop in sequence;
- identifies `from` and `by` hosts;
- extracts authentication results;
- surfaces Exclaimer processing headers;
- flags transport hosts that recur multiple times; and
- optionally exports the reconstructed hop path to CSV.

Repeated hosts are not automatically declared a loop because legitimate mail paths can revisit infrastructure. The output makes the route visible so it can be compared with connector and transport-rule configuration.

## Safety / Notes

- The script is read-only and operates on a local message file. It does not connect to Exchange Online or alter connectors, rules, or mailboxes.
- Routing conclusions were based on hop order rather than a single NDR string.
- Authentication results were evaluated separately from connector behavior.
- Public samples should remove real email addresses, tenant IDs, internal hostnames, and message IDs.

## Result

The original incident was narrowed from a generic external-send failure to a mail-flow problem on the Microsoft 365 / Exclaimer route, giving a concrete path for reviewing connector scoping and preventing a repeated relay path. The recovered headers independently prove the environment's actual route through Exclaimer and back into Exchange Online protection.

## Notes
**Public reconstruction backed by recovered production headers.** The analyzer packages the method used during the incident; the header evidence itself stays private.
