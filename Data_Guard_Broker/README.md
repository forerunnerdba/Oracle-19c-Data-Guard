# Oracle 19c Data Guard Broker Configuration

This repository contains the commands and execution output from my lab for configuring and validating **Oracle 19c Data Guard Broker** on an existing Physical Standby / Active Data Guard environment.

For the complete commands and actual execution output, refer to:

`ConfigureDataGuardBroker.sh`

## Environment

| Component | Configuration |
|---|---|
| Oracle Database | 19c (19.32.0) |
| Primary Database | PRIMCA |
| Physical Standby | STDBYCA |
| Broker Configuration | CAOCIPR_DG |
| Protection Mode | MaxPerformance |
| Redo Transport | ASYNC |
| Storage | ASM (+DATA / +FRA) |

## What Is Covered

1. Enable Flashback Database on Primary and Standby
2. Configure Broker configuration files in ASM
3. Enable `DG_BROKER_START`
4. Reset `LOG_ARCHIVE_DEST_2` on the Standby
5. Create the Broker configuration using DGMGRL
6. Add the Physical Standby to the configuration
7. Review and enable the Broker configuration
8. Validate Primary and Standby using `SHOW DATABASE VERBOSE`

## Final Validation

- `PRIMCA` — PRIMARY / `TRANSPORT-ON`
- `STDBYCA` — PHYSICAL STANDBY / `APPLY-ON`
- Protection Mode — `MaxPerformance`
- Redo Transport — `ASYNC`
- Transport Lag — `0 seconds`
- Apply Lag — `0 seconds`
- Real Time Query — `ON`
- Broker Configuration Status — `SUCCESS`
- Primary Database Status — `SUCCESS`
- Standby Database Status — `SUCCESS`

## Data Guard Series

- **Part 1 — Build It:** Physical Standby & Active Data Guard
- **Part 2 — Manage It:** Data Guard Broker
- **Part 3 — Test It:** Switchover, Failover & Reinstatement

🔐 Security

Sensitive information such as passwords, private keys, tokens, credentials and environment-specific secrets has been removed or replaced with placeholders before publication.

## 👨‍💻 Author

**Chakravarthy P**

Oracle Database Administrator / SME

Areas of interest:

* Oracle Database
* Oracle RAC
* Oracle ASM
* Oracle Data Guard
* Oracle Restart
* Oracle Cloud
* Microsoft Azure
* Database Migration
* Oracle Patching
* Ansible Automation
* Linux

## ⭐ Feedback

If you find this documentation useful, feel free to share your feedback, suggestions or corrections. Please consider giving the repository a Star.

The objective is to continuously improve the documentation and capture practical Oracle DBA deployment experiences.
