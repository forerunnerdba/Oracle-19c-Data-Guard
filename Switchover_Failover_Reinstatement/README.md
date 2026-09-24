# Oracle 19c Data Guard — Switchover, Failover & Reinstatement

This repository contains the **commands and execution output** from my Oracle 19c Data Guard lab covering **switchover, failover, and reinstatement using DGMGRL**.

##Files

The complete command sequence and actual execution output are available here:

👉 **[Oracle 19c DataGuard Broker Switchover Failover Reinstate Command & Execution Output](Switchover_Failover_Reinstate.log)**

## Environment

| Component | Configuration |
|---|---|
| Oracle Database | 19c (19.32.0) |
| Broker Configuration | CAOCIPR_DG |
| Initial Primary | PRIMCA |
| Initial Physical Standby | STDBYCA |
| Protection Mode | MaxPerformance |
| Redo Transport | ASYNC |
| Fast-Start Failover | Disabled |

## What Is Covered

1. Pre-switchover health checks
2. Validation of Primary and Standby using DGMGRL
3. Planned switchover from `PRIMCA` to `STDBYCA`
4. Data Guard Broker log monitoring during role transition
5. Post-switchover role validation
6. Manual failover back to `PRIMCA`
7. Detection of `ORA-16661` requiring reinstatement
8. Reinstatement of `STDBYCA`
9. Broker warning recovery and final `SUCCESS` status
10. Final role validation using `GV$DATABASE`

## Tested Flow

```text
Initial State
PRIMCA   = PRIMARY
STDBYCA  = PHYSICAL STANDBY

        |
        | SWITCHOVER TO STDBYCA
        v

STDBYCA  = PRIMARY
PRIMCA   = PHYSICAL STANDBY

        |
        | FAILOVER TO PRIMCA
        v

PRIMCA   = PRIMARY
STDBYCA  = REINSTATE REQUIRED

        |
        | REINSTATE DATABASE STDBYCA
        v

Final State
PRIMCA   = PRIMARY
STDBYCA  = PHYSICAL STANDBY
```

## Final Validation

The final environment returned to:

- `PRIMCA` — `PRIMARY`, `READ WRITE`
- `STDBYCA` — `PHYSICAL STANDBY`, `READ ONLY WITH APPLY`
- Protection Mode — `MAXIMUM PERFORMANCE`
- Force Logging — `YES`
- Broker Configuration Status — `SUCCESS`


## Data Guard Series

- **Part 1 — Build It:** Physical Standby & Active Data Guard
- **Part 2 — Manage It:** Data Guard Broker
- **Part 3 — Test It:** Switchover, Failover & Reinstatement

## Security Note

> Sensitive information such as passwords, private keys, tokens, credentials and environment-specific secrets has been removed or replaced with placeholders before publication.

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
