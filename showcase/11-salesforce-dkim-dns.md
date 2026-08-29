# Field Note: Salesforce DKIM and DNS Verification

## Summary

Configured Salesforce DKIM for a custom domain while preserving the organization's existing Microsoft 365 DKIM configuration — a compact but useful case in selector-based DKIM, DNS record types, and coexistence between different mail-producing systems.

## The problem

Salesforce required DKIM records. Initial DNS checking made it unclear whether the selectors were correctly published.

## Salesforce selectors

Two Salesforce DKIM selectors were configured (sanitized):

```
company-sf-dkim1
company-sf-dkim2
```

pointing at Salesforce `custdkim.salesforce.com` targets.

## The important DNS detail

The records were **CNAMEs**, so an explicit CNAME query was needed:

```
nslookup -type=CNAME company-sf-dkim1._domainkey.example.com
nslookup -type=CNAME company-sf-dkim2._domainkey.example.com
```

Successful output showed a canonical name pointing into `custdkim.salesforce.com`. A default (A-record) query had made healthy records look missing.

## Microsoft 365 coexistence

The organization already had Microsoft 365 DKIM. The key realization: **DKIM is selector-based.**

```
selector1._domainkey.example.com          (Microsoft 365)
selector2._domainkey.example.com          (Microsoft 365)
company-sf-dkim1._domainkey.example.com   (Salesforce)
company-sf-dkim2._domainkey.example.com   (Salesforce)
```

Different sending platforms can coexist on one domain as long as each uses its own selectors. Activating Salesforce DKIM did not require removing Microsoft 365 DKIM.

## Result

Both Salesforce selectors verified through DNS, and Salesforce DKIM now coexists with the existing Microsoft 365 email authentication configuration.

## Technologies

DNS · DKIM · Salesforce · Microsoft 365 · `nslookup` · CNAME records
