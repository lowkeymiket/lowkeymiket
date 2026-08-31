# Remove a Stale SharePoint User Identity

## Problem
A rehired employee had a current Entra ID account, but SharePoint still retained the legacy identity from the employee's previous account. The stale entry appeared as an inactive user and could trigger duplicate-account behavior because the legacy and current identities shared the same email address.

## Fix
A PnP PowerShell workflow connects to each affected SharePoint or OneDrive site, removes the stale membership identity, then queries the site's User Information List to verify that the legacy entry is gone.

## Safety / Notes
- Operates only against a reviewed list of affected sites.
- Targets the exact SharePoint membership login rather than a fuzzy display-name match.
- Performs a post-removal verification query.
- Records a result for every site, including failures, instead of silently continuing.

## Result
The stale identity was removed from affected sites while the active Entra account remained intact, resolving the legacy-account conflict.

## Notes
**Recovered from the production console session and parameterized for publication.** Organization domains, names, app IDs, and paths were removed.
