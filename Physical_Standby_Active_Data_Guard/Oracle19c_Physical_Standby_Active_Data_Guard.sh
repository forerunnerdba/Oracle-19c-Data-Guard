**********************************************************************************************************************************************************************************************

																			Oracle 19c Physical Standby & Active Data Guard

***********************************************************************************************************************************************************************************************
																			Set up the primary database
************************************************************************************************************************************************************************************************

1. Enable the archive log mode. For our environment, archive logging is already enabled. Use the following verification steps to confirm its status.

SQL> archive log list;
Database log mode              Archive Mode
Automatic archival             Enabled
Archive destination            USE_DB_RECOVERY_FILE_DEST
Oldest online log sequence     0
Next log sequence to archive   0
Current log sequence           0


SQL> SELECT LOG_MODE from V$DATABASE;

LOG_MODE
------------
ARCHIVELOG

#If archive logging is not enabled, follow the steps below to turn it on.
#The database must be in MOUNT mode before archive log mode can be enabled.

SQL> SHUTDOWN IMMEDIATE;
SQL> STARTUP MOUNT;
SQL> ALTER DATABASE ARCHIVELOG;
SQL> ALTER DATABASE OPEN;
SQL> archive log list;
SQL> SELECT LOG_MODE from V$DATABASE;


2. Enable FORCE LOGGING. 
FORCE LOGGING ensures that all database changes are written to the redo logs, including operations that would normally bypass redo generation.
By enabling FORCE LOGGING , you guarantee that every structural and transactional change is fully captured and propagated.


select name, db_unique_name, database_role, open_mode, protection_mode, FORCE_LOGGING FROM gV$DATABASE;
SQL>
NAME      DATABASE_ROLE    OPEN_MODE            FORCE_LOGGING    
--------- ---------------- -------------------- -----------------
PRIMCA    PRIMARY          READ WRITE           NO            


SQL> ALTER DATABASE FORCE LOGGING;

Database altered.

SQL>select name, db_unique_name, database_role, open_mode, protection_mode, FORCE_LOGGING FROM gV$DATABASE;

NAME      DATABASE_ROLE    OPEN_MODE            FORCE_LOGGING    
--------- ---------------- -------------------- -----------------
PRIMCA    PRIMARY          READ WRITE           YES            

3. Configure FRA

SQL> show parameter DB_RECOVERY_FILE_DEST
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
db_recovery_file_dest                string      +REDO
db_recovery_file_dest_size           big integer 20G

#If the FRA is not set, run the commands below to configure the Recovery File Destination.

SQL> ALTER SYSTEM SET DB_RECOVERY_FILE_DEST='+REDO' SCOPE=BOTH;
SQL> ALTER SYSTEM SET DB_RECOVERY_FILE_DEST_SIZE=20G SCOPE=BOTH;

SQL> show parameter DB_RECOVERY_FILE_DEST
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
db_recovery_file_dest                string      +REDO
db_recovery_file_dest_size           big integer 20G

4. Configure LOG_ARCHIVE_CONFIG 

SQL> show parameter LOG_ARCHIVE_CONFIG

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
log_archive_config                   string

SQL> ALTER SYSTEM SET LOG_ARCHIVE_CONFIG='DG_CONFIG=(PRIMCA,STDBYCA)' SCOPE=BOTH;

System altered.

SQL> show parameter LOG_ARCHIVE_CONFIG

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
log_archive_config                   string      DG_CONFIG=(PRIMCA,STDBYCA)

5. Turn on Automatic Standby File Management
#Automatic standby file management ensures that any new files or structural changes on the primary are seamlessly replicated to the standby, maintaining consistency and minimizing manual intervention.

SQL> ALTER SYSTEM SET STANDBY_FILE_MANAGEMENT='AUTO' SCOPE=BOTH;

System altered.

5. Configure the archive destinations for both the local primary and the remote standby on the primary database.

#For Primary
SQL> ALTER SYSTEM SET LOG_ARCHIVE_DEST_1='LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=PRIMCA' SCOPE=BOTH;

System altered.

#For Remote Standby
SQL> ALTER SYSTEM SET LOG_ARCHIVE_DEST_2='SERVICE=STDBYCA ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=STDBYCA' SCOPE=BOTH;

System altered.

6.Verify Primary Online Redo Logs 

SQL>set linesize 300
SQL>column REDOLOG_FILE_NAME format a70
SQL>SELECT
    a.GROUP#,
    a.THREAD#,
    a.SEQUENCE#,
    a.ARCHIVED,
    a.STATUS,
    b.MEMBER    AS REDOLOG_FILE_NAME,
    (a.BYTES/1024/1024) AS SIZE_MB
FROM v$log a
JOIN v$logfile b ON a.Group#=b.Group#
ORDER BY a.GROUP# ASC;

    GROUP#    THREAD#  SEQUENCE# ARC STATUS           REDOLOG_FILE_NAME                                                         SIZE_MB
---------- ---------- ---------- --- ---------------- ---------------------------------------------------------------------- ----------
         5          1          1 YES INACTIVE         +DATA/PRIMCA/ONLINELOG/group_5.308.1243061391                                 200
         5          1          1 YES INACTIVE         +REDO/PRIMCA/ONLINELOG/group_5.309.1243061397                                 200
         6          1          2 NO  CURRENT          +DATA/PRIMCA/ONLINELOG/group_6.309.1243061405                                 200
         6          1          2 NO  CURRENT          +REDO/PRIMCA/ONLINELOG/group_6.310.1243061413                                 200
         7          1          0 YES UNUSED           +DATA/PRIMCA/ONLINELOG/group_7.310.1243061419                                 200
         7          1          0 YES UNUSED           +REDO/PRIMCA/ONLINELOG/group_7.311.1243061427                                 200
         8          1          0 YES UNUSED           +DATA/PRIMCA/ONLINELOG/group_8.311.1243061433                                 200
         8          1          0 YES UNUSED           +REDO/PRIMCA/ONLINELOG/group_8.312.1243061439                                 200


7. Create Standby Redo Logs (SRLs)
Standby Redo Logs (SRLs) are essential for real-time apply in Oracle Data Guard. They allow the standby to receive redo directly from the primary and apply it immediately, without waiting for archived logs. This improves synchronization, reduces apply lag, and is essential for Active Data Guard and fast role transitions.
SRLs must be configured with one more log group than the number of online redo log groups on the primary. This ensures smooth log switching and uninterrupted redo transport during periods of high activity.

Formula:  
SRL count = ORL (online redo log groups) + 1

In my setup, the primary database has 4 online redo log groups, so the recommended number of SRLs is 5 (ORL + 1). I created 6 SRL groups, which is fully acceptable and provides additional flexibility during high redo activity.

SQL>SELECT
    a.GROUP#,
    a.THREAD#,
    a.SEQUENCE#,
    a.ARCHIVED,
    a.STATUS,
    b.MEMBER    AS STANDBY_REDOLOG_FILE_NAME,
   (a.BYTES/1024/1024) AS SIZE_MB
FROM v$standby_log a
JOIN v$logfile b ON a.Group#=b.Group#
ORDER BY a.GROUP# ASC; 

    GROUP#    THREAD#  SEQUENCE# ARC STATUS     STANDBY_REDOLOG_FILE_NAME                                                 SIZE_MB
---------- ---------- ---------- --- ---------- ---------------------------------------------------------------------- ----------
        10          1          0 YES UNASSIGNED +DATA/PRIMCA/ONLINELOG/group_10.291.1243061563                                200
        10          1          0 YES UNASSIGNED +REDO/PRIMCA/ONLINELOG/group_10.313.1243061569                                200
        11          1          0 YES UNASSIGNED +DATA/PRIMCA/ONLINELOG/group_11.289.1243061577                                200
        11          1          0 YES UNASSIGNED +REDO/PRIMCA/ONLINELOG/group_11.314.1243061585                                200
        12          1          0 YES UNASSIGNED +DATA/PRIMCA/ONLINELOG/group_12.312.1243061591                                200
        12          1          0 YES UNASSIGNED +REDO/PRIMCA/ONLINELOG/group_12.315.1243061599                                200
        13          1          0 YES UNASSIGNED +DATA/PRIMCA/ONLINELOG/group_13.313.1243061607                                200
        13          1          0 YES UNASSIGNED +REDO/PRIMCA/ONLINELOG/group_13.316.1243061613                                200
        14          1          0 YES UNASSIGNED +DATA/PRIMCA/ONLINELOG/group_14.314.1243061621                                200
        14          1          0 YES UNASSIGNED +REDO/PRIMCA/ONLINELOG/group_14.317.1243061629                                200
        15          1          0 YES UNASSIGNED +DATA/PRIMCA/ONLINELOG/group_15.315.1243061635                                200
        15          1          0 YES UNASSIGNED +REDO/PRIMCA/ONLINELOG/group_15.318.1243061643                                200



8. Copy Password File from Primary to Standby
scp -i ~/.ssh/pr.key /u01/app/19.3.0/db/dbs/orapwPRIMCA oracle@<StandbyIP>:/u01/app/19.3.0/db/dbs/orapwSTDBYCA


9. Create TNS Entries in both primary and standby servers

PRIMCA =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <Primary Hostname>)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PRIMCA)
    )
  )

STDBYCA =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <Standby Hostname>)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = STDBYCA)
    )
  )

10. Create static listener entries on the standby server to associate the standby database service STDBYCA with the standby Oracle home and instance.

vi /u01/app/19.3.0/grid/network/admin/listener.ora

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
        (GLOBAL_DBNAME = STDBYCA)
        (ORACLE_HOME = /u01/app/19.3.0/db)
        (SID_NAME = STDBYCA)
     )
  )

11. Test connectivity between the primary and standby databases in both directions using TNSPing & SQL*Plus

#Primary -> Connection from Primary to Standby is Good
[oracle@caoradb04 ~]$ tnsping stdbyca

TNS Ping Utility for Linux: Version 19.0.0.0.0 - Production on 17-SEP-2026 14:07:18

Copyright (c) 1997, 2026, Oracle.  All rights reserved.

Used parameter files:


Used TNSNAMES adapter to resolve the alias
Attempting to contact (DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = <Standby_Hostname>)(PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SERVICE_NAME = STDBYCA)))
OK (0 msec)
[oracle@caoradb04 ~]$ sqlplus sys/<SYS_PASSWORD>@STDBYCA as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Thu Sep 17 14:10:37 2026
Version 19.32.0.0.0

Copyright (c) 1982, 2026, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.32.0.0.0

SQL> define
DEFINE _DATE           = "17-SEP-26" (CHAR)
DEFINE _CONNECT_IDENTIFIER = "STDBYCA" (CHAR)
DEFINE _USER           = "SYS" (CHAR)
DEFINE _PRIVILEGE      = "AS SYSDBA" (CHAR)
DEFINE _SQLPLUS_RELEASE = "1932000000" (CHAR)
DEFINE _EDITOR         = "vi" (CHAR)
DEFINE _O_VERSION      = "Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.32.0.0.0" (CHAR)
DEFINE _O_RELEASE      = "1932000000" (CHAR)


#Standby -> Connection from Standby to Primary is Good
[oracle@caoradb05 ~]$ tnsping primca

TNS Ping Utility for Linux: Version 19.0.0.0.0 - Production on 17-SEP-2026 14:10:55

Copyright (c) 1997, 2026, Oracle.  All rights reserved.

Used parameter files:


Used TNSNAMES adapter to resolve the alias
Attempting to contact (DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = <Primary_Hostname>)(PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SERVICE_NAME = PRIMCA)))
OK (0 msec)
[oracle@caoradb05 ~]$ sqlplus sys/<SYS_PASSWORD>@PRIMCA as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Thu Sep 17 14:11:05 2026
Version 19.32.0.0.0

Copyright (c) 1982, 2026, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.32.0.0.0

SQL> define
DEFINE _DATE           = "17-SEP-26" (CHAR)
DEFINE _CONNECT_IDENTIFIER = "PRIMCA" (CHAR)
DEFINE _USER           = "SYS" (CHAR)
DEFINE _PRIVILEGE      = "AS SYSDBA" (CHAR)
DEFINE _SQLPLUS_RELEASE = "1932000000" (CHAR)
DEFINE _EDITOR         = "vi" (CHAR)
DEFINE _O_VERSION      = "Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.32.0.0.0" (CHAR)
DEFINE _O_RELEASE      = "1932000000" (CHAR)
SQL> exit

12. Create Primary PFile for Standby 

SQL> create pfile='/u01/app/oracle/dba/initprim.ora' from spfile;

File created.

SQL> ho cat /u01/app/oracle/dba/initprim.ora
PRIMCA.__data_transfer_cache_size=0
PRIMCA.__db_cache_size=4194304000
PRIMCA.__inmemory_ext_roarea=0
PRIMCA.__inmemory_ext_rwarea=0
PRIMCA.__java_pool_size=0
PRIMCA.__large_pool_size=67108864
PRIMCA.__oracle_base='/u01/app/oracle'#ORACLE_BASE set from environment
PRIMCA.__pga_aggregate_target=536870912
PRIMCA.__sga_target=5368709120
PRIMCA.__shared_io_pool_size=134217728
PRIMCA.__shared_pool_size=922746880
PRIMCA.__streams_pool_size=33554432
PRIMCA.__unified_pga_pool_size=0
*.audit_file_dest='/u01/app/oracle/admin/PRIMCA/adump'
*.audit_trail='db'
*.compatible='19.0.0'
*.control_files='+DATA/PRIMCA/CONTROLFILE/current.288.1243050511'
*.db_block_size=8192
*.db_create_file_dest='+DATA'
*.db_create_online_log_dest_1='+DATA'
*.db_name='PRIMCA'
*.db_recovery_file_dest='+REDO'
*.db_recovery_file_dest_size=20g
*.diagnostic_dest='/u01/app/oracle'
*.dispatchers='(PROTOCOL=TCP) (SERVICE=PRIMCAXDB)'
*.enable_pluggable_database=true
*.local_listener='LISTENER_PRIMCA'
*.log_archive_config='dg_config=(PRIMCA,STDBYCA)'
*.log_archive_dest_1='location=use_db_recovery_file_dest valid_for=(all_logfiles,all_roles) db_unique_name=PRIMCA'
*.log_archive_dest_2='service=STDBYCA async valid_for=(online_logfiles,primary_role) db_unique_name=STDBYCA'
*.log_archive_format='%t_%s_%r.dbf'
*.nls_language='ENGLISH'
*.nls_territory='AMERICA'
*.open_cursors=300
*.pga_aggregate_target=512m
*.processes=300
*.remote_login_passwordfile='EXCLUSIVE'
*.sga_target=5g
*.standby_file_management='AUTO'
*.undo_tablespace='UNDOTBS1'

************************************************************************************************************************************************************************************************
																						Prepare Standby Server
************************************************************************************************************************************************************************************************

13. Make the necessary changes to the Primary PFILE on the Standby Server so that it can be used as the Standby PFILE.

[oracle@caoradb05 chakri]$ cat initstdbyca.ora
*.audit_file_dest='/u01/app/oracle/admin/STDBYCA/adump'
*.audit_trail='db'
*.compatible='19.0.0'
*.control_files='+DATA/STDBYCA/CONTROLFILE/current.288.1243050511'
*.db_block_size=8192
*.db_create_file_dest='+DATA'
*.db_create_online_log_dest_1='+DATA'
*.db_name='PRIMCA'
*.db_unique_name='STDBYCA'
*.db_recovery_file_dest='+REDO'
*.db_recovery_file_dest_size=20g
*.diagnostic_dest='/u01/app/oracle'
*.dispatchers='(PROTOCOL=TCP) (SERVICE=STDBYCAXDB)'
*.enable_pluggable_database=true
*.log_archive_config='dg_config=(PRIMCA,STDBYCA)'
*.log_archive_dest_1='location=use_db_recovery_file_dest valid_for=(all_logfiles,all_roles) db_unique_name=STDBYCA'
*.log_archive_dest_2='service=PRIMCA async valid_for=(online_logfiles,primary_role) db_unique_name=PRIMCA'
*.log_archive_format='%t_%s_%r.dbf'
*.nls_language='ENGLISH'
*.nls_territory='AMERICA'
*.open_cursors=300
*.pga_aggregate_target=512m
*.processes=300
*.remote_login_passwordfile='EXCLUSIVE'
*.sga_target=5g
*.standby_file_management='AUTO'
*.undo_tablespace='UNDOTBS1'

14. Create audit directory in Standby Server

mkdir -p /u01/app/oracle/admin/STDBYCA/adump

15. Start the Standby Database in NOMOUNT

The ORACLE_SID is defined in the .bash_profile, ensuring it is automatically exported each time the oracle user logs in. On servers hosting multiple databases, you can set the preferred SID in the .bash_profile and manually load additional SIDs when required.

[oracle@caoradb05 ~]$ echo $ORACLE_SID
STDBYCA
[oracle@caoradb05 ~]$ echo $ORACLE_HOME
/u01/app/19.3.0/db

16. Create SPFILE from pfile and start the database in NOMOUNT mode.

SQL> conn /as sysdba
Connected to an idle instance.
SQL> CREATE SPFILE FROM PFILE='/u01/app/oracle/dba/initstdbyca.ora';

File created.

SQL> startup nomount;
ORACLE instance started.

Total System Global Area 5368706880 bytes
Fixed Size                  9189184 bytes
Variable Size             989855744 bytes
Database Buffers         4362076160 bytes
Redo Buffers                7585792 bytes
SQL> exit


#Because the standby is being built through Active Duplicate from the primary database, we do not need to restore control files or use backup directories during the setup.
#I created the RMAN command script along with an execution script, then executed it using nohup. Using nohup ensures the process runs in the background and remains unaffected by any network disconnections.
17. RMAN Command script rman_command.cmd

run
{
  allocate channel c1 type disk;
  allocate channel c2 type disk;
  allocate channel c3 type disk;
  allocate channel c4 type disk;
  allocate auxiliary channel stby1 type disk;
  allocate auxiliary channel stby2 type disk;
  allocate auxiliary channel stby3 type disk;
  allocate auxiliary channel stby4 type disk;
  allocate auxiliary channel stby5 type disk;
  allocate auxiliary channel stby6 type disk;
  allocate auxiliary channel stby7 type disk;
  allocate auxiliary channel stby8 type disk;
  allocate auxiliary channel stby9 type disk;
  allocate auxiliary channel stby10 type disk;
  DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE NOFILENAMECHECK;
}

18. RMAN Execution 
[oracle@caoradb05 chakri]$ rman target sys/<SYS_PASSWORD>@PRIMCA cmdfile=rman_command.cmd log=rman_stndby_restore.log auxiliary sys/<SYS_PASSWORD>@STDBYCA

19. Monitor the RMAN Restore Log
I’ve filtered the Restore Log to show the first 30 lines (using head -30) and the last 20 lines (using tail -20).

Recovery Manager: Release 19.0.0.0.0 - Production on Fri Sep 4 07:15:32 2026
Version 19.32.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

connected to target database: PRIMCA (DBID=359333451)
connected to auxiliary database: PRIMCA (not mounted)

RMAN> run
2> {
3>   allocate channel c1 type disk;
4>   allocate channel c2 type disk;
5>   allocate channel c3 type disk;
6>   allocate channel c4 type disk;
7>   allocate auxiliary channel stby1 type disk;
8>   allocate auxiliary channel stby2 type disk;
9>   allocate auxiliary channel stby3 type disk;
10>   allocate auxiliary channel stby4 type disk;
11>   allocate auxiliary channel stby5 type disk;
12>   allocate auxiliary channel stby6 type disk;
13>   allocate auxiliary channel stby7 type disk;
14>   allocate auxiliary channel stby8 type disk;
15>   allocate auxiliary channel stby9 type disk;
16>   allocate auxiliary channel stby10 type disk;
17>   DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE NOFILENAMECHECK;
18> }
19>
using target database control file instead of recovery catalog
allocated channel: c1
............................
............................
input datafile copy RECID=23 STAMP=1243063223 file name=+DATA/STDBYCA/5AA1EFD5649DCE61E063D100000A1B83/DATAFILE/users.299.1243063085
datafile 13 switched to datafile copy
input datafile copy RECID=24 STAMP=1243063223 file name=+DATA/STDBYCA/5AA1EFD5649DCE61E063D100000A1B83/DATAFILE/host_ops.298.1243063087
Finished Duplicate Db at 04-SEP-26
released channel: c1
released channel: c2
released channel: c3
released channel: c4
released channel: stby1
released channel: stby2
released channel: stby3
released channel: stby4
released channel: stby5
released channel: stby6
released channel: stby7
released channel: stby8
released channel: stby9
released channel: stby10

Recovery Manager complete.

20. Verify Primary and Standby Database Views

#Primary
SQL> set line 200
select name, db_unique_name, database_role, open_mode, protection_mode, FORCE_LOGGING FROM gV$DATABASE;
SQL>
NAME      DB_UNIQUE_NAME                 DATABASE_ROLE    OPEN_MODE            PROTECTION_MODE      FORCE_LOGGING                           
--------- ------------------------------ ---------------- -------------------- -------------------- ---------------------------------------
PRIMCA    PRIMCA                         PRIMARY          READ WRITE           MAXIMUM PERFORMANCE  YES                                    


#Standby
SQL> set line 200
select name, db_unique_name, database_role, open_mode, protection_mode, FORCE_LOGGING FROM gV$DATABASE;
SQL>
NAME      DB_UNIQUE_NAME                 DATABASE_ROLE    OPEN_MODE            PROTECTION_MODE      FORCE_LOGGING                          
--------- ------------------------------ ---------------- -------------------- -------------------- ---------------------------------------
PRIMCA    STDBYCA                        PHYSICAL STANDBY MOUNTED              MAXIMUM PERFORMANCE  YES                                    


21. Start the Managed Recovery Process

SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;

22. Monitor the archive destination to identify any errors during redo transmission. Any problems will be logged in this view.

col DESTINATION format a35
col ERROR format a65
set lines 200
SELECT DESTINATION, ERROR FROM V$ARCHIVE_DEST ;
DESTINATION                         ERROR
----------------------------------- -----------------------------------------------------------------
USE_DB_RECOVERY_FILE_DEST
STDBYCA


23. Monitor the archive logs being generated and transmitted to verify that redo data is flowing properly between the primary and standby.
#Primary
SQL> SELECT PROCESS, PID, STATUS, SEQUENCE#, BLOCKS, BLOCK#, THREAD# FROM V$MANAGED_STANDBY where status not in ('IDLE','CONNECTED');

PROCESS   PID                      STATUS        SEQUENCE#     BLOCKS     BLOCK#    THREAD#
--------- ------------------------ ------------ ---------- ---------- ---------- ----------
DGRD      183615                   ALLOCATED             0          0          0          0
ARCH      183617                   CLOSING             120          5          1          1
DGRD      183619                   ALLOCATED             0          0          0          0
ARCH      183621                   CLOSING             122       9782          1          1
ARCH      183623                   CLOSING             114        804      90112          1
ARCH      183625                   CLOSING             123        211          1          1
DGRD      183627                   ALLOCATED             0          0          0          0
LNS       220535                   WRITING             124          1        708          1
LNS       223342                   WRITING             124          4       1396          1
DGRD      205429                   ALLOCATED             0          0          0          0

10 rows selected.

#Standby
SQL> SELECT PROCESS, PID, STATUS, SEQUENCE#, BLOCKS, BLOCK#, THREAD# FROM V$MANAGED_STANDBY where status not in ('IDLE','CONNECTED');

PROCESS   PID                      STATUS        SEQUENCE#     BLOCKS     BLOCK#    THREAD#
--------- ------------------------ ------------ ---------- ---------- ---------- ----------
DGRD      26074                    ALLOCATED             0          0          0          0
DGRD      26076                    ALLOCATED             0          0          0          0
ARCH      26080                    CLOSING             123        211          1          1
MRP0      28974                    APPLYING_LOG        124     409600        321          1


24. Manual Switch of Logs.
#By manually switching logs on the primary, we can confirm whether every generated redo log is being transmitted to the standby.
#Before Swith the last log that's writting is 124

#From Standby 124 has been received and apply is going on 
SQL> SELECT ROLE, THREAD#, SEQUENCE#, ACTION FROM V$DATAGUARD_PROCESS;

ROLE                        THREAD#  SEQUENCE# ACTION
------------------------ ---------- ---------- ------------
post role transition              0          0 IDLE
RFS async                         1        124 IDLE
archive redo                      0          0 IDLE
archive redo                      0          0 IDLE
archive redo                      0          0 IDLE
recovery apply slave              0          0 APPLYING_LOG
RFS ping                          1        124 IDLE
redo transport timer              0          0 IDLE
managed recovery                  0          0 IDLE
RFS archive                       0          0 IDLE
archive local                     0          0 IDLE

ROLE                        THREAD#  SEQUENCE# ACTION
------------------------ ---------- ---------- ------------
recovery apply slave              0          0 APPLYING_LOG
recovery apply slave              0          0 APPLYING_LOG
gap manager                       0          0 IDLE
recovery apply slave              0          0 APPLYING_LOG
redo transport monitor            0          0 IDLE
log writer                        0          0 IDLE
recovery logmerger                1        124 APPLYING_LOG
recovery apply slave              0          0 APPLYING_LOG
recovery apply slave              0          0 APPLYING_LOG
recovery apply slave              0          0 APPLYING_LOG
recovery apply slave              0          0 APPLYING_LOG

22 rows selected.


SQL> alter system switch logfile;

System altered.

SQL> /

System altered.

#After couple of switches the 

SQL> SELECT PROCESS, PID, STATUS, SEQUENCE#, BLOCKS, BLOCK#, THREAD# FROM V$MANAGED_STANDBY where status not in ('IDLE','CONNECTED');

PROCESS   PID                      STATUS        SEQUENCE#     BLOCKS     BLOCK#    THREAD#
--------- ------------------------ ------------ ---------- ---------- ---------- ----------
DGRD      183615                   ALLOCATED             0          0          0          0
ARCH      183617                   CLOSING             125          6          1          1
DGRD      183619                   ALLOCATED             0          0          0          0
ARCH      183621                   CLOSING             122       9782          1          1
ARCH      183623                   CLOSING             114        804      90112          1
ARCH      183625                   CLOSING             124       1410          1          1
DGRD      183627                   ALLOCATED             0          0          0          0
LNS       220535                   WRITING             126          1          6          1
DGRD      205429                   ALLOCATED             0          0          0          0

9 rows selected.


#From Standby 126 has been received and it's applying
SQL> /

PROCESS   PID                      STATUS        SEQUENCE#     BLOCKS     BLOCK#    THREAD#
--------- ------------------------ ------------ ---------- ---------- ---------- ----------
ARCH      38647                    CLOSING             125          6          1          1
DGRD      38649                    ALLOCATED             0          0          0          0
DGRD      38651                    ALLOCATED             0          0          0          0
ARCH      38657                    CLOSING             124       1410          1          1
MRP0      39289                    APPLYING_LOG        126     409600         11          1


25. Verify Primary and Standby Database View for the Swithover Status column

SQL> set line 200
select name, db_unique_name, database_role, open_mode, protection_mode, FORCE_LOGGING, SWITCHOVER_STATUS FROM gV$DATABASE;
SQL>
NAME      DB_UNIQUE_NAME                 DATABASE_ROLE    OPEN_MODE            PROTECTION_MODE      FORCE_LOGGING                           SWITCHOVER_STATUS
--------- ------------------------------ ---------------- -------------------- -------------------- --------------------------------------- --------------------
PRIMCA    PRIMCA                         PRIMARY          READ WRITE           MAXIMUM PERFORMANCE  YES                                     TO STANDBY


SQL> set line 200
select name, db_unique_name, database_role, open_mode, protection_mode, FORCE_LOGGING, SWITCHOVER_STATUS FROM gV$DATABASE;
SQL>
NAME      DB_UNIQUE_NAME                 DATABASE_ROLE    OPEN_MODE            PROTECTION_MODE      FORCE_LOGGING                           SWITCHOVER_STATUS
--------- ------------------------------ ---------------- -------------------- -------------------- --------------------------------------- --------------------
PRIMCA    STDBYCA                        PHYSICAL STANDBY MOUNTED              MAXIMUM PERFORMANCE  YES                                     TO PRIMARY




26. Monitor the Data Guard status for any transport or apply lag. In this environment, the database size and low workload ensure faster log switching and redo transfer, so lag is typically minimal.

SQL> COLUMN NAME FORMAT a20
SQL> COLUMN VALUE FORMAT a30
SQL> SELECT NAME, VALUE FROM V$DATAGUARD_STATS WHERE NAME LIKE '%lag%';

no rows selected

SQL> alter system switch logfile
  2  ;

System altered.

SQL> COLUMN NAME FORMAT a20
SQL> COLUMN VALUE FORMAT a30
SQL> SELECT NAME, VALUE FROM V$DATAGUARD_STATS WHERE NAME LIKE '%lag%';

no rows selected

SQL> /

27. Migrating the Standby SPFILE from Filesystem to ASM

SQL> show parameter spfile

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
spfile                               string      /u01/app/19.3.0/db/dbs/spfileS
                                                 TDBYCA.ora

SQL> create pfile='/u01/app/oracle/dba/initSTDBYCA.ora' from spfile;

File created.

SQL> host mv /u01/app/19.3.0/db/dbs/spfileSTDBYCA.ora /u01/app/19.3.0/db/dbs/spfileSTDBYCA.orabkp

SQL> create spfile='+DATA/STDBYCA/spfileSTDBYCA.ora' from pfile='/u01/app/oracle/dba/initSTDBYCA.ora';

File created.

SQL> host echo SPFILE='+DATA/STDBYCA/spfileSTDBYCA.ora' > /u01/app/19.3.0/db/dbs/initSTDBYCA.ora

SQL> startup mount;
ORACLE instance started.

Total System Global Area 5368706880 bytes
Fixed Size                  9189184 bytes
Variable Size             989855744 bytes
Database Buffers         4362076160 bytes
Redo Buffers                7585792 bytes
Database mounted.

SQL> show parameter spfile

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
spfile                               string      +DATA/STDBYCA/spfilestdbyca.or
                                                 a

28. Register the standby database as a resource in the Oracle Clusterware.
[oracle@caoradb05 ~]$ $ORACLE_HOME/bin/srvctl add database -d STDBYCA -o $ORACLE_HOME -p '+DATA/STDBYCA/spfileSTDBYCA.ora' -r physical_standby -s mount -y AUTOMATIC -a "DATA,REDO,FRA"
[oracle@caoradb05 ~]$ $ORACLE_HOME/bin/srvctl modify database -d STDBYCA -startoption "READ ONLY"
[oracle@caoradb05 ~]$ $ORACLE_HOME/bin/srvctl config database -d STDBYCA
Database unique name: STDBYCA
Database name:
Oracle home: /u01/app/19.3.0/db
Oracle user: oracle
Spfile: +DATA/STDBYCA/spfileSTDBYCA.ora
Password file:
Domain:
Start options: read only
Stop options: immediate
Database role: PHYSICAL_STANDBY
Management policy: AUTOMATIC
Disk Groups: DATA,REDO,FRA
Services:
OSDBA group: oinstall
OSOPER group:
Database instance: STDBYCA

#Manually shut down the database before performing start or stop operations through SRVCTL.
SQL> shutdown immediate
ORA-01109: database not open


Database dismounted.
ORACLE instance shut down.

29. Start the Database using SRVCTL
[oracle@caoradb05 ~]$ srvctl start database -d STDBYCA

SQL> set line 200
select name, db_unique_name, database_role, open_mode, protection_mode, FORCE_LOGGING, SWITCHOVER_STATUS FROM gV$DATABASE;SQL>

NAME      DB_UNIQUE_NAME                 DATABASE_ROLE    OPEN_MODE            PROTECTION_MODE      FORCE_LOGGING                           SWITCHOVER_STATUS
--------- ------------------------------ ---------------- -------------------- -------------------- --------------------------------------- --------------------
PRIMCA    STDBYCA                        PHYSICAL STANDBY READ ONLY            MAXIMUM PERFORMANCE  YES                                     NOT ALLOWED

30. Start the Recovery Proess
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;

Database altered.

31. Few Final Checks 

(a). Check the MRP Process
SQL> ho ps -ef | grep mrp
oracle     13137       1  0 03:15 ?        00:00:00 ora_mrp0_STDBYCA
oracle     14085   12906  0 03:26 pts/1    00:00:00 /bin/bash -c ps -ef | grep mrp
oracle     14087   14085  0 03:26 pts/1    00:00:00 grep mrp


SQL> set line 200
select name, db_unique_name, database_role, open_mode, protection_mode, FORCE_LOGGING, SWITCHOVER_STATUS FROM gV$DATABASE;SQL>

NAME      DB_UNIQUE_NAME                 DATABASE_ROLE    OPEN_MODE            PROTECTION_MODE      FORCE_LOGGING                           SWITCHOVER_STATUS
--------- ------------------------------ ---------------- -------------------- -------------------- --------------------------------------- --------------------
PRIMCA    STDBYCA                        PHYSICAL STANDBY READ ONLY WITH APPLY MAXIMUM PERFORMANCE  YES                                     NOT ALLOWED


(b). Check the Cluster resources

[oracle@caoradb05 ~]$ /u01/app/19.3.0/grid/bin/crsctl stat res -init -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               ONLINE  ONLINE       caoradb05                STABLE
ora.FRA.dg
               ONLINE  ONLINE       caoradb05                STABLE
ora.LISTENER.lsnr
               ONLINE  ONLINE       caoradb05                STABLE
ora.REDO.dg
               ONLINE  ONLINE       caoradb05                STABLE
ora.VOTK.dg
               ONLINE  ONLINE       caoradb05                STABLE
ora.asm
               ONLINE  ONLINE       caoradb05                Started,STABLE
ora.ons
               OFFLINE OFFLINE      caoradb05                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.cssd
      1        ONLINE  ONLINE       caoradb05                STABLE
ora.diskmon
      1        OFFLINE OFFLINE                               STABLE
ora.evmd
      1        ONLINE  ONLINE       caoradb05                STABLE
ora.stdbyca.db
      1        ONLINE  ONLINE       caoradb05                Open,Readonly,HOME=/
                                                             u01/app/19.3.0/db,ST
                                                             ABLE
--------------------------------------------------------------------------------