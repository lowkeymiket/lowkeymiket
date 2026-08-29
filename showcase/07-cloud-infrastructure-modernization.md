# Cloud Infrastructure and File-Service Modernization

## Executive summary

Participated in the transition from distributed on-premises office infrastructure toward centralized cloud infrastructure and Microsoft 365 services.

The legacy environment included domain controllers, file servers, print servers, VMware ESXi hosts, FortiGate firewalls, satellite offices, and site-to-site connectivity. The organization ultimately moved toward a substantially cloud-first architecture.

## Previous architecture

```
HQ
 |
 +-- Domain Controller
 +-- File Server
 +-- Print Server
 +-- ESXi
 +-- FortiGate
 |
 +=========== VPN =========+
                           |
Satellite Office          Satellite Office
 |                         |
 +-- DC                    +-- DC
 +-- File/Print            +-- File/Print
 +-- FortiGate             +-- FortiGate
```

## Modernized direction

```
                    Microsoft 365
                    /     |     \
             SharePoint  Teams  OneDrive
                   |
Users -------- Microsoft Entra
                   |
                 Azure
                   |
             Central services
```

## File migration

Traditional file shares were moved toward SharePoint and Teams. This required far more than copying files. For every share, the questions included:

- Who owns this data?
- What SharePoint site should contain it?
- Should it be Teams-connected?
- Who needs access?
- Does the old NTFS structure make sense in SharePoint?
- What data should *not* migrate?
- How should users access it afterward?
- What synchronization behavior is appropriate?

## Directory services

Distributed domain-controller infrastructure could be reduced as workloads and identity dependencies moved toward cloud services.

## Operational benefit

Decommissioning local office infrastructure reduces dependency on:

- Physical server hardware
- UPS hardware
- Local storage
- Office power
- Office internet connectivity
- Hypervisors
- Site-specific backup
- Local server maintenance

## The important engineering point

"Move to cloud" is **not**:

```
Server file share
     |
   COPY
     v
SharePoint
```

The application and the user workflow have to change with it. A migration that preserves a broken structure in a new location has not modernized anything.

## Technologies

Azure · Active Directory · Azure AD Connect · ADFS · Microsoft 365 · SharePoint Online · Teams · OneDrive · VMware ESXi · FortiGate · Windows Server
