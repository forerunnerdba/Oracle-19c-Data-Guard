Oracle 19c Physical Standby & Active Data Guard

This repository contains the commands and execution steps used to build an Oracle 19c Physical Standby Database and enable Active Data Guard.

The document is based on a hands-on lab implementation and includes the actual commands, configuration steps, and selected execution output.

Environment

Component

Primary

Standby

DB_NAME

PRIMCA

PRIMCA

DB_UNIQUE_NAME

PRIMCA

STDBYCA

Oracle Version

19.32.0

19.32.0

Listener Port

1522

1521

Database Role

PRIMARY

PHYSICAL STANDBY

Storage

ASM

ASM

Host/IP details in the command log may contain lab-specific values. Replace them with values from your own environment.

Prerequisites

Before starting, make sure:

Oracle Database 19c is installed on both servers.

Primary and standby are on the same Oracle Database version and patch level.

Primary database is in ARCHIVELOG mode.

FORCE LOGGING is enabled on the primary.

Network connectivity exists between both servers.

Required listener ports are open.

Sufficient standby storage is available.

ASM/storage is configured as required.

STANDBY_FILE_MANAGEMENT=AUTO is configured.

Password file and Oracle Net/TNS configuration are available.

RMAN can connect to both primary and standby.

What Is Covered

The command log walks through the following:

Verify and configure ARCHIVELOG mode

Enable FORCE LOGGING

Configure the Fast Recovery Area (FRA)

Configure LOG_ARCHIVE_CONFIG

Configure STANDBY_FILE_MANAGEMENT=AUTO

Configure local and remote archive destinations

Verify primary online redo logs

Create Standby Redo Logs (SRLs)

Copy the password file

Configure TNS entries

Configure a static listener on the standby

Test Primary ↔ Standby connectivity

Create the primary PFILE

Prepare the standby PFILE

Create the standby audit directory

Start the standby instance in NOMOUNT

Create the standby using RMAN Active Duplicate

Monitor the RMAN execution log

Validate primary and standby roles

Start Managed Recovery

Monitor redo transport and redo apply

Perform manual log switches to validate redo flow

Check switchover status and Data Guard statistics

Move the standby SPFILE from filesystem to ASM

Register the standby database with Oracle Clusterware using srvctl

Start the standby through srvctl

Start Redo Apply

Perform final database and Clusterware validation

Final State

The lab was successfully validated with:

Primary
--------
DB_NAME        : PRIMCA
DB_UNIQUE_NAME : PRIMCA
ROLE           : PRIMARY
OPEN_MODE      : READ WRITE
PROTECTION     : MAXIMUM PERFORMANCE
FORCE_LOGGING  : YES


Standby
--------
DB_NAME        : PRIMCA
DB_UNIQUE_NAME : STDBYCA
ROLE           : PHYSICAL STANDBY
OPEN_MODE      : READ ONLY WITH APPLY
PROTECTION     : MAXIMUM PERFORMANCE
FORCE_LOGGING  : YES

Redo transport and Managed Recovery were also validated by generating log switches on the primary and confirming redo receipt/apply on the standby.

Files

The main command/execution file for this lab is:

Oracle19c_Physical_Standby_Active_Data_Guard.sh

It contains the detailed commands, configuration examples, and execution output from the lab.

Important

This is a lab/reference implementation, not a universal production deployment script.

Review and modify the following for your environment before execution:

Hostnames/IP addresses

Listener ports

Oracle Home

ORACLE_SID

ASM diskgroup names

Database file locations

TNS aliases

Password file paths

RMAN channels

Memory parameters

FRA size

Redo/SRL sizes

Clusterware configuration

Security

Do not commit real database passwords, SSH private keys, wallet files, or other credentials to GitHub.

Replace credentials in command examples with placeholders such as:

<PRIMARY_SYS_PASSWORD>
<STANDBY_SYS_PASSWORD>
<SSH_KEY>

Series

This is Part 1 of my Oracle 19c Data Guard series:

Part 1 — Build It: Physical Standby & Active Data Guard

Part 2 — Manage It: Data Guard Broker

Part 3 — Test It: Switchover, Failover & Reinstatement

The LinkedIn article provides the explanation and configuration walkthrough, while this repository contains the detailed command and execution log.
