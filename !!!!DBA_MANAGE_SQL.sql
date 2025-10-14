--#########################################################
--##### SP_DBA_ACTIVESESSION
--#########################################################

SELECT A.*
FROM (
    SELECT
        GETDATE() AS COLLECTION_DATE,
        SPID = CONVERT(NUMERIC, S.SESSION_ID),
        DBNAME = DB_NAME(R.DATABASE_ID),
        LOGIN = RTRIM(S.LOGIN_NAME),
        CMD = RTRIM(R.COMMAND),
        ELAPSED_SEC = CONVERT(DEC(12,3), CONVERT(FLOAT, GETDATE() - R.START_TIME) * 86400),
        STATUS = CONVERT(NVARCHAR(30), R.STATUS),
        BLOCKED = R.BLOCKING_SESSION_ID,
		-- wait
        WAIT_TIME_SEC = R.WAIT_TIME / 1000,
        WAIT_TYPE = R.LAST_WAIT_TYPE,
        WAIT_RESOURCE = RTRIM(R.WAIT_RESOURCE),
		-- query
        SQL = SUBSTRING(S2.TEXT, STATEMENT_START_OFFSET / 2, 
            ((CASE WHEN STATEMENT_END_OFFSET = -1 THEN LEN(CONVERT(NVARCHAR(MAX), S2.TEXT)) * 2 
            ELSE STATEMENT_END_OFFSET END) - STATEMENT_START_OFFSET) / 2),
        PARENT_QUERY = ISNULL(S2.TEXT, ''),
		-- cpu, io
		CPU = R.CPU_TIME,
        LOGICAL_READ = R.LOGICAL_READS,
        PHYSICAL_IO = R.READS + R.WRITES,
		-- memory usage in MB
        M.REQUESTED_MEMORY_KB / 1024 AS REQUESTED_MEMORY_MB,
        M.GRANTED_MEMORY_KB / 1024 AS GRANTED_MEMORY_MB,
        M.USED_MEMORY_KB / 1024 AS USED_MEMORY_MB,
        M.MAX_USED_MEMORY_KB / 1024 AS MAX_USED_MEMORY_MB,
		-- tempdb usage in MB
        CAST(TSU.user_objects_alloc_page_count AS FLOAT) / 128 AS TEMPDB_USER_MB,
        CAST(TSU.internal_objects_alloc_page_count AS FLOAT) / 128 AS TEMPDB_INTERNAL_MB,
        R.DOP,        
        S.OPEN_TRANSACTION_COUNT AS OPEN_TRAN,
        LAST_BATCH = R.START_TIME,
        HOST_NAME = S.HOST_NAME,
        CLIENTIP = C.CLIENT_NET_ADDRESS,
        PROGRAM = LEFT(S.PROGRAM_NAME, 50),
        OBJECT_NAME = ISNULL(OBJECT_NAME(S2.OBJECTID), ''),
        R.SQL_HANDLE,
        R.PLAN_HANDLE        
    FROM SYS.DM_EXEC_SESSIONS S (NOLOCK)
    JOIN SYS.DM_EXEC_REQUESTS R (NOLOCK) ON S.SESSION_ID = R.SESSION_ID
    LEFT JOIN SYS.DM_EXEC_QUERY_MEMORY_GRANTS M ON S.SESSION_ID = M.SESSION_ID
    OUTER APPLY SYS.DM_EXEC_SQL_TEXT(R.SQL_HANDLE) S2
    JOIN SYS.DM_EXEC_CONNECTIONS C ON S.SESSION_ID = C.SESSION_ID
    LEFT JOIN SYS.DM_DB_SESSION_SPACE_USAGE TSU ON S.SESSION_ID = TSU.session_id
) A
ORDER BY SPID;


--#########################################################
--##### 세션 모니터링, WHILE
--#########################################################
WHILE 1=1
BEGIN
	EXEC SP_DBA_ACTIVESESSION1
	waitfor delay '0:0:4:0'
END

--#########################################################
--##### 현재 락 LOCK 정보 확인, 트랜잭션 TRANSACTION 확인
--#########################################################
SELECT SESSION_ID AS [SESSION_ID]
     , WAIT_TYPE 
	 , BLOCKING_SESSION_ID
	 , WAIT_TIME / 1000 AS [WAIT_TIME_SEC]
	 , ST.TEXT AS [QUERY]
  FROM SYS.DM_EXEC_REQUESTS AS ER
 CROSS APPLY SYS.DM_EXEC_SQL_TEXT(ER.SQL_HANDLE) AS ST
 WHERE ER.SESSION_ID > 50
   AND ER.WAIT_TIME > 1000 -- 1초 이상 차단
GO


-- WAIT_RESOURCE
- TAB: 5:261575970:1 = DATABASE_ID:OBJECT_ID:1(CLUSTERED INDEX)
> 오브젝트명 확인 방법 
> OBJECT_NAME(OBJECT_ID, DATABASE_ID)
> 예) OBJECT_NAME(261575970,5)

- PAGE: 5:1:104 = DATABASE_ID:FILE_ID:PAGE_ID
> 오브젝트명 확인 방법 
> SELECT OBJECT_NAME(OBJECT_ID, DATABASE_ID) FROM sys.dm_db_page_info(DATABASE_ID, FILE_ID, PAGE_ID,'DETAILED')
> 예) SELECT OBJECT_NAME(OBJECT_ID,DATABASE_ID) FROM sys.dm_db_page_info(5,1,8552,'DETAILED')

- RID: 5:1:104:3 = DATABASE_ID:FILE_ID:PAGE_ID:SLOT_ID
> 상동

WITH cteBL (session_id, blocking_these) AS 
(SELECT s.session_id, blocking_these = x.blocking_these FROM sys.dm_exec_sessions s 
CROSS APPLY    (SELECT isnull(convert(varchar(6), er.session_id),'') + ', '  
                FROM sys.dm_exec_requests as er
                WHERE er.blocking_session_id = isnull(s.session_id ,0)
                AND er.blocking_session_id <> 0
                FOR XML PATH('') ) AS x (blocking_these)
)
SELECT s.session_id
, blocked_by = r.blocking_session_id
, bl.blocking_these
--, T.TEXT
, IB.event_info
, S.SESSION_ID
, S.STATUS
, R.WAIT_TYPE
, R.WAIT_RESOURCE
, R.WAIT_TIME
, S.LOGIN_NAME
, S.LOGIN_TIME
, S.HOST_NAME
, S.PROGRAM_NAME
, S.NT_USER_NAME
, S.CPU_TIME
, S.MEMORY_USAGE
, S.TOTAL_ELAPSED_TIME
, R.TOTAL_ELAPSED_TIME 
, S.transaction_isolation_level
, S.lock_timeout
, S.LAST_REQUEST_START_TIME
, S.LAST_REQUEST_END_TIME
, S.READS
, S.WRITES
, S.LOGICAL_READS
, S.IS_USER_PROCESS
, S.ROW_COUNT
, S.DATABASE_ID
, S.OPEN_TRANSACTION_COUNT
, R.START_TIME
, R.COMMAND
, R.STATEMENT_START_OFFSET
, R.STATEMENT_END_OFFSET
--, * 
FROM sys.dm_exec_sessions s 
LEFT OUTER JOIN sys.dm_exec_requests r 
on r.session_id = s.session_id
INNER JOIN cteBL as bl 
on s.session_id = bl.session_id
OUTER APPLY sys.dm_exec_sql_text (r.sql_handle) t
OUTER APPLY sys.dm_exec_input_buffer(s.session_id, NULL) AS ib
WHERE blocking_these is not null or r.blocking_session_id > 0
ORDER BY len(bl.blocking_these) desc, r.blocking_session_id desc, r.session_id
GO



SELECT RESOURCE_TYPE
, DB_NAME
, OBJECT_NAME
, CASE WHEN FILE_ID IS NOT NULL AND FILE_ID <> '' THEN 'SELECT OBJECT_NAME(OBJECT_ID, DATABASE_ID) OBJECT_NAME FROM sys.dm_db_page_info('+CONVERT(VARCHAR,RESOURCE_DATABASE_ID)+','+FILE_ID+','+PAGE_ID+',''DETAILED'')'  ELSE '' END AS dm_db_page_info
--, RESOURCE_DATABASE_ID DB_ID
--, FILE_ID
--, PAGE_ID
, REQUEST_MODE
, REQUEST_TYPE
, REQUEST_STATUS
, REQUEST_REFERENCE_COUNT
, REQUEST_SESSION_ID
, REQUEST_OWNER_TYPE
, REQUEST_OWNER_ID
, '================'
--, CASE WHEN FILE_ID IS NOT NULL AND FILE_ID <> '' THEN 'sys.dm_db_page_info('+CONVERT(VARCHAR,RESOURCE_DATABASE_ID)+','+FILE_ID+','+PAGE_ID+',''DETAILED'')'  ELSE '' END AS dm_db_page_info
FROM (SELECT RESOURCE_TYPE
, DB_NAME(RESOURCE_DATABASE_ID) AS DB_NAME
, CASE WHEN RESOURCE_TYPE='OBJECT' THEN OBJECT_NAME(RESOURCE_ASSOCIATED_ENTITY_ID, RESOURCE_DATABASE_ID)
       ELSE '' END OBJECT_NAME
, RESOURCE_DATABASE_ID
, RESOURCE_DESCRIPTION
, CASE WHEN RESOURCE_TYPE='PAGE' THEN TRIM(SUBSTRING(RESOURCE_DESCRIPTION,1,CHARINDEX(':',RESOURCE_DESCRIPTION)-1))
       WHEN RESOURCE_TYPE='RID' THEN TRIM(SUBSTRING(RESOURCE_DESCRIPTION,1,CHARINDEX(':',RESOURCE_DESCRIPTION)-1))
  ELSE '' END AS FILE_ID
, CASE WHEN RESOURCE_TYPE='PAGE' THEN TRIM(SUBSTRING(RESOURCE_DESCRIPTION,CHARINDEX(':',RESOURCE_DESCRIPTION)+1,99))
       WHEN RESOURCE_TYPE='RID' THEN TRIM(SUBSTRING(RESOURCE_DESCRIPTION,CHARINDEX(':',RESOURCE_DESCRIPTION)+1,CHARINDEX(':',RESOURCE_DESCRIPTION,CHARINDEX(':',RESOURCE_DESCRIPTION)+1)-CHARINDEX(':',RESOURCE_DESCRIPTION)-1))
  ELSE '' END AS PAGE_ID
, RESOURCE_ASSOCIATED_ENTITY_ID
, REQUEST_MODE
, REQUEST_TYPE
, REQUEST_STATUS
, REQUEST_REFERENCE_COUNT
, REQUEST_SESSION_ID
, REQUEST_OWNER_TYPE
, REQUEST_OWNER_ID
FROM sys.dm_tran_locks) DTL
WHERE REQUEST_MODE NOT IN ('S')
GO


WITH cteHead ( session_id,request_id,wait_type,wait_resource,last_wait_type,is_user_process,request_cpu_time
,request_logical_reads,request_reads,request_writes,wait_time,blocking_session_id,memory_usage
,session_cpu_time,session_reads,session_writes,session_logical_reads
,percent_complete,est_completion_time,request_start_time,request_status,command
,plan_handle,sql_handle,statement_start_offset,statement_end_offset,most_recent_sql_handle
,session_status,group_id,query_hash,query_plan_hash) 
AS ( SELECT sess.session_id, req.request_id, LEFT (ISNULL (req.wait_type, ''), 50) AS 'wait_type'
    , LEFT (ISNULL (req.wait_resource, ''), 40) AS 'wait_resource', LEFT (req.last_wait_type, 50) AS 'last_wait_type'
    , sess.is_user_process, req.cpu_time AS 'request_cpu_time', req.logical_reads AS 'request_logical_reads'
    , req.reads AS 'request_reads', req.writes AS 'request_writes', req.wait_time, req.blocking_session_id,sess.memory_usage
    , sess.cpu_time AS 'session_cpu_time', sess.reads AS 'session_reads', sess.writes AS 'session_writes', sess.logical_reads AS 'session_logical_reads'
    , CONVERT (decimal(5,2), req.percent_complete) AS 'percent_complete', req.estimated_completion_time AS 'est_completion_time'
    , req.start_time AS 'request_start_time', LEFT (req.status, 15) AS 'request_status', req.command
    , req.plan_handle, req.[sql_handle], req.statement_start_offset, req.statement_end_offset, conn.most_recent_sql_handle
    , LEFT (sess.status, 15) AS 'session_status', sess.group_id, req.query_hash, req.query_plan_hash
    FROM sys.dm_exec_sessions AS sess
    LEFT OUTER JOIN sys.dm_exec_requests AS req ON sess.session_id = req.session_id
    LEFT OUTER JOIN sys.dm_exec_connections AS conn on conn.session_id = sess.session_id 
    )
, cteBlockingHierarchy (head_blocker_session_id, session_id, blocking_session_id, wait_type, wait_duration_ms,
wait_resource, statement_start_offset, statement_end_offset, plan_handle, sql_handle, most_recent_sql_handle, [Level])
AS ( SELECT head.session_id AS head_blocker_session_id, head.session_id AS session_id, head.blocking_session_id
    , head.wait_type, head.wait_time, head.wait_resource, head.statement_start_offset, head.statement_end_offset
    , head.plan_handle, head.sql_handle, head.most_recent_sql_handle, 0 AS [Level]
    FROM cteHead AS head
    WHERE (head.blocking_session_id IS NULL OR head.blocking_session_id = 0)
    AND head.session_id IN (SELECT DISTINCT blocking_session_id FROM cteHead WHERE blocking_session_id != 0)
    UNION ALL
    SELECT h.head_blocker_session_id, blocked.session_id, blocked.blocking_session_id, blocked.wait_type,
    blocked.wait_time, blocked.wait_resource, h.statement_start_offset, h.statement_end_offset,
    h.plan_handle, h.sql_handle, h.most_recent_sql_handle, [Level] + 1
    FROM cteHead AS blocked
    INNER JOIN cteBlockingHierarchy AS h ON h.session_id = blocked.blocking_session_id and h.session_id!=blocked.session_id --avoid infinite recursion for latch type of blocking
    WHERE h.wait_type COLLATE Latin1_General_BIN NOT IN ('EXCHANGE', 'CXPACKET') or h.wait_type is null
    )
SELECT bh.*, txt.text AS blocker_query_or_most_recent_query 
FROM cteBlockingHierarchy AS bh 
OUTER APPLY sys.dm_exec_sql_text (ISNULL ([sql_handle], most_recent_sql_handle)) AS txt
GO


SELECT [s_tst].[session_id],
[database_name] = DB_NAME (s_tdt.database_id),
[s_tdt].[database_transaction_begin_time], 
[sql_text] = [s_est].[text] 
FROM sys.dm_tran_database_transactions [s_tdt]
INNER JOIN sys.dm_tran_session_transactions [s_tst] ON [s_tst].[transaction_id] = [s_tdt].[transaction_id]
INNER JOIN sys.dm_exec_connections [s_ec] ON [s_ec].[session_id] = [s_tst].[session_id]
CROSS APPLY sys.dm_exec_sql_text ([s_ec].[most_recent_sql_handle]) AS [s_est]
GO



SELECT table_name = schema_name(o.schema_id) + '.' + o.name
, wt.wait_duration_ms, wt.wait_type, wt.blocking_session_id, wt.resource_description
, tm.resource_type, tm.request_status, tm.request_mode, tm.request_session_id
FROM sys.dm_tran_locks AS tm
INNER JOIN sys.dm_os_waiting_tasks as wt ON tm.lock_owner_address = wt.resource_address
LEFT OUTER JOIN sys.partitions AS p on p.hobt_id = tm.resource_associated_entity_id
LEFT OUTER JOIN sys.objects o on o.object_id = p.object_id or tm.resource_associated_entity_id = o.object_id
WHERE resource_database_id = DB_ID()
AND object_name(p.object_id) = 'TEST'
GO


SELECT page_info.*
FROM sys.dm_exec_requests AS d 
CROSS APPLY sys.fn_PageResCracker (d.page_resource) AS r 
CROSS APPLY sys.dm_db_page_info(r.db_id, r.file_id, r.page_id, 1) AS page_info
GO

SELECT tst.session_id, [database_name] = db_name(s.database_id)
, tat.transaction_begin_time
, transaction_duration_s = datediff(s, tat.transaction_begin_time, sysdatetime()) 
, transaction_type = CASE tat.transaction_type  WHEN 1 THEN 'Read/write transaction'
                                                WHEN 2 THEN 'Read-only transaction'
                                                WHEN 3 THEN 'System transaction'
                                                WHEN 4 THEN 'Distributed transaction' END
, input_buffer = ib.event_info, tat.transaction_uow     
, transaction_state  = CASE tat.transaction_state    
            WHEN 0 THEN 'The transaction has not been completely initialized yet.'
            WHEN 1 THEN 'The transaction has been initialized but has not started.'
            WHEN 2 THEN 'The transaction is active - has not been committed or rolled back.'
            WHEN 3 THEN 'The transaction has ended. This is used for read-only transactions.'
            WHEN 4 THEN 'The commit process has been initiated on the distributed transaction.'
            WHEN 5 THEN 'The transaction is in a prepared state and waiting resolution.'
            WHEN 6 THEN 'The transaction has been committed.'
            WHEN 7 THEN 'The transaction is being rolled back.'
            WHEN 8 THEN 'The transaction has been rolled back.' END 
, transaction_name = tat.name, request_status = r.status
, tst.is_user_transaction, tst.is_local
, session_open_transaction_count = tst.open_transaction_count  
, s.host_name, s.program_name, s.client_interface_name, s.login_name, s.is_user_process
FROM sys.dm_tran_active_transactions tat 
INNER JOIN sys.dm_tran_session_transactions tst  on tat.transaction_id = tst.transaction_id
INNER JOIN Sys.dm_exec_sessions s on s.session_id = tst.session_id 
LEFT OUTER JOIN sys.dm_exec_requests r on r.session_id = s.session_id
CROSS APPLY sys.dm_exec_input_buffer(s.session_id, null) AS ib
GO


--#########################################################
--##### ACTIVE SESSION
--#########################################################
(1) 병렬 쿼리 포함
select getdate() AS logtime
       , a.elapsed_time
       , a.login_name
       , a.database_name
       , a.session_id
       , a.ecid
       , a.blocking_sessionid
       , a.command_type
       , a.status
       , a.sql_wait_type
       , a.sql_wait_time
       , a.sql_wait_resource
       , case when st.objectid is not null then object_name(st.objectid,st.dbid) else object_name(p.objectid,p.dbid) end as [object_name]
       , case when (statement_start_offset=0
                      and statement_end_offset=0
                     ) then text
             else substring(st.text, (statement_start_offset/2)+1, ((case statement_end_offset
                                                                       when -1 then datalength(st.text)
                                                                       else statement_end_offset
                                                                     end-statement_start_offset)/2)+1)
        end as sql_text
       , a.open_tran
       , a.sql_last_wait_type
       , a.cpu_time
       , a.logical_reads
       , a.physical_reads
       , case when ecid = 0 then isnull(convert(numeric(15,2),mg.requested_memory_kb/1024.0),0) else null end as requested_memory_mb
       , case when ecid = 0 then isnull( convert(numeric(15,2),mg.granted_memory_kb/1024.0),0) else null end as granted_memory_mb
       , case when ecid = 0 then isnull( convert(numeric(15,2),mg.required_memory_kb/1024.0),0) else null end as required_memory_mb
       , case when ecid = 0 then isnull( convert(numeric(15,2),mg.used_memory_kb/1024.0),0) else null end as used_memory_mb
       , case when ecid = 0 then isnull( convert(numeric(15,2),mg.max_used_memory_kb/1024.0) ,0) else null end as max_used_memory_mb
       , a.host_name
       , a.program_name
       , a.login_time
       , a.sql_handle
       , a.plan_handle
       , a.sql_hash
       , a.plan_hash
       , a.statement_start_offset
       , a.statement_end_offset
       , a.start_time
       , a.row_count
       , 'Not Support' as event_info
       , st.encrypted as encrypted
	   , convert(xml,p.query_plan) as query_plan
from    (select convert(numeric(15,2),r.total_elapsed_time/1000.0) as elapsed_time
               ,case when ecid = 0 then rtrim(p.loginame) else null end as login_name
			   ,db_name(p.dbid) as database_name
               ,p.spid as session_id
			   ,p.ecid as ecid
			   ,p.blocked as blocking_sessionid
			   ,rtrim(p.cmd) as command_type
			   ,p.status as status
			   ,isnull(r.wait_type,'') as sql_wait_type
			   ,convert(numeric(15,2),p.waittime/1000.0) as sql_wait_time
			   ,p.waitresource as sql_wait_resource
               ,p.open_tran as open_tran
               ,p.lastwaittype as sql_last_wait_type
               ,convert(numeric(15,2),r.cpu_time/1000.0) as cpu_time
               ,case when p.ecid=0 then r.logical_reads
                     else 0
                end as logical_reads
               ,r.reads as physical_reads
               ,case when ecid = 0 then rtrim(p.hostname) else null end as host_name
               ,case when ecid = 0 then rtrim(p.program_name) else null end as program_name
               ,case when ecid = 0 then p.login_time else null end as login_time
               ,case when ecid = 0 then p.sql_handle else null end as sql_handle
               ,case when ecid = 0 then r.plan_handle else null end as plan_handle
               ,case when ecid = 0 then r.query_hash else null end as sql_hash
               ,case when ecid = 0 then r.query_plan_hash else null end as plan_hash
               ,case when ecid = 0 then isnull(stmt_start, 0) else null end as statement_start_offset
               ,case when ecid = 0 then isnull(stmt_end, 0) else null end as statement_end_offset
               ,start_time as start_time
               ,r.row_count
         from   sys.sysprocesses p (NOLOCK)
            left outer join  sys.dm_exec_requests r (NOLOCK) on p.spid=r.session_id
            left outer join sys.dm_exec_sessions s (NOLOCK) on p.spid=s.session_id
            where  ((p.status <> 'sleeping' and start_time is not null) or (p.open_tran > 0 and p.status = 'sleeping'))
            and hostprocess <> ''
            and p.program_name not in ('Microsoft® Windows® Operating System','SqlServer')
            and p.spid <> @@spid
            --and rtrim(p.cmd) <> 'BACKUP DATABASE'
			--and r.total_elapsed_time >= 1000
            ) a
outer apply sys.dm_exec_sql_text(a.sql_handle) st
left outer join sys.dm_exec_query_memory_grants as mg (NOLOCK)
    on mg.session_id = a.[session_id]
outer apply sys.dm_exec_text_query_plan(a.plan_handle, a.statement_start_offset, a.statement_end_offset) p ;



(2)실시간 세션, SESSION 모니터링, HEAD BLOCKED/BLOCKER 포함
WITH CTE_BLOCKED(SPID, BLOCKED_SPID)
AS 
(SELECT SPID, BLOCKED
   FROM SYSPROCESSES
  WHERE BLOCKED <> 0
  UNION ALL
 SELECT SP.SPID, SP.BLOCKED
   FROM SYSPROCESSES SP
   JOIN CTE_BLOCKED CTE
     ON SP.SPID = CTE.BLOCKED_SPID
)
, HEAD_BLOCKED(HEAD_SPID)
AS 
(SELECT DISTINCT SPID AS HEAD_SPID
   FROM CTE_BLOCKED
  WHERE BLOCKED_SPID = 0
)
SELECT SYSP.SPID
     , USER_NAME(UID) AS USERNAME
     , DB_NAME(SYSP.DBID) AS DBNAME
     , SYSP.HOSTNAME
     , SYSP.PROGRAM_NAME
     , SYSP.STATUS
     , SYSP.CMD
     , DMVR.START_TIME
     , DMVR.CPU_TIME
     , ROUND(DMVR.TOTAL_ELAPSED_TIME/1000,3) ELAPSED_TIME_SEC
     , SYSP.PHYSICAL_IO
     , DMVR.ROW_COUNT
     , SYSP.BLOCKED AS BLOCKED_SPID
     , (SELECT CASE WHEN HBLK.HEAD_SPID IS NOT NULL THEN '1' ELSE '0' END
          FROM HEAD_BLOCKED HBLK
         WHERE HBLK.HEAD_SPID = SYSP.SPID) AS HEAD_BLOCKER
     , (SELECT (SELECT TEXT FROM SYS.DM_EXEC_SQL_TEXT(SQL_HANDLE)) FROM SYSPROCESSES SP2 WHERE SP2.SPID = SYSP.BLOCKED) BLOCKED_TEXT
     , SYSP.LOGIN_TIME
     , SYSP.LAST_BATCH
     , DMVR.WAIT_TYPE
     , DMVR.LAST_WAIT_TYPE
     , SYSP.LASTWAITTYPE
     , SYSP.OPEN_TRAN
     , ST.TEXT
     , SUBSTRING( ST.TEXT
                , (SYSP.STMT_START/2)+1
                , ((CASE STMT_END WHEN -1 THEN DATALENGTH(ST.TEXT) ELSE SYSP.STMT_END END - SYSP.STMT_START)/2)+1) AS STATEMENT_TEXT
     , SYSP.SQL_HANDLE
  FROM SYSPROCESSES SYSP
  LEFT OUTER JOIN SYS.DM_EXEC_REQUESTS DMVR
    ON SYSP.SPID = DMVR.SESSION_ID
 CROSS APPLY SYS.dm_exec_sql_text(SYSP.SQL_HANDLE) ST
 WHERE 1=1
   AND DB_NAME(SYSP.DBID) IN ('ERP')
   --AND SYSP.STATUS NOT IN ('SLEEPING')
 ORDER BY SYSP.STATUS, LAST_BATCH 
GO


(3) PR_DBA_ACTIVESESS 쿼리
SELECT 
SPID = S.SESSION_ID  
,GETDATE() AS 'DATECHECKED'
,BLOCKED = R.BLOCKING_SESSION_ID  
,[DUR2(S)] = CAST(CONVERT(DEC(12,3),CONVERT(FLOAT,GETDATE()-R.START_TIME)*24*60*60) AS NVARCHAR)  
,LOGICALREAD = R.LOGICAL_READS  
,LAST_BATCH = R.START_TIME   
,LOGIN = RTRIM(S.LOGIN_NAME)  
,HOSTNAME = S.HOST_NAME  
,CLIENTIP = C.CLIENT_NET_ADDRESS  
,PROGRAM = LEFT(S.PROGRAM_NAME,50)  
,DBNAME = DB_NAME(R.DATABASE_ID)  
,OBJECTNAME = OBJECT_NAME(S2.OBJECTID)   
,CASE WHEN UPPER(S2.TEXT) LIKE '%NOLOCK%'     
           THEN ''  
           ELSE 'LOCK'   
        END AS IS_NOLOCK    
,CMD = RTRIM(R.COMMAND)  
,STATUS = CONVERT(NVARCHAR(30), R.STATUS)  
,SQL = SUBSTRING(S2.TEXT,  STATEMENT_START_OFFSET / 2, ( (CASE WHEN STATEMENT_END_OFFSET = -1 THEN (LEN(CONVERT(NVARCHAR(MAX),S2.TEXT)) * 2)  
ELSE STATEMENT_END_OFFSET END)  - STATEMENT_START_OFFSET) / 2)  
,WAITTIME = R.TOTAL_ELAPSED_TIME /1000  
,WAITTYPE = R.LAST_WAIT_TYPE  
,WAITRESOURCE = RTRIM(R.WAIT_RESOURCE)  
,CPU = R.CPU_TIME  
,PHYSICALIO = (R.READS+R.WRITES)  
--,R.WRITES  
--,R.START_TIME  
,PARENT_QUERY = ISNULL(S2.TEXT,'')  
,R.SQL_HANDLE
,R.PLAN_HANDLE
FROM SYS.DM_EXEC_SESSIONS S (NOLOCK)  
JOIN SYS.DM_EXEC_REQUESTS R (NOLOCK) ON S.SESSION_ID = R.SESSION_ID  
OUTER APPLY SYS.DM_EXEC_SQL_TEXT(R.SQL_HANDLE) S2
JOIN SYS.DM_EXEC_CONNECTIONS C ON S.SESSION_ID = C.SESSION_ID  
WHERE  1=1
--AND S.IS_USER_PROCESS = 1   
--  AND S.SESSION_ID<>@@SPID  
ORDER BY R.START_TIME  ;



(4) MONITOR이용 LOCKED 세션 조회
SELECT DATECHECKED
, DBNAME
, SPID
, LOGIN
, BLOCKED
, STATUS
, CMD
, [Dur2(s)]
, CPU
, LogicalRead
, WAITTYPE
, WAITTIME
, WAITRESOURCE
, SQL
, HOSTNAME
, CLIENTIP
, Last_Batch
, PROGRAM
, OBJECTNAME
, IS_NOLOCK
, PhysicalIO
, Parent_Query
, sql_handle
, plan_handle
FROM MONITOR.DBO.DBA_SESSIONS_DETAIL A
WHERE 1=1
AND DATECHECKED BETWEEN CONVERT(DATETIME, '20241023 09:00:00') AND CONVERT(DATETIME, '20241023 10:00:00')
AND LOGIN = 'EAIINF'
ORDER BY DATECHECKED, DBNAME, SPID ;

(5) 백그라운드 BACKGROUND 세션 조회
SELECT p.status ,p.program_name ,p.hostname ,p.spid ,p.blocked ,p.kpid
     , p.cpu ,p.physical_io ,p.waittype ,p.waittime ,p.lastwaittype
     , p.waitresource ,p.dbid ,p.uid ,p.memusage ,p.login_time ,p.last_batch
     , p.ecid ,p.open_tran ,p.sid ,p.hostprocess
     , p.cmd ,p.nt_domain ,p.nt_username ,p.net_address
     , p.net_library ,p.loginame ,p.context_info ,p.sql_handle
     , p.stmt_start ,p.stmt_end
FROM master..sysprocesses p
WHERE (
       STATUS LIKE 'run%'
       OR waittime > 0
       OR blocked <> 0
       OR open_tran <> 0
       OR EXISTS (
           SELECT *
           FROM master..sysprocesses p1
           WHERE p.spid = p1.blocked
               AND p1.spid <> p1.blocked
           )
       )
--AND spid > 50
AND spid <> @@spid
order BY SPID ;



--#########################################################
--##### OS CPU 메모리 정보 확인
--#########################################################
select * from sys.dm_os_sys_info with(nolock)



--#########################################################
--##### 개체별 메모리 사용량
--#########################################################

select DB_NAME(b.database_id) AS [Database Name],
       OBJECT_NAME(p.object_id) as [object_name],
       p.index_id, i.name as [index_name],
       COUNT(*) as buffer_count,
       CAST( count(*) as bigint )*8/1024.0 as [buffe_rsize(MB)]
from       sys.allocation_units as a (NOLOCK) 
inner join sys.dm_os_buffer_descriptors as b (NOLOCK)
        on a.allocation_unit_id =b.allocation_unit_id
inner join sys.partitions as p (nolock)
        on a.container_id=p.hobt_id
inner join sys.indexes as i (nolock)
        on p.object_id = i.object_id
AND p.index_id = i.index_id 
where b.database_id <> 32767
and p.[object_id]>100
group by b.database_id, p.[object_id],p.index_id, i.name, DB_NAME(b.database_id)
go


--#########################################################
--##### 병렬 강제 적용, PARALLEL 강제 적용
--#########################################################

select * 
from a inner join b 
on a.num = b.num
option(use hint('ENABLE_PARALLEL_PLAN_PREFERENCE'),maxdop 2);


SELECT PP.[ProductID]
      ,[Name]
      ,[ProductNumber]
      ,PTH.ActualCost 
      ,PTH.TransactionType      
  FROM [MSSQLTipsDemo].[Production].[Product] PP
  JOIN [MSSQLTipsDemo].[Production].TransactionHistory PTH
  ON PP.ProductID =PTH.ProductID 
  WHERE PP.SellEndDate <GETDATE()-2 AND MakeFlag =1 and Weight >148
  OPTION(QUERYTRACEON 8649)
  

SELECT PP.[ProductID]
      ,[Name]
      ,[ProductNumber]
      ,PTH.ActualCost 
      ,PTH.TransactionType      
  FROM [MSSQLTipsDemo].[Production].[Product] PP
  JOIN [MSSQLTipsDemo].[Production].TransactionHistory PTH
  ON PP.ProductID =PTH.ProductID 
  WHERE PP.SellEndDate <GETDATE()-2 AND MakeFlag =1 and Weight >148
  OPTION(USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'))

--#########################################################
--##### 제품 정보 확인
--#########################################################

select serverproperty('productversion')
, serverproperty('productlevel')
, serverproperty('EngineEdition') as "EngineEdition"
, ServerProperty('InstanceName')
, ServerProperty('MachineName')
, DB_NAME()  ;

/*
 BuildClrVersion / Microsoft .NET Framework CLR(공용 언어 런타임)의 버전
 Collation / 서버의 기본 데이터 정렬 이름
 CollationID / 서버의 기본 데이터 정렬 아이디
 ComparisonStyle / 데이터 정렬 스타일
 ComputerNamePhysicalNetBIOS / SQL Server 인스턴스가 현재 실행되고 있는 로컬 컴퓨터의 NetBIOS 이름
 Edition / SQL Server 인스턴스의 설치된 제품 버전
 EditionID / SQL Server 인스턴스의 설치된 제품 버전 아이디
 EngineEdition / 서버에 설치된 SQL Server 인스턴스의 데이터베이스 엔진 버전
 -- EngineEdition
   1 = Personal 또는 Desktop Engine(SQL Server 2005(9.x) 이상 버전에는 사용할 수 없음)
   2 = Standard(Standard, Web 및 Business Intelligence인 경우)
   3 = Enterprise(Evaluation, Developer 및 Enterprise 버전인 경우)
   4 = Express(Express, Express with Tools 및 Express with Advanced Services인 경우)
   5 = SQL Database
   6 = Azure Synapse Analytics
   8 = Azure SQL Managed Instance
   9 = Azure SQL Edge(모든 버전의 Azure SQL Edge)
   11 = Azure Synapse 서버리스 SQL 풀
 HadrManagerStatus / 가용성 그룹 관리자가 시작되었는지 여부
 InstanceName / 사용자가 연결된 인스턴스의 이름
 IsClustered / 서버 인스턴스가 장애 조치(failover) 클러스터에 구성되어 있는지 표시
 IsFullTextInstalled / 전체 텍스트 및 의미 체계 인덱싱 구성 요소 설치 여부
 IsHadrEnabled / 가용성 그룹 사용 여부
 IsIntegratedSecurityOnly / 통합 보안 모드 사용 여부
 IsLocalDB / SQL Server Express LocalDB의 인스턴스
 IsSingleUser / 단일 사용자 모드 여부
 IsXTPSupported / 메모리 OLTP를 지원 여부
 MachineName / 서버 인스턴스가 실행 중인 컴퓨터 이름
 ProcessID / SQL Server 서비스의 프로세스 아이디
 ProductVersion / SQL Server 제품 버전
 ProductLevel / SQL Server 인스턴스의 버전 레벨
 ResourceLastUpdateDateTime / 리소스 데이터베이스를 마지막으로 업데이트한 날짜
 ResourceVersion / 리소스 데이터베이스 버전
 ServerName / Windows 서버 및 지정된 SQL Server 인스턴스에 대한 인스턴스 정보
 SqlCharSet / SQL 문자 집합 아이디
 SqlCharSetName / SQL 문자 집합 이름
 SqlSortOrder / SQL 정렬 순서 아이디
 SqlSortOrderName / SQL 정렬 순서 이름
 FilestreamShareName / FILESTREAM이 사용하는 공유명
 FilestreamConfiguredLevel / FILESTREAM액세스 수준
 FilestreamEffectiveLevel / 유효한 FILESTREAM 액세스 수준
*/

--#########################################################
--##### 호환성 compatibility 확인
--#########################################################
SELECT name, compatibility_level FROM sys.databases ; 

--#########################################################
--##### 로그인, 사용자, DB 계정
--#########################################################
--로그인
SELECT *
  FROM SYS.sql_logins 
 WHERE NAME LIKE '%APP'
 ORDER BY NAME ;

--DB 사용자
SELECT @@Servername as ServerName
     , db_name() as DBName
     , Roles.Name
     , Roles.Type_Desc as RDesc
     , Members.Name MemberName
     , Members.Type_Desc as MDesc
  FROM sys.database_role_members RoleMembers
 INNER JOIN sys.database_principals Roles 
    ON Roles.Principal_Id = RoleMembers.Role_Principal_Id
 INNER JOIN sys.database_principals Members 
    ON Members.Principal_Id =RoleMembers.Member_Principal_Id ;


--#########################################################
--##### 오브젝트명, OBJECT NAME, 컬럼명, COLUMN NAME
--#########################################################
SELECT OBJECT_NAME(object_id) AS object_name,
       COL_NAME(object_id, column_id) AS column_name,
	   
	   
--#########################################################
--##### 컬럼 DEFAULT 추가
--#########################################################	   
ALTER TABLE DBO.테이블명 ADD DEFAULT '기본값' FOR 컬럼명 ;
예) ALTER TABLE DBO.EI_EXPO_BKNG_CTNR_M ADD DEFAULT 'N' FOR DEL_YN ;


--#########################################################
--##### DEFAULT 제약조건 확인
--#########################################################	   

select schema_name(t.schema_id) + '.' + t.[name] as TABLE_NAME
, col.[name] as COLUMN_NAME
, con.[name] as CONSTRAINT_NAME
, con.[definition] DEFINITION
from sys.default_constraints con
left outer join sys.objects t
on con.parent_object_id = t.object_id
left outer join sys.all_columns col
on con.parent_column_id = col.column_id
and con.parent_object_id = col.object_id ;

--DEFAULT 제약조건 변경
SELECT 'SP_RENAME '''+SCHEMA_NAME+'.'+CONSTRAINT_NAME+''','''+TABLE_NAME+'_'+COLUMN_NAME+'_DFLT'',''OBJECT'''+CHAR(10)+'GO'
FROM (select schema_name(t.schema_id) AS SCHEMA_NAME
, t.[name] as TABLE_NAME
, col.[name] as COLUMN_NAME
, con.[name] as CONSTRAINT_NAME
, con.[definition] DEFINITION
from sys.default_constraints con
left outer join sys.objects t
on con.parent_object_id = t.object_id
left outer join sys.all_columns col
on con.parent_column_id = col.column_id
and con.parent_object_id = col.object_id ) A
WHERE CONSTRAINT_NAME <> TABLE_NAME+'_'+COLUMN_NAME+'_DFLT' ;




--#########################################################
--##### 쿼리별 메모리 사용량(실시간)
--#########################################################
(1) 
SELECT 
  session_id
  ,requested_memory_kb/1024 AS requested_memory_MB
  ,granted_memory_kb/1024 AS granted_memory_MB
  ,used_memory_kb/1024 AS used_memory_MB
  ,queue_id
  ,wait_order
  ,wait_time_ms
  ,is_next_candidate
  ,pool_id
  ,text
  ,query_plan
FROM sys.dm_exec_query_memory_grants
  CROSS APPLY sys.dm_exec_sql_text(sql_handle)
  CROSS APPLY sys.dm_exec_query_plan(plan_handle)
  
(2)
SELECT    CONVERT (varchar(30), GETDATE(), 121) as runtime
         , r.session_id
         , r.wait_time
         , r.wait_type
         , mg.request_time 
         , mg.grant_time 
         , mg.requested_memory_kb
          / 1024 requested_memory_mb 
         , mg.granted_memory_kb
          / 1024 AS granted_memory_mb 
         , mg.required_memory_kb
          / 1024 AS required_memory_mb 
         , max_used_memory_kb
          / 1024 AS max_used_memory_mb
         , ideal_memory_kb
          / 1024 AS ideal_memory_mb
		 , (mg.requested_memory_kb-ideal_memory_kb)
          / 1024 AS diff_ideal_memory_mb
         --, rs.pool_id as resource_pool_id
         , mg.query_cost 
         , mg.timeout_sec 
         , mg.resource_semaphore_id 
         , mg.wait_time_ms AS memory_grant_wait_time_ms 
         , CASE mg.is_next_candidate 
           WHEN 1 THEN 'Yes'
           WHEN 0 THEN 'No'
           ELSE 'Memory has been granted'
         END AS 'Next Candidate for Memory Grant'
         , r.command
         , ltrim(rtrim(replace(replace (substring (q.text, 1, 1000), char(10), ' '), char(13), ' '))) [text]
         --, rs.target_memory_kb
         -- / 1024 AS server_target_grant_memory_mb 
         --, rs.max_target_memory_kb
         -- / 1024 AS server_max_target_grant_memory_mb 
         --, rs.total_memory_kb
         -- / 1024 AS server_total_resource_semaphore_memory_mb 
         --, rs.available_memory_kb
         -- / 1024 AS server_available_memory_for_grants_mb 
         --, rs.granted_memory_kb
         -- / 1024 AS server_total_granted_memory_mb 
         --, rs.used_memory_kb
         -- / 1024 AS server_used_granted_memory_mb 
         --, rs.grantee_count AS successful_grantee_count 
         --, rs.waiter_count AS grant_waiters_count 
         --, rs.timeout_error_count 
         --, rs.forced_grant_count 
         , mg.dop 
         , r.blocking_session_id
         , r.cpu_time
         , r.total_elapsed_time
         , r.reads
         , r.writes
         , r.logical_reads
         , r.row_count
         , s.login_time
         , d.name
         , s.login_name
         , s.host_name
         , s.nt_domain
         , s.nt_user_name
         , s.status
         , c.client_net_address
         , s.program_name
         , s.client_interface_name
         , s.last_request_start_time
         , s.last_request_end_time
         , c.connect_time
         , c.last_read
         , c.last_write
         --, qp.query_plan
FROM     sys.dm_exec_requests r
         INNER JOIN sys.dm_exec_connections c
           ON r.connection_id = c.connection_id
         INNER JOIN sys.dm_exec_sessions s
           ON c.session_id = s.session_id
         INNER JOIN sys.databases d
           ON r.database_id = d.database_id
         INNER JOIN sys.dm_exec_query_memory_grants mg
           ON s.session_id = mg.session_id
         --INNER JOIN sys.dm_exec_query_resource_semaphores rs
         --  ON mg.resource_semaphore_id = rs.resource_semaphore_id
         CROSS APPLY sys.dm_exec_sql_text (r.sql_handle ) AS q
         --CROSS APPLY sys.dm_exec_query_plan(mg.plan_handle) qp
OPTION (MAXDOP 1, LOOP JOIN ) ;
  
  
  
  
--#########################################################
--##### 쿼리별 메모리 사용량(통계)
--#########################################################
SELECT 
SELECT TOP 20
  SUBSTRING(ST.text, (QS.statement_start_offset/2) + 1,  
    ((CASE statement_end_offset   
        WHEN -1 THEN DATALENGTH(ST.text)  
        ELSE QS.statement_end_offset END   
            - QS.statement_start_offset)/2) + 1) AS statement_text  
  ,CONVERT(DECIMAL (10,2), max_grant_kb /1024.0) AS max_grant_mb
  ,CONVERT(DECIMAL (10,2), min_grant_kb /1024.0) AS min_grant_mb
  ,CONVERT(DECIMAL (10,2), (total_grant_kb / execution_count) /1024.0) AS avg_grant_mb
  ,CONVERT(DECIMAL (10,2), max_used_grant_kb /1024.0) AS max_grant_used_mb
  ,CONVERT(DECIMAL (10,2), min_used_grant_kb /1024.0) AS min_grant_used_mb
  ,CONVERT(DECIMAL (10,2), (total_used_grant_kb/ execution_count)  /1024.0) AS avg_grant_used_mb
  ,CONVERT(DECIMAL (10,2), (total_ideal_grant_kb/ execution_count)  /1024.0) AS avg_ideal_grant_mb
  ,CONVERT(DECIMAL (10,2), (total_ideal_grant_kb/ 1024.0)) AS total_grant_for_all_executions_mb
  ,execution_count
FROM sys.dm_exec_query_stats QS
  CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) as ST
WHERE max_grant_kb > 5120 -- greater than 5 MB
ORDER BY max_grant_kb DESC


--#########################################################
--##### 메모리 사용량, 버퍼 사용량
--#########################################################
-- 2012 이상
SELECT TOP(10) mc.[type] AS [Memory Clerk Type],
       CAST((SUM(mc.pages_kb)/(1024.0 *1024)) AS DECIMAL (15,2)) AS [Memory Usage (GB)],
       CAST((SUM(mc.pages_kb)/1024.0) AS DECIMAL (15,2)) AS [Memory Usage (MB)]
FROM sys.dm_os_memory_clerks AS mc WITH (NOLOCK)
GROUP BY mc.[type] 
ORDER BY SUM(mc.pages_kb) DESC OPTION (RECOMPILE);
go
 
 
--BUFFER POOL 사용량 조회 (DB별)
--Buffer pool distribution
--Per database DataCache usage inside buffer pool
SELECT
CASE database_id WHEN 32767 THEN 'ResourceDB' ELSE DB_NAME(database_id) END as "DatabaseName",
COUNT(*) PageCount,
CAST(COUNT(*) * 8 / 1024.0 AS NUMERIC(10, 2))  as "Size (MB)-Only DataCache-in-BufferPool"
From sys.dm_os_buffer_descriptors
--WHERE database_id = DB_ID('DUMMY')
GROUP BY db_name(database_id),database_id
ORDER BY "Size (MB)-Only DataCache-in-BufferPool" DESC  OPTION (RECOMPILE);
go



--#########################################################
--##### BAD SQL, 쿼리 성능, 튜닝 대상
--#########################################################
SELECT *
 FROM (SELECT GETDATE() AS SNAP_DTTM
                 , (SELECT TEXT FROM SYS.DM_EXEC_SQL_TEXT(SQL_HANDLE)) AS PARENT_SQL_TEXT
				 , SUBSTRING(S2.TEXT,  STATEMENT_START_OFFSET / 2, ( (CASE WHEN STATEMENT_END_OFFSET = -1 THEN (LEN(CONVERT(NVARCHAR(MAX),S2.TEXT)) * 2)  ELSE STATEMENT_END_OFFSET END)  - STATEMENT_START_OFFSET) / 2) AS SQL_TEXT
				 , execution_count
                 , total_worker_time/1000000 total_worker_time_SEC
				 , (total_worker_time/1000000)/execution_count AVG_WORKER_TIME_SEC
                 , last_worker_time/1000000 LAST_WORKER_TIME_SEC
                 , min_worker_time
                 , max_worker_time
                 , total_physical_reads
                 , last_physical_reads
                 , min_physical_reads
                 , max_physical_reads
                 , total_logical_writes
                 , last_logical_writes
                 , min_logical_writes
                 , max_logical_writes
                 , total_logical_reads
                 , last_logical_reads
                 , min_logical_reads
                 , max_logical_reads
                 , statement_start_offset
                 , statement_end_offset
                 , plan_generation_num
                 , creation_time
                 , last_execution_time                 
                 , total_clr_time
                 , last_clr_time
                 , min_clr_time
                 , max_clr_time
                 , total_elapsed_time
                 , last_elapsed_time
                 , min_elapsed_time
                 , max_elapsed_time
                 , query_hash
                 , query_plan_hash
                 , total_rows
                 , last_rows
                 , min_rows
                 , max_rows
                 , statement_sql_handle
                 , statement_context_id
                 , total_dop
                 , last_dop
                 , min_dop
                 , max_dop
                 , total_grant_kb
                 , last_grant_kb
                 , min_grant_kb
                 , max_grant_kb
                 , total_used_grant_kb
                 , last_used_grant_kb
                 , min_used_grant_kb
                 , max_used_grant_kb
                 , total_ideal_grant_kb
                 , last_ideal_grant_kb
                 , min_ideal_grant_kb
                 , max_ideal_grant_kb
                 , total_reserved_threads
                 , last_reserved_threads
                 , min_reserved_threads
                 , max_reserved_threads
                 , total_used_threads
                 , last_used_threads
                 , min_used_threads
                 , max_used_threads
                 , total_columnstore_segment_reads
                 , last_columnstore_segment_reads
                 , min_columnstore_segment_reads
                 , max_columnstore_segment_reads
                 , total_columnstore_segment_skips
                 , last_columnstore_segment_skips
                 , min_columnstore_segment_skips
                 , max_columnstore_segment_skips
                 , total_spills
                 , last_spills
                 , min_spills
                 , max_spills
                 , total_num_physical_reads
                 , last_num_physical_reads
                 , min_num_physical_reads
                 , max_num_physical_reads
                 , total_page_server_reads
                 , last_page_server_reads
                 , min_page_server_reads
                 , max_page_server_reads
                 , total_num_page_server_reads
                 , last_num_page_server_reads
                 , min_num_page_server_reads
                 , max_num_page_server_reads
                 , sql_handle
                 , plan_handle
                 --, (SELECT QUERY_PLAN FROM SYS.dm_exec_query_plan(PLAN_HANDLE)) AS SQL_PLAN
            --INTO DBA_HIST_SQLSTATS
            FROM SYS.dm_exec_query_stats R WITH(NOLOCK)
			CROSS APPLY SYS.DM_EXEC_SQL_TEXT(R.SQL_HANDLE) S2 
			) A
			WHERE PARENT_SQL_TEXT NOT LIKE '%MIGRATION%'
			ORDER BY AVG_WORKER_TIME_SEC DESC
GO

(1) 실시간
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SELECT TOP 100 
     QS.EXECUTION_COUNT
    ,[AVG_ELPASED_TIME] = QS.TOTAL_ELAPSED_TIME/QS.EXECUTION_COUNT/1000000
	,[Avg_cpu_time] = (qs.total_worker_time)/(qs.execution_count)/1000000
	,[Average IO] = (total_logical_reads + total_logical_writes) / qs.execution_count
	,[Individual Query] = SUBSTRING (qt.text,qs.statement_start_offset/2 + 1, 
	(CASE WHEN qs.statement_end_offset = -1 
		THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
		ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)
	--,qr.query_plan
	,DatabaseName = DB_NAME(qt.dbid)
	--,[Parent Query] = qt.text
	,object_name(qt.objectid) as object_name
	,qs.last_execution_time
FROM sys.dm_exec_query_stats qs with (nolock)
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) as qr
where qs.last_execution_time > GETDATE() - 1
--and (qs.total_worker_time)/(qs.execution_count)/1000000 > 0.01
--and object_name(qt.objectid) ='USP_SEL_PROBE_MAP_BY_WAFER'
and qs.execution_count > 10
--and DB_NAME(qt.dbid) ='FILMFEST'
ORDER BY  [Avg_cpu_time] DESC, [Average IO]desc, qs.execution_count desc
GO


(2) MONITOR DB 기준 최근 CAPTURE에서 CPU 사용량 많은 쿼리순
WITH MAX_DATE_CHECKED(RECENT_TIME)
AS
(SELECT MAX(DATECHECKED)
   FROM MONITOR.DBO.DBA_SESSIONS_DETAIL
)
SELECT DATECHECKED	
, SPID	
, BLOCKED	
, [Dur2(s)]
, LOGIN	
, HOSTNAME	
, CLIENTIP	
, PROGRAM	
, STATUS	
, CPU	
, PhysicalIO	
, LogicalRead	
, Last_Batch	
, DBNAME	
, OBJECTNAME	
, IS_NOLOCK	
, WAITTYPE	
, WAITRESOURCE
, CMD	
, SQL	
, WAITTIME	
, Parent_Query	
, sql_handle	
, plan_handle
FROM MONITOR.DBO.DBA_SESSIONS_DETAIL A
JOIN MAX_DATE_CHECKED B
  ON A.DATECHECKED = B.RECENT_TIME
ORDER BY CPU DESC ;


(3) 입력 받은 시간 이후로 실행 시간이 N초 이상인 쿼리들, CPU 사용량 많은 순, 최신 데이터 먼저(ORDER BY DATECHECKED DESC)
SELECT *
FROM (
SELECT DATECHECKED
, RANK() OVER(PARTITION BY DATECHECKED ORDER BY CPU DESC) AS CPU_RANK
, SPID
, BLOCKED
, [Dur2(s)] AS ELAPSED_TIME_S
, LOGICALREAD
, CPU
, PhysicalIO
, LAST_BATCH
, LOGIN
, HOSTNAME
, CLIENTIP
, PROGRAM
, DBNAME
, STATUS
, CMD
, IS_NOLOCK
, SQL
, Parent_Query
, sql_handle
, plan_handle
FROM MONITOR.DBO.DBA_SESSIONS_DETAIL
WHERE 1=1
AND DATECHECKED >= CONVERT(DATETIME,'20240314 16:00:00')
AND DATECHECKED <= CONVERT(DATETIME,'20240314 16:10:00')
) A
WHERE 1=1
  AND CPU_RANK <= 10
  AND ELAPSED_TIME_S >= 5
--ORDER BY DATECHECKED 
ORDER BY DATECHECKED DESC
;


(4)입력받은 시간 사이의 SQL 성능 정보(DBA_HIST_SQLSTATS)
WITH BASELINE
( SQL_HANDLE
, MIN_SNAP_DTTM
, MAX_SNAP_DTTM
)
AS
(SELECT SQL_HANDLE
      , MIN(SNAP_DTTM) MIN_SNAP_DTTM
	  , MAX(SNAP_DTTM) MAX_SNAP_DTTM
  FROM DBA_HIST_SQLSTATS
 WHERE SNAP_DTTM >= '2024-03-11 08:00:00'
   AND SNAP_DTTM <= '2024-03-11 18:00:00'
 GROUP BY SQL_HANDLE
)
SELECT TOP(100) 
     MIN_SNAP_DTTM
   , MAX_SNAP_DTTM
   , SQL_TEXT
   , DELTA_COUNT
   , [AVG_TOTAL_ELAPSED_TIME_S] = ROUND(DELTA_TOTAL_ELAPSED_TIME/DELTA_COUNT/1000,3)
   , [AVG_TOTAL_WORKER_TIME_S] = ROUND(DELTA_TOTAL_WORKER_TIME/DELTA_COUNT/1000,3)
   , [AVG_TOTAL_PHYSICAL_READS] = DELTA_TOTAL_PHYSICAL_READS/DELTA_COUNT
   , [AVG_TOTAL_LOGICAL_WRITES] = DELTA_TOTAL_LOGICAL_WRITES/DELTA_COUNT
   , [AVG_TOTAL_LOGICAL_READS] = DELTA_TOTAL_LOGICAL_READS/DELTA_COUNT
   , [AVG_TOTAL_CLR_TIME] = DELTA_TOTAL_CLR_TIME/DELTA_COUNT
   , [AVG_TOTAL_ROWS] = DELTA_TOTAL_ROWS/DELTA_COUNT
   , [AVG_TOTAL_NUM_PHYSICAL_READS] = DELTA_TOTAL_NUM_PHYSICAL_READS/DELTA_COUNT
FROM (SELECT B.SNAP_DTTM MIN_SNAP_DTTM
           , C.SNAP_DTTM MAX_SNAP_DTTM
           , SUBSTRING(B.SQL_TEXT
                     ,(B.STATEMENT_START_OFFSET/2)+1
                     ,((CASE B.STATEMENT_END_OFFSET WHEN -1 THEN DATALENGTH(B.SQL_TEXT) ELSE B.STATEMENT_END_OFFSET END - B.STATEMENT_START_OFFSET)/2)+1) AS SQL_TEXT
           , [DELTA_COUNT] = C.execution_count - B.execution_count
           , [DELTA_TOTAL_ELAPSED_TIME] = C.total_elapsed_time - B.total_elapsed_time
           , [DELTA_TOTAL_WORKER_TIME] = C.total_worker_time - B.total_worker_time
           , [DELTA_TOTAL_PHYSICAL_READS] = C.total_physical_reads - B.total_physical_reads
           , [DELTA_TOTAL_LOGICAL_WRITES] = C.total_logical_writes - B.total_logical_writes
           , [DELTA_TOTAL_LOGICAL_READS] = C.total_logical_reads - B.total_logical_reads
           , [DELTA_TOTAL_CLR_TIME] = C.total_clr_time - B.total_clr_time
           , [DELTA_TOTAL_ROWS] = C.total_rows - B.total_rows
           , [DELTA_TOTAL_NUM_PHYSICAL_READS] = C.total_num_physical_reads - B.total_num_physical_reads
        FROM BASELINE A
        JOIN DBA_HIST_SQLSTATS B
          ON A.SQL_HANDLE = B.SQL_HANDLE
         AND A.MIN_SNAP_DTTM = B.SNAP_DTTM
        JOIN DBA_HIST_SQLSTATS C
          ON A.SQL_HANDLE = C.SQL_HANDLE
         AND A.MAX_SNAP_DTTM = C.SNAP_DTTM
       WHERE 1=1
      ) D
ORDER BY DELTA_COUNT DESC 
GO

--CREATE INDEX IX_DBA_HIST_SQLSTATS_01 ON DBO.DBA_HIST_SQLSTATS(SQL_HANDLE, SNAP_DTTM) ;
--CREATE INDEX IX_DBA_HIST_SQLSTATS_02 ON DBO.DBA_HIST_SQLSTATS(SNAP_DTTM) ;


--기간 입력 받고, 해당 기간동안 동일 QUERY_HASH값을 가지는 다른 쿼리들과 성능 비교




CREATE PROCEDURE [dbo].[PR_DBA_ACTIVESESS]
AS
SELECT 
SPID = S.SESSION_ID  
,GETDATE() AS 'DATECHECKED'
,BLOCKED = R.BLOCKING_SESSION_ID  
,[DUR2(S)] = CAST(CONVERT(DEC(12,3),CONVERT(FLOAT,GETDATE()-R.START_TIME)*24*60*60) AS NVARCHAR)  
,LOGICALREAD = R.LOGICAL_READS  
,LAST_BATCH = R.START_TIME   
,LOGIN = RTRIM(S.LOGIN_NAME)  
,HOSTNAME = S.HOST_NAME  
,CLIENTIP = C.CLIENT_NET_ADDRESS  
,PROGRAM = LEFT(S.PROGRAM_NAME,50)  
,DBNAME = DB_NAME(R.DATABASE_ID)  
,OBJECTNAME = OBJECT_NAME(S2.OBJECTID)   
,CASE WHEN UPPER(S2.TEXT) LIKE '%NOLOCK%'     
           THEN ''  
           ELSE 'LOCK'   
        END AS IS_NOLOCK    
,CMD = RTRIM(R.COMMAND)  
,STATUS = CONVERT(NVARCHAR(30), R.STATUS)  
,SQL = SUBSTRING(S2.TEXT,  STATEMENT_START_OFFSET / 2, ( (CASE WHEN STATEMENT_END_OFFSET = -1 THEN (LEN(CONVERT(NVARCHAR(MAX),S2.TEXT)) * 2)  
ELSE STATEMENT_END_OFFSET END)  - STATEMENT_START_OFFSET) / 2)  
,WAITTIME = R.TOTAL_ELAPSED_TIME /1000  
,WAITTYPE = R.LAST_WAIT_TYPE  
,WAITRESOURCE = RTRIM(R.WAIT_RESOURCE)  
,CPU = R.CPU_TIME  
,PHYSICALIO = (R.READS+R.WRITES)  
--,R.WRITES  
--,R.START_TIME  
,PARENT_QUERY = ISNULL(S2.TEXT,'')  
,R.SQL_HANDLE
,R.PLAN_HANDLE
FROM SYS.DM_EXEC_SESSIONS S (NOLOCK)  
JOIN SYS.DM_EXEC_REQUESTS R (NOLOCK) ON S.SESSION_ID = R.SESSION_ID  
OUTER APPLY SYS.DM_EXEC_SQL_TEXT(R.SQL_HANDLE) S2  
JOIN SYS.DM_EXEC_CONNECTIONS C ON S.SESSION_ID = C.SESSION_ID  
WHERE  1=1
--AND S.IS_USER_PROCESS = 1   
--  AND S.SESSION_ID<>@@SPID  
ORDER BY R.START_TIME  ;




--#########################################################
--##### 데이터베이스 사이즈
--#########################################################

DECLARE @dbname nvarchar(20)
SELECT @dbname = DB_NAME()


SELECT  
@dbname  AS DatabaseName,  
sysfilegroups.groupname AS FileGroup,
CAST(sysfiles.size/128.0 AS numeric(10,2)) AS 'FileSize(MB)',  
CAST(FILEPROPERTY(sysfiles.name,'SpaceUsed' )/128.0 AS numeric(10,2)) AS 'UsedSpace(MB)',
CAST(100-100 * (CAST (((sysfiles.size/128.0 - FILEPROPERTY(sysfiles.name,'SpaceUsed' )/128.0)/(sysfiles.size/128.0))  
AS decimal(4,2))) AS varchar(8)) + '%'  AS UsedSpacePct,  
CAST(sysfiles.size/128.0 - CAST(FILEPROPERTY(sysfiles.name,  
       'SpaceUsed' ) AS int)/128.0 AS int) AS FreeSpaceMB,  
CASE when sysfiles.maxsize = -1 then 'unlimited' else CAST(CAST(sysfiles.maxsize/128.0 AS numeric(10,2)) AS CHAR(12)) end  MaxSize,
CAST(sysfiles.growth/128.0 AS NUMERIC(10,2)) as growthMB,
sysfiles.name AS LogicalFileName, sysfiles.filename AS PhysicalFileName,  
CONVERT(sysname,DatabasePropertyEx(@dbname,'Status')) AS Status,  
CONVERT(sysname,DatabasePropertyEx(@dbname,'Updateability')) AS Updateability,  
CONVERT(sysname,DatabasePropertyEx(@dbname,'Recovery')) AS RecoveryMode, 
CAST(100 * (CAST (((sysfiles.size/128.0 - FILEPROPERTY(sysfiles.name,'SpaceUsed' )/128.0)/(sysfiles.size/128.0))  
AS decimal(4,2))) AS varchar(8)) + '%'  AS FreeSpacePct,  
GETDATE() as PollDate 
FROM dbo.sysfiles  (nolock)
left outer join sysfilegroups (nolock)
on sysfiles.groupid=sysfilegroups.groupid
order by sysfilegroups.groupid,filename


--#########################################################
--##### 로그인 계정 매핑, DB 복구 후 계정 매핑
--#########################################################

sp_change_users_login @Action='Report'
GO

sp_change_users_login 'update_one', 
                      'CRMAPP',   -- DB 유저 
                      'CRMAPP';   -- 로그인
GO


--#########################################################
--##### 파일그룹, 파일구성현황
--#########################################################

EXEC sp_MSforeachdb '
use [?]
select ''?'' as db_name,
sysfilegroups.groupname AS FileGroup,
sysfiles.name AS LogicalFileName, 
CAST(sysfiles.size/128.0 AS int) AS ''FileSize(MB)'',  
sysfiles.filename AS PhysicalFileName,  
case when sysfiles.maxsize = -1 then ''unlimited'' else CAST((sysfiles.maxsize/128.0) AS VARCHAR) end AS ''MaxSize(MB)'',
CAST(ROUND(sysfiles.growth/128.0,1) AS int) AS ''GrowthMB'',
-- case when sysfiles.maxsize = -1 then ''unlimited'' else CAST(sysfiles.maxsize AS VARCHAR) end AS maxsize,
CONVERT(sysname,DatabasePropertyEx(''?'',''Updateability'')) AS Updateability,  
GETDATE() as PollDate ,
''##########'' AS ''EndOfDoc'',
-- 여기까지 산출물 작성
CAST(100-100 * (CAST (((sysfiles.size/128.0 -CAST(FILEPROPERTY(sysfiles.name,''SpaceUsed'' ) AS int)/128.0)/(sysfiles.size/128.0))  AS decimal(4,2))) AS varchar(8)) + ''%''  AS UsedSpacePct,  
CAST(FILEPROPERTY(sysfiles.name,''SpaceUsed'' ) AS int)/128.0 AS UsedSpaceMB,
CAST(sysfiles.size/128.0 - CAST(FILEPROPERTY(sysfiles.name, ''SpaceUsed'' ) AS int)/128.0 AS int) AS FreeSpaceMB, 
CAST(100 * (CAST (((sysfiles.size/128.0 -CAST(FILEPROPERTY(sysfiles.name, ''SpaceUsed'' ) AS int)/128.0)/(sysfiles.size/128.0))  AS decimal(4,2))) AS varchar(8)) + ''%''  AS FreeSpacePct,  
CONVERT(sysname,DatabasePropertyEx(''?'',''Status'')) AS Status,  
CONVERT(sysname,DatabasePropertyEx(''?'',''Recovery'')) AS RecoveryMode
FROM dbo.sysfiles 
     left outer join sysfilegroups 
       on sysfiles.groupid=sysfilegroups.groupid
order by sysfilegroups.groupid,filename  '



--#########################################################
--##### 테이블 조회
--#########################################################
SELECT (SELECT B.TABLE_CATALOG FROM INFORMATION_SCHEMA.TABLES B WHERE B.TABLE_SCHEMA = OBJECT_SCHEMA_NAME(A2.OBJECT_ID) AND B.TABLE_NAME =  A2.NAME) AS DATABASE_NAME
     , OBJECT_SCHEMA_NAME(A2.OBJECT_ID) AS SCHEMANAME
     , A2.NAME AS TABLENAME
	 , A1.ROWS AS [ROWCOUNT]
	 , CAST(ROUND(((A1.RESERVED + ISNULL(A4.RESERVED,0)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)) AS RESERVEDSIZE_MB
	 , CAST(ROUND(A1.DATA * 8 / 1024.00, 2) AS NUMERIC(36, 2)) AS DATASIZE_MB
	 , CAST(ROUND((CASE WHEN (A1.USED + ISNULL(A4.USED,0)) > A1.DATA THEN (A1.USED + ISNULL(A4.USED,0)) - A1.DATA ELSE 0 END) * 8 / 1024.00, 2) AS NUMERIC(36, 2)) AS INDEXSIZE_MB
	 , CAST(ROUND((CASE WHEN (A1.RESERVED + ISNULL(A4.RESERVED,0)) > A1.USED THEN (A1.RESERVED + ISNULL(A4.RESERVED,0)) - A1.USED ELSE 0 END) * 8 / 1024.00, 2) AS NUMERIC(36, 2)) AS UNUSEDSIZE_MB
	 , B.VALUE AS TABLE_COMMENTS
	 , A2.TYPE_DESC
	 , A2.CREATE_DATE
  FROM
    (SELECT PS.OBJECT_ID
	      , SUM (CASE WHEN (PS.INDEX_ID < 2) THEN ROW_COUNT ELSE 0 END) AS [ROWS]
		  , SUM (PS.RESERVED_PAGE_COUNT) AS RESERVED
		  , SUM (CASE WHEN (PS.INDEX_ID < 2) THEN (PS.IN_ROW_DATA_PAGE_COUNT + PS.LOB_USED_PAGE_COUNT + PS.ROW_OVERFLOW_USED_PAGE_COUNT)
                      ELSE (PS.LOB_USED_PAGE_COUNT + PS.ROW_OVERFLOW_USED_PAGE_COUNT) END) AS DATA
          , SUM (PS.USED_PAGE_COUNT) AS USED
       FROM SYS.DM_DB_PARTITION_STATS PS
      GROUP BY PS.OBJECT_ID) AS A1
       LEFT OUTER JOIN 
    (SELECT  IT.PARENT_ID
	      , SUM(PS.RESERVED_PAGE_COUNT) AS RESERVED
		  , SUM(PS.USED_PAGE_COUNT) AS USED
       FROM SYS.DM_DB_PARTITION_STATS PS
      INNER JOIN SYS.INTERNAL_TABLES IT ON (IT.OBJECT_ID = PS.OBJECT_ID)
      WHERE IT.INTERNAL_TYPE IN (202,204)
      GROUP BY IT.PARENT_ID) AS A4 ON (A4.PARENT_ID = A1.OBJECT_ID)
  INNER JOIN SYS.ALL_OBJECTS A2  ON ( A1.OBJECT_ID = A2.OBJECT_ID ) 
   LEFT OUTER JOIN (SELECT OBJECT_ID(OBJNAME) AS TABLE_ID
                         , VALUE 
                      FROM ::FN_LISTEXTENDEDPROPERTY (NULL, 'SCHEMA','DBO','TABLE',NULL,NULL,NULL)
                     UNION ALL
					SELECT OBJECT_ID(OBJNAME) AS TABLE_ID
					     , VALUE 
                      FROM ::FN_LISTEXTENDEDPROPERTY (NULL, 'SCHEMA','FRAMEWKO','TABLE',NULL,NULL,NULL)) B
    ON A2.OBJECT_ID = B.TABLE_ID
 WHERE A2.TYPE <> N'S' 
   AND A2.TYPE <> N'IT'
   AND A2.NAME NOT LIKE 'MSPEER%'
   AND A2.NAME NOT LIKE 'MSPUB%'
   AND A2.NAME NOT LIKE 'SYNCOBJ%'
   AND A2.NAME NOT LIKE 'SYS%'
 ORDER BY RESERVEDSIZE_MB DESC ;
 

--#########################################################
--##### 테이블 코멘트 COMMENT 조회(PR_DBA_TABCOMMENT)
--#########################################################
CREATE PROCEDURE [dbo].[PR_DBA_TABCOMMENT](@I_TABLE_NAME VARCHAR(100))
AS
DECLARE @V_LANG VARCHAR(10);
BEGIN
  SELECT @V_LANG=CASE WHEN patindex('%[ㄱ-힇]%', @I_TABLE_NAME) <> 0 THEN 'KOR' ELSE 'ENG' END ;
  IF (@V_LANG='ENG')
    BEGIN
      SELECT DB_NAME() AS DBNAME
           , O.NAME AS TABLENAME
           , '=====================' AS COLUMNNAME
           , CAST(p.value AS sql_variant) AS COMMENTS
           , '' AS COLUMNTYPE
           , '' AS LENGTH
           , '' AS XPREC
           , '' AS XSCALE
           , '' AS ISNULLABLE
           , '' AS COLLATION_NAME
           , '' AS COLID
           , P.MINOR_ID AS COLUMN_ID
        FROM SYSOBJECTS O (NOLOCK)
        LEFT OUTER JOIN sys.extended_properties p 
          ON p.major_id=O.ID
         AND p.class=1
       WHERE 1=1
         AND OBJECT_NAME(O.ID)=@I_TABLE_NAME
         AND P.minor_id=0
       UNION ALL
      SELECT DB_NAME() AS DBNAME
           , O.NAME AS TABLENAME
           , C.NAME AS COLUMNNAME
           , CAST(p.value AS sql_variant) AS COMMENTS
           , I.DATA_TYPE AS COLUMNTYPE
           , C.LENGTH
           , C.XPREC
           , C.XSCALE
           , CASE WHEN C.ISNULLABLE=0 THEN 'NOT NULL' ELSE 'NULL' END ISNULLABLE
           , I.COLLATION_NAME
           , C.COLID
           , P.minor_id
        FROM SYSOBJECTS O (NOLOCK)
        LEFT OUTER JOIN SYSCOLUMNS C (NOLOCK) 
          ON O.ID = C.ID
        LEFT OUTER JOIN INFORMATION_SCHEMA.COLUMNS I (NOLOCK) 
          ON O.NAME = I.TABLE_NAME 
         AND C.NAME = I.COLUMN_NAME
        LEFT OUTER JOIN sys.extended_properties p 
          ON p.major_id=C.ID
         AND p.minor_id=C.COLID
         AND p.class=1
       WHERE 1=1
         AND OBJECT_NAME(O.ID)=@I_TABLE_NAME
       ORDER BY TABLENAME, P.MINOR_ID
    END
  ELSE
    BEGIN
	  SELECT OBJTYPE OBJECT_TYPE
           , OBJNAME OBJECT_NAME
           , VALUE COMMENTS
        FROM ::FN_LISTEXTENDEDPROPERTY (NULL, 'SCHEMA','DBO','TABLE',NULL,NULL,NULL)
       WHERE CONVERT(VARCHAR, VALUE) LIKE '%'+@I_TABLE_NAME+'%'
	   ORDER BY OBJECT_NAME 
    END
END
GO

--실행(EXAMPLE)
EXEC DBO.PR_DBA_TABCOMMENT CM_TODO_LIST_M
EXEC DBO.PR_DBA_TABCOMMENT 관리
 
 
--#########################################################
--##### 테이블 크기 조회
--#########################################################
DECLARE @TABLE_NAME nvarchar(20)
SELECT @TABLE_NAME = 'CM_ATRZ_TMPLT_VAR_D'

SELECT DB_NAME() AS DB_NAME
     , SCHEMA_NM AS SCHEMA_NAME
     , TABLE_NAME
     , '' AS FILEGROUP
     , ROWS
	 , reservedpages * 8 / 1024 AS RESERVED_MB
     , pages * 8 / 1024         AS DATA_MB
     , (CASE WHEN usedpages > pages THEN (usedpages - pages) ELSE 0 END) * 8 / 1024 AS INDEX_SIZE_MB
     , (CASE WHEN reservedpages > usedpages THEN (reservedpages - usedpages) ELSE 0 END) * 8 / 1024 AS UNUSED_MB
     , GETDATE() AS DATECACHED
FROM (
       SELECT schema_name(aa.schema_id) as schema_nm
             ,object_name(aa.object_id) as table_name 
             ,sum(aa.rows)              as rows
             ,sum(aa.reserved_page_count)     as reservedpages
             ,sum(aa.used_page_count)         as usedpages
             ,sum(aa.pages)             as pages
       FROM (
               SELECT b.schema_id
                    , a.object_id
                    , a.index_id
                    , a.reserved_page_count   
                    , a.used_page_count    
                    , CASE  WHEN (a.index_id < 2) 
                                      THEN (a.in_row_data_page_count + a.lob_used_page_count + a.row_overflow_used_page_count)  
                                      ELSE 0   
                                 END pages 
                    , CASE  WHEN (a.index_id < 2) THEN a.row_count  ELSE 0  END  rows
               FROM sys.dm_db_partition_stats as a WITH(NOLOCK)
                   ,sys.objects as b WITH(NOLOCK)
               WHERE a.object_id = b.object_id 
               AND b.type ='U'
            ) aa
       group by aa.schema_id, aa.object_id
   ) spu
WHERE 1=1
--AND TABLE_NAME=@TABLE_NAME
ORDER BY reserved_mb DESC
GO



--#########################################################
--##### 테이블 크기 조회(PROCEDURE, PR_DBA_TABSIZE)
--#########################################################
CREATE PROCEDURE [dbo].[PR_DBA_TABSIZE](@I_TABLE_NAME VARCHAR(100))
AS
SELECT DB_NAME() as db_name
     , schema_nm
     , table_name
     , '' as filegroup
     , rows
     , STR ( reservedpages * 8 / 1024, 15, 0)  as reserved_mb
     , STR ( pages * 8 / 1024, 15, 0) as data_mb
     , STR ((CASE WHEN usedpages > pages THEN (usedpages - pages) ELSE 0 END) * 8 / 1024, 15, 0) as index_size_mb
     , STR ((CASE WHEN reservedpages > usedpages THEN (reservedpages - usedpages) ELSE 0 END) * 8 / 1024, 15, 0) as unused_mb
     , getdate() as datecached
FROM (
       SELECT schema_name(aa.schema_id) as schema_nm
             ,object_name(aa.object_id) as table_name 
             ,sum(aa.rows)              as rows
             ,sum(aa.reserved_page_count)     as reservedpages
             ,sum(aa.used_page_count)         as usedpages
             ,sum(aa.pages)             as pages
       FROM (
               SELECT b.schema_id
                    , a.object_id
                    , a.index_id
                    , a.reserved_page_count   
                    , a.used_page_count    
                    , CASE  WHEN (a.index_id < 2) 
                                      THEN (a.in_row_data_page_count + a.lob_used_page_count + a.row_overflow_used_page_count)  
                                      ELSE 0   
                                 END pages 
                    , CASE  WHEN (a.index_id < 2) THEN a.row_count  ELSE 0  END  rows
               FROM sys.dm_db_partition_stats as a
                   ,sys.objects as b 
               WHERE a.object_id = b.object_id 
               AND b.type ='U'
            ) aa
       group by aa.schema_id, aa.object_id
   ) spu
WHERE 1=1
AND TABLE_NAME=@I_TABLE_NAME
ORDER BY 1,2,reserved_mb DESC
GO

EXEC PR_DBA_TABSIZE FI_CUST_REQ_ADDR_D
 

--#########################################################
--##### 컬럼 정보 조회(COMMENT 포함)
--#########################################################
DECLARE @TABLE_NAME VARCHAR(100)
--DECLARE @COLUMN_NAME VARCHAR(100)
SET @TABLE_NAME='CO_INVT_BDGT_D'
--SET @COLUMN_NAME='COMP_CD'

WITH COLUMN_INFO
AS
(SELECT DB_NAME() AS DB_NAME
     , I.TABLE_SCHEMA
     , O.NAME AS TABLE_NAME
     , C.NAME AS COLUMN_NAME
     , CAST(p.value AS sql_variant) AS ExtendedPropertyValue
     , I.ORDINAL_POSITION 
     , I.DATA_TYPE AS DATA_TYPE
     , C.LENGTH
     , C.XPREC
     , C.XSCALE
     , CASE WHEN C.ISNULLABLE=0 THEN 'Y' ELSE '' END AS [NOT NULL]
     , I.COLLATION_NAME
     , CASE WHEN Q.COLUMN_NAME IS NOT NULL THEN 'Y'
       ELSE 'N' END IS_PK
	 , CASE WHEN C.STATUS=128 THEN 'Y' ELSE 'N' END IS_IDENTITY
  FROM SYSOBJECTS O (NOLOCK)
 INNER JOIN SYSCOLUMNS C (NOLOCK)
    ON O.ID = C.ID
 INNER JOIN INFORMATION_SCHEMA.COLUMNS I (NOLOCK)
    ON O.NAME = I.TABLE_NAME 
   AND C.NAME = I.COLUMN_NAME
  LEFT OUTER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE  Q (NOLOCK)
    ON Q.TABLE_NAME = I.TABLE_NAME
   AND Q.COLUMN_NAME = I.COLUMN_NAME
  LEFT OUTER JOIN sys.extended_properties p 
    ON p.major_id=C.ID 
   AND p.minor_id=C.COLID
   AND p.class=1
 WHERE 1=1
   --AND O.NAME=@TABLE_NAME
   --AND C.NAME=@COLUMN_NAME
 --ORDER BY DB_NAME, TABLE_NAME, ORDINAL_POSITION
)
SELECT *
  FROM COLUMN_INFO
 ORDER BY DB_NAME, TABLE_NAME, ORDINAL_POSITION
GO



--#########################################################
--##### PK명, PK 컬럼, PK COLUMN 조회, PK 백업
--#########################################################
SELECT 'ALTER TABLE '+TABLE_NAME+' DROP CONSTRAINT '+CONSTRAINT_NAME AS 'DROP_CONST_STMT'
, 'ALTER TABLE '+TABLE_NAME+' ADD CONSTRAINT '+CONSTRAINT_NAME+' PRIMARY KEY('+KEY_COLUMN+')' AS 'CREATE_CONST_STMT'
, TABLE_NAME
, CONSTRAINT_NAME
, KEY_COLUMN	
FROM (SELECT TABLE_NAME, CONSTRAINT_NAME, STRING_AGG(COLUMN_NAME,', ') WITHIN GROUP(ORDER BY ORDINAL_POSITION) KEY_COLUMN
        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
		WHERE TABLE_NAME IN
		(,'WM_OUT_D'
		,'WM_OUT_OPEN_D'
		,'WM_STGDS_D'
		,'WM_STGDS_IN_D'
		,'WM_STGDS_IN_SETL_M'
		,'WM_STGDS_M'
		,'WM_STGDS_OUT_D'
		,'WM_STGDS_RTNG_REQ_D'
		,'WM_STGDS_RTNG_REQ_M')
		GROUP BY TABLE_NAME, CONSTRAINT_NAME) A ;


--#########################################################
--##### 시스템 컬럼 정상여부 확인
--#########################################################
WITH COLUMN_INFO
AS
(SELECT DB_NAME() AS DB_NAME
     , I.TABLE_SCHEMA
     , O.NAME AS TABLE_NAME
     , C.NAME AS COLUMN_NAME
     , CAST(p.value AS sql_variant) AS ExtendedPropertyValue
     , I.ORDINAL_POSITION 
     , I.DATA_TYPE AS DATA_TYPE
     , C.LENGTH
     , C.XPREC
     , C.XSCALE
     , CASE WHEN C.ISNULLABLE=0 THEN 'NOT NULL' ELSE 'NULLABLE' END IS_NULLABLE
     , I.COLLATION_NAME
     , CASE WHEN Q.COLUMN_NAME IS NOT NULL THEN 'Y'
       ELSE 'N' END IS_PK
	 , CASE WHEN C.STATUS=128 THEN 'Y' ELSE 'N' END IS_IDENTITY
  FROM SYSOBJECTS O (NOLOCK)
 INNER JOIN SYSCOLUMNS C (NOLOCK)
    ON O.ID = C.ID
 INNER JOIN INFORMATION_SCHEMA.COLUMNS I (NOLOCK)
    ON O.NAME = I.TABLE_NAME 
   AND C.NAME = I.COLUMN_NAME
  LEFT OUTER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE  Q (NOLOCK)
    ON Q.TABLE_NAME = I.TABLE_NAME
   AND Q.COLUMN_NAME = I.COLUMN_NAME
  LEFT OUTER JOIN sys.extended_properties p 
    ON p.major_id=C.ID 
   AND p.minor_id=C.COLID
   AND p.class=1
 WHERE 1=1
   --AND O.NAME=@TABLE_NAME
   --AND C.NAME=@COLUMN_NAME
 --ORDER BY DB_NAME, TABLE_NAME, ORDINAL_POSITION
)
, MAX_COLUMN_POSITION
AS
(SELECT DB_NAME, TABLE_SCHEMA, TABLE_NAME, MAX(ORDINAL_POSITION) MAX_ORDINAL_POSITION
  FROM COLUMN_INFO
GROUP BY DB_NAME, TABLE_SCHEMA, TABLE_NAME
)
SELECT *
FROM (
SELECT C.DB_NAME
, C.TABLE_SCHEMA
, C.TABLE_NAME
, C.COLUMN_NAME
, C.ORDINAL_POSITION
, C.MAX_ORDINAL_POSITION
, CASE WHEN C.ORDINAL_POSITION=C.MAX_ORDINAL_POSITION-5 AND C.COLUMN_NAME='REG_MENU_ID' THEN 'Y'
       WHEN C.ORDINAL_POSITION=C.MAX_ORDINAL_POSITION-4 AND C.COLUMN_NAME='REG_ID' THEN 'Y'
	   WHEN C.ORDINAL_POSITION=C.MAX_ORDINAL_POSITION-3 AND C.COLUMN_NAME='REG_DTTM' THEN 'Y'
	   WHEN C.ORDINAL_POSITION=C.MAX_ORDINAL_POSITION-2 AND C.COLUMN_NAME='MOD_MENU_ID' THEN 'Y'
	   WHEN C.ORDINAL_POSITION=C.MAX_ORDINAL_POSITION-1 AND C.COLUMN_NAME='MOD_ID' THEN 'Y'
	   WHEN C.ORDINAL_POSITION=C.MAX_ORDINAL_POSITION   AND C.COLUMN_NAME='MOD_DTTM' THEN 'Y'
	   ELSE 'N' END SYSTEM_COLUMN_YN
FROM (SELECT A.DB_NAME, A.TABLE_SCHEMA, A.TABLE_NAME, A.COLUMN_NAME, A.ORDINAL_POSITION, B.MAX_ORDINAL_POSITION
        FROM COLUMN_INFO A 
        JOIN MAX_COLUMN_POSITION B
          ON A.DB_NAME=B.DB_NAME
         AND A.TABLE_SCHEMA=B.TABLE_SCHEMA
         AND A.TABLE_NAME=B.TABLE_NAME
       WHERE 1=1
         AND A.ORDINAL_POSITION > (SELECT MAX_ORDINAL_POSITION-6 
                                     FROM MAX_COLUMN_POSITION B 
                                    WHERE B.DB_NAME = A.DB_NAME
                                      AND B.TABLE_SCHEMA = A.TABLE_SCHEMA
                                      AND B.TABLE_NAME = A.TABLE_NAME)
         AND A.ORDINAL_POSITION <= (SELECT MAX_ORDINAL_POSITION
                                     FROM MAX_COLUMN_POSITION B 
                                    WHERE B.DB_NAME = A.DB_NAME
                                      AND B.TABLE_SCHEMA = A.TABLE_SCHEMA
                                      AND B.TABLE_NAME = A.TABLE_NAME)) C
) D
WHERE D.SYSTEM_COLUMN_YN='N'
  AND D.TABLE_SCHEMA ='DBO'
  AND D.TABLE_NAME NOT LIKE 'DBA%'
  AND D.TABLE_NAME NOT LIKE 'TEMP%'
  AND D.TABLE_NAME NOT LIKE 'TMP%'
ORDER BY D.DB_NAME, D.TABLE_SCHEMA, D.TABLE_NAME, D.ORDINAL_POSITION
GO

--#########################################################
--##### 테이블 코멘트COMMENT 조회(PR_DBA_TABCOLUMNS)
--#########################################################

SELECT *
FROM (
SELECT OBJ.NAME AS TABLE_NAME
     , EXT.VALUE AS COMMENT
	 , EXT.NAME EXTENDEDPROPERTY
FROM SYSOBJECTS OBJ
JOIN sys.extended_properties EXT
ON OBJ.ID = EXT.MAJOR_ID
WHERE XTYPE='U' 
AND EXT.MINOR_ID = 0 ) A
WHERE COMMENT LIKE '%회원%';



CREATE PROCEDURE [dbo].[PR_DBA_TABCOLUMNS](@I_TABLE_NAME VARCHAR(100))
AS
SELECT 
DB_NAME() AS DBNAME
,O.NAME AS TABLENAME
,C.NAME AS COLUMNNAME
--,(SELECT CAST(p.value AS sql_variant) AS ExtendedPropertyValue FROM sys.extended_properties p WHERE 
, CAST(p.value AS sql_variant) AS ExtendedPropertyValue
, I.DATA_TYPE AS COLUMNTYPE
, C.LENGTH
, C.XPREC
, C.XSCALE
, CASE WHEN C.ISNULLABLE=0 THEN 'NOT NULL' ELSE 'NULL' END ISNULLABLE
, I.COLLATION_NAME
FROM SYSOBJECTS O (NOLOCK)
INNER JOIN SYSCOLUMNS C (NOLOCK) ON O.ID = C.ID
INNER JOIN INFORMATION_SCHEMA.COLUMNS I (NOLOCK) ON O.NAME = I.TABLE_NAME AND C.NAME = I.COLUMN_NAME
LEFT OUTER JOIN sys.extended_properties p ON p.major_id=C.ID 
                                          AND p.minor_id=C.COLID
										  AND p.class=1
WHERE 1=1
--AND I.DATA_TYPE ='VARBINARY'
--AND OBJECT_NAME(O.ID) = 'T_TRAN_LOG'
AND OBJECT_NAME(O.ID)=@I_TABLE_NAME
ORDER BY TABLENAME, C.COLID




--#########################################################
--##### 컬럼 코멘트COMMENT 조회(PR_DBA_COLCOMMENT)
--#########################################################
CREATE PROCEDURE [dbo].[PR_DBA_COLCOMMENT](@I_COLUMN_NAME VARCHAR(100))
AS
DECLARE @V_LANG VARCHAR(10);
BEGIN
  SELECT @V_LANG=CASE WHEN patindex('%[ㄱ-힇]%', @I_COLUMN_NAME) <> 0 THEN 'KOR' ELSE 'ENG' END ;
  IF (@V_LANG='ENG')
  BEGIN
    SELECT A.TABLE_CATALOG AS [DB_NAME]
         , A.TABLE_SCHEMA AS [SCHEMA_NAME]
         , A.TABLE_NAME
         , C.VALUE TABLE_COMMENT
         , A.COLUMN_NAME
         , B.VALUE COLUMN_COMMENT
         , A.COLUMN_DEFAULT AS [DEFAULT_VALUE]
         , A.IS_NULLABLE
         , A.DATA_TYPE
         , CASE WHEN A.DATA_TYPE IN ('CHAR','VARCHAR','NVARCHAR','NCHAR','TEXT') THEN CONVERT(VARCHAR, A.CHARACTER_MAXIMUM_LENGTH)
                WHEN A.DATA_TYPE IN ('INT','FLOAT','NUMERIC','BIGINT') THEN CONVERT(VARCHAR, A.NUMERIC_PRECISION) + ',' + CONVERT(VARCHAR, A.NUMERIC_SCALE)
                WHEN A.DATA_TYPE IN ('DATE','DATETIME','DATETIME2','DATETIMEOFFSET') THEN CONVERT(VARCHAR, A.DATETIME_PRECISION)
                WHEN A.DATA_TYPE IN ('VARBINARY') THEN '' END AS [DATA_LEN]
           FROM INFORMATION_SCHEMA.COLUMNS A
           LEFT JOIN SYS.EXTENDED_PROPERTIES B
             ON B.MAJOR_ID = OBJECT_ID(A.TABLE_NAME)
            AND B.MINOR_ID = A.ORDINAL_POSITION
           LEFT JOIN (SELECT OBJECT_ID(OBJNAME) TABLE_ID
    	                   , VALUE
                        FROM ::FN_LISTEXTENDEDPROPERTY(NULL,'USER','DBO','TABLE',NULL,NULL,NULL)) C
             ON C.TABLE_ID=OBJECT_ID(A.TABLE_NAME)
          WHERE A.COLUMN_NAME = @I_COLUMN_NAME
          ORDER BY B.VALUE, A.TABLE_CATALOG, A.TABLE_SCHEMA, A.TABLE_NAME
  END
  ELSE
  BEGIN
    SELECT A.TABLE_CATALOG AS [DB_NAME]
         , A.TABLE_SCHEMA AS [SCHEMA_NAME]
         , A.TABLE_NAME
         , C.VALUE TABLE_COMMENT
         , A.COLUMN_NAME
         , B.VALUE COLUMN_COMMENT
         , A.COLUMN_DEFAULT AS [DEFAULT_VALUE]
         , A.IS_NULLABLE
         , A.DATA_TYPE
         , CASE WHEN A.DATA_TYPE IN ('CHAR','VARCHAR','NVARCHAR','NCHAR','TEXT') THEN CONVERT(VARCHAR, A.CHARACTER_MAXIMUM_LENGTH)
                WHEN A.DATA_TYPE IN ('INT','FLOAT','NUMERIC','BIGINT') THEN CONVERT(VARCHAR, A.NUMERIC_PRECISION) + ',' + CONVERT(VARCHAR, A.NUMERIC_SCALE)
                WHEN A.DATA_TYPE IN ('DATE','DATETIME','DATETIME2','DATETIMEOFFSET') THEN CONVERT(VARCHAR, A.DATETIME_PRECISION)
                WHEN A.DATA_TYPE IN ('VARBINARY') THEN '' END AS [DATA_LEN]
           FROM INFORMATION_SCHEMA.COLUMNS A
           LEFT JOIN SYS.EXTENDED_PROPERTIES B
             ON B.MAJOR_ID = OBJECT_ID(A.TABLE_NAME)
            AND B.MINOR_ID = A.ORDINAL_POSITION
           LEFT JOIN (SELECT OBJECT_ID(OBJNAME) TABLE_ID
    	                   , VALUE
                        FROM ::FN_LISTEXTENDEDPROPERTY(NULL,'USER','DBO','TABLE',NULL,NULL,NULL)) C
             ON C.TABLE_ID=OBJECT_ID(A.TABLE_NAME)
          WHERE CONVERT(VARCHAR, B.VALUE) LIKE '%'+@I_COLUMN_NAME+'%'
          ORDER BY B.VALUE, A.TABLE_CATALOG, A.TABLE_SCHEMA, A.TABLE_NAME
  END
END

EXEC PR_DBA_COLCOMMENT COMP_CD
EXEC PR_DBA_COLCOMMENT 관리
 

--#########################################################
--##### 컬럼 정보 조회(COMMENT 포함)
--#########################################################
DECLARE @TABLE_NAME VARCHAR(100)
SELECT @TABLE_NAME='CO_INVT_M'

SELECT 
DB_NAME() AS DBNAME
,O.NAME AS TABLENAME
,C.NAME AS COLUMNNAME
--,(SELECT CAST(p.value AS sql_variant) AS ExtendedPropertyValue FROM sys.extended_properties p WHERE 
, CAST(p.value AS sql_variant) AS ExtendedPropertyValue
, I.DATA_TYPE AS COLUMNTYPE
, C.LENGTH
, C.XPREC
, C.XSCALE
, CASE WHEN C.ISNULLABLE=0 THEN 'NOT NULL' ELSE 'NULL' END ISNULLABLE
, I.COLLATION_NAME
FROM SYSOBJECTS O (NOLOCK)
INNER JOIN SYSCOLUMNS C (NOLOCK) ON O.ID = C.ID
INNER JOIN INFORMATION_SCHEMA.COLUMNS I (NOLOCK) ON O.NAME = I.TABLE_NAME AND C.NAME = I.COLUMN_NAME
LEFT OUTER JOIN sys.extended_properties p ON p.major_id=C.ID 
                                          AND p.minor_id=C.COLID
										  AND p.class=1
WHERE 1=1
--AND I.DATA_TYPE ='VARBINARY'
--AND OBJECT_NAME(O.ID) = 'T_TRAN_LOG'
AND OBJECT_NAME(O.ID)=@TABLE_NAME
ORDER BY TABLENAME, C.COLID ;


--#########################################################
--##### 변경 관리,PR_DBA_RECREATETAB
--#########################################################
ALTER PROCEDURE PR_DBA_RECREATETAB(@I_TABLE_NAME VARCHAR(50))
AS
BEGIN
    BEGIN TRY
	    --
	    DECLARE @V_SQL_COUNT     VARCHAR(200)
		      , @V_SQL_BACKUP    VARCHAR(200)
			  , @V_SQL_GETPRIVS  VARCHAR(200)
			  , @V_SQL_RESTORE   VARCHAR(200) ;
        SET @V_SQL_COUNT     = 'SELECT COUNT(*) FROM '+@I_TABLE_NAME+CHAR(10)+'GO' ;
		SET @V_SQL_BACKUP    = 'PR_DBA_BACKUPTAB '+@I_TABLE_NAME+','+@I_TABLE_NAME+'_BAK_'+FORMAT(GETDATE(),'yyyyMMdd')+CHAR(10)+'GO';
		SET @V_SQL_GETPRIVS  = 'PR_DBA_GETPRIVS '+@I_TABLE_NAME+CHAR(10)+'GO';
		SET @V_SQL_RESTORE   = 'PR_DBA_RESTORETAB '+@I_TABLE_NAME+'_BAK_'+FORMAT(GETDATE(),'yyyyMMdd')+','+@I_TABLE_NAME+CHAR(10)+'GO';

		/* PRINT SQL */
		PRINT @V_SQL_COUNT ;
		PRINT @V_SQL_BACKUP ;
		PRINT @V_SQL_GETPRIVS ;
		PRINT @V_SQL_RESTORE ;
    END TRY
	BEGIN CATCH
	    --
	END CATCH
END

PR_DBA_RECREATETAB CM_DEPT_M


--#########################################################
--##### 컬럼 COMMENTS 조회
--#########################################################
DECLARE @TABLE_NAME nvarchar(20)
SELECT @TABLE_NAME = 'CM_ATRZ_TMPLT_VAR_D'

SELECT
   SCHEMA_NAME(tbl.schema_id) AS SchemaName,	
   tbl.name AS TableName, 
   clmns.name AS ColumnName,
   p.name AS ExtendedPropertyName,
   CAST(p.value AS sql_variant) AS ExtendedPropertyValue
FROM
   sys.tables AS tbl
   INNER JOIN sys.all_columns AS clmns ON clmns.object_id=tbl.object_id
   INNER JOIN sys.extended_properties AS p ON p.major_id=tbl.object_id 
                                          AND p.minor_id=clmns.column_id 
										  AND p.class=1
WHERE 1=1
--AND  SCHEMA_NAME(tbl.schema_id)='Pays'  /* SCHEMA �� */
AND  tbl.name IN (@TABLE_NAME)               /* TABLE �� */
--AND clmns.name='SUBMALL_ID'               /* COLUMN �� */
--AND p.name='MS_Description'             /* DESCRIPTION �� */
ORDER BY tbl.name, clmns.column_id
GO


--#########################################################
--##### 컬럼 코멘트COMMENT 추가/변경
--#########################################################
--추가
EXEC sp_addextendedproperty 
	@name=N'MS_Description', @value=N'사용여부', 
	@level0type=N'SCHEMA', @level0name=N'dbo', 
	@level1type=N'TABLE', @level1name=N'CO_INVT_M', 
	@level2type=N'COLUMN', @level2name=N'USE_YN'
GO

--변경
EXEC sp_updateextendedproperty 
	@name=N'MS_Description', @value=N'차대변코드', 
	@level0type=N'SCHEMA', @level0name=N'dbo', 
	@level1type=N'TABLE', @level1name=N'co_consacnt_m', 
	@level2type=N'COLUMN', @level2name=N'DRCR_CD'
GO



--#########################################################
--##### 컬럼 코멘트 COMMENT 문장 추출, 코멘트 추출, COMMENT 추출
--#########################################################
SELECT u.name + '.' + t.name AS [table]
     , td.value AS [table_desc]
	 , c.name AS [column]
	 , cd.value AS [column_desc]
	 , 'EXEC sp_updateextendedproperty @name=N''MS_Description'', @value=N'''+CONVERT(VARCHAR,cd.value)+''', @level0type=N''SCHEMA'', @level0name=N''dbo'', @level1type=N''TABLE'', @level1name=N'''+t.name+''', @level2type=N''COLUMN'', @level2name=N'''+c.name+'''' AS UPDATE_STMT
	 , 'EXEC sp_addextendedproperty @name=N''MS_Description'', @value=N'''+CONVERT(VARCHAR,cd.value)+''', @level0type=N''SCHEMA'', @level0name=N''dbo'', @level1type=N''TABLE'', @level1name=N'''+t.name+''', @level2type=N''COLUMN'', @level2name=N'''+c.name+'''' AS ADD_STMT
FROM        sysobjects t
INNER JOIN  sysusers u
    ON      u.uid = t.uid
LEFT OUTER JOIN sys.extended_properties td
    ON      td.major_id = t.id
    AND     td.minor_id = 0
    AND     td.name = 'MS_Description'
INNER JOIN  syscolumns c
    ON      c.id = t.id
LEFT OUTER JOIN sys.extended_properties cd
    ON      cd.major_id = c.id
    AND     cd.minor_id = c.colid
    AND     cd.name = 'MS_Description'
WHERE t.type = 'u'
and t.name like 'SA%'
and t.name IN ('SA_TAXBIL_T')
ORDER BY    t.name, c.colorder ;




--#########################################################
--##### 인덱스 조회
--#########################################################
SELECT *
FROM (
SELECT (SELECT D.TABLE_CATALOG FROM INFORMATION_SCHEMA.TABLES D WHERE D.TABLE_SCHEMA=C.NAME AND D.TABLE_NAME=B.NAME) AS DB_NAME
     , 'INDEX' AS OBJECT_TYPE
     , C.NAME SCHEMA_NAME
     , B.NAME TABLE_NAME
     , A.NAME INDEX_NAME
     , A.TYPE_DESC IS_CLUSTERED
     , CASE WHEN IS_PRIMARY_KEY=1 THEN 'Y' ELSE 'N' END IS_PRIMARY
     , CASE WHEN IS_UNIQUE=1 THEN 'Y' ELSE 'N' END IS_UNIQUE
-- , STATS_DATE(A.OBJECT_ID, INDEX_ID) AS INDEX_CREATE_DATE
     , CASE WHEN STATS_DATE(A.OBJECT_ID, INDEX_ID) IS NULL THEN B.CREATE_DATE
            ELSE STATS_DATE(A.OBJECT_ID, INDEX_ID) END AS  INDEX_CREATION_DATE
  FROM SYS.INDEXES A
  JOIN SYS.ALL_OBJECTS  B
    ON B.OBJECT_ID = A.OBJECT_ID 
  JOIN (SELECT SCHEMA_ID, NAME FROM SYS.schemas) C
    ON C.SCHEMA_ID = B.SCHEMA_ID ) Z
WHERE 1=1
  AND TABLE_NAME NOT LIKE 'MSpeer%'
  AND TABLE_NAME NOT LIKE 'MSpub%'
  AND SCHEMA_NAME NOT LIKE 'syncobj%'
  AND SCHEMA_NAME NOT LIKE 'sys%'
  AND INDEX_NAME IS NOT NULL 
ORDER BY DB_NAME, SCHEMA_NAME, TABLE_NAME, INDEX_NAME ;


--#########################################################
--##### 인덱스 DDL, INDEX DLL, 인덱스 백업, 인덱스 컬럼 전체 (딕셔너리 DICTIONARY 활용)
--#########################################################
WITH IDX_INFO
    ( DB_NM, SCHEMA_NM, TBL_NM, OBJECT_ID,  IDX_NM, IDX_ID, COL_NM, [NO], PARTITION_ORDINAL, [DES]
    , IS_INCLUDED_COLUMN, TYPE_DESC, [UNIQUE], [KEY], FGNAME
	) 
AS
(
SELECT DB_NAME() DB_NM
      ,SCHEMA_NAME(SCHEMA_ID) SCHEMA_NM
      ,B.NAME TBL_NM
	  , A.OBJECT_ID
	  , A.NAME IDX_NM
	  , A.INDEX_ID
	  , COL_NAME(C.OBJECT_ID,COLUMN_ID) COL_NM 
	  , KEY_ORDINAL [NO]
      , PARTITION_ORDINAL
	  , CASE WHEN IS_DESCENDING_KEY = 1 THEN '(-)' 
		     WHEN IS_DESCENDING_KEY = 0 THEN '' END  [DES]
	  , IS_INCLUDED_COLUMN
	  , A.TYPE_DESC
	  , CASE WHEN A.IS_UNIQUE = 1 THEN 'UNIQUE'
	         WHEN A.IS_UNIQUE = 0 THEN '' END [UNIQUE]
	  , CASE WHEN A.IS_UNIQUE_CONSTRAINT = 1 THEN 'UNIQUE KEY'
	         WHEN A.IS_UNIQUE_CONSTRAINT = 0 THEN '' END 
      + CASE WHEN A.IS_PRIMARY_KEY =1 THEN 'PRIMARY KEY'
	         WHEN A.IS_PRIMARY_KEY =0 THEN '' END [KEY]
	  , FG.GROUPNAME FGNAME
FROM SYS.INDEXES A
	JOIN SYS.OBJECTS B ON A.OBJECT_ID = B.OBJECT_ID
	JOIN SYS.INDEX_COLUMNS C ON A.OBJECT_ID = C.OBJECT_ID AND A.INDEX_ID = C.INDEX_ID
	JOIN SYSINDEXES IFG ON A.OBJECT_ID = IFG.ID AND A.INDEX_ID = IFG.INDID
	LEFT OUTER JOIN SYS.SYSFILEGROUPS AS FG ON IFG.GROUPID=FG.GROUPID 
WHERE B.TYPE = 'U' 
)
SELECT TBL_NM, IDX_NM, [INCLUDED_COLUMN]
, 'DROP INDEX '+TRIM(IDX_NM COLLATE Korean_Wansung_CI_AS)+' ON '+TBL_NM AS DROP_STMT
, 'CREATE '+[UNIQUE]+' '+TYPE_DESC+' INDEX '+TRIM(IDX_NM COLLATE Korean_Wansung_CI_AS)+' ON '+TBL_NM+'('+TRIM([COLUMN])+') '
   +CASE WHEN [INCLUDED_COLUMN]<>'' THEN ' INCLUDE('+[INCLUDED_COLUMN]+')' ELSE '' END + ' WITH (MAXDOP=4) ON FG_'+DB_NAME()+'_IDX' AS CREATE_STMT
--SELECT 'DROP INDEX '+TRIM(IDX_NM COLLATE Korean_Wansung_CI_AS)+' ON '+TBL_NM AS DROP_STMT
--     , 'CREATE '+[UNIQUE]+' '+TYPE_DESC+' INDEX '+TRIM(IDX_NM COLLATE Korean_Wansung_CI_AS)+' ON '+TBL_NM+'('+TRIM([COLUMN])+')' AS CREATE_STMT 
--     , DB_NM, SCHEMA_NM, TBL_NM, IDX_NM, IDX_ID, TYPE_DESC, [UNIQUE], [KEY], [COLUMN], [INCLUDED_COLUMN], FGNAME
FROM (SELECT DB_NM, SCHEMA_NM, TBL_NM, IDX_NM, IDX_ID, TYPE_DESC, [UNIQUE],  [KEY]
	, STUFF(
			(
				SELECT 
					', ',+CAST(COL_NM AS VARCHAR(100)) + ' ' + [DES] 
				FROM IDX_INFO A2 
				WHERE A2.TBL_NM = B2.TBL_NM AND A2.IDX_NM = B2.IDX_NM
				AND A2.IS_INCLUDED_COLUMN = 0
				ORDER BY TBL_NM, IDX_NM, [NO]
				FOR XML PATH('')
			 ),1,1,''
		  ) [COLUMN]
	, ISNULL(STUFF(
			(
				SELECT 
					', ',+CAST(COL_NM AS VARCHAR(100)) + ' ' 
				FROM IDX_INFO A2 
				WHERE A2.TBL_NM = B2.TBL_NM AND A2.IDX_NM = B2.IDX_NM
				AND A2.IS_INCLUDED_COLUMN = 1
				ORDER BY TBL_NM, IDX_NM, [NO]
				FOR XML PATH('')
			 ),1,1,''
		  ), '') [INCLUDED_COLUMN]
   , FGNAME
FROM IDX_INFO B2 
	JOIN SYS.STATS B WITH (NOLOCK) ON B2.OBJECT_ID = B.OBJECT_ID
WHERE 1=1
AND TYPE_DESC = 'NONCLUSTERED'
GROUP BY DB_NM, SCHEMA_NM, TBL_NM, IDX_NM, IDX_ID, TYPE_DESC, [UNIQUE],  [KEY], FGNAME) A
WHERE 1=1
  --AND TBL_NM = 'IF_PN_PLM_APRL_MOLD_RCV_M'
  --AND IDX_NM = 'IX_IF_PN_PLM_APRL_MOLD_RCV_M_01'
  --AND [INCLUDED_COLUMN] <> ''
ORDER BY DB_NM, SCHEMA_NM, TBL_NM, IDX_ID
GO

--#########################################################
--##### 인덱스 DDL 조회(DBA_IND_COLUMNS 사용)
--#########################################################

WITH MAX_DTTM
AS
(SELECT SCHEMA_NAME, TABLE_NAME, INDEX_NAME, MAX(SNAP_DTTM) MAX_SNAP_DTTM
   FROM DBA_IND_COLUMNS
  WHERE 1=1
  --AND TABLE_NAME LIKE 'EV%'
  GROUP BY SCHEMA_NAME, TABLE_NAME, INDEX_NAME)
SELECT DIC.TABLE_NAME
, DIC.INDEX_NAME
, CONCAT('CREATE ',DIC.UNIQUENESS, ' ', DIC.INDEX_TYPE, ' INDEX ', DIC.INDEX_NAME, ' ON ', DIC.SCHEMA_NAME, '.', DIC.TABLE_NAME, '(', DIC.INDEX_COLUMN, ')'
             , CASE WHEN DATALENGTH(TRIM(DIC.INCLUDE_COLUMN))<>0 THEN 'INCLUDE ('+DIC.INCLUDE_COLUMN+')' ELSE '' END
, ' WITH (', DIC.INDEX_OPTION, ') ', CASE WHEN DIC.FILE_GROUP_ID = 1 THEN '' ELSE 'ON '+FILE_NAME(DIC.FILE_GROUP_ID) END) CREATE_STMT
     , DIC.SNAP_DTTM
, MT.MAX_SNAP_DTTM
  FROM DBA_IND_COLUMNS DIC
  JOIN MAX_DTTM MT
    ON DIC.SNAP_DTTM = MT.MAX_SNAP_DTTM
   AND DIC.SCHEMA_NAME = MT.SCHEMA_NAME
   AND DIC.TABLE_NAME = MT.TABLE_NAME
   AND DIC.INDEX_NAME = MT.INDEX_NAME
 WHERE 1=1
   --AND MT.TABLE_NAME='TEST'
GO


--DBA_IND_COLUMNS 기준 미생성 인덱스 확인
WITH MAX_DTTM
AS
(SELECT SCHEMA_NAME, TABLE_NAME, INDEX_NAME, MAX(SNAP_DTTM) MAX_SNAP_DTTM
   FROM DBA_IND_COLUMNS
  WHERE 1=1
  --AND TABLE_NAME LIKE 'EV%'
  GROUP BY SCHEMA_NAME, TABLE_NAME, INDEX_NAME)
SELECT DIC.TABLE_NAME
, DIC.INDEX_NAME
, CONCAT('CREATE ',DIC.UNIQUENESS, ' ', DIC.INDEX_TYPE, ' INDEX ', DIC.INDEX_NAME, ' ON ', DIC.SCHEMA_NAME, '.', DIC.TABLE_NAME, '(', DIC.INDEX_COLUMN, ')'
             , CASE WHEN DATALENGTH(TRIM(DIC.INCLUDE_COLUMN))<>0 THEN 'INCLUDE ('+DIC.INCLUDE_COLUMN+')' ELSE '' END
, ' WITH (', DIC.INDEX_OPTION, ') ', CASE WHEN DIC.FILE_GROUP_ID = 1 THEN '' ELSE 'ON '+FILE_NAME(DIC.FILE_GROUP_ID) END) CREATE_STMT
     , DIC.SNAP_DTTM
, MT.MAX_SNAP_DTTM
  FROM DBA_IND_COLUMNS DIC
  JOIN MAX_DTTM MT
    ON DIC.SNAP_DTTM = MT.MAX_SNAP_DTTM
   AND DIC.SCHEMA_NAME = MT.SCHEMA_NAME
   AND DIC.TABLE_NAME = MT.TABLE_NAME
   AND DIC.INDEX_NAME = MT.INDEX_NAME
 WHERE 1=1
   AND DIC.INDEX_NAME IN (SELECT INDEX_NAME
                            FROM DBA_IND_COLUMNS
							EXCEPT
						  SELECT NAME
						    FROM SYS.INDEXES )
   --AND MT.TABLE_NAME='TEST'
GO





--#########################################################
--##### 인덱스 DDL 추출 프로시저(PK 인덱스 제외)
--#########################################################
USE CRM
GO

CREATE PROCEDURE PR_DBA_GETINDEX
AS
BEGIN
    DECLARE @SCHEMANAME VARCHAR(100)DECLARE @TABLENAME VARCHAR(256)
	DECLARE @INDEXNAME VARCHAR(256)
	DECLARE @COLUMNNAME VARCHAR(100)
	DECLARE @IS_UNIQUE VARCHAR(100)
	DECLARE @INDEXTYPEDESC VARCHAR(100)
	DECLARE @FILEGROUPNAME VARCHAR(100)
	DECLARE @IS_DISABLED VARCHAR(100)
	DECLARE @INDEXOPTIONS VARCHAR(MAX)
	DECLARE @INDEXCOLUMNID INT
	DECLARE @ISDESCENDINGKEY INT 
	DECLARE @ISINCLUDEDCOLUMN INT
	DECLARE @TSQLSCRIPCREATIONINDEX VARCHAR(MAX)
	DECLARE @TSQLSCRIPDISABLEINDEX VARCHAR(MAX)

	IF NOT EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='DBA_IND_COLUMNS')
	CREATE TABLE DBA_IND_COLUMNS
	( UNIQUENESS VARCHAR(100)
	, INDEX_TYPE VARCHAR(100)
	, SCHEMA_NAME VARCHAR(100)
	, TABLE_NAME VARCHAR(100)
	, INDEX_NAME VARCHAR(100)
	, INDEX_COLUMN VARCHAR(2000)
	, INCLUDE_COLUMN VARCHAR(2000)
	, INDEX_OPTION VARCHAR(2000)
	, FILE_GROUP VARCHAR(100)
	, SNAP_DTTM DATETIME DEFAULT SYSDATETIME()
	);
	
	DECLARE CURSORINDEX CURSOR FOR
	SELECT SCHEMA_NAME(T.SCHEMA_ID) [SCHEMA_NAME]
	     , T.NAME
		 , IX.NAME
		 , CASE WHEN IX.IS_UNIQUE = 1 THEN 'UNIQUE ' ELSE '' END 
		 , IX.TYPE_DESC
		 , CASE WHEN IX.IS_PADDED=1 THEN 'PAD_INDEX = ON, ' ELSE 'PAD_INDEX = OFF, ' END
		   + CASE WHEN IX.ALLOW_PAGE_LOCKS=1 THEN 'ALLOW_PAGE_LOCKS = ON, ' ELSE 'ALLOW_PAGE_LOCKS = OFF, ' END
		   + CASE WHEN IX.ALLOW_ROW_LOCKS=1 THEN  'ALLOW_ROW_LOCKS = ON, ' ELSE 'ALLOW_ROW_LOCKS = OFF, ' END
		   + CASE WHEN INDEXPROPERTY(T.OBJECT_ID, IX.NAME, 'ISSTATISTICS') = 1 THEN 'STATISTICS_NORECOMPUTE = ON, ' ELSE 'STATISTICS_NORECOMPUTE = OFF, ' END
		   + CASE WHEN IX.IGNORE_DUP_KEY=1 THEN 'IGNORE_DUP_KEY = ON, ' ELSE 'IGNORE_DUP_KEY = OFF, ' END
		   + 'SORT_IN_TEMPDB = OFF'
		   + CASE WHEN FILL_FACTOR>0 THEN ', FILLFACTOR =' + CAST(IX.FILL_FACTOR AS VARCHAR(3)) ELSE '' END AS INDEXOPTIONS
		 , IX.IS_DISABLED 
		 , FILEGROUP_NAME(IX.DATA_SPACE_ID) FILEGROUPNAME
      FROM SYS.TABLES T 
	 INNER JOIN SYS.INDEXES IX 
        ON T.OBJECT_ID=IX.OBJECT_ID
     WHERE IX.TYPE>0 
	   AND IX.IS_PRIMARY_KEY=0 
	   AND IX.IS_UNIQUE_CONSTRAINT=0 
 --AND SCHEMA_NAME(TB.SCHEMA_ID)= @SCHEMANAME AND TB.NAME=@TABLENAME
       AND T.IS_MS_SHIPPED=0 
	   AND T.NAME<>'SYSDIAGRAMS'
     ORDER BY SCHEMA_NAME(T.SCHEMA_ID), T.NAME, IX.NAME

    OPEN CURSORINDEX
	FETCH NEXT FROM CURSORINDEX INTO  @SCHEMANAME, @TABLENAME, @INDEXNAME, @IS_UNIQUE, @INDEXTYPEDESC, @INDEXOPTIONS,@IS_DISABLED, @FILEGROUPNAME

    WHILE (@@FETCH_STATUS=0)
	BEGIN
	    DECLARE @INDEXCOLUMNS VARCHAR(MAX)
		DECLARE @INCLUDEDCOLUMNS VARCHAR(MAX)
		
		SET @INDEXCOLUMNS=''
		SET @INCLUDEDCOLUMNS=''
		
		DECLARE CURSORINDEXCOLUMN CURSOR FOR 
		SELECT COL.NAME
		     , IXC.IS_DESCENDING_KEY
			 , IXC.IS_INCLUDED_COLUMN
		FROM SYS.TABLES TB 
		INNER JOIN SYS.INDEXES IX 
		ON TB.OBJECT_ID=IX.OBJECT_ID
		INNER JOIN SYS.INDEX_COLUMNS IXC 
		ON IX.OBJECT_ID=IXC.OBJECT_ID 
		AND IX.INDEX_ID= IXC.INDEX_ID
		INNER JOIN SYS.COLUMNS COL 
		ON IXC.OBJECT_ID =COL.OBJECT_ID  
		AND IXC.COLUMN_ID=COL.COLUMN_ID
		WHERE IX.TYPE>0 
		AND (IX.IS_PRIMARY_KEY=0 OR IX.IS_UNIQUE_CONSTRAINT=0)
		AND SCHEMA_NAME(TB.SCHEMA_ID)=@SCHEMANAME 
		AND TB.NAME=@TABLENAME 
		AND IX.NAME=@INDEXNAME
		ORDER BY IXC.INDEX_COLUMN_ID
 
		OPEN CURSORINDEXCOLUMN 
		FETCH NEXT FROM CURSORINDEXCOLUMN INTO  @COLUMNNAME, @ISDESCENDINGKEY, @ISINCLUDEDCOLUMN
 
		WHILE (@@FETCH_STATUS=0)
		BEGIN
			IF @ISINCLUDEDCOLUMN=0 
				SET @INDEXCOLUMNS=@INDEXCOLUMNS + @COLUMNNAME  + CASE WHEN @ISDESCENDINGKEY=1  THEN ' DESC, ' ELSE  ' ASC, ' END
			ELSE
				SET @INCLUDEDCOLUMNS=@INCLUDEDCOLUMNS  + @COLUMNNAME  +', ' 

			FETCH NEXT FROM CURSORINDEXCOLUMN INTO @COLUMNNAME, @ISDESCENDINGKEY, @ISINCLUDEDCOLUMN
		END

		CLOSE CURSORINDEXCOLUMN
		DEALLOCATE CURSORINDEXCOLUMN

		SET @INDEXCOLUMNS = SUBSTRING(@INDEXCOLUMNS, 1, LEN(@INDEXCOLUMNS)-1)
		SET @INCLUDEDCOLUMNS = CASE WHEN LEN(@INCLUDEDCOLUMNS) >0 THEN SUBSTRING(@INCLUDEDCOLUMNS, 1, LEN(@INCLUDEDCOLUMNS)-1) ELSE '' END
 
 /*
 PRINT 'UNIQUENESS: '+@IS_UNIQUE
 PRINT 'INDEX TYPE: '+@INDEXTYPEDESC
 PRINT 'QUOTENAME(@INDEXNAME): '+QUOTENAME(@INDEXNAME)
 PRINT '@INDEXNAME: '+@INDEXNAME
 PRINT 'QUOTENAME(@SCHEMANAME): '+QUOTENAME(@SCHEMANAME)
 PRINT '@SCHEMANAME: '+@SCHEMANAME
 PRINT 'QUOTENAME(@TABLENAME): '+QUOTENAME(@TABLENAME)
 PRINT '@TABLENAME: '+@TABLENAME
 PRINT '@INDEXCOLUMNS: '+@INDEXCOLUMNS
 PRINT '@INCLUDEDCOLUMNS: '+@INCLUDEDCOLUMNS
 PRINT '@INDEXOPTIONS: '+@INDEXOPTIONS
 PRINT '@FILEGROUPNAME: '+@FILEGROUPNAME
 */

		BEGIN TRAN
			INSERT INTO DBA_IND_COLUMNS
				( UNIQUENESS 
				, INDEX_TYPE 
				, SCHEMA_NAME 
				, TABLE_NAME 
				, INDEX_NAME 
				, INDEX_COLUMN 
				, INCLUDE_COLUMN 
				, INDEX_OPTION 
				, FILE_GROUP 
				)
				VALUES
				( @IS_UNIQUE
				, @INDEXTYPEDESC
				, @SCHEMANAME
				, @TABLENAME
				, @INDEXNAME
				, @INDEXCOLUMNS
				, @INCLUDEDCOLUMNS
				, @INDEXOPTIONS
				, @FILEGROUPNAME
				);
		COMMIT TRAN;

 --SET @TSQLSCRIPCREATIONINDEX =''
 --SET @TSQLSCRIPDISABLEINDEX =''
 --SET @TSQLSCRIPCREATIONINDEX='CREATE '+ @IS_UNIQUE  +@INDEXTYPEDESC + ' INDEX ' +QUOTENAME(@INDEXNAME)+' ON ' + QUOTENAME(@SCHEMANAME) +'.'+ QUOTENAME(@TABLENAME)+ '('+@INDEXCOLUMNS+') '+ 
 --CASE WHEN LEN(@INCLUDEDCOLUMNS)>0 THEN CHAR(13) +'INCLUDE (' + @INCLUDEDCOLUMNS+ ')' ELSE '' END + CHAR(13)+'WITH (' + @INDEXOPTIONS+ ') ON ' + QUOTENAME(@FILEGROUPNAME) + ';'  

		IF @IS_DISABLED=1 
			SET  @TSQLSCRIPDISABLEINDEX=  CHAR(13) +'ALTER INDEX ' +QUOTENAME(@INDEXNAME) + ' ON ' + QUOTENAME(@SCHEMANAME) +'.'+ QUOTENAME(@TABLENAME) + ' DISABLE;' + CHAR(13) 

		PRINT @TSQLSCRIPCREATIONINDEX
		PRINT @TSQLSCRIPDISABLEINDEX

		FETCH NEXT FROM CURSORINDEX INTO  @SCHEMANAME, @TABLENAME, @INDEXNAME, @IS_UNIQUE, @INDEXTYPEDESC, @INDEXOPTIONS,@IS_DISABLED, @FILEGROUPNAME
	END
	CLOSE CURSORINDEX
	DEALLOCATE CURSORINDEX
END


--EXEC PR_DBA_GETINDEX




--#########################################################
--##### 인덱스 크기
--#########################################################
SELECT SCHEMA_NAME
     , TABLE_NAME
     , INDEX_NAME
     , INDEX_ID
     , INDEX_TYPE
     , ALLOCATION_SIZE_MB
     , USED_SIZE_MB
  FROM (SELECT OBJECT_SCHEMA_NAME(i.object_id) AS SCHEMA_NAME
             , OBJECT_NAME(i.OBJECT_ID) AS TABLE_NAME
             , i.name AS INDEX_NAME
             , i.index_id AS INDEX_ID
             , CASE i.index_id WHEN 1 THEN 'Clustered Index' ELSE 'NonClustered Index' END AS INDEX_TYPE
             , SUM(au.total_pages) * 8/1024 AS ALLOCATION_SIZE_MB
             , SUM(au.used_pages) * 8/1024 AS USED_SIZE_MB
          FROM sys.indexes AS i
          JOIN sys.partitions AS p
            ON p.OBJECT_ID = i.OBJECT_ID
           AND p.index_id = i.index_id
          JOIN sys.allocation_units AS au
            ON au.container_id = p.partition_id
         WHERE i.index_id != 0
           AND OBJECT_SCHEMA_NAME(i.object_id) != 'sys'
         GROUP 
            BY OBJECT_SCHEMA_NAME(i.object_id)
             , OBJECT_NAME(i.OBJECT_ID)
             , i.OBJECT_ID
             , i.index_id
             , i.name) A
ORDER BY ALLOCATION_SIZE_MB DESC ;


--#########################################################
--##### 인덱스 명명규칙 위배 검색
--#########################################################
SELECT (SELECT D.TABLE_CATALOG FROM INFORMATION_SCHEMA.TABLES D WHERE D.TABLE_SCHEMA=C.NAME AND D.TABLE_NAME=B.NAME) AS DB_NAME
     , 'INDEX' AS OBJECT_TYPE
     , C.NAME AS SCHEMA_NAME
     , B.NAME AS TABLE_NAME
 , A.NAME AS INDEX_NAME
 , A.TYPE_DESC IS_CLUSTERED
 , CASE WHEN IS_PRIMARY_KEY=1 THEN 'Y' ELSE 'N' END IS_PRIMARY
 , CASE WHEN IS_UNIQUE=1 THEN 'Y' ELSE 'N' END IS_UNIQUE
-- , STATS_DATE(A.OBJECT_ID, INDEX_ID) AS INDEX_CREATE_DATE
 , CASE WHEN STATS_DATE(A.OBJECT_ID, INDEX_ID) IS NULL THEN B.CREATE_DATE
        ELSE STATS_DATE(A.OBJECT_ID, INDEX_ID) END AS  INDEX_CREATION_DATE
  FROM SYS.INDEXES A
  JOIN SYS.ALL_OBJECTS  B
    ON B.OBJECT_ID = A.OBJECT_ID 
  JOIN (SELECT SCHEMA_ID, NAME FROM SYS.schemas) C
    ON C.SCHEMA_ID = B.SCHEMA_ID
WHERE 1=1
  AND B.NAME NOT LIKE 'MSpeer%'
  AND B.NAME NOT LIKE 'MSpub%'
  AND B.NAME NOT LIKE 'syncobj%'
  AND B.NAME NOT LIKE 'sys%'
  AND A.NAME IS NOT NULL
  --AND A.NAME LIKE 'IX%PK'
  AND A.NAME LIKE 'IX%'
  AND A.NAME NOT LIKE '%\_0_' ESCAPE '\''  -- 마지막 ' 제거해야함
ORDER BY C.NAME, B.NAME, A.INDEX_ID ;


--#########################################################
--##### 인덱스 이름 변경
--#########################################################
EXEC sp_rename N'스키마.테이블.인덱스', N'TOBE_인덱스', N'오브젝트TYPE(INDEX)';   
EXEC sp_rename N'dbo.TM_VIMNXM.IX_TM_VIMNXM_PK', N'PK_TM_VIMNXM', N'INDEX';   




--#########################################################
--##### 컬럼별 통계정보명 조회
--#########################################################
DECLARE @I_TABLE_NAME VARCHAR(100), @I_COLUMN_NAME VARCHAR(100) ;
SET @I_TABLE_NAME='PY_PYMT_ACNTCD_M', @I_COLUMN_NAME='SLP_PRCS_SE_CD';

SELECT OBJECT_NAME(A.OBJECT_ID) AS TABLE_NAME
, A.NAME COLUMN_NAME
, B.STATS_ID
, C.NAME AS STATS_NAME
FROM SYS.ALL_COLUMNS A
JOIN SYS.STATS_COLUMNS B
ON A.OBJECT_ID = B.OBJECT_ID
AND A.COLUMN_ID = B.COLUMN_ID
JOIN SYS.STATS C
ON B.OBJECT_ID = C.OBJECT_ID
AND B.STATS_ID = C.STATS_ID
WHERE 1=1
AND A.NAME=@I_COLUMN_NAME
AND A.OBJECT_ID=OBJECT_ID(@I_TABLE_NAME);


--#########################################################
--##### 통계정보 일괄삭제
--#########################################################
SELECT 'DROP STATISTICS '+OBJECT_NAME(OBJECT_ID)+'.'+NAME
FROM SYS.STATS
WHERE OBJECT_NAME(OBJECT_ID) IN (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE 'CS%')
AND NAME NOT LIKE 'PK%'
AND NAME NOT LIKE 'IX%'
GO


--#########################################################
--##### 미사용 인덱스, 인덱스 사용량
--#########################################################
SELECT *
FROM (SELECT DATABASENAME = DB_NAME()
     , TABLE_NAME = OBJECT_NAME(S.[OBJECT_ID])
     , INDEX_NAME = I.NAME
	 --, 'DROP INDEX '+I.NAME+' ON '+OBJECT_NAME(S.[OBJECT_ID]) AS DROP_STMT
	 --, 'ALTER INDEX '+I.NAME+' ON '+OBJECT_NAME(S.[OBJECT_ID])+' DISABLE' DISABLE_STMT
	 , USER_SEEKS
	 , USER_SCANS
	 , USER_LOOKUPS
     , USER_UPDATES
     , SYSTEM_UPDATES
  FROM SYS.DM_DB_INDEX_USAGE_STATS S
 INNER JOIN SYS.INDEXES I 
    ON S.[OBJECT_ID] = I.[OBJECT_ID]
   AND S.INDEX_ID = I.INDEX_ID
 WHERE S.DATABASE_ID = DB_ID()
   AND OBJECTPROPERTY(S.[OBJECT_ID], 'ISMSSHIPPED') = 0
   --AND USER_SEEKS = 0
   --AND USER_SCANS = 0
   --AND USER_LOOKUPS = 0
   AND I.IS_DISABLED = 0
   AND I.NAME IS NOT NULL
   AND I.NAME NOT LIKE 'PK\_%' ESCAPE '\') A
WHERE TABLE_NAME = 'SP_SL_PDITEM_D'
ORDER BY TABLE_NAME, INDEX_NAME 
GO

'


--#########################################################
--##### 중복 인덱스 조회
--#########################################################
WITH IDX_INFO
    ( DB_NM, SCHEMA_NM, TBL_NM, OBJECT_ID,  IDX_NM, IDX_ID, COL_NM, [NO], PARTITION_ORDINAL, [DES]
    , IS_INCLUDED_COLUMN, TYPE_DESC, [UNIQUE], [KEY], FGNAME
	) 
AS
(
SELECT DB_NAME() DB_NM
      ,SCHEMA_NAME(SCHEMA_ID) SCHEMA_NM
      ,B.NAME TBL_NM
	  , A.OBJECT_ID
	  , A.NAME IDX_NM
	  , A.INDEX_ID
	  , COL_NAME(C.OBJECT_ID,COLUMN_ID) COL_NM 
	  , KEY_ORDINAL [NO]
      , PARTITION_ORDINAL
	  , CASE WHEN IS_DESCENDING_KEY = 1 THEN '(-)' 
		     WHEN IS_DESCENDING_KEY = 0 THEN '' END  [DES]
	  , IS_INCLUDED_COLUMN
	  , A.TYPE_DESC
	  , CASE WHEN A.IS_UNIQUE = 1 THEN 'UNIQUE'
	         WHEN A.IS_UNIQUE = 0 THEN '' END [UNIQUE]
	  , CASE WHEN A.IS_UNIQUE_CONSTRAINT = 1 THEN 'UNIQUE KEY'
	         WHEN A.IS_UNIQUE_CONSTRAINT = 0 THEN '' END 
      + CASE WHEN A.IS_PRIMARY_KEY =1 THEN 'PRIMARY KEY'
	         WHEN A.IS_PRIMARY_KEY =0 THEN '' END [KEY]
	  , FG.GROUPNAME FGNAME
FROM SYS.INDEXES A
	JOIN SYS.OBJECTS B ON A.OBJECT_ID = B.OBJECT_ID
	JOIN SYS.INDEX_COLUMNS C ON A.OBJECT_ID = C.OBJECT_ID AND A.INDEX_ID = C.INDEX_ID
	JOIN SYSINDEXES IFG ON A.OBJECT_ID = IFG.ID AND A.INDEX_ID = IFG.INDID
	LEFT OUTER JOIN SYS.SYSFILEGROUPS AS FG ON IFG.GROUPID=FG.GROUPID 
WHERE B.TYPE = 'U' 
--AND B.NAME IN (     -- 특정 테이블 조회시(SP_HELPINDEX)
-- 'MPIHISTORY'
--,'T_BATCH_CMS'
--,'T_BATCH_CMS_MEMBER'
--,'T_BATCH_CMS_PAYMENT'
--,'T_BATCHKEY'
--,'T_DD_RAMT_CLOSE'
--   )
)
, IDX_COL_INFO
AS (SELECT 
	 DB_NM, SCHEMA_NM, TBL_NM, IDX_NM, IDX_ID, TYPE_DESC, [UNIQUE],  [KEY]
	, STUFF(
			(
				SELECT 
					', ',+CAST(COL_NM AS VARCHAR(100)) + ' ' + [DES] 
				FROM IDX_INFO A2 
				WHERE A2.TBL_NM = B2.TBL_NM AND A2.IDX_NM = B2.IDX_NM
				AND A2.IS_INCLUDED_COLUMN = 0
				ORDER BY TBL_NM, IDX_NM, [NO]
				FOR XML PATH('')
			 ),1,1,''
		  ) INDEX_COLUMN
	, ISNULL(STUFF(
			(
				SELECT 
					', ',+CAST(COL_NM AS VARCHAR(100)) + ' ' 
				FROM IDX_INFO A2 
				WHERE A2.TBL_NM = B2.TBL_NM AND A2.IDX_NM = B2.IDX_NM
				AND A2.IS_INCLUDED_COLUMN = 1
				ORDER BY TBL_NM, IDX_NM, [NO]
				FOR XML PATH('')
			 ),1,1,''
		  ), '') [INCLUDED_COLUMN]
   , FGNAME
FROM IDX_INFO B2 
	JOIN SYS.STATS B WITH (NOLOCK) ON B2.OBJECT_ID = B.OBJECT_ID
GROUP BY DB_NM, SCHEMA_NM, TBL_NM, IDX_NM, IDX_ID, TYPE_DESC, [UNIQUE],  [KEY], FGNAME
)
SELECT *
FROM IDX_COL_INFO A
, IDX_COL_INFO B
WHERE A.DB_NM = B.DB_NM
AND A.SCHEMA_NM=B.SCHEMA_NM
AND A.TBL_NM = B.TBL_NM
AND A.IDX_NM <> B.IDX_NM
AND B.INDEX_COLUMN LIKE A.INDEX_COLUMN+'%' ;


--#########################################################
--##### 인덱스 사용여부
--#########################################################
SELECT Object_name(s.object_id) as TableName
, i.name as IndexName
, User_seeks
, User_scans
, User_Lookups
, User_Updates
, last_user_lookup
, last_user_scan
, last_user_seek 
FROM sys.dm_db_index_usage_stats AS s 
RIGHT OUTER JOIN sys.indexes AS i 
ON i.object_id = s.object_id and i.index_id = s.index_id 
WHERE objectProperty(i.object_id, 'IsUserTable') = 1 
AND (User_Seeks = 0 or User_seeks IS NULL) ;


--#########################################################
--##### 인덱스 후보 검토, WHERE 조건 분석
--#########################################################
select mig.*
, statement as tableName
, Column_id
, Column_name
, Column_usage 
From sys.dm_db_missing_index_details as mid 
cross apply sys.dm_db_missing_index_columns (mid.index_handle) 
inner join sys.dm_db_missing_index_groups as mig 
on mig.index_handle = mid.index_handle 
Order by mig.index_group_handle, mig.index_handle, column_id ;


--#########################################################
--##### 뷰VIEW 조회
--#########################################################
-- 전체 DB
EXEC sp_MSforeachdb '
USE [?]
SELECT A.TABLE_CATALOG AS DB_NAME
     , ''VIEW'' AS OBJECT_TYPE
     , A.TABLE_SCHEMA AS VIEW_SCHEMA
     , A.TABLE_NAME AS OBJECT_NAME
 , ''COMMENT'' AS COMMENT
     , (SELECT B.CREATE_DATE FROM SYS.OBJECTS B WHERE B.NAME = A.TABLE_NAME) AS CREATE_DATE
  FROM INFORMATION_SCHEMA.VIEWS A  '

-- 싱글 DB
SELECT A.TABLE_CATALOG AS DB_NAME
     , 'VIEW' AS OBJECT_TYPE
     , A.TABLE_SCHEMA AS VIEW_SCHEMA
     , A.TABLE_NAME AS OBJECT_NAME
 , 'COMMENT' AS COMMENT
     , (SELECT B.CREATE_DATE FROM SYS.OBJECTS B WHERE B.NAME = A.TABLE_NAME) AS CREATE_DATE
  FROM INFORMATION_SCHEMA.VIEWS A 
GO


--#########################################################
--##### 함수FUNCTION 조회
--#########################################################
-- 전체 DB
EXEC sp_MSforeachdb '
USE [?]
SELECT DB_NAME() AS DB_NAME
     , A.TYPE_DESC
     , B.NAME
     , A.NAME
     , ''COMMENT''
     , A.CREATE_DATE
  FROM SYS.ALL_OBJECTS A
 JOIN SYS.SCHEMAS B
   ON A.SCHEMA_ID = B.schema_id
 WHERE TYPE_DESC LIKE ''%FUNC%''
   AND B.NAME NOT IN (''SYS'') '
GO

-- 싱글 DB
SELECT DB_NAME() AS DB_NAME
     , A.TYPE_DESC
     , B.NAME
     , A.NAME
     , 'COMMENT'
     , A.CREATE_DATE
  FROM SYS.ALL_OBJECTS A
 JOIN SYS.SCHEMAS B
   ON A.SCHEMA_ID = B.schema_id
 WHERE TYPE_DESC LIKE '%FUNC%'
   AND B.NAME NOT IN ('SYS') 
GO



--#########################################################
--##### 프로시저PROCEDURE 조회
--#########################################################
-- 전체 DB
EXEC sp_MSforeachdb '
USE [?]
SELECT *
  FROM INFORMATION_SCHEMA.ROUTINES
 WHERE 1=1
   AND ROUTINE_TYPE=''PROCEDURE''
   AND ROUTINE_NAME IN (''FN_SA_GET_AGV_COST'',''FN_SA_GET_SM_MG_RT'') ; '

-- 싱글 DB
SELECT *
  FROM INFORMATION_SCHEMA.ROUTINES
 WHERE 1=1
   AND ROUTINE_TYPE='PROCEDURE'
   AND ROUTINE_NAME IN ('FN_SA_GET_AGV_COST','FN_SA_GET_SM_MG_RT') ;



--#########################################################
--##### 시퀀스SEQUENCE 조회
--#########################################################
-- 전체 DB
EXEC sp_MSforeachdb '
USE [?]
SELECT DB_NAME() AS DB_NAME
     , A.TYPE_DESC
     , B.NAME
     , A.NAME
     , ''COMMENT''
     , A.CREATE_DATE
  FROM SYS.ALL_OBJECTS A
 JOIN SYS.SCHEMAS B
   ON A.SCHEMA_ID = B.schema_id
 WHERE TYPE_DESC LIKE ''%SEQ%''
   AND B.NAME NOT IN (''SYS'') '
   
-- 싱글 DB
SELECT DB_NAME() AS DB_NAME
     , A.TYPE_DESC
     , B.NAME
     , A.NAME
     , 'COMMENT'
     , A.CREATE_DATE
  FROM SYS.ALL_OBJECTS A
 JOIN SYS.SCHEMAS B
   ON A.SCHEMA_ID = B.schema_id
 WHERE TYPE_DESC LIKE '%SEQ%'
   AND B.NAME NOT IN ('SYS') 
   
--#########################################################
--##### 시퀀스 생성문 만들기
--#########################################################
SELECT *
, 'CREATE SEQUENCE '+SCHEMA_NAME(SCHEMA_ID)+'.'+NAME+' START WITH '+CONVERT(VARCHAR, START_VALUE)+' INCREMENT BY '+CONVERT(VARCHAR,INCREMENT)+' MINVALUE '+CONVERT(VARCHAR,minimum_value)+' MAXVALUE '+CONVERT(VARCHAR,MAXIMUM_VALUE)+CASE WHEN IS_CYCLING=1 THEN' CYCLE ' ELSE ' ' END + ' CACHE '+CONVERT(VARCHAR, ISNULL(CACHE_SIZE,0)) AS CREATE_STMT
FROM SYS.sequences 
WHERE NAME LIKE 'SQ\_%' ESCAPE '\'
SQ_CM_USER_H
ORDER BY NAME ;

'

--#########################################################
--##### 시퀀스 RESTART WITH, 통합테스트용
--#########################################################

--운영(PRD)에서 실행
--ERP
WITH MIG_SEQUENCE
AS
(SELECT NAME AS SEQUENCE_NAME, ISNULL(CURRENT_VALUE,0) AS CURRENT_VALUE
FROM LS_PROD2MIG.ERP_TT.SYS.SEQUENCES)
, PRD_SEQUENCE
AS
(SELECT NAME AS SEQUENCE_NAME, ISNULL(CURRENT_VALUE,0) AS CURRENT_VALUE
FROM ERP.SYS.SEQUENCES)
SELECT SEQUENCE_NAME
, CURRENT_VALUE
, CONVERT(BIGINT,CURRENT_VALUE)+100 AS CURRNET_VALUE_100
, 'ALTER SEQUENCE DBO.'+SEQUENCE_NAME+' RESTART WITH '+ CONVERT(VARCHAR,CONVERT(BIGINT,CURRENT_VALUE)+100) AS RESTART_STMT
FROM (SELECT PRD.SEQUENCE_NAME
, CASE WHEN PRD.CURRENT_VALUE >= MIG.CURRENT_VALUE  THEN PRD.CURRENT_VALUE
  ELSE MIG.CURRENT_VALUE END AS CURRENT_VALUE
FROM PRD_SEQUENCE PRD
LEFT JOIN MIG_SEQUENCE MIG
ON MIG.SEQUENCE_NAME = PRD.SEQUENCE_NAME) A
ORDER BY SEQUENCE_NAME ;

--CRM
WITH MIG_SEQUENCE
AS
(SELECT NAME AS SEQUENCE_NAME, ISNULL(CURRENT_VALUE,0) AS CURRENT_VALUE
FROM LS_PROD2MIG.CRM_TT.SYS.SEQUENCES)
, PRD_SEQUENCE
AS
(SELECT NAME AS SEQUENCE_NAME, ISNULL(CURRENT_VALUE,0) AS CURRENT_VALUE
FROM CRM.SYS.SEQUENCES)
SELECT SEQUENCE_NAME
, CURRENT_VALUE
, CONVERT(BIGINT,CURRENT_VALUE)+100 AS CURRNET_VALUE_100
, 'ALTER SEQUENCE DBO.'+SEQUENCE_NAME+' RESTART WITH '+ CONVERT(VARCHAR,CONVERT(BIGINT,CURRENT_VALUE)+100) AS RESTART_STMT
FROM (SELECT PRD.SEQUENCE_NAME
, CASE WHEN PRD.CURRENT_VALUE >= MIG.CURRENT_VALUE  THEN PRD.CURRENT_VALUE
  ELSE MIG.CURRENT_VALUE END AS CURRENT_VALUE
FROM PRD_SEQUENCE PRD
LEFT JOIN MIG_SEQUENCE MIG
ON MIG.SEQUENCE_NAME = PRD.SEQUENCE_NAME ) A
ORDER BY SEQUENCE_NAME ;



--#########################################################
--##### 링크드서버LINKED SERVER 조회
--#########################################################
SELECT CASE WHEN CAST(SERVERPROPERTY('ServerName') AS VARCHAR) LIKE 'P%' THEN '운영'
            WHEN CAST(SERVERPROPERTY('ServerName') AS VARCHAR) LIKE 'D%' THEN '개발' END AS SCTN
 , CONNECTIONPROPERTY('local_net_address') AS IP
 , DB_NAME() DBName
 , NAME LinkedServerName
 , DATA_SOURCE DataSource
 , 'RemoteUser' RemoteUser
 , '용도' purpose
 FROM SYS.SERVERS WITH (NOLOCK)
GO



--#########################################################
--##### 권한 조회, 권한 백업
--#########################################################
--(1)
SELECT 
'GRANT '+PERMISSION_NAME+' ON '+CONVERT(VARCHAR(100), OBJECT_NAME COLLATE KOREAN_WANSUNG_CI_AS)+' TO '+GRANTEE AS GRANT_STMT
--'REVOKE '+PERMISSION_NAME+' ON '+CONVERT(VARCHAR(100), OBJECT_NAME COLLATE KOREAN_WANSUNG_CI_AS)+' FROM '+GRANTEE AS REVOKE_STMT
--DISTINCT OBJECT_NAME
--A.*
FROM (
SELECT USER_NAME(GRANTEE_PRINCIPAL_ID) AS GRANTEE
    , CASE CLASS WHEN 1 THEN 'OBJECT' WHEN 0 THEN 'ALL' END CLASS
	, SCHEMA_NAME(SCHEMA_ID) AS SCHEMA_NAME
	, B.NAME AS OBJECT_NAME
	, B.TYPE
	, PERMISSION_NAME
	,A.CLASS_DESC
	, STATE_DESC
	, CASE WHEN B.NAME IS NOT NULL 
        THEN CASE STATE WHEN 'W' THEN LEFT(STATE_DESC, CHARINDEX('_', STATE_DESC)-1) + ' ' + PERMISSION_NAME + ' ON ' + SCHEMA_NAME(SCHEMA_ID) + '.' + B.NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) + ' WITH GRANT OPTION;' COLLATE KOREAN_WANSUNG_CI_AS
						ELSE STATE_DESC + ' ' + PERMISSION_NAME + ' ON ' + SCHEMA_NAME(SCHEMA_ID) + '.' + B.NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) + ';'    COLLATE KOREAN_WANSUNG_CI_AS END
        ELSE CASE STATE WHEN 'W' THEN LEFT(STATE_DESC, CHARINDEX('_', STATE_DESC)-1) + ' ' + PERMISSION_NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) + ' WITH GRANT OPTION;'
						ELSE STATE_DESC + ' ' + PERMISSION_NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) END
		END AS SCRIPT
FROM SYS.DATABASE_PERMISSIONS A WITH (NOLOCK)
	LEFT JOIN SYS.OBJECTS B WITH(NOLOCK) ON A.MAJOR_ID = B.OBJECT_ID
	JOIN SYS.DATABASE_PRINCIPALS C WITH (NOLOCK) ON A.GRANTEE_PRINCIPAL_ID = C.PRINCIPAL_ID
WHERE MAJOR_ID >= 0 AND  A.TYPE <>'CO' 
AND GRANTEE_PRINCIPAL_ID <> 0 
AND C.PRINCIPAL_ID > 4
AND USER_NAME(GRANTEE_PRINCIPAL_ID) NOT LIKE '%MS_%'
) A
WHERE 1=1
AND OBJECT_NAME NOT LIKE 'OLD%'
AND OBJECT_NAME NOT LIKE 'ZZ%'
GO


--(2)
SELECT *
--SELECT 'GRANT '+PERMISSIONTYPE+' ON '+CONVERT(VARCHAR(200), OBJECTNAME) COLLATE KOREAN_WANSUNG_CI_AS+' TO '+ROLE+'_P' AS STMT
--SELECT DISTINCT 'ALTER ROLE '+ROLE+' DROP MEMBER '+USERNAME AS STMT
FROM (
SELECT  
    LOGIN_NAME = CASE princ.[type] 
                    WHEN 'S' THEN princ.[name]
                    WHEN 'U' THEN ulogin.[name] COLLATE Latin1_General_CI_AI
                 END,
    USER_TYPE = CASE princ.[type]
                    WHEN 'S' THEN 'SQL User'
                    WHEN 'U' THEN 'Windows User'
                 END,  
    DATABASE_USER_NAME = princ.[name],       
    ROLE = null,      
    PERMISSION_TYPE = perm.[permission_name],       
    PERMISSION_STATE = perm.[state_desc],       
	PERMISSION_CLASS = perm.[class_desc],
    OBJECT_TYPE = obj.type_desc,       
    OBJECT_NAME = OBJECT_NAME(perm.major_id),
    COLUMN_NAME = col.[name]
FROM    
    --database user
    sys.database_principals princ  
LEFT JOIN
    --Login accounts
    sys.login_token ulogin on princ.[sid] = ulogin.[sid]
LEFT JOIN        
    --Permissions
    sys.database_permissions perm ON perm.[grantee_principal_id] = princ.[principal_id]
LEFT JOIN
    --Table columns
    sys.columns col ON col.[object_id] = perm.major_id 
                    AND col.[column_id] = perm.[minor_id]
LEFT JOIN
    sys.objects obj ON perm.[major_id] = obj.[object_id]
WHERE 
    princ.[type] in ('S','U')
UNION
--List all access provisioned to a sql user or windows user/group through a database or application role
SELECT  
    [UserName] = CASE memberprinc.[type] 
                    WHEN 'S' THEN memberprinc.[name]
                    WHEN 'U' THEN ulogin.[name] COLLATE Latin1_General_CI_AI
                 END,
    [UserType] = CASE memberprinc.[type]
                    WHEN 'S' THEN 'SQL User'
                    WHEN 'U' THEN 'Windows User'
                 END, 
    [DatabaseUserName] = memberprinc.[name],   
    [Role] = roleprinc.[name],      
    [PermissionType] = perm.[permission_name],       
    [PermissionState] = perm.[state_desc],      
    [PermissionClass] = perm.[class_desc], 
    [ObjectType] = obj.type_desc,--perm.[class_desc],   
    [ObjectName] = OBJECT_NAME(perm.major_id),
    [ColumnName] = col.[name]
FROM    
    --Role/member associations
    sys.database_role_members members
JOIN
    --Roles
    sys.database_principals roleprinc ON roleprinc.[principal_id] = members.[role_principal_id]
JOIN
    --Role members (database users)
    sys.database_principals memberprinc ON memberprinc.[principal_id] = members.[member_principal_id]
LEFT JOIN
    --Login accounts
    sys.login_token ulogin on memberprinc.[sid] = ulogin.[sid]
LEFT JOIN        
    --Permissions
    sys.database_permissions perm ON perm.[grantee_principal_id] = roleprinc.[principal_id]
LEFT JOIN
    --Table columns
    sys.columns col on col.[object_id] = perm.major_id 
                    AND col.[column_id] = perm.[minor_id]
LEFT JOIN
    sys.objects obj ON perm.[major_id] = obj.[object_id]
UNION
--List all access provisioned to the public role, which everyone gets by default
SELECT  
    [UserName] = '{All Users}',
    [UserType] = '{All Users}', 
    [DatabaseUserName] = '{All Users}',       
    [Role] = roleprinc.[name],      
    [PermissionType] = perm.[permission_name],       
    [PermissionState] = perm.[state_desc],  
    [PermissionClass] = perm.[class_desc],     
    [ObjectType] = obj.type_desc,--perm.[class_desc],  
    [ObjectName] = OBJECT_NAME(perm.major_id),
    [ColumnName] = col.[name]
FROM    
    --Roles
    sys.database_principals roleprinc
LEFT JOIN        
    --Role permissions
    sys.database_permissions perm ON perm.[grantee_principal_id] = roleprinc.[principal_id]
LEFT JOIN
    --Table columns
    sys.columns col on col.[object_id] = perm.major_id 
                    AND col.[column_id] = perm.[minor_id]                   
JOIN 
    --All objects   
    sys.objects obj ON obj.[object_id] = perm.[major_id]
WHERE
    --Only roles
    roleprinc.[type] = 'R' AND
    --Only public role
    roleprinc.[name] = 'public' AND
    --Only objects of ours, not the MS objects
    obj.is_ms_shipped = 0
--ORDER BY 1,3,4,5
    --princ.[Name],
    --OBJECT_NAME(perm.major_id),
    --col.[name],
    --perm.[permission_name],
    --perm.[state_desc],
    --obj.type_desc--perm.[class_desc] 
) A
WHERE 1=1
--AND ROLE = 'RL_CREATE'
--ORDER BY USERNAME, DATABASEUSERNAME, ROLE, PERMISSIONTYPE 
ORDER BY 1,3,4,5
GO


--(3) 롤멤버, 롤 멤버, ROLE MEMBER 확인

SELECT *
, 'ALTER ROLE '+ROLE_NAME+' ADD MEMBER '+MEMBER_NAME
FROM (
SELECT @@Servername as SERVER_NAME, db_name() as DB_NAME,Roles.Name ROLE_NAME, Roles.Type_Desc as ROLE_DESC, Members.Name MEMBER_NAME, Members.Type_Desc as MEMBER_DESC
FROM sys.database_role_members RoleMembers
INNER JOIN sys.database_principals Roles 
ON Roles.Principal_Id = RoleMembers.Role_Principal_Id
INNER JOIN sys.database_principals Members 
ON Members.Principal_Id =RoleMembers.Member_Principal_Id ) A
ORDER BY MEMBER_NAME, ROLE_NAME ;




-- Single DB
SELECT DatabaseUserName, DatabaseRoleName
FROM (
SELECT DP1.name AS DatabaseRoleName,   
   isnull (DP2.name, 'No members') AS DatabaseUserName   
 FROM sys.database_role_members AS DRM  
 RIGHT OUTER JOIN sys.database_principals AS DP1  
   ON DRM.role_principal_id = DP1.principal_id  
 LEFT OUTER JOIN sys.database_principals AS DP2  
   ON DRM.member_principal_id = DP2.principal_id  
WHERE DP1.type = 'R' ) A
WHERE 1=1
AND DatabaseUserName IN ('CRMAPP','SCMAPP') 
ORDER BY DatabaseUserName, DatabaseRoleName ;

-- All DB
exec sp_MSforeachdb '
use ?;

SELECT DB_NAME() AS DB_NAME, DatabaseUserName, DatabaseRoleName
, ''USE ?; ALTER ROLE ''+DatabaseRoleName+'' DROP MEMBER ''+DatabaseUserName AS DROP_USER_STMT
FROM (
SELECT DP1.name AS DatabaseRoleName,   
   isnull (DP2.name, ''No members'') AS DatabaseUserName   
 FROM sys.database_role_members AS DRM  
 RIGHT OUTER JOIN sys.database_principals AS DP1  
   ON DRM.role_principal_id = DP1.principal_id  
 LEFT OUTER JOIN sys.database_principals AS DP2  
   ON DRM.member_principal_id = DP2.principal_id  
WHERE DP1.type = ''R'' ) A
WHERE 1=1
AND DatabaseUserName LIKE ''P\_%'' ESCAPE ''\''
AND DatabaseUserName NOT IN (''P_MISTO'',''P_SELECT'')
ORDER BY DatabaseUserName, DatabaseRoleName';

'

SELECT 
    dp.name AS principal_name,
    dp.type_desc AS principal_type,
    s.name AS schema_name,
    p.permission_name,
    p.state_desc AS permission_state
FROM 
    sys.database_permissions p
JOIN 
    sys.schemas s ON p.major_id = s.schema_id
JOIN 
    sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
WHERE 
    p.class = 3 -- 스키마 수준 권한
ORDER BY 
    dp.name, s.name, p.permission_name;
	
	
	
	
-- 사용자 정의서 쿼리	
USE ERP
GO

WITH PERMISSION_ALL
AS
(
SELECT *
--SELECT 'GRANT '+PERMISSIONTYPE+' ON '+CONVERT(VARCHAR(200), OBJECTNAME) COLLATE KOREAN_WANSUNG_CI_AS+' TO '+ROLE+'_P' AS STMT
--SELECT DISTINCT 'ALTER ROLE '+ROLE+' DROP MEMBER '+USERNAME AS STMT
FROM (
SELECT  
    LOGIN_NAME = CASE princ.[type] 
                    WHEN 'S' THEN princ.[name]
                    WHEN 'U' THEN ulogin.[name] COLLATE Latin1_General_CI_AI
                 END,
    USER_TYPE = CASE princ.[type]
                    WHEN 'S' THEN 'SQL User'
                    WHEN 'U' THEN 'Windows User'
                 END,  
    DATABASE_USER_NAME = princ.[name],       
    ROLE = null,      
    PERMISSION_TYPE = perm.[permission_name],       
    PERMISSION_STATE = perm.[state_desc],       
	PERMISSION_CLASS = perm.[class_desc],
    OBJECT_TYPE = obj.type_desc,       
    OBJECT_NAME = OBJECT_NAME(perm.major_id),
    COLUMN_NAME = col.[name]
FROM    
    --database user
    sys.database_principals princ  
LEFT JOIN
    --Login accounts
    sys.login_token ulogin on princ.[sid] = ulogin.[sid]
LEFT JOIN        
    --Permissions
    sys.database_permissions perm ON perm.[grantee_principal_id] = princ.[principal_id]
LEFT JOIN
    --Table columns
    sys.columns col ON col.[object_id] = perm.major_id 
                    AND col.[column_id] = perm.[minor_id]
LEFT JOIN
    sys.objects obj ON perm.[major_id] = obj.[object_id]
WHERE 
    princ.[type] in ('S','U')
UNION
--List all access provisioned to a sql user or windows user/group through a database or application role
SELECT  
    USER_NAME = CASE memberprinc.[type] 
                    WHEN 'S' THEN memberprinc.[name]
                    WHEN 'U' THEN ulogin.[name] COLLATE Latin1_General_CI_AI
                 END,
    USER_TYPE = CASE memberprinc.[type]
                    WHEN 'S' THEN 'SQL User'
                    WHEN 'U' THEN 'Windows User'
                 END, 
    DATABASE_USER_NAME = memberprinc.[name],   
    ROLE = roleprinc.[name],      
    PERMISSION_TYPE = perm.[permission_name],       
    PERMISSION_STATE = perm.[state_desc],      
    PERMISSION_CLASS = perm.[class_desc], 
    OBJECT_TYPE = obj.type_desc,--perm.[class_desc],   
    OBJECT_NAME = OBJECT_NAME(perm.major_id),
    COLUMN_NAME = col.[name]
FROM    
    --Role/member associations
    sys.database_role_members members
JOIN
    --Roles
    sys.database_principals roleprinc ON roleprinc.[principal_id] = members.[role_principal_id]
JOIN
    --Role members (database users)
    sys.database_principals memberprinc ON memberprinc.[principal_id] = members.[member_principal_id]
LEFT JOIN
    --Login accounts
    sys.login_token ulogin on memberprinc.[sid] = ulogin.[sid]
LEFT JOIN        
    --Permissions
    sys.database_permissions perm ON perm.[grantee_principal_id] = roleprinc.[principal_id]
LEFT JOIN
    --Table columns
    sys.columns col on col.[object_id] = perm.major_id 
                    AND col.[column_id] = perm.[minor_id]
LEFT JOIN
    sys.objects obj ON perm.[major_id] = obj.[object_id]
UNION
--List all access provisioned to the public role, which everyone gets by default
SELECT  
    USER_NAME = '{All Users}',
    UER_TYPE = '{All Users}', 
    DATABASE_USER_NAME = '{All Users}',       
    ROLE = roleprinc.[name],      
    PERMISSION_TYPE = perm.[permission_name],       
    PERMISSION_STATE = perm.[state_desc],  
    PERMISSION_CLASS = perm.[class_desc],     
    OBJECT_TYPE = obj.type_desc,--perm.[class_desc],  
    OBJECT_NAME = OBJECT_NAME(perm.major_id),
    COLUMN_NAME = col.[name]
FROM    
    --Roles
    sys.database_principals roleprinc
LEFT JOIN        
    --Role permissions
    sys.database_permissions perm ON perm.[grantee_principal_id] = roleprinc.[principal_id]
LEFT JOIN
    --Table columns
    sys.columns col on col.[object_id] = perm.major_id 
                    AND col.[column_id] = perm.[minor_id]                   
JOIN 
    --All objects   
    sys.objects obj ON obj.[object_id] = perm.[major_id]
WHERE
    --Only roles
    roleprinc.[type] = 'R' AND
    --Only public role
    roleprinc.[name] = 'public' AND
    --Only objects of ours, not the MS objects
    obj.is_ms_shipped = 0
) A
WHERE 1=1
)
SELECT LOGIN_NAME
, DB_NAME
, DATABASE_USER_NAME
, PERMISSION_ALL
, ISNULL(CASE WHEN PERMISSION_ALL LIKE '%RL_RW%' 
    OR PERMISSION_ALL LIKE '%INSERT%' 
	OR PERMISSION_ALL LIKE '%DELETE%' 
	OR PERMISSION_ALL LIKE '%UPDATE%' THEN 'Y' END,'') AS [DML]
, ISNULL(CASE WHEN PERMISSION_ALL LIKE '%ALTER ON OBJECT%' 
    OR PERMISSION_ALL LIKE '%ALTER ON SCHEMA%' 
	OR PERMISSION_ALL LIKE '%ALTER ON DATABASE%' THEN 'Y' END,'') AS [DDL]
, ISNULL(CASE WHEN PERMISSION_ALL LIKE '%DB_DATAREADER%' THEN 'Y' END,'') AS [DB_DATAREADER]
, ISNULL(CASE WHEN PERMISSION_ALL LIKE '%DB_DATAWRITER%' THEN 'Y' END,'') AS [DB_DATAWRITER]
, ISNULL(CASE WHEN PERMISSION_ALL LIKE '%DDLADMIN%' THEN 'Y' END,'') AS [DDLADMIN]
, ISNULL(CASE WHEN PERMISSION_ALL LIKE '%EXECUT%' THEN 'Y' END,'') AS [EXECUTE]
, ISNULL(CASE WHEN PERMISSION_ALL LIKE '%SHOWPLAN%' THEN 'Y' END,'') AS [SHOWPLAN]
, ISNULL(CASE WHEN PERMISSION_ALL LIKE '%CREATE%' THEN 'Y' END,'') AS [CREATE]
FROM (
SELECT LOGIN_NAME, DB_NAME, DATABASE_USER_NAME, STRING_AGG(PERMISSION,', ') PERMISSION_ALL
FROM (
SELECT LOGIN_NAME
, DB_NAME
, DATABASE_USER_NAME
--, 'ROLE' AS PERMISSION_TYPE
, CONVERT(VARCHAR(MAX), STRING_AGG(ROLE,CHAR(10)+',') COLLATE KOREAN_WANSUNG_CI_AS) AS PERMISSION
FROM (SELECT DISTINCT LOGIN_NAME
, DB_NAME() AS DB_NAME
, DATABASE_USER_NAME
, ROLE
FROM PERMISSION_ALL
WHERE 1=1
AND ROLE IS NOT NULL
) A
GROUP BY LOGIN_NAME
, DB_NAME
, DATABASE_USER_NAME
UNION ALL
SELECT LOGIN_NAME
, DB_NAME
, DATABASE_USER_NAME
--, 'DATABASE_SCHEMA' AS PERMISSION_TYPE
, STRING_AGG(PERMISSION_TYPE+' ON '+PERMISSION_CLASS,CHAR(10)+',') AS PERMISSION
FROM (SELECT DISTINCT LOGIN_NAME
, DB_NAME() AS DB_NAME
, DATABASE_USER_NAME
, PERMISSION_TYPE
, PERMISSION_CLASS
FROM PERMISSION_ALL
WHERE 1=1
AND ROLE IS NULL
) A
GROUP BY LOGIN_NAME
, DB_NAME
, DATABASE_USER_NAME) B
GROUP BY LOGIN_NAME, DB_NAME, DATABASE_USER_NAME ) C
GO

	
	

--#########################################################
--##### 스키마 권한 조회
--#########################################################

SELECT P.CLASS_DESC
, DP.NAME AS GRANTEE
, P.PERMISSION_NAME
, S.NAME AS GRANTED_SCHEMA
, P.STATE_DESC
, STATE_DESC+' '+PERMISSION_NAME+' ON '+CLASS_DESC+'::'+S.NAME+' TO '+(DP.NAME COLLATE Korean_Wansung_CI_AS) AS GRANT_STMT
FROM 
    sys.database_permissions p
JOIN 
    sys.schemas s ON p.major_id = s.schema_id
JOIN 
    sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
WHERE 1=1
--AND dp.name = 'your_user_or_role_name'
AND 
    p.class = 3 -- Schema-level permissions
ORDER BY 
    dp.name, s.name, p.permission_name;



--#########################################################
--##### 권한 부여 (CREATE PROCEDURE, CREATE FUNCTION), ERROR 2760
--#########################################################
CREATE PROCEDURE 권한 외에 스키마에 대한 변경(ALTER ON SCHEMA::dbo) 권한도 있어야 프로시저, 함수 생성 가능함
CREATE ROLE RL_CREATE ;
ALTER ROLE RL_CREATE ADD MEMBER SCMAPP ;
GRANT CREATE PROCEDURE TO RL_CREATE ;
GRANT ALTER ON SCHEMA::dbo TO RL_CREATE ;




--#########################################################
--##### 읽기 권한 부여 RL_RO_ALL
--#########################################################
SELECT NAME, 'GRANT SELECT ON '+NAME+' TO RL_RO_ALL'
FROM SYS.tables
WHERE TYPE_DESC='USER_TABLE' ;





--#########################################################
--##### 롤에 포함된 멤버 조회
--#########################################################
SELECT members.[name] 
FROM sys.database_role_members AS rolemembers
    JOIN sys.database_principals AS roles 
        ON roles.[principal_id] = rolemembers.[role_principal_id]
    JOIN sys.database_principals AS members 
        ON members.[principal_id] = rolemembers.[member_principal_id]
WHERE roles.[name]='RL_CREATE'; 

ALTER ROLE RL_CREATE DROP MEMBER POLAPP;



 
--#########################################################
--##### RUNNING 상태의 SESSION의 PLAN 뜨기
--#########################################################
DECLARE @plan_handle varbinary(64)
       ,@sql_handle varbinary(64)

select @sql_handle = sql_handle
, @plan_handle = plan_handle 
from sys.dm_exec_requests 
--where session_id =117
;

select * from sys.dm_exec_sql_text(@sql_handle)       
select * from sys.dm_exec_query_plan(@plan_handle)



--#########################################################
--##### 백업BACKUP HISTORY 조회
--#########################################################
USE msdb
go
SELECT  
   CONVERT(CHAR(100), SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) AS Server, 
   ISNULL(CONVERT(CHAR(100), SERVERPROPERTY('InstanceName')),'MSSQLSERVER') AS Instance,
   msdb.dbo.backupset.database_name, 
   msdb.dbo.backupset.recovery_model,
   CASE msdb..backupset.type  
       WHEN 'D' THEN 'Database'  
       WHEN 'I' THEN 'Differential'           
       WHEN 'L' THEN 'Log'  
   END AS backup_type, 
   msdb.dbo.backupset.backup_start_date,  
   msdb.dbo.backupset.backup_finish_date,  
   DATEDIFF(mi,msdb.dbo.backupset.backup_start_date,msdb.dbo.backupset.backup_finish_date) "backup_time(분)", 
   CAST(msdb.dbo.backupset.backup_size/1024/1024 as INT) "backup_size(MB)" ,
   --CAST(msdb.dbo.backupset.compressed_backup_size/1024/1024 as INT) "compressed_backup_size(MB)" ,
   msdb.dbo.backupset.expiration_date,  
   msdb.dbo.backupmediafamily.logical_device_name,  
   msdb.dbo.backupmediafamily.physical_device_name,   
   msdb.dbo.backupset.name AS backupset_name, 
   msdb.dbo.backupset.description 
FROM   msdb.dbo.backupmediafamily  
   INNER JOIN msdb.dbo.backupset ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id  
WHERE  1=1
AND (CONVERT(datetime, msdb.dbo.backupset.backup_start_date, 102) >= GETDATE() - 4)  
AND  msdb.dbo.backupset.database_name in ('CJSPGV2','CJSCASHLOGV2','CJSPaymentGateway','SUGARPAY') --
AND  msdb..backupset.type = 'D' -- D,L
ORDER BY  
   msdb.dbo.backupset.database_name,
   msdb..backupset.type, 
   msdb.dbo.backupset.backup_start_date  DESC
   
   
   
--#########################################################
--##### 파일 위치 변경
--#########################################################
0) 파일 위치 및 파일명 기록
1) DB 오프라인
2) DB DETACH
SP_DETACH_DB INTERFACE
3) 파일 COPY
COPY D:\MSSQL\DATA\ERP\ERP_DATA_01.mdf D:\ERPDB\DATA\ERP_DATA_01.mdf
COPY D:\MSSQL\LOG\ERP\ERP_LOG_01.ldf D:\ERPDB\LOG\ERP_LOG_01.ldf
4) DB ATTACH
sp_attach_db N'ERP','D:\ERPDB\DATA\ERP_DATA_01.mdf','D:\ERPDB\LOG\ERP_LOG_01.ldf'


-- 아래는 MULTIPLE FILE일 경우 샘플임

SSMS에서>
EXEC sp_detach_db @dbname = N'ERP_TT'

CMD에서>
MOVE D:\MSSQL\DATA\ERP_DATA.mdf D:\ERPDB\DATA\ERP_TT_DATA_01.mdf
MOVE D:\MSSQL\LOG\ERP_LOG.ldf D:\ERPDB\LOG\ERP_TT_LOG.ldf
MOVE D:\MSSQL\DATA\ERP_DATA_01.ndf D:\ERPDB\DATA\ERP_TT_DATA_01.ndf
MOVE D:\MSSQL\DATA\ERP_DATA_02.ndf D:\ERPDB\DATA\ERP_TT_DATA_02.ndf
MOVE D:\MSSQL\DATA\ERP_DATA_03.ndf D:\ERPDB\DATA\ERP_TT_DATA_03.ndf
MOVE D:\MSSQL\DATA\ERP_IDX_01.ndf D:\ERPDB\DATA\ERP_TT_IDX_01.ndf
MOVE D:\MSSQL\DATA\ERP_IDX_02.ndf D:\ERPDB\DATA\ERP_TT_IDX_02.ndf

SSMS에서>
EXEC sp_attach_db @dbname = N'ERP_TT',  -- MOUNT 하고자하는 DB명으로 설정
                  @filename1 = N'D:\ERPDB\DATA\ERP_TT_DATA_01.mdf',
                  @filename2 = N'D:\ERPDB\LOG\ERP_TT_LOG.ldf',
                  @filename3 = N'D:\ERPDB\DATA\ERP_TT_DATA_01.ndf',
				  @filename4 = N'D:\ERPDB\DATA\ERP_TT_DATA_02.ndf',
				  @filename5 = N'D:\ERPDB\DATA\ERP_TT_DATA_03.ndf',
				  @filename6 = N'D:\ERPDB\DATA\ERP_TT_IDX_01.ndf',
				  @filename7 = N'D:\ERPDB\DATA\ERP_TT_IDX_02.ndf';



--#########################################################
--##### 통계정보수집
--#########################################################
-- 테이블 통계정보 생성
CREATE STATISTICS 통계정보명 ON 테이블명(컬럼1, 컬럼2,..., 컬럼n) WITH FULLSCAN|SAMPLE n PERCENT|SAMPLE n ROWS

-- 테이블 통계정보 생성
SELECT 'CREATE STATISTICS '+COLUMN_NAME+' ON '+TABLE_NAME+'('+COLUMN_NAME+')'+CHAR(10)+'GO'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME='CM_CD_M' ;


-- 일자 기준 통계 갱신
DROP TABLE IF EXISTS #TABLE_SIZE ;
SELECT DB_NAME() AS DB_NAME
     , SCHEMA_NM AS SCHEMA_NAME
     , TABLE_NAME
     , '' AS FILE_GROUP
     , ROWS
	 , reservedpages * 8 / 1024 AS RESERVED_MB
     , pages * 8 / 1024         AS DATA_MB
     , (CASE WHEN usedpages > pages THEN (usedpages - pages) ELSE 0 END) * 8 / 1024 AS INDEX_SIZE_MB
     , (CASE WHEN reservedpages > usedpages THEN (reservedpages - usedpages) ELSE 0 END) * 8 / 1024 AS UNUSED_MB
     , GETDATE() AS DATECACHED
  INTO #TABLE_SIZE
FROM (
       SELECT schema_name(aa.schema_id) as schema_nm
             ,object_name(aa.object_id) as table_name 
             ,sum(aa.rows)              as rows
             ,sum(aa.reserved_page_count)     as reservedpages
             ,sum(aa.used_page_count)         as usedpages
             ,sum(aa.pages)             as pages
       FROM (
               SELECT b.schema_id
                    , a.object_id
                    , a.index_id
                    , a.reserved_page_count   
                    , a.used_page_count    
                    , CASE  WHEN (a.index_id < 2) 
                                      THEN (a.in_row_data_page_count + a.lob_used_page_count + a.row_overflow_used_page_count)  
                                      ELSE 0   
                                 END pages 
                    , CASE  WHEN (a.index_id < 2) THEN a.row_count  ELSE 0  END  rows
               FROM sys.dm_db_partition_stats as a WITH(NOLOCK)
                   ,sys.objects as b WITH(NOLOCK)
               WHERE a.object_id = b.object_id 
               AND b.type ='U'
            ) aa
       group by aa.schema_id, aa.object_id
   ) spu ;

SELECT DISTINCT A.TABLE_NAME
              , A.LAST_UPDATED
			  , TABSIZE.ROWS
			  , 'UPDATE STATISTICS '+A.TABLE_NAME AS UPDATE_STMT			  
FROM (
 SELECT 
    OBJECT_NAME(s.object_id) AS TABLE_NAME
    , i.name AS INDEX_NAME
    , s.name AS STATISTICS_NAME
    , STATS_DATE(s.object_id, s.stats_id) AS LAST_UPDATED
FROM 
    sys.stats AS s
INNER JOIN 
    sys.indexes AS i 
	ON s.object_id = i.object_id AND s.name = i.name
WHERE 
    OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1 ) A
 LEFT JOIN #TABLE_SIZE TABSIZE
   ON A.TABLE_NAME = TABSIZE.TABLE_NAME
WHERE 1=1
  --AND A.TABLE_NAME LIKE 'OZ%'
  AND FORMAT(LAST_UPDATED,'yyyyMMdd') <> FORMAT(GETDATE(),'yyyyMMdd')
  AND LAST_UPDATED IS NOT NULL
ORDER BY 2, 3 DESC;



-- MODIFY_DATE 이후 통계 수집이 안된 테이블
USE ERP
GO

SELECT DISTINCT A.TABLE_NAME
			  , A.LAST_UPDATED 
			  , TABS.modify_date
FROM (
	SELECT 
		OBJECT_NAME(s.object_id) AS TABLE_NAME
		, i.name AS INDEX_NAME
		, s.name AS STATISTICS_NAME
		, STATS_DATE(s.object_id, s.stats_id) AS LAST_UPDATED
	FROM sys.stats AS s
	INNER JOIN sys.indexes AS i 
	  ON s.object_id = i.object_id AND s.name = i.name
	WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1 ) A
	INNER JOIN SYS.TABLES TABS
	   ON A.TABLE_NAME = TABS.NAME
WHERE A.LAST_UPDATED <= TABS.modify_date


- DB내 전체 테이블 통계정보 생성(컬럼별 통계정보 생성_
EXEC SP_CREATESTATS

-- 테이블 통계정보 갱신
UPDATE STATISTICS CO_ACUNIT_M
Update STATISTICS HumanResources.Employee IX_Employee_OrganizationNode WITH FULLSCAN
Update STATISTICS HumanResources.Employee IX_Employee_OrganizationNode WITH SAMPLE 10 PERCENT
Update STATISTICS HumanResources.Employee IX_Employee_OrganizationNode WITH SAMPLE 1000 ROWS
Update STATISTICS HumanResources.Employee  WITH FULLSCAN, COLUMNS

-- 데이터베이스 전체 통계정보 갱신
-- 모든 테이블들을 다 돌리진 않고 변경량이 XXX 이상인 대상에 한함
-- 전체 수집 하고 싶으면 테이블마다 개별로 수행해야 함

EXEC SP_UPDATESTATS




--#########################################################
--##### 통계 NULL 확인, SP_DBA_MAKE_STATS_FOR_NULL용 쿼리
--#########################################################
SELECT *
FROM (
	SELECT OBJECT_NAME(A.OBJECT_ID) AS TABLE_NAME
		, A.NAME COLUMN_NAME
		, B.STATS_ID
		, C.NAME AS STATS_NAME
		, 'DROP STATISTICS '+OBJECT_NAME(A.OBJECT_ID)+'.'+C.NAME AS DROP_STMT
		, 'CREATE STATISTICS '+A.NAME+' ON '+OBJECT_NAME(A.OBJECT_ID)+'('+A.NAME+')' AS CREATE_STMT
		FROM SYS.ALL_COLUMNS A
		LEFT JOIN SYS.STATS_COLUMNS B
		ON A.OBJECT_ID = B.OBJECT_ID
		AND A.COLUMN_ID = B.COLUMN_ID
		LEFT JOIN SYS.STATS C
		ON B.OBJECT_ID = C.OBJECT_ID
		AND B.STATS_ID = C.STATS_ID
		WHERE 1=1
		AND B.stats_id IS NULL ) A
WHERE 1=1
AND LEFT(TABLE_NAME,3) IN ('OZ_','EM_','RC_','AT_','PY_','EV_','ST_','HR_','FI_','CO_','CM_','WM_','SA_','SP_','PN_','PO_','PP_','CR_','CS_','EB_')
ORDER BY TABLE_NAME, COLUMN_NAME ;

--#########################################################
--##### 통계정보확인
--#########################################################
DBCC SHOW_STATISTICS (테이블명, 인덱스명)
예시) DBCC SHOW_STATISTICS (CM_SLIPP,IX_CM_SLIPP_01)

SELECT *
  FROM sys.stats AS stat
 CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
 WHERE stat.object_id = object_id('CM_SLIPP');



--#########################################################
--##### 계정 패스워드 복잡도 계정 만료
--#########################################################
select name as Login_name
      ,default_database_name as DF_Databse
      ,case when is_disabled = 0 then 'enabled' else 'disabled' end as L_Status
      ,case when LOGINPROPERTY(name, N'isLocked') = 0 then 'Unlocked' else 'Locked' end CK_Lock
      ,case when is_policy_checked = 0 then 'OFF' else 'ON' end as CK_Policy      
      ,case when is_expiration_checked = 0 then 'OFF' else 'ON' end as CK_Expiration      
      ,create_date
      ,modify_date
from sys.sql_logins
WHERE NAME NOT LIKE '##MS%' 
order by name;





--#########################################################
--##### 오브젝트OBJECT 검색 PR_DBA_OBJECT
--#########################################################
CREATE PROCEDURE [dbo].[PR_DBA_OBJECT](@I_OBJECT_NAME VARCHAR(100))
AS
SELECT *
FROM SYS.ALL_objects WITH(NOLOCK)
WHERE 1=1
AND NAME LIKE '%'+@I_OBJECT_NAME+'%'
GO

EXEC PR_DBA_OBJECT 'SP%HELP%INDEX'




--#########################################################
--##### 조각화 점검
--#########################################################
-- 테이블 조각화 점검
DBCC SHOWCONTIG(CM_SLIPP)
-- 인덱스 조각화 점검
DBCC SHOWCONTIG(CM_SLIPP,IX_CM_SLIPP_01)
-- 테이블+인덱스 조각화 점검
DBCC SHOWCONTIG(CM_SLIPP) WITH ALL_INDEXES
-- 빠른 조각화 점검
DBCC SHOWCONTIG(CM_SLIPP) WITH FAST


SELECT 
object_name(object_id) AS TableName, 
index_id AS indexid, 
partition_number AS partitionNumber, 
avg_fragmentation_in_percent AS frag, 
record_count 
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL , NULL, 'Detailed') --'Limited') 
WHERE avg_fragmentation_in_percent > 10.0 AND index_id > 0 and record_count > 1000 
ORDER BY record_count desc;



--#########################################################
--##### page life expectancy
--#########################################################
SELECT * 
FROM sys.dm_os_performance_counters WITH (NOLOCK) 
WHERE counter_name = 'Page life expectancy' AND instance_name = '';





--#########################################################
--##### LOCK
--#########################################################
EXEC SP_LOCK ;
--> Mode 가 'X'
SELECT * FROM SYS.sysprocesses WHERE BLOCKED > 0;
--> blocked 컬럼에 값이 있으면 Lock 걸린 프로세스
EXEC SP_WHO2;
--> BlkBy 컬럼에 값이 있으면 Lock을 건 프로세스(Lock Holder)

--Lock 걸린 쿼리 확인방법
--spid를 가진 세션의 실행중인 쿼리를 확인
dbcc inputbuffer ( [spid] );

--Lock 걸린 프로세스 KILL 방법
EXEC KILL [spid]


--#########################################################
--##### 오브젝트ID OBJECT_ID 오브젝트명 OBJECT_NAME 확인
--#########################################################
-- 오브젝트ID 확인
SELECT OBJECT_ID('오브젝트명');
-- 오브젝트명 확인
SELECT OBJECT_NAME(오브젝트ID);


--#########################################################
--##### 프로시저, 함수 TEXT 검색
--#########################################################
SELECT A.NAME
     , A.CRDATE
	 , A.REFDATE
	 , B.COLID
	 , TEXT
  FROM sys.sysobjects AS A WITH (NOLOCK)		
 INNER JOIN sys.syscomments AS B WITH (NOLOCK)			
    ON A.ID = B.ID
 WHERE 1=1
   AND A.NAME LIKE 'PR%'
   --AND A.NAME LIKE 'FN%'
   AND B.TEXT LIKE '%CURSOR%'
 ORDER BY A.NAME, B.COLID ;



--#########################################################
--##### 랜덤함수 RAND()
--#########################################################
SELECT RAND() ;
M<= X < N
SELECT RAND()*(N-M)+M;

M<= X <= N
SELECT FLOOR(RAND()*(N-M+1)+M);



--#########################################################
--##### 컬럼내 한글 포함여부 확인, PATINDEX
--#########################################################
patindex('%[ㄱ-힇]%', C.PLAINTEXT)
리턴값이 =0이면 한글 미포함
리턴값이 >0이면 한글 포함

PATINDEX('%[^0-9A-Za-zㄱ-힇]%', COLUMN)
숫자,영어,한글이 아닌 문자 포함 여부(=특수문자)




--#########################################################
--##### 인덱스 조각화(FRAGMENTATION) 확인
--#########################################################
SELECT OBJECT_SCHEMA_NAME(ips.object_id) AS schema_name,
       OBJECT_NAME(ips.object_id) AS object_name,
       i.name AS index_name,
       i.type_desc AS index_type,
       ips.avg_fragmentation_in_percent,
       ips.avg_page_space_used_in_percent,
       ips.page_count,
       ips.alloc_unit_type_desc
FROM sys.dm_db_index_physical_stats(DB_ID(), default, default, default, 'SAMPLED') AS ips
INNER JOIN sys.indexes AS i 
ON ips.object_id = i.object_id
   AND
   ips.index_id = i.index_id
ORDER BY page_count DESC;


--#########################################################
--##### 인덱스 REBUILD, REORGANIZTION
--#########################################################
인덱스 Reorganization(재구성)
- 기존에 사용되던 Page 정보를 순서대로 다시 구성하는 작업
- Rebuilding보다 리소스가 덜 사용되므로, 이 방법을 기본 인덱스 유지 관리 방법으로 사용하는 게 바람직함.
- 온라인 작업이기 때문에, 장기간의 object-level locks가 발생하지 않으며 Reorganization 작업 중에 기본 테이블에 대한 쿼리나 업데이트 작업을 계속 진행할 수 있다.
- 인덱스 재구성 쿼리
-- 인덱스 재구성(REORGANIZTION)
ALTER INDEX [IndexName] ON [dbo].[TableName] REORGANIZE WITH ( LOB_COMPACTION = ON )
--LOB_COMPACTION = ON 옵션은 LOB 데이터 타입(대용량 데이터)에 대한 압축 작업을 진행한다는 의미

--테이블의 모든 인덱스 재구성
ALTER INDEX ALL ON [TableName] REORGANIZE;


-- 인덱스 Reorganization(재구성)
- 기존에 사용되던 Page 정보를 순서대로 다시 구성하는 작업
- Rebuilding보다 리소스가 덜 사용되므로, 이 방법을 기본 인덱스 유지 관리 방법으로 사용하는 게 바람직함.
- 온라인 작업이기 때문에, 장기간의 object-level locks가 발생하지 않으며 Reorganization 작업 중에 기본 테이블에 대한 쿼리나 업데이트 작업을 계속 진행할 수 있다.
- 인덱스 재구성 쿼리
ALTER INDEX [IndexName] ON [dbo].[TableName] REBUILD PARTITION = ALL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, ONLINE = OFF,
ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)


# PAD_INDEX = OFF)
# Fill Factor 설정(페이지의 어느 정도의 공간을 비워 둘 것인지 결정, 기본 값은 0)은 Leaf 노드에서만 적용이 되는데, 
# PAD_INDEX = ON으로 설정하는 경우에는 intermediate 노드에도 Fill Factor 설정이 적용.
 
# STATISTICS_NORECOMPUTE = OFF)
# 통계 자동 업데이트 비활성화(대용량 테이블의 경우 통계 자동 업데이트 활성화 시켜 두면 성능 저하 발생 가능)
 
# SORT_IN_TEMPDB = OFF)
# 인덱스를 생성하거나 리빌드할 때 발생하는 정렬 동작의 중간 결과값을 tempdb에 저장할 것인지 결정
# 사용하는 데이터베이스와 tempdb가 다른 디스크에 위치해 있는 경우 인덱스 리빌드 시간 단축 가능



--#########################################################
--##### TMPDEV 테이블 형상 비교
--#########################################################

USE TMPDEV

DROP TABLE IF EXISTS #TABLE_COLUMN_INFO_DEV ;
SELECT TAB.NAME AS TABLE_NAME
, COL.NAME AS COLUMN_NAME
, COL.COLUMN_ID
, ROW_NUMBER() OVER(PARTITION BY TAB.NAME ORDER BY COLUMN_ID) COLUMN_SEQ
, COL.MAX_LENGTH
, COL.PRECISION
, COL.SCALE
, COL.COLLATION_NAME
, COL.IS_NULLABLE
, COL.IS_IDENTITY
, COL.IS_COMPUTED
INTO #TABLE_COLUMN_INFO_DEV
FROM CRM.SYS.ALL_COLUMNS COL
JOIN CRM.SYS.TABLES TAB
ON COL.OBJECT_ID = TAB.OBJECT_ID
WHERE TAB.TYPE_DESC='USER_TABLE' ;

DROP TABLE IF EXISTS #TABLE_COLUMN_INFO_QA ;
SELECT TAB.NAME AS TABLE_NAME
, COL.NAME AS COLUMN_NAME
, COL.COLUMN_ID
, ROW_NUMBER() OVER(PARTITION BY TAB.NAME ORDER BY COLUMN_ID) COLUMN_SEQ
, COL.MAX_LENGTH
, COL.PRECISION
, COL.SCALE
, COL.COLLATION_NAME
, COL.IS_NULLABLE
, COL.IS_IDENTITY
, COL.IS_COMPUTED
INTO #TABLE_COLUMN_INFO_QA
FROM TMPDEV.SYS.ALL_COLUMNS COL
JOIN TMPDEV.SYS.TABLES TAB
ON COL.OBJECT_ID = TAB.OBJECT_ID
WHERE TAB.TYPE_DESC='USER_TABLE' ;

--INSERT INTO DBA_WORK
SELECT DISTINCT
 'dbo' AS SCHEMA_NAME
, 
'TABLE:COLUMN' AS OBJECT_TYPE
,
DEV.TABLE_NAME AS OBJECT_NAME
,
NULL AS COLUMN_NAME
,
'테이블 컬럼 불일치' AS ERROR_TYPE
,
'-' AS DEV_EXISTS
,
'Y' AS TMPDEV_EXISTS
FROM #TABLE_COLUMN_INFO_DEV DEV
LEFT OUTER JOIN #TABLE_COLUMN_INFO_QA QA
ON DEV.TABLE_NAME = QA.TABLE_NAME
AND DEV.COLUMN_NAME = QA.COLUMN_NAME
--AND DEV.COLUMN_ID = QA.COLUMN_ID
AND DEV.COLUMN_SEQ = QA.COLUMN_SEQ
AND DEV.MAX_LENGTH = QA.MAX_LENGTH
AND DEV.PRECISION = QA.PRECISION
AND DEV.SCALE = QA.SCALE
--AND DEV.COLLATION_NAME = QA.COLLATION_NAME
AND DEV.IS_NULLABLE = QA.IS_NULLABLE
AND DEV.IS_IDENTITY = QA.IS_IDENTITY
AND DEV.IS_COMPUTED = QA.IS_COMPUTED
WHERE 1=1
AND DEV.TABLE_NAME NOT LIKE 'ZZ%'
AND DEV.TABLE_NAME NOT LIKE 'TEST%'
AND DEV.TABLE_NAME NOT LIKE 'TMP%'
AND DEV.TABLE_NAME NOT LIKE 'OLD%'
AND DEV.TABLE_NAME NOT LIKE 'TRACE_XE%'
AND QA.COLUMN_NAME IS NULL
--ORDER BY DEV.TABLE_NAME, DEV.COLUMN_SEQ
;



--#########################################################
--##### 트랜잭션로그 축소
--#########################################################
--1)
ALTER DATABASE ERP SET RECOVERY SIMPLE ;
DBCC SHRINKFILE(ERP_LOG,1024);  --TEST_DB_log:LOG파일명GO
DBCC SHRINKFILE(ERP_LOG,0,TRUNCATEONLY);  --TEST_DB_log:LOG파일명GO
ALTER DATABASE ERP SET RECOVERY FULL ;

--2)
DBCC SQLPERF(Logspace); 
ALTER DATABASE ASIS_ERP MODIFY FILE (NAME = ASIS_ERP_LOG, SIZE = 100MB); 



--#########################################################
--##### 00시 DATETRUNC
--#########################################################
DATETRUNC(YEAR|MONTH|DAY, GETDATE()-1)



--#########################################################
--##### 권한 추출(DBA_TAB_PRIVS)
--#########################################################
(1)
WITH CTE_MAX_REG_DT
AS
(SELECT TABLE_NAME, MAX(REG_DT) MAX_REG_DT
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME IN 
('IF_PN_PLM_APRL_MOLD_RCV_M'
,'IF_PN_PLM_CM_CD_RCV_M'
,'IF_PN_PLM_CTGR_RCV_M'
,'IF_PN_PLM_FW_MOLD_RCV_M'
,'IF_PN_PLM_LAST_RCV_M'
,'IF_PN_PLM_MTRL_CLR_RCV_M'
,'IF_PN_PLM_MTRL_RCV_M'
,'IF_PN_PLM_SIZE_DEF_RCV_M'
,'IF_PN_PLM_SIZE_REL_RCV_M'
,'IF_PN_PLM_STYL_CLR_RCV_M'
,'IF_PN_PLM_STYL_RCV_M'
,'IF_PN_PLM_STYL_SIZE_SKU_RCV_M'
,'IF_PN_PLM_STYL_SPEC_CHT_RCV_M'
,'PN_MAIN_STYL_CLR_M_NEW'
,'PN_MAIN_STYL_M_NEW'
,'PN_PLM_CM_CD_M'
,'PN_SIZE_DEF_M'
,'PN_SIZE_REL_M'
,'PN_STYL_SIZE_SKU_M'
,'PN_STYL_SPEC_CHT_M')
GROUP BY TABLE_NAME
)
SELECT 'GRANT '+PERMISSION_NAME+' ON '+SCHEMA_NAME+'.'+DTR.TABLE_NAME+' TO '+GRANTEE AS CREATE_STMT
     , DTR.*
  FROM DBA_TAB_PRIVS DTR
  JOIN CTE_MAX_REG_DT CMRD
    ON DTR.TABLE_NAME=CMRD.TABLE_NAME
   AND DTR.REG_DT = CMRD.MAX_REG_DT
GO


(2)
SELECT 'GRANT '+PERMISSION_NAME+ ' ON '+SCHEMA_NAME+'.'+TABLE_NAME+' TO '+GRANTEE+';'
  FROM DBA_TAB_PRIVS
 WHERE 1=1
   AND REG_DT = DATETRUNC(DAY,GETDATE()-1)
   AND TABLE_NAME = 'WM_IN_D'
GO


--#########################################################
--##### 권한 추출 (PR_DBA_GETPRIVS)
--#########################################################
CREATE PROCEDURE [dbo].[PR_DBA_GETPRIVS](@I_TABLE_NAME VARCHAR(100))
AS
BEGIN
  SELECT A.*
    FROM (SELECT USER_NAME(GRANTEE_PRINCIPAL_ID) AS GRANTEE
               , CASE CLASS WHEN 1 THEN 'OBJECT' WHEN 0 THEN 'ALL' END CLASS
               , SCHEMA_NAME(SCHEMA_ID) AS SCHEMA_NAME
               , B.NAME AS OBJECT_NAME
               , B.TYPE
               , PERMISSION_NAME
               ,A.CLASS_DESC
               , STATE_DESC
               , CASE WHEN B.NAME IS NOT NULL THEN CASE STATE WHEN 'W' THEN 'USE ' + DB_NAME() + '; ' + LEFT(STATE_DESC, CHARINDEX('_', STATE_DESC)-1) + ' ' + PERMISSION_NAME + ' ON ' + SCHEMA_NAME(SCHEMA_ID) + '.' + B.NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) + ' WITH GRANT OPTION;' COLLATE KOREAN_WANSUNG_CI_AS
                                                              ELSE 'USE ' + DB_NAME() + '; ' + STATE_DESC + ' ' + PERMISSION_NAME + ' ON ' + SCHEMA_NAME(SCHEMA_ID) + '.' + B.NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) + ';'    COLLATE KOREAN_WANSUNG_CI_AS 
                                                   END
		              ELSE CASE STATE WHEN 'W' THEN 'USE ' + DB_NAME() + '; ' + LEFT(STATE_DESC, CHARINDEX('_', STATE_DESC)-1) + ' ' + PERMISSION_NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) + ' WITH GRANT OPTION;'
                                      ELSE 'USE ' + DB_NAME() + '; ' + STATE_DESC + ' ' + PERMISSION_NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) 
                                      END
                 END AS SCRIPT
            FROM SYS.DATABASE_PERMISSIONS A WITH (NOLOCK)
            LEFT JOIN SYS.OBJECTS B WITH(NOLOCK) 
              ON A.MAJOR_ID = B.OBJECT_ID
            JOIN SYS.DATABASE_PRINCIPALS C WITH (NOLOCK)
              ON A.GRANTEE_PRINCIPAL_ID = C.PRINCIPAL_ID
           WHERE MAJOR_ID >= 0 AND  A.TYPE <>'CO' 
             AND GRANTEE_PRINCIPAL_ID <> 0 
             AND C.PRINCIPAL_ID > 4
             AND USER_NAME(GRANTEE_PRINCIPAL_ID) NOT LIKE '%MS_%') A
   WHERE 1=1
     AND OBJECT_NAME = @I_TABLE_NAME
   ORDER BY GRANTEE, A.CLASS ;
  END
GO

--사용법
PR_DBA_GETPRIVS 테이블명
--예제
PR_DBA_GETPRIVS EM_PRMT_LANGST_BASE_M



--#########################################################
--##### OLM 번역
--#########################################################
-- LANGUAGEID 1042(한국어), 1033(영어)
WITH  ENG_ITEM  --LANGUAGEID 1033
AS
(Select TIA.ItemID
, TIA.AttrTypeCode
, TIA.PlainText
, TI.IDENTIFIER
, TIA.LanguageID 
From XBOLTADM.TB_ELEMENT TE
JOIN XBOLTADM.Tb_Item_ATTR TIA
ON TIA.ItemID = TE.Link
LEFT OUTER JOIN XBOLTADM.TB_MODEL TM 
ON TE.ModelID = TM.ModelID 
JOIN XBOLTADM.Tb_ITEM TI
ON TM.ItemID = TI.ItemID 
WHERE 1=1
  AND TI.Identifier like 'EI%' 
  And TI.Deleted != 1
  And TE.CategoryCode IN ('MOJ','MCN', 'TXT')
  And TIA.LanguageID = 1033
  And TIA.AttrTypeCode = 'AT00001'
  And ISNULL(TIA.PlainText, '') != ''
UNION
SELECT A.ITEMID
     , A.ATTRTYPECODE
, A.PLAINTEXT
, B.Identifier
, A.LANGUAGEID
  FROM OLM_MASTER.XBOLTADM.TB_ITEM_ATTR A WITH(NOLOCK)
  JOIN OLM_MASTER.XBOLTADM.TB_ITEM B WITH(NOLOCK)
    ON A.ITEMID = B.ITEMID
WHERE 1=1
   AND B.Identifier LIKE 'EI%'
   AND A.LANGUAGEID=1033
)
SELECT *
FROM ENG_ITEM
WHERE patindex('%[ㄱ-힇]%', PLAINTEXT) <> 0
ORDER BY PLAINTEXT
GO

-- 바꿔야 하는 조건(1) : Identifier LIKE 'EI%'
-- 바꿔야 하는 조건(2) : patindex('%[ㄱ-힇]%', PLAINTEXT) <> 0
-- ※ 영어로 번역 안된거 : patindex('%[ㄱ-힇]%', PLAINTEXT) <> 0
--   영어로 번역  된거 : patindex('%[ㄱ-힇]%', PLAINTEXT) =  0



-- 번역안된거 ITEMID, ATTRTYPECODE 확인
WITH KOR_ITEM
AS (
SELECT B.IDENTIFIER, A.ITEMID, A.ATTRTYPECODE, A.LANGUAGEID, A.PLAINTEXT, A.LASTUPDATED
  FROM XBOLTADM.TB_ITEM_ATTR A WITH(NOLOCK)
  JOIN XBOLTADM.TB_ITEM B 
    ON A.ITEMID = B.ITEMID
WHERE 1=1
  AND A.LANGUAGEID = 1042  --KOREAN
)
, ENG_ITEM
AS (
SELECT B.IDENTIFIER, A.ITEMID, A.ATTRTYPECODE, A.LANGUAGEID, A.PLAINTEXT, A.LASTUPDATED
  FROM XBOLTADM.TB_ITEM_ATTR A WITH(NOLOCK)
  JOIN XBOLTADM.TB_ITEM B 
    ON A.ITEMID = B.ITEMID
WHERE 1=1
  AND A.LANGUAGEID = 1033  --ENGLISH
)
SELECT *
  FROM KOR_ITEM C
  JOIN ENG_ITEM D
    ON C.ITEMID=D.ITEMID
   AND C.ATTRTYPECODE=D.ATTRTYPECODE
   --AND C.IDENTIFIER=D.IDENTIFIER
   --AND C.LANGUAGEID <> D.LANGUAGEID
   --AND C.PLAINTEXT = D.PLAINTEXT
 WHERE 1=1
   --AND C.IDENTIFIER LIKE 'EI%'
   --AND C.IDENTIFIER IS NULL
   --AND patindex('%[ㄱ-힇]%', C.PLAINTEXT) > 0
   --AND patindex('%[ㄱ-힇]%', D.PLAINTEXT) = 0
   AND C.PLAINTEXT ='SO정보 연동'
GO


--번역 안된거 전체, LANGUAGEID=1033(영어)인데 한글 PLAINTEXT 가지고 있는 것
SELECT B.IDENTIFIER
     , A.ITEMID
     , A.ATTRTYPECODE
     , A.PLAINTEXT
     , A.LASTUPDATED
  FROM XBOLTADM.TB_ITEM_ATTR A WITH(NOLOCK)
  JOIN XBOLTADM.TB_ITEM B 
    ON A.ITEMID = B.ITEMID
 WHERE 1=1
   AND A.LANGUAGEID = 1033
   AND patindex('%[ㄱ-힇]%', A.PLAINTEXT) > 0
GO


--번역 안된거(공통CM 제외, 20240215)
SELECT DISTINCT B.IDENTIFIER
     , A.ITEMID
     , A.ATTRTYPECODE
     , A.PLAINTEXT
     , A.LASTUPDATED
	 , B.DELETED
  FROM XBOLTADM.TB_ITEM_ATTR A WITH(NOLOCK)
  JOIN XBOLTADM.TB_ITEM B 
    ON A.ITEMID = B.ITEMID
 WHERE 1=1
   AND A.LANGUAGEID = 1033
   AND patindex('%[ㄱ-힇]%', A.PLAINTEXT) > 0
   AND B.IDENTIFIER NOT LIKE 'CM%'
   AND B.DELETED=0
ORDER BY PLAINTEXT
GO


--#########################################################
--##### INVALID OBJECT, OBJECT STATUS
--#########################################################
SELECT DISTINCT
  cte.referencing_id
, obj_name = QUOTENAME(SCHEMA_NAME(all_object.[schema_id])) + '.' + QUOTENAME(all_object.name) 
--,   'Invalid object name ''' + cte.obj_name + ''''   
   , all_object.[type] obj_type
   --INTO #invalid_db_objects
FROM ( SELECT
      sed.referencing_id
    , obj_name = COALESCE(sed.referenced_schema_name + '.', '') + sed.referenced_entity_name
FROM sys.sql_expression_dependencies sed
WHERE sed.is_ambiguous = 0    AND sed.referenced_id IS NULL
) cte
JOIN sys.objects all_object ON cte.referencing_id = all_object.[object_id]



--#########################################################
--##### 메모리 할당 Pending
--#########################################################
SELECT * 
FROM sys.dm_os_performance_counters WITH (NOLOCK) 
WHERE counter_name = 'Memory Grants Pending' ;
--정상: cntr_value < 3
--취약: cntr_value >= 3



--#########################################################
--##### 계정 패스워드 복잡도
--#########################################################
SELECT name, is_policy_checked, is_expiration_checked 
FROM sys.sql_logins 
WHERE 1=1
AND NAME NOT LIKE '##MS%' ; 


--#########################################################
--##### LINKED SERVER
--#########################################################
SELECT * INTO SM_CRDT_SLS FROM OPENQUERY(LS_ERPDEV2_SCMADM, 'SELECT * FROM SM_CRDT_SLS');
SELECT * INTO SA_SMS_SEND_TRST_HSTR FROM OPENQUERY(LS_ERPDEV2_SCMADM, 'SELECT * FROM SA_SMS_SEND_TRST_HSTR WHERE INPUT_DTTM >= TO_DATE(''20220101'',''YYYYMMDD'')');
SELECT * INTO SA_MV_ORD_BUF FROM OPENQUERY(LS_ERPDEV2_SCMADM, 'SELECT * FROM SA_MV_ORD_BUF WHERE ORD_DT >= ''20230101''');


--#########################################################
--##### 실행계획 권한 부여 SHOWPLAN
--#########################################################
USE [ERP]
GO

CREATE ROLE [db_showplan]
GO
GRANT SHOWPLAN TO [db_showplan]
GO
ALTER ROLE [db_showplan] ADD MEMBER [SCMAPP]
GO


--#########################################################
--##### 프로파일러 PROFILER 권한 부여
--#########################################################
GRANT ALTER TRACE TO 로그인명 ;



--#########################################################
--##### 테이블 백업 DBO.PR_DBA_BACKUPTAB
--#########################################################
CREATE PROCEDURE [dbo].[PR_DBA_BACKUPTAB]
  @ORIGINAL_TABLE_NAME VARCHAR(100)
, @BACKUP_TABLE_NAME VARCHAR(100)
WITH EXECUTE AS OWNER
AS
BEGIN
  DECLARE @V_SQL VARCHAR(500);
  SET @V_SQL = 'SELECT * INTO '+@BACKUP_TABLE_NAME +' FROM '+@ORIGINAL_TABLE_NAME  ;
  EXEC (@V_SQL) ;
  PRINT 'SELECT * INTO '+@BACKUP_TABLE_NAME+'  FROM '+@ORIGINAL_TABLE_NAME   ;
END
GO

--사용법
EXEC DBO.SP_BACKUPTAB BATCH_JOB_EXECUTION, BATCH_JOB_EXECUTION_BAK_20240115




--#########################################################
--##### RENAME 이름 변경
--#########################################################
--테이블명 변경
EXEC sp_rename 'dbo.SA_SHOP_ADD_INFO', 'SA_SHOP_ADD_INFO_M';
--제약조건명 변경
EXEC sp_rename N'dbo.PK_SA_SHOP_INFO_M3', N'PK_SA_SHOP_ADD_INFO_M', N'OBJECT' 



--#########################################################
--##### DEFAULT 제약사항 추가
--#########################################################
ALTER TABLE 테이블명 ADD CONSTRAINT 테이블명_컬럼명_DFLT DEFAULT 디폴트값 FOR 컬럼;
ALTER TABLE ERP.dbo.EM_PRMT_TRGT_M ADD CONSTRAINT EM_PRMT_TRGT_M_MOD_DTTM_DFLT DEFAULT sysdatetimeoffset() FOR MOD_DTTM;


--#########################################################
--##### PR_DBA_RESTORETAB 백업에서 복구(INSERT..SELECT..)
--#########################################################
--NEW
CREATE PROCEDURE [dbo].[PR_DBA_RESTORETAB]
( @I_SOURCE_TABLE VARCHAR(100)
, @I_TARGET_TABLE VARCHAR(100))
AS
SET NOCOUNT ON;
/******************************************************************************
[프로그램명]
PR_DBA_RESTORETAB
[설명]
변경관리작업중 백업 받은 데이터(*_BAK_YYYYMMD)를 원본으로 복구
[파라미터]
@I_SOURCE_TABLE  VARCHAR    복구 해야할 데이터보유하고 있는 테이블명(=BAK테이블명)
@I_TARGET_TABLE  VARCHAR    데이터 저장할 테이블명
[VERSIONS]
----------  ---------------  ------------------------------------
2024-01-19  강현호           최초 작성
2024-02-27  강현호           프로시저 표준TEMPLATE 적용
[TEST/EXCUTE]
EXEC PR_DBA_RESTORETAB SA_SHOP_INFO_M_BAK_20240221, SA_SHOP_INFO_M
EXEC PR_DBA_RESTORETAB @I_SOURCE_TABLE=SA_SHOP_INFO_M_BAK_20240221, @I_TARGET_TABLE=SA_SHOP_INFO_M
******************************************************************************/
BEGIN
    BEGIN TRY
        DECLARE @V_SQL            VARCHAR(4000)
          , @V_INS_SQL            VARCHAR(4000)
	      , @V_SEL_SQL            VARCHAR(4000)
	      , @V_DEFAULT            VARCHAR(10)
	      , @V_INT_COLUMN         VARCHAR(1000)
	      , @V_COLUMN_NAME        VARCHAR(100)
	      , @V_COLUMN_DATA_TYPE   VARCHAR(20)
	      , @V_PROC_NM            VARCHAR(50)     -- 프로시저명
	      , @V_EXEC_STRT_DTTM     DATETIME        -- 프로시저 시작일시
          , @V_EXEC_END_DTTM      DATETIME        -- 프로시저 종료일시
          , @V_EXEC_STAT_CD       CHAR(1)         -- 프로시저 실행완료상태
	      , @V_ERR_NO             VARCHAR(20)
	      , @V_ERR_MESSAGE        NVARCHAR(2000)
	      , @V_USER_MESSAGE       NVARCHAR(2000)
	      , @V_ERR_STATE          VARCHAR(20)
	      , @V_ERR_SEVERITY       VARCHAR(20)
	      , @V_ERR_LINE           VARCHAR(20)
        ;

        /* 프로시저 시작 시간 저장 */
        SET @V_EXEC_STRT_DTTM = SYSDATETIME();
        /* 실행 프로시저명 저장 */	
        SET @V_PROC_NM = OBJECT_NAME(@@PROCID);

        /* 임시 테이블이 존재할 경우 삭제: #TMP_TB_TARGET */
        IF OBJECT_ID('tempdb..#TMP_TB_TARGET') IS NOT NULL
        BEGIN 
            DROP TABLE #TMP_TB_TARGET ;
        END  -- END IF 

        /* 임시 테이블이 존재할 경우 삭제: #TMP_TB_SOURCE */
        IF OBJECT_ID('tempdb..#TMP_TB_SOURCE') IS NOT NULL
        BEGIN 
            DROP TABLE #TMP_TB_SOURCE ;
        END  -- END IF 
	
        /* 타겟 컬럼정보를 가지고 있는 임시 테이블 생성: #TMP_TB_TARGET */
        SELECT * INTO #TMP_TB_TARGET
          FROM (
	    SELECT DB_NAME() AS DB_NAME
	         , I.TABLE_SCHEMA
	         , O.NAME AS TABLE_NAME
	         , C.NAME AS COLUMN_NAME
	         , CAST(p.value AS sql_variant) AS ExtendedPropertyValue
	         , I.ORDINAL_POSITION 
	         , I.DATA_TYPE AS DATA_TYPE
	         , C.LENGTH
	         , C.XPREC
	         , C.XSCALE
	         , CASE WHEN C.ISNULLABLE=0 THEN 'NOT NULL' ELSE 'NULLABLE' END IS_NULLABLE
	         , I.COLLATION_NAME
	         , CASE WHEN Q.COLUMN_NAME IS NOT NULL THEN 'Y'
	                ELSE 'N' END IS_PK
                 , CASE WHEN C.STATUS=128 THEN 'Y' ELSE 'N' END IS_IDENTITY
	      FROM SYSOBJECTS O (NOLOCK)
	     INNER JOIN SYSCOLUMNS C (NOLOCK)
	        ON O.ID = C.ID
	     INNER JOIN INFORMATION_SCHEMA.COLUMNS I (NOLOCK)
	        ON O.NAME = I.TABLE_NAME 
	       AND C.NAME = I.COLUMN_NAME
	      LEFT OUTER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE  Q (NOLOCK)
	        ON Q.TABLE_NAME = I.TABLE_NAME
	       AND Q.COLUMN_NAME = I.COLUMN_NAME
	      LEFT OUTER JOIN sys.extended_properties p 
	        ON p.major_id=C.ID 
	       AND p.minor_id=C.COLID
	       AND p.class=1
	     WHERE 1=1
               AND O.NAME = @I_TARGET_TABLE
        ) A ;

        /* 백업(=원본) 컬럼정보를 가지고 있는 임시 테이블 생성: #TMP_TB_SOURCE */
        SELECT * INTO #TMP_TB_SOURCE
          FROM (
	    SELECT DB_NAME() AS DB_NAME
	         , I.TABLE_SCHEMA
	         , O.NAME AS TABLE_NAME
	         , C.NAME AS COLUMN_NAME
	         , CAST(p.value AS sql_variant) AS ExtendedPropertyValue
	         , I.ORDINAL_POSITION 
	         , I.DATA_TYPE AS DATA_TYPE
	         , C.LENGTH
	         , C.XPREC
	         , C.XSCALE
	         , CASE WHEN C.ISNULLABLE=0 THEN 'NOT NULL' ELSE 'NULLABLE' END IS_NULLABLE
	         , I.COLLATION_NAME
	         , CASE WHEN Q.COLUMN_NAME IS NOT NULL THEN 'Y'
	                ELSE 'N' END IS_PK
                 , CASE WHEN C.STATUS=128 THEN 'Y' ELSE 'N' END IS_IDENTITY
	      FROM SYSOBJECTS O (NOLOCK)
	     INNER JOIN SYSCOLUMNS C (NOLOCK)
	        ON O.ID = C.ID
	     INNER JOIN INFORMATION_SCHEMA.COLUMNS I (NOLOCK)
	        ON O.NAME = I.TABLE_NAME 
	       AND C.NAME = I.COLUMN_NAME
	      LEFT OUTER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE  Q (NOLOCK)
	        ON Q.TABLE_NAME = I.TABLE_NAME
	       AND Q.COLUMN_NAME = I.COLUMN_NAME
	      LEFT OUTER JOIN sys.extended_properties p 
	        ON p.major_id=C.ID 
	       AND p.minor_id=C.COLID
	       AND p.class=1
	     WHERE 1=1
               AND O.NAME = @I_SOURCE_TABLE
        ) A ;

        /* 공통컬럼 조사 */
        SELECT @V_INT_COLUMN = STRING_AGG(COLUMN_NAME, ',')
          FROM (SELECT COLUMN_NAME
                  FROM #TMP_TB_TARGET
               --WHERE TABLE_NAME=@I_TARGET_TABLE
             INTERSECT
                SELECT COLUMN_NAME
                  FROM #TMP_TB_SOURCE
               --WHERE TABLE_NAME=@I_SOURCE_TABLE
         ) A ;
    
        SET @V_INS_SQL = 'INSERT INTO '+@I_TARGET_TABLE+'('+@V_INT_COLUMN ;
        SET @V_SEL_SQL = 'SELECT '+@V_INT_COLUMN ;
		--PRINT '@V_SEL_SQL: '+@V_SEL_SQL ;
        /* 커서 상태 점검, 이미 생성되어 있으면 CLOSE, DEALLOCATE */		
        IF CURSOR_STATUS('global','CUR_GET_DIFF_COL') IN (1,0)
        BEGIN
            CLOSE CUR_GET_DIFF_COL
            DEALLOCATE CUR_GET_DIFF_COL
        END

        /* 커서 생성 : 원본, 백업 테이블간 컬럼 차이 */
        DECLARE CUR_GET_DIFF_COL CURSOR FOR
        SELECT UPPER(COLUMN_NAME), UPPER(DATA_TYPE)
          FROM #TMP_TB_TARGET
        EXCEPT
        SELECT COLUMN_NAME, DATA_TYPE
          FROM #TMP_TB_SOURCE

        /* 커서 오픈 : 원본, 백업 테이블간 컬럼 차이(커서명 : CUR_GET_DIFF_COL) */
        OPEN CUR_GET_DIFF_COL
        FETCH NEXT FROM CUR_GET_DIFF_COL INTO @V_COLUMN_NAME, @V_COLUMN_DATA_TYPE
        WHILE @@FETCH_STATUS = 0
        BEGIN
            /* INSERT SQL에 신규/변경 컬럼 추가 */
            SET @V_INS_SQL = @V_INS_SQL + ', ' + @V_COLUMN_NAME ;		
			--PRINT '@V_COLUMN_DATA_TYPE: '+@V_COLUMN_DATA_TYPE

            /* 신규/변경 컬럼의 데이터타입에 맞는 기본값 설정 문자형 '', 숫자형 0으로 설정 */
            IF @V_COLUMN_DATA_TYPE IN ('CHAR','VARCHAR','NVARCHAR')
            BEGIN
			    --PRINT '@V_COLUMN_DATA_TYPE IN CHAR VARCHAR NVARCHAR';
                SET @V_DEFAULT = '''''';
				--PRINT '@V_DEFAULT IN CHAR: '+@V_DEFAULT ;
            END
            ELSE IF @V_COLUMN_DATA_TYPE IN ('INT','BIGINT','DECIMAL','NUMBER','NUMERIC')
            BEGIN
                --PRINT '@V_COLUMN_DATA_TYPE IN INT BIGINT DECIMAL NUMBER';
				SET  @V_DEFAULT = '0';
				--PRINT '@V_DEFAULT IN NUMBER: '+@V_DEFAULT ;
            END
			ELSE
			BEGIN
			    --PRINT '@V_COLUMN_DATA_TYPE IN ELSE';
				SET @V_DEFAULT = '''''';
				--PRINT '@V_DEFAULT IN ELSE: '+@V_DEFAULT ;
            END


            /* INSERT 타겟테이블 SELECT 백업(=원본)테이블 */
			--PRINT '@V_SEL_SQL IN CURSOR: '+@V_SEL_SQL ;
			--PRINT '@V_DEFAULT IN CURSOR: '+@V_DEFAULT ;
            SET @V_SEL_SQL = @V_SEL_SQL + ',' + @V_DEFAULT ;
			--PRINT '@V_SEL_SQL IN CURSOR2: '+@V_SEL_SQL ;
            FETCH NEXT FROM CUR_GET_DIFF_COL INTO @V_COLUMN_NAME, @V_COLUMN_DATA_TYPE
        END

        /* INSERET 문장 완성 */
        SET @V_INS_SQL = @V_INS_SQL + ') ';
		--PRINT '@V_INS_SQL : '+@V_INS_SQL ;
		--PRINT '@V_SEL_SQL : '+@V_SEL_SQL ;
        /* SELECT 문장 완성 */
        SET @V_SEL_SQL = @V_SEL_SQL + ' FROM '+@I_SOURCE_TABLE;
		--PRINT @V_SEL_SQL ;
        /* 신규/변경 컬럼을 포함한 INSERT..SELECT.. 문장 완성 */
		SET @V_SQL = @V_INS_SQL + @V_SEL_SQL ;
		PRINT '@V_SQL: '+@V_SQL ;
        SET NOCOUNT OFF;
        EXEC(@V_SQL);
		SET NOCOUNT ON;

        /* 임시 테이블 삭제 #TMP_TB_TARGET */
        IF OBJECT_ID('tempdb..#TMP_TB_TARGET') IS NOT NULL
        BEGIN 
            DROP TABLE #TMP_TB_TARGET ;
        END  -- END IF 

        /* 임시 테이블 삭제 #TMP_TB_SOURCE */
        IF OBJECT_ID('tempdb..#TMP_TB_SOURCE') IS NOT NULL
        BEGIN 
            DROP TABLE #TMP_TB_SOURCE ;
        END  -- END IF 
        /* 이하 프로시저 실행 결과 로깅을 위한 정보 설정 */
        /* 종료 상태 SET */
        SET @V_EXEC_STAT_CD = 'Y';
        /* 종료 시간 SET */
        SET @V_EXEC_END_DTTM = SYSDATETIME();
        /* 사용자 정의 메시지(USER MESSAGE) SET(OPTION), 사용자 정의 메시지 불필요할경우 아래 내용 주석 */
        SET @V_USER_MESSAGE = N'RESTORE 완료, '+FORMAT(GETDATE(),'yyyy-MM-dd hh:mm:ss')+ ', SOURCE: '+@I_SOURCE_TABLE+', TARGET: '+@I_SOURCE_TABLE ;
        /* 실행 이력(정상) 저장:시작 */
        EXEC PR_PROC_EXEC_LOG @I_PROC_NM = @V_PROC_NM
                            , @I_EXEC_STAT_CD = @V_EXEC_STAT_CD
                            , @I_EXEC_STRT_DTTM = @V_EXEC_STRT_DTTM
                            , @I_EXEC_END_DTTM = @V_EXEC_END_DTTM
                            , @I_USER_MESSAGE = @V_USER_MESSAGE
        ;
    END TRY
    BEGIN CATCH
        SET @V_EXEC_STAT_CD = 'N';
        SET @V_EXEC_END_DTTM = SYSDATETIME();
        SET @V_ERR_NO = ERROR_NUMBER();
        SET @V_ERR_MESSAGE = ERROR_MESSAGE();
        SET @V_USER_MESSAGE = 'XXX';
        SET @V_ERR_STATE = ERROR_STATE();
        SET @V_ERR_SEVERITY = ERROR_SEVERITY();
        SET @V_ERR_LINE = ERROR_LINE();
		PRINT @V_ERR_MESSAGE ;

        EXEC PR_PROC_EXEC_LOG @I_PROC_NM = @V_PROC_NM
                            , @I_EXEC_STAT_CD = @V_EXEC_STAT_CD
                            , @I_EXEC_STRT_DTTM = @V_EXEC_STRT_DTTM
                            , @I_EXEC_END_DTTM = @V_EXEC_END_DTTM 
                            , @I_ERR_NO = @V_ERR_NO
                            , @I_ERR_MESSAGE = @V_ERR_MESSAGE
                            , @I_ERR_STATE = @V_ERR_STATE
                            , @I_ERR_SEVERITY = @V_ERR_SEVERITY
                            , @I_ERR_LINE = @V_ERR_LINE 
        ;
    END CATCH
    SET NOCOUNT OFF
END


--OLD
CREATE PROCEDURE [dbo].[PR_DBA_RESTORETAB](@I_SOURCE_TABLE VARCHAR(100), @I_TARGET_TABLE VARCHAR(100))
AS
DECLARE @V_SQL VARCHAR(4000), @V_COLUMN VARCHAR(1000) ;
BEGIN
WITH COLUMN_INFO
AS
(SELECT DB_NAME() AS DB_NAME
     , I.TABLE_SCHEMA
     , O.NAME AS TABLE_NAME
     , C.NAME AS COLUMN_NAME
     , CAST(p.value AS sql_variant) AS ExtendedPropertyValue
     , I.ORDINAL_POSITION 
     , I.DATA_TYPE AS DATA_TYPE
     , C.LENGTH
     , C.XPREC
     , C.XSCALE
     , CASE WHEN C.ISNULLABLE=0 THEN 'NOT NULL' ELSE 'NULLABLE' END IS_NULLABLE
     , I.COLLATION_NAME
     , CASE WHEN Q.COLUMN_NAME IS NOT NULL THEN 'Y'
       ELSE 'N' END IS_PK
	 , CASE WHEN C.STATUS=128 THEN 'Y' ELSE 'N' END IS_IDENTITY
  FROM SYSOBJECTS O (NOLOCK)
 INNER JOIN SYSCOLUMNS C (NOLOCK)
    ON O.ID = C.ID
 INNER JOIN INFORMATION_SCHEMA.COLUMNS I (NOLOCK)
    ON O.NAME = I.TABLE_NAME 
   AND C.NAME = I.COLUMN_NAME
  LEFT OUTER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE  Q (NOLOCK)
    ON Q.TABLE_NAME = I.TABLE_NAME
   AND Q.COLUMN_NAME = I.COLUMN_NAME
  LEFT OUTER JOIN sys.extended_properties p 
    ON p.major_id=C.ID 
   AND p.minor_id=C.COLID
   AND p.class=1
 WHERE 1=1
   AND O.NAME IN (@I_TARGET_TABLE, @I_SOURCE_TABLE)
)
SELECT @V_COLUMN = STRING_AGG(COLUMN_NAME, ',')
  FROM (SELECT COLUMN_NAME
          FROM COLUMN_INFO
         WHERE TABLE_NAME=@I_TARGET_TABLE
     INTERSECT
        SELECT COLUMN_NAME
          FROM COLUMN_INFO
         WHERE TABLE_NAME=@I_SOURCE_TABLE) A
SET @V_SQL='INSERT INTO '+@I_TARGET_TABLE+'('+@V_COLUMN+') SELECT '+@V_COLUMN+' FROM '+@I_SOURCE_TABLE;
PRINT @V_SQL;
EXEC(@V_SQL);
END
GO

--사용법
PR_DBA_RESTORETAB @I_SOURCE_TABLE='FI_ACNT_M_BAK_20210123', @I_TARGET_TABLE='FI_ACNT_M'



--#########################################################
--##### RW GRANTEE 확인 PR_DBA_GETRWGRANTEE
--#########################################################

CREATE PROCEDURE PR_DBA_GETRWGRANTEE(@I_TABLE_NAME VARCHAR(100))
AS
BEGIN
  DECLARE @O_RW_GRANTEE VARCHAR(100);

  CREATE TABLE #RW_INFO
  (TABLE_NAME_PREFIX VARCHAR(100)
  ,RW_GRANTEE VARCHAR(100));

  INSERT INTO #RW_INFO 
  SELECT DISTINCT LEFT(TABLE_NAME,CHARINDEX('_',TABLE_NAME)-1)
	   , REVERSE(LEFT(REVERSE(GRANTEE),CHARINDEX('_',REVERSE(GRANTEE))-1)) 
    FROM DBA_TAB_PRIVS 
   WHERE 1=1
     --AND GRANTEE LIKE 'RL\_%' ESCAPE '\'
	 AND GRANTEE LIKE 'RL%' 
     AND CLASS_DESC ='OBJECT_OR_COLUMN'
	 AND REG_DT = CONVERT(DATE, GETDATE()-1)

  SELECT @O_RW_GRANTEE = RW_GRANTEE
    FROM #RW_INFO
   WHERE TABLE_NAME_PREFIX = LEFT(@I_TABLE_NAME,CHARINDEX('_',@I_TABLE_NAME)-1)
   
  PRINT 'RW GRANTEE : '+@O_RW_GRANTEE ;
  DROP TABLE #RW_INFO ;
END
GO

-- 사용법
PR_DBA_GETRWGRANTEE 테이블명
PR_DBA_GETRWGRANTEE EI_IMPO_IN_CAR_ASGMT_M


--#########################################################
--##### 테이블 카운트 COUNT
--#########################################################
CREATE PROCEDURE PR_DBA_CNTROWS
(@I_DB VARCHAR(100)
,@I_SCHEMA VARCHAR(100)
)
AS
BEGIN
  DECLARE @V_SQL VARCHAR(4000) ;
  /*
  SET @V_SQL = SELECT 'SELECT ROW_NUMBER() OVER(ORDER BY (SELECT 1)) AS ROWNUM
                , ''SELECT '''+TABLE_NAME+''' AS TABLE_NAME, (SELECT COUNT(*) FROM '+@I_DB+'.'+@I_SCHEMA+'.'+TABLE_NAME+' AS CNT'
    FROM DBO.DBA_COUNT ;
	*/
  SET @V_SQL = '
  WITH TB_STMT
  AS 
  (SELECT ROW_NUMBER() OVER(ORDER BY (SELECT 1)) AS RNUM
        , ''SELECT ''''''+TABLE_NAME+'''''' AS TABLE_NAME, (SELECT COUNT(*) FROM '+@I_DB+'.'+@I_SCHEMA+'.''+TABLE_NAME+'' WITH(NOLOCK)) AS CNT'' AS STMT
     FROM ERP.DBO.DBA_COUNT
  )
  
  SELECT CASE WHEN A.RNUM <> 1 THEN ''UNION ALL'' ELSE REPLICATE('' '', LEN(''UNION ALL'')) END + '' '' + A.STMT AS STMT
    FROM TB_STMT A
   ORDER BY A.RNUM' ;
  PRINT @V_SQL;
  EXEC(@V_SQL);
END;

--실행
INSERT INTO ERP.DBO.DBA_COUNT VALUES('COUNT 해야할 테이블명');
EXEC PR_DBA_CNTROWS @I_DB='ERP', @I_SCHEMA='DBO'


--#########################################################
--##### 테이블에 해당하는 업무코드 확인
--#########################################################
CREATE PROCEDURE [dbo].[PR_DBA_GETRWGRANTEE](@I_TABLE_NAME VARCHAR(100))
AS
BEGIN
  DECLARE @O_RW_GRANTEE VARCHAR(100);

  CREATE TABLE #RW_INFO
  (TABLE_NAME_PREFIX VARCHAR(100)
  ,RW_GRANTEE VARCHAR(100));

  INSERT INTO #RW_INFO 
  SELECT DISTINCT LEFT(TABLE_NAME,CHARINDEX('_',TABLE_NAME)-1)
	   , REVERSE(LEFT(REVERSE(GRANTEE),CHARINDEX('_',REVERSE(GRANTEE))-1)) 
    FROM DBA_TAB_PRIVS 
   WHERE 1=1
     --AND GRANTEE LIKE 'RL\_%' ESCAPE '\'
	 AND GRANTEE LIKE 'RL%' 
     AND CLASS_DESC ='OBJECT_OR_COLUMN';

  SELECT @O_RW_GRANTEE = RW_GRANTEE
    FROM #RW_INFO
   WHERE TABLE_NAME_PREFIX = LEFT(@I_TABLE_NAME,CHARINDEX('_',@I_TABLE_NAME)-1)
   
  PRINT 'RW GRANTEE : '+@O_RW_GRANTEE ;
  DROP TABLE #RW_INFO ;
END

--사용법
PR_DBA_GETRWGRANTEE CO_XXX


--#########################################################
--##### PK 삭제, PRIMARY KEY 삭제
--#########################################################
WITH PK_CONSTRAINT
AS
(SELECT NAME AS PK_NAME
, OBJECT_NAME(PARENT_OBJECT_ID) AS TABLE_NAME
FROM SYS.key_constraints WITH(NOLOCK)
WHERE OBJECT_NAME(PARENT_OBJECT_ID) IN (SELECT NAME FROM SYS.ALL_OBJECTS WHERE TYPE='U')
AND TYPE ='PK'
)
SELECT 'ALTER TABLE '+TABLE_NAME+' DROP CONSTRAINT '+PK_NAME AS STMT
FROM PK_CONSTRAINT
ORDER BY STMT
GO


--#########################################################
--##### GAP 비교(QA-DEV)
--#########################################################

CREATE TABLE #GAP
(DB_NAME		VARCHAR(20)
,SCHEMA_NAME	VARCHAR(20)
,OBJECT_TYPE	VARCHAR(100)
,OBJECT_NAME	VARCHAR(100)
,COLUMN_NAME	VARCHAR(500)
,ERROR_TYPE		VARCHAR(200)
,QA_EXISTS		VARCHAR(10)
,DEV_EXISTS		VARCHAR(10)
)
GO

INSERT INTO #GAP EXEC SP_DBA_GAPINFO_QADEV ERP


--#########################################################
--##### GAP 비교(ERP-TMPDEV)
--#########################################################

-- 테이블 존재 비교
USE ERP
GO

DECLARE @I_DB_NAME VARCHAR(100) ;
SET @I_DB_NAME = 'ERP'
 SELECT SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME  
  , A.TYPE_DESC AS OBJECT_TYPE  
  , A.NAME AS OBJECT_NAME  
  , NULL AS COLUMN_NAME  
  , '테이블 미 존재' AS ERROR_TYPE  
  , 'Y' AS ERP_EXISTS  
  , '-' AS TMPDEV_EXISTS   
  FROM ERP.SYS.ALL_OBJECTS A  
  LEFT OUTER JOIN TMPDEV.SYS.ALL_OBJECTS B  
  ON A.SCHEMA_ID = B.SCHEMA_ID  
  AND A.TYPE_DESC = B.TYPE_DESC  
  AND A.NAME = B.NAME  
  WHERE 1=1  
  AND A.TYPE IN ('U')   
  AND A.SCHEMA_ID NOT IN (SCHEMA_ID('SYS'))  
  AND A.NAME NOT LIKE 'ZZ%' 
  AND B.NAME IS NULL  
  UNION ALL  
  SELECT SCHEMA_NAME(B.SCHEMA_ID) AS SCHEMA_NAME  
  , B.TYPE_DESC AS OBJECT_TYPE  
  , B.NAME AS OBJECT_NAME  
  , NULL AS COLUMN_NAME  
  , '테이블 미 존재' AS ERROR_TYPE  
  , '-' AS ERP_EXISTS  
  , 'Y' AS TMPDEV_EXISTS  
  FROM ERP.SYS.ALL_OBJECTS A  
  RIGHT OUTER JOIN TMPDEV.SYS.ALL_OBJECTS B  
  ON A.SCHEMA_ID = B.SCHEMA_ID  
  AND A.TYPE_DESC = B.TYPE_DESC  
  AND A.NAME = B.NAME  
  WHERE 1=1  
  AND B.TYPE IN ('U')   
  AND B.SCHEMA_ID NOT IN (SCHEMA_ID('SYS'))  
  AND B.NAME NOT LIKE 'ZZ%'   
  AND A.NAME IS NULL
GO


-- 테이블 컬럼 비교
USE ERP
GO

WITH TABLE_COLUMN_INFO_DEV  
  AS  
  ( SELECT TAB.NAME AS TABLE_NAME  
  , COL.NAME AS COLUMN_NAME  
  , COL.COLUMN_ID  
  , ROW_NUMBER() OVER(PARTITION BY TAB.NAME ORDER BY COLUMN_ID) COLUMN_SEQ  
  , COL.MAX_LENGTH  
  , COL.PRECISION  
  , COL.SCALE  
  , COL.COLLATION_NAME  
  , COL.IS_NULLABLE  
  , COL.IS_IDENTITY  
  , COL.IS_COMPUTED  
  FROM TMPDEV.SYS.ALL_COLUMNS COL  
  JOIN TMPDEV.SYS.TABLES TAB  
  ON COL.OBJECT_ID = TAB.OBJECT_ID  
  WHERE TAB.TYPE_DESC='USER_TABLE'  
  )  
  , TABLE_COLUMN_INFO_QA  
  AS  
  (SELECT TAB.NAME AS TABLE_NAME  
  , COL.NAME AS COLUMN_NAME  
  , COL.COLUMN_ID  
  , ROW_NUMBER() OVER(PARTITION BY TAB.NAME ORDER BY COLUMN_ID) COLUMN_SEQ  
  , COL.MAX_LENGTH  
  , COL.PRECISION  
  , COL.SCALE  
  , COL.COLLATION_NAME  
  , COL.IS_NULLABLE  
  , COL.IS_IDENTITY  
  , COL.IS_COMPUTED  
  FROM ERP.SYS.ALL_COLUMNS COL  
  JOIN ERP.SYS.TABLES TAB  
  ON COL.OBJECT_ID = TAB.OBJECT_ID  
  WHERE TAB.TYPE_DESC='USER_TABLE')  
  SELECT DISTINCT 'dbo' AS SCHEMA_NAME  
  , 'TABLE:COLUMN' AS OBJECT_TYPE  
  , DEV.TABLE_NAME AS OBJECT_NAME  
  , NULL AS COLUMN_NAME  
  , '테이블 컬럼 불일치' AS ERROR_TYPE  
  , '-' AS ERP_EXISTS  
  , 'Y' AS TMPDEV_EXISTS     
  FROM TABLE_COLUMN_INFO_DEV DEV  
  LEFT OUTER JOIN TABLE_COLUMN_INFO_QA QA  
  ON DEV.TABLE_NAME = QA.TABLE_NAME  
  AND DEV.COLUMN_NAME = QA.COLUMN_NAME  
  --AND DEV.COLUMN_ID = QA.COLUMN_ID   
  AND DEV.COLUMN_SEQ = QA.COLUMN_SEQ  
  AND DEV.MAX_LENGTH = QA.MAX_LENGTH   
  AND DEV.PRECISION = QA.PRECISION   
  AND DEV.SCALE = QA.SCALE   
  --AND DEV.COLLATION_NAME = QA.COLLATION_NAME   
  AND DEV.IS_NULLABLE = QA.IS_NULLABLE   
  AND DEV.IS_IDENTITY = QA.IS_IDENTITY   
  AND DEV.IS_COMPUTED = QA.IS_COMPUTED  
  WHERE 1=1  
  AND DEV.TABLE_NAME NOT LIKE 'ZZ%'  
  AND DEV.TABLE_NAME NOT LIKE 'TEST%'  
  AND DEV.TABLE_NAME NOT LIKE 'TMP%'  
  AND DEV.TABLE_NAME NOT LIKE 'TRACE_XE%'  
  AND QA.COLUMN_NAME IS NULL  
  --ORDER BY DEV.TABLE_NAME, DEV.COLUMN_SEQ  
  GO




--#########################################################
--##### 제약조건 위배
--#########################################################
--PK, PRIMARY KEY
SELECT DISTINCT 'ALTER TABLE '+TABLE_NAME+' DROP CONSTRAINT '+CONSTRAINT_NAME STMT
--SELECT *
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE 1=1
AND TABLE_CATALOG LIKE 'FILA%'
AND CONSTRAINT_NAME NOT LIKE 'PK%' 
AND TABLE_NAME NOT LIKE 'BATCH%'
AND TABLE_NAME NOT LIKE 'TB%'
--ORDER BY TABLE_NAME, ORDINAL_POSITION 
UNION ALL
SELECT 'ALTER TABLE '+TABLE_NAME+' ADD CONSTRAINT '+CONSTRAINT_NAME+' PRIMARY KEY('+COLUMN_NAME+')' STMT
FROM (SELECT TABLE_NAME
, STRING_AGG(COLUMN_NAME,',') WITHIN GROUP(ORDER BY ORDINAL_POSITION) COLUMN_NAME
, 'PK_'+TABLE_NAME CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE 1=1
AND TABLE_CATALOG LIKE 'FILA%'
AND CONSTRAINT_NAME NOT LIKE 'PK%' 
AND TABLE_NAME NOT LIKE 'BATCH%'
AND TABLE_NAME NOT LIKE 'TB%'
GROUP BY TABLE_NAME) A
GO


--DEFAULT
WITH CHECK_CONSTRAINT_INFO
AS (
SELECT B.TABLE_NAME
     , B.COLUMN_NAME
     , A.NAME AS [ASIS_CONST_NAME]
	 , B.TABLE_NAME+'_'+B.COLUMN_NAME+'_DFLT' AS [TOBE_CONST_NAME]
	 , A.PARENT_COLUMN_ID
	 , B.ORDINAL_POSITION
  FROM SYS.DEFAULT_CONSTRAINTS A WITH(NOLOCK)
  JOIN INFORMATION_SCHEMA.COLUMNS B WITH(NOLOCK)
    ON OBJECT_NAME(A.PARENT_OBJECT_ID) = B.TABLE_NAME
   AND A.PARENT_COLUMN_ID = B.ORDINAL_POSITION
 WHERE 1=1
   AND B.TABLE_CATALOG = 'ERP'
)
SELECT TABLE_NAME
     , COLUMN_NAME
	 , ASIS_CONST_NAME
	 , TABLE_NAME+'_'+COLUMN_NAME+'_DFLT' [TT]
	 , TOBE_CONST_NAME
	 --, 'SP_RENAME '''+ASIS_CONST_NAME+''''+','+''''+ASIS_CONST_NAME+'_TEMP''' AS SP_RENAME_STMT_TEMP
	 --, 'SP_RENAME '''+ASIS_CONST_NAME+''''+','+''''+TOBE_CONST_NAME AS SP_RENAME_STMT
  FROM CHECK_CONSTRAINT_INFO
 WHERE ASIS_CONST_NAME <> TABLE_NAME+'_'+COLUMN_NAME+'_DFLT'
 ORDER BY TABLE_NAME, COLUMN_NAME
GO


--#########################################################
--##### WAITFOR DELAY
--#########################################################
  UPDATE ...
  SET ...
  WHERE  ...
  WAITFOR DELAY '00:00:07' 
  

--#########################################################
--##### 관리용 프로시저
--#########################################################
--PR_DBA_ACTIVESESS
--설명
ACTIVE SESSION 조회
EXEC sp_addextendedproperty 
	@name=N'MS_Description', @value=N'Active Session 조회', 
	@level0type=N'SCHEMA', @level0name=N'dbo', 
	@level1type=N'PROCEDURE', @level1name=N'PR_DBA_ACTIVESESS'
GO
--사용법
PR_DBA_ACTIVESESS

--PR_DBA_BACKUPTAB
--설명
TAB1 테이블을 TAB2로 백업한다(SELECT...INTO...)
--사용법
PR_DBA_BACKUPTAB TAB1 TAB2
OR PR_DBA_BACKUPTAB @ORIGINAL_TABLE_NAME=EI_IMPO_IN_CAR_ASGMT_M , @BACKUP_TABLE_NAME=EI_IMPO_IN_CAR_ASGMT_M_BAK_20240122

--PR_DBA_RESTORETAB @I_TARGET_TABLE='FI_ACNT_M', @I_SOURCE_TABLE='FI_ACNT_M_BAK_20210123'
--설명
파라미터로 받은 2개의 테이블간에 컬럼명이 동일한 데이터 입력
--사용법
PR_DBA_RESTORETAB EI_IMPO_IN_CAR_ASGMT_M_BAK_20240122, EI_IMPO_IN_CAR_ASGMT_M
OR PR_DBA_RESTORETAB @I_SOURCE_TABLE='FI_ACNT_M_BAK_20210123', @I_TARGET_TABLE='FI_ACNT_M'

--PR_DBA_COLCOMMENT
--설명
입력값으로 영문을 받을 경우 해당 컬럼의 한글COMMENT 및 컬럼 정보 출력
입력값으로 한글을 받을 경우 입력 받은 입력값을 한글COMMENT에 포함하는 컬럼 정보 출력
--사용법
--1) 영문 입력 시 : 컬럼명(영문)으로 한글명 조회
PR_DBA_COLCOMMENT 컬럼명(영문)
--예) PR_DBA_COLCOMMENT COMP_CD
PR_DBA_COLCOMMENT @I_COLUMN_NAME=컬럼명(영문)
--예) PR_DBA_COLCOMMENT @I_COLUMN_NAME=COMP_CD


--2) 한글 입력 시 : 컬럼명(한글)으로 영문명 조회
--영문으로 조회할 때와 다르게 LIKE '%컬럼명(한글)%'으로 검색
PR_DBA_COLCOMMENT 컬럼명(한글)
--예) PR_DBA_COLCOMMENT 회사
PR_DBA_COLCOMMENT @I_COLUMN_NAME=컬럼명(한글)
--예) PR_DBA_COLCOMMENT @I_COLUMN_NAME=회사


--PR_DBA_CNTROWS
--설명
테이블명과 건수 카운트한 결과 출력
--사용법
--1) 카운팅 해야 할 테이블 입력
INSERT INTO ERP.DBO.DBA_COUNT VALUES('COUNT 해야할 테이블명');
--2) 프로시저 실행
EXEC PR_DBA_CNTROWS @I_DB='ERP', @I_SCHEMA='DBO'

--PR_DBAOBJECT SA_STYL_YR_RYLTY_MNG_M
--설명
오브젝트 정보를 조회
--사용법
PR_DBA_OBJECT 오브젝트명
OR PR_DBA_OBJECT @I_OBJECT_NAME=오브젝트명

--PR_DBA_GETRWGRANTEE CO_XXX
--설명
BIZ CODE에 해당하는 계정 조회. CO_XXX 테이블의 BIZCODE는 FCM
--사용법
PR_DBA_GETRWGRANTEE CO_XXX
OR PR_DBA_GETRWGRANTEE @I_TABLE_NAME=CO_XXX

--PR_DBA_TABCOMMENT
--설명
테이블의 컬럼 코멘트 조회
--사용법
--1) 영문 입력 시 : 테이블명(영문)으로 한글명 조회
PR_DBA_TABCOMMENT 테이블명(영문)
--예) PR_DBA_TABCOMMENT CM_TODO_LIST_M
PR_DBA_TABCOMMENT @I_TABLE_NAME=테이블명(영문)
--예) PR_DBA_TABCOMMENT @I_TABLE_NAME=CM_TODO_LIST_M

--2) 한글 입력 시 : 테이블명(한글)으로 영문명 조회
--영문으로 조회할 때와 다르게 LIKE '%테이블명(한글)%'으로 검색
PR_DBA_TABCOMMENT 테이블명(한글)
--예) PR_DBA_TABCOMMENT 관리
PR_DBA_TABCOMMENT @I_TABLE_NAME=테이블명(한글)
--예) PR_DBA_TABCOMMENT @I_TABLE_NAME=관리


--PR_DBA_RECREATETAB
--변경관리, 변경 관리용 프로시저
--SELECT COUNT(*), PR_DBA_BACKUPTAB, PR_DBA_GETPRIVS, PR_DBA_RESTORETAB 문장 만들어줌
PR_DBA_TABCOMMENT 테이블명(영문)

--PR_DBA_TABSIZE
--설명
테이블의 용량 정보 조회
--사용법
PR_DBA_TABSIZE 테이블명
OR PR_DBA_TABSIZE @I_TABLE_NAME=테이블명

--SP_HELP
--설명
테이블의 정보(컬럼, PK, 인덱스 등) 조회
--사용법
SP_HELP 테이블명

--SP_HELPDB
--설명
데이터베이스 정보(SIZE, 파일그룹, STATUS, COMPATIBILITY, MAXSIZE, GROWTH) 조회
--사용법
SP_HELPDB 데이터베이스명

--SP_HELPINDEX
--설명
테이블이 가지고 있는 인덱스 정보
--사용법
SP_HELPINDEX 테이블명

--PR_DBA_GETPRIVS 테이블명
--설명
테이블의 권한 조회(GRANT문 포함)
--사용법
PR_DBA_GETPRIVS 테이블명




--ASIS에서 DML 포함하는 PROCEDURE, FUNCTION 찾기
SELECT OWNER, TYPE, NAME, LISTAGG(DML_TYPE,',') WITHIN GROUP(ORDER BY OWNER, TYPE, NAME) AS DML_T
FROM (
SELECT OWNER
, NAME
, TYPE
--, TEXT
, CASE WHEN UPPER(TEXT) LIKE '%INSERT%' THEN 'INSERT'
       WHEN UPPER(TEXT) LIKE '%UPDATE%' THEN 'UPDATE'
       WHEN UPPER(TEXT) LIKE '%DELETE%' THEN 'DELETE'
       WHEN UPPER(TEXT) LIKE '%MERGE%' THEN 'MERGE'
       ELSE 'ELSE' END DML_TYPE
FROM DBA_SOURCE
WHERE 1=1
AND OWNER NOT LIKE 'SYS%'
AND OWNER NOT LIKE '%SYS' 
AND OWNER NOT IN ('OUTLN','XDB','DBSNMP','ORACLE_OCM','PERFSTAT')
AND (UPPER(TEXT) LIKE '%INSERT%' OR UPPER(TEXT) LIKE '%DELETE%' OR UPPER(TEXT) LIKE '%UPDATE%' OR UPPER(TEXT) LIKE '%MERGE%')
)
GROUP BY OWNER, TYPE, NAME
ORDER BY OWNER, TYPE, NAME
;


--#########################################################
--##### WAITRESOURCE PAGE: 8:281474978938880 (2813675afbcf)
--#########################################################

DBCC TRACEON(3604)
dbcc page ( 8, 1, 23840755, 2)
결과 아래쪽에 Metadata: ObjectId = 1067150847 나옴, ObjectId 로 조회
SELECT OBJECT_NAME(1067150847)


--#########################################################
--##### WAITRESOURCE KEY: 8:281474978938880 (2813675afbcf)
--#########################################################
WAITRESOURCE에 아래와 같이 KEY: X:XXXXXXXXXXXXXXX (XXXXXXXXX)로 나타날때 대상 조회
KEY: 27:72057594271563776 (c5000d8469fb)

SELECT 
    name 
FROM sys.databases 
WHERE database_id=27;
GO
위에서 확인된 DB로 이동(ERP일 경우)

USE ERP

SELECT 
    sc.name as schema_name, 
    so.name as object_name, 
    si.name as index_name
FROM sys.partitions AS p
JOIN sys.objects as so on 
    p.object_id=so.object_id
JOIN sys.indexes as si on 
    p.index_id=si.index_id and 
    p.object_id=si.object_id
JOIN sys.schemas AS sc on 
    so.schema_id=sc.schema_id
WHERE hobt_id = 72057594271563776;
GO


SELECT * FROM table_name WHERE %%LOCKRES%% = 'c5000d8469fb';


--#########################################################
--##### WAITRESOURCE RID: 23:4:3474480:0
--#########################################################
RID: 23:4:3474480:0  (db id:file id:page id:slot)
SELECT OBJECT_NAME(OBJECT_ID) FROM SYS.dm_db_page_info(23,4,3474480,NULL)





-- 여부컬럼(%_YN) 정보
SELECT A.TABLE_SCHEMA
, A.TABLE_NAME
, D.VALUE TABLE_COMMENT
, A.COLUMN_NAME
, C.VALUE COLUMN_COMMENT
, A.COLUMN_DEFAULT
, A.IS_NULLABLE
, A.DATA_TYPE
, A.CHARACTER_MAXIMUM_LENGTH
--, A.CHARACTER_SET_NAME
, A.COLLATION_NAME
, B.CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.COLUMNS  A -- TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME
LEFT OUTER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE B
ON A.TABLE_SCHEMA = B.TABLE_SCHEMA
AND A.TABLE_NAME = B.TABLE_NAME
AND A.COLUMN_NAME = B.COLUMN_NAME
LEFT JOIN SYS.EXTENDED_PROPERTIES C
             ON C.MAJOR_ID = OBJECT_ID(A.TABLE_NAME)
            AND C.MINOR_ID = A.ORDINAL_POSITION
LEFT JOIN (SELECT OBJECT_ID(OBJNAME) TABLE_ID
    	                   , VALUE
                        FROM ::FN_LISTEXTENDEDPROPERTY(NULL,'USER','DBO','TABLE',NULL,NULL,NULL)) D
             ON D.TABLE_ID=OBJECT_ID(A.TABLE_NAME)
WHERE 1=1
AND A.COLUMN_NAME LIKE '%\_YN' ESCAPE '\' 
AND A.TABLE_NAME NOT LIKE 'TMP\_%' ESCAPE '\' 
AND A.TABLE_NAME NOT LIKE 'ASIS\_%' ESCAPE '\' 
AND A.TABLE_NAME NOT LIKE 'TB\_%' ESCAPE '\' 
AND A.TABLE_NAME NOT LIKE '%\_BAK\_202%' ESCAPE '\' 
ORDER BY A.TABLE_SCHEMA
, A.TABLE_NAME
, A.COLUMN_NAME ;
'




--#########################################################
--##### PR_DBA_GETSQLSTATS, DBA_HIST_SQLSTATS
--#########################################################
CREATE PROCEDURE [dbo].[PR_DBA_GETSQLSTATS]
AS
--SET NOCOUNT ON; 
/******************************************************************************
[프로그램명]
PR_DBA_GETSQLSTATS
[설명]
SQL 성능정보 수집(DM_EXEC_QUERY_STATS 데이터 누적)
[파라미터]
N/A
[VERSIONS]
----------  ---------------  ------------------------------------
2024-03-08  강현호           최초 작성
[TEST/EXCUTE]
EXEC PR_DBA_RESTORETAB 
******************************************************************************/
BEGIN
    BEGIN TRY
        /* DBA_HIST_SQLSTATS 테이블이 없을 경우 SELECT .. INTO .. 로 테이블 생성 */
        IF OBJECT_ID('ERP..DBA_HIST_SQLSTATS') IS NULL
        BEGIN 
            SELECT GETDATE() AS SNAP_DTTM
                 , (SELECT TEXT FROM SYS.DM_EXEC_SQL_TEXT(SQL_HANDLE)) AS PARENT_SQL_TEXT
				 , SUBSTRING(S2.TEXT,  STATEMENT_START_OFFSET / 2, ( (CASE WHEN STATEMENT_END_OFFSET = -1 THEN (LEN(CONVERT(NVARCHAR(MAX),S2.TEXT)) * 2)  ELSE STATEMENT_END_OFFSET END)  - STATEMENT_START_OFFSET) / 2) AS SQL_TEXT
                 , statement_start_offset
                 , statement_end_offset
                 , plan_generation_num
                 , creation_time
                 , last_execution_time
                 , execution_count
                 , total_worker_time
                 , last_worker_time
                 , min_worker_time
                 , max_worker_time
                 , total_physical_reads
                 , last_physical_reads
                 , min_physical_reads
                 , max_physical_reads
                 , total_logical_writes
                 , last_logical_writes
                 , min_logical_writes
                 , max_logical_writes
                 , total_logical_reads
                 , last_logical_reads
                 , min_logical_reads
                 , max_logical_reads
                 , total_clr_time
                 , last_clr_time
                 , min_clr_time
                 , max_clr_time
                 , total_elapsed_time
                 , last_elapsed_time
                 , min_elapsed_time
                 , max_elapsed_time
                 , query_hash
                 , query_plan_hash
                 , total_rows
                 , last_rows
                 , min_rows
                 , max_rows
                 , statement_sql_handle
                 , statement_context_id
                 , total_dop
                 , last_dop
                 , min_dop
                 , max_dop
                 , total_grant_kb
                 , last_grant_kb
                 , min_grant_kb
                 , max_grant_kb
                 , total_used_grant_kb
                 , last_used_grant_kb
                 , min_used_grant_kb
                 , max_used_grant_kb
                 , total_ideal_grant_kb
                 , last_ideal_grant_kb
                 , min_ideal_grant_kb
                 , max_ideal_grant_kb
                 , total_reserved_threads
                 , last_reserved_threads
                 , min_reserved_threads
                 , max_reserved_threads
                 , total_used_threads
                 , last_used_threads
                 , min_used_threads
                 , max_used_threads
                 , total_columnstore_segment_reads
                 , last_columnstore_segment_reads
                 , min_columnstore_segment_reads
                 , max_columnstore_segment_reads
                 , total_columnstore_segment_skips
                 , last_columnstore_segment_skips
                 , min_columnstore_segment_skips
                 , max_columnstore_segment_skips
                 , total_spills
                 , last_spills
                 , min_spills
                 , max_spills
                 , total_num_physical_reads
                 , last_num_physical_reads
                 , min_num_physical_reads
                 , max_num_physical_reads
                 , total_page_server_reads
                 , last_page_server_reads
                 , min_page_server_reads
                 , max_page_server_reads
                 , total_num_page_server_reads
                 , last_num_page_server_reads
                 , min_num_page_server_reads
                 , max_num_page_server_reads
                 , sql_handle
                 , plan_handle
                 , (SELECT QUERY_PLAN FROM SYS.dm_exec_query_plan(PLAN_HANDLE)) AS SQL_PLAN
            INTO DBA_HIST_SQLSTATS
            FROM SYS.dm_exec_query_stats R WITH(NOLOCK)
			CROSS APPLY SYS.DM_EXEC_SQL_TEXT(R.SQL_HANDLE) S2 
        END  -- END IF 
		ELSE
        BEGIN 
            INSERT INTO DBA_HIST_SQLSTATS
            SELECT GETDATE() AS SNAP_DTTM
                 , (SELECT TEXT FROM SYS.DM_EXEC_SQL_TEXT(SQL_HANDLE)) AS PARENT_SQL_TEXT
				 , SUBSTRING(S2.TEXT,  STATEMENT_START_OFFSET / 2, ( (CASE WHEN STATEMENT_END_OFFSET = -1 THEN (LEN(CONVERT(NVARCHAR(MAX),S2.TEXT)) * 2)  ELSE STATEMENT_END_OFFSET END)  - STATEMENT_START_OFFSET) / 2) AS SQL_TEXT
                 , statement_start_offset
                 , statement_end_offset
                 , plan_generation_num
                 , creation_time
                 , last_execution_time
                 , execution_count
                 , total_worker_time
                 , last_worker_time
                 , min_worker_time
                 , max_worker_time
                 , total_physical_reads
                 , last_physical_reads
                 , min_physical_reads
                 , max_physical_reads
                 , total_logical_writes
                 , last_logical_writes
                 , min_logical_writes
                 , max_logical_writes
                 , total_logical_reads
                 , last_logical_reads
                 , min_logical_reads
                 , max_logical_reads
                 , total_clr_time
                 , last_clr_time
                 , min_clr_time
                 , max_clr_time
                 , total_elapsed_time
                 , last_elapsed_time
                 , min_elapsed_time
                 , max_elapsed_time
                 , query_hash
                 , query_plan_hash
                 , total_rows
                 , last_rows
                 , min_rows
                 , max_rows
                 , statement_sql_handle
                 , statement_context_id
                 , total_dop
                 , last_dop
                 , min_dop
                 , max_dop
                 , total_grant_kb
                 , last_grant_kb
                 , min_grant_kb
                 , max_grant_kb
                 , total_used_grant_kb
                 , last_used_grant_kb
                 , min_used_grant_kb
                 , max_used_grant_kb
                 , total_ideal_grant_kb
                 , last_ideal_grant_kb
                 , min_ideal_grant_kb
                 , max_ideal_grant_kb
                 , total_reserved_threads
                 , last_reserved_threads
                 , min_reserved_threads
                 , max_reserved_threads
                 , total_used_threads
                 , last_used_threads
                 , min_used_threads
                 , max_used_threads
                 , total_columnstore_segment_reads
                 , last_columnstore_segment_reads
                 , min_columnstore_segment_reads
                 , max_columnstore_segment_reads
                 , total_columnstore_segment_skips
                 , last_columnstore_segment_skips
                 , min_columnstore_segment_skips
                 , max_columnstore_segment_skips
                 , total_spills
                 , last_spills
                 , min_spills
                 , max_spills
                 , total_num_physical_reads
                 , last_num_physical_reads
                 , min_num_physical_reads
                 , max_num_physical_reads
                 , total_page_server_reads
                 , last_page_server_reads
                 , min_page_server_reads
                 , max_page_server_reads
                 , total_num_page_server_reads
                 , last_num_page_server_reads
                 , min_num_page_server_reads
                 , max_num_page_server_reads
                 , sql_handle
                 , plan_handle
                 , (SELECT QUERY_PLAN FROM SYS.dm_exec_query_plan(PLAN_HANDLE)) AS SQL_PLAN
            FROM SYS.dm_exec_query_stats R WITH(NOLOCK)
			CROSS APPLY SYS.DM_EXEC_SQL_TEXT(R.SQL_HANDLE) S2 
        END  -- END ELSE
		PRINT 'SUCCESS'
    END TRY
    BEGIN CATCH
        PRINT 'ERROR'
    END CATCH
    --SET NOCOUNT OFF
END






--#########################################################
--##### PK 제외 전체 인덱스 생성
--#########################################################
set nocount on

declare @c_idx table
( keyno int, 
  id int, 
  indid int,
  table_name sysname,
  index_name sysname,
  pad_indexs bit,
  fillfactors int,
  uniqueClause varchar(10),
  descClause varchar(10),
  column_name sysname,
  filegroups sysname
)


declare @c_table table
(
    id int identity,
    index_name sysname
)

insert into @c_table(index_name)
select i.name index_name
from   sysindexes i
       inner join sysobjects o
       on  i.id = o.id
where  o.xtype = 'U'
and    isnull(indexproperty(o.id, i.name, 'IsStatistics'), 1) = 0
and    indexproperty(o.id, i.name, 'IsClustered') = 0
and i.name in (select B.name from sysindexkeys A (nolock)  join sysindexes B (nolock)  on A.id = B.id and A.indid = B.indid )
and i.name like 'IX%'
-- do not select index that are already in the destination filegroup
-- sort by table, index and index-column order


insert into @c_idx
select ik.keyno, o.id, i.indid
,      o.name table_name
,      i.name index_name
,      isnull(indexproperty(o.id, i.name, 'PadIndex'), 0)
,      indexproperty(o.id, i.name, 'IndexFillFactor')
,      case indexproperty(o.id, i.name, 'IsUnique')
       when 1 then 'unique '
       else ''
       end
,      case indexkey_property(o.id, i.indid, ik.keyno, 'IsDescending')
       when 1 then ' desc'
       else ''
       end
,      c.name column_name
,      d.groupname
from   sysindexes i
       inner join sysobjects o
       on  i.id = o.id
       inner join sysindexkeys ik
       on  ik.id = o.id
       and ik.indid = i.indid
       inner join syscolumns c
       on  o.id = c.id
       and ik.colid = c.colid
       inner join sysfilegroups d
       on i.groupid = d.groupid
-- only indexes for user tables
where  o.xtype = 'U'
and    isnull(indexproperty(o.id, i.name, 'IsStatistics'), 1) = 0
and    indexproperty(o.id, i.name, 'IsClustered') = 0
and i.name in (select B.name from sysindexkeys A  (nolock) join sysindexes B  (nolock) on A.id = B.id and A.indid = B.indid )
-- do not select index that are already in the destination filegroup
-- sort by table, index and index-column order
order by o.name, i.name, ik.keyno

declare @id     int
declare @indid    int
declare @table_name  sysname
declare @index_name  sysname
declare @pad_index  bit
declare @fillfactor  int
declare @uniqueClause varchar(10)
declare @descClause  varchar(10)
declare @column_name  sysname
declare @NEW_FILEGROUP sysname

declare @currId   int
declare @currIndid  int

declare @sql    varchar(4000)

declare @t_num int, @t_max int
select @t_num=1, @t_max = max(id) from @c_table

while(@t_num <= @t_max)
begin

    select @index_name = index_name from @c_table where id = @t_num

            declare @num int, @max  int
            select @num = 1, @max = max(keyno) from @c_idx where  index_name = @index_name
            
            
            -- initialize @id and @indid for "not equal" comparison
            set @currId = -1
            set @currIndid = -1
            
            while @num <= @max
            begin
                    select @id = id, @indid = indid, @table_name = table_name, @index_name = index_name, @pad_index = pad_indexs, @fillfactor = fillfactors, @uniqueClause = uniqueClause,
                              @descClause = descClause, @column_name = column_name, @NEW_FILEGROUP = filegroups from @c_idx where keyno = @num and index_name = @index_name
    
                 if (@id != @currId) or (@indid != @currIndid)
                 begin
                  -- first, we have to finish and print the previous statement,
                  -- if any (@currId != -1)
                  if @currId != -1
                  begin
                   -- close column list and start index_options clause
                   set @sql = @sql + ')' + char(10) + 'with '
                
                   -- add index oprions pad_index and fillfactor
                   if @pad_index = 1
                    set @sql = @sql + 'pad_index' + char(10)
                
                   if @fillfactor > 0 
                     set @sql = @sql + 'fillfactor=' + cast(@fillfactor as varchar(10)) + char(10)
                
                   set @sql = @sql + 'drop_existing' + char(10) +
                   'on ' + @NEW_FILEGROUP + char(10) + 'go' + char(10)
                   print(@sql)
                  end
                
                  -- start a new create index statement
                  set @sql = 'create ' + @uniqueClause + 'index ' + @index_name + char(10) +
                             'on ' + @table_name + ' ('
                
                  set @currId = @id
                  set @currIndid = @indid
                 end
                
                 -- add column to list, ommit comma for first column
                 if right(@sql, 1) = '('
                  set @sql = @sql + @column_name + @descClause
                 else
                  set @sql = @sql + ', ' + @column_name + @descClause
                
                    set @num = @num + 1
            end
            
            -- don't forget to close the last statement too
            if @currId != -1
            begin
             -- close column list and start index_options clause
             set @sql = @sql + ')' + char(10)

             if (@pad_index = 1 or @fillfactor > 0 )
                set @sql = @sql + 'with '            
             -- add index oprions pad_index and fillfactor
             if @pad_index = 1
              set @sql = @sql + 'pad_index' + char(10)
            
             if @fillfactor > 0 
              set @sql = @sql + 'fillfactor=' + cast(@fillfactor as varchar(10)) + char(10)
            
             set @sql = @sql + 'on ' + @NEW_FILEGROUP + char(10) + 'go' + char(10)
             print(@sql)
            end

    set @t_num = @t_num + 1
end




CREATE TABLE IF NOT EXISTS ...


CREATE TABLE SCHEMA_NAME.TABLE_NAME (COLUMN_NAME DATATYPE(LENGTH) COLLATE Korean_Wansung_CS_AS) ;
* Korean_Wansung_CS_AS : 대소문자 구별
  Korean_Wansung_CI_AS : 대소문자 구별안함
  
  
  
  


--#########################################################
--##### ASIS SQL 성능정보
--#########################################################
WITH SQL_ID_MAX_REG_DTTM
AS
(SELECT SQL_ID, MAX(REG_DTTM) MAX_REG_DTTM
   FROM VSQLSTATS
   GROUP BY SQL_ID
)
SELECT A.SQL_ID
, A.SQL_FULLTEXT
, A.LAST_ACTIVE_TIME
, A.EXECUTIONS
, ROUND(A.ELAPSED_TIME/A.EXECUTIONS/1000000,4)   AS AVG_ELAPSED_TIME
, ROUND(A.CPU_TIME/A.EXECUTIONS/1000000,4)       AS AVG_CPU_TIME
, A.ROWS_PROCESSED/A.EXECUTIONS                  AS AVG_ROWS_PROCESSED
, A.PARSE_CALLS/A.EXECUTIONS                     AS AVG_PARSE_CALLS
, A.BUFFER_GETS/A.EXECUTIONS                     AS AVG_BUFFER_GETS
, A.PHYSICAL_READ_REQUESTS/A.EXECUTIONS          AS AVG_PHYSICAL_READ_REQUESTS
, A.PHYSICAL_READ_BYTES/A.EXECUTIONS             AS AVG_PHYSICAL_READ_BYTES
FROM VSQLSTATS A
JOIN SQL_ID_MAX_REG_DTTM B
ON A.SQL_ID = B.SQL_ID
AND A.REG_DTTM = B.MAX_REG_DTTM
WHERE A.SQL_ID IN (SELECT SQL_ID
                   FROM VSQL_PLAN
				   WHERE OBJECT_NAME = 'WM_OUT_DETL' )
AND A.EXECUTIONS >0
AND ROUND(A.ELAPSED_TIME/A.EXECUTIONS/1000000,4) >= 3
AND A.EXECUTIONS >= 1000
ORDER BY A.EXECUTIONS DESC ;



--#########################################################
--##### 컬럼 밀도 DENSITY
--#########################################################
WITH COL_COMMENTS
AS
(SELECT A.TABLE_CATALOG AS [DB_NAME]
     , A.TABLE_SCHEMA AS [SCHEMA_NAME]
     , A.TABLE_NAME
     , C.VALUE TABLE_COMMENT
     , A.COLUMN_NAME
     , B.VALUE COLUMN_COMMENT
     , A.COLUMN_DEFAULT AS [DEFAULT_VALUE]
     , A.IS_NULLABLE
     , A.DATA_TYPE
     , CASE WHEN A.DATA_TYPE IN ('CHAR','VARCHAR','NVARCHAR','NCHAR','TEXT') THEN CONVERT(VARCHAR, A.CHARACTER_MAXIMUM_LENGTH)
            WHEN A.DATA_TYPE IN ('INT','FLOAT','NUMERIC','BIGINT') THEN CONVERT(VARCHAR, A.NUMERIC_PRECISION) + ',' + CONVERT(VARCHAR, A.NUMERIC_SCALE)
            WHEN A.DATA_TYPE IN ('DATE','DATETIME','DATETIME2','DATETIMEOFFSET') THEN CONVERT(VARCHAR, A.DATETIME_PRECISION)
            WHEN A.DATA_TYPE IN ('VARBINARY') THEN '' END AS [DATA_LEN]
  FROM INFORMATION_SCHEMA.COLUMNS A
  LEFT JOIN SYS.EXTENDED_PROPERTIES B
    ON B.MAJOR_ID = OBJECT_ID(A.TABLE_NAME)
   AND B.MINOR_ID = A.ORDINAL_POSITION
  LEFT JOIN (SELECT OBJECT_ID(OBJNAME) TABLE_ID
                  , VALUE
               FROM ::FN_LISTEXTENDEDPROPERTY(NULL,'USER','DBO','TABLE',NULL,NULL,NULL)) C
                 ON C.TABLE_ID=OBJECT_ID(A.TABLE_NAME)
)
SELECT D.OBJECT_ID
     , D.TABLE_NAME
	 , F.TABLE_COMMENT
	 , D.STATS_ID
	 , D.STATS_NAME
	 , D.COLUMN_ID
	 , D.COLUMN_NAME
	 , F.COLUMN_COMMENT
	 , D.DENSITY
	 , E.UNFILTERED_ROWS
	 , D.DENSITY * E.UNFILTERED_ROWS SELECTIVITY
  FROM (SELECT A.OBJECT_ID
             , OBJECT_NAME(A.OBJECT_ID) AS TABLE_NAME
			 , A.STATS_ID
			 , C.NAME AS STATS_NAME
			 --, A.STATS_COLUMN_ID
			 , A.COLUMN_ID
			 , B.NAME AS COLUMN_NAME
			 --, C.*
			 , 1.0/(sum(D.distinct_range_rows)+count(D.distinct_range_rows)) DENSITY			 
          FROM SYS.STATS_COLUMNS A
		  JOIN SYS.ALL_COLUMNS B
		    ON A.OBJECT_ID = B.OBJECT_ID
		   AND A.COLUMN_ID = B.COLUMN_ID
		  JOIN SYS.STATS C
		    ON A.OBJECT_ID = C.OBJECT_ID
		   AND A.STATS_ID = C.STATS_ID
		 CROSS APPLY SYS.DM_DB_STATS_HISTOGRAM(A.OBJECT_ID, A.STATS_ID) D
         WHERE 1=1
		 --AND A.OBJECT_ID=OBJECT_ID('CM_MENU_M')
		 GROUP 
		    BY A.OBJECT_ID
			 , OBJECT_NAME(A.OBJECT_ID) 
			 , A.STATS_ID
			 , C.NAME
			 , A.COLUMN_ID
			 , B.NAME ) D
  JOIN COL_COMMENTS F
    ON D.TABLE_NAME = F.TABLE_NAME
   AND D.COLUMN_NAME = F.COLUMN_NAME
  CROSS APPLY SYS.dm_db_stats_properties(D.OBJECT_ID, D.STATS_ID) E
  WHERE 1=1
    AND D.TABLE_NAME IN (SELECT NAME FROM SYS.ALL_OBJECTS WHERE TYPE='U')
	AND D.COLUMN_NAME NOT IN ('REG_MENU_ID','REG_ID','REG_DTTM','MOD_MENU_ID','MOD_ID','MOD_DTTM')
    --AND DENSITY <= 0.01
	--AND D.DENSITY * E.UNFILTERED_ROWS < 10000
 ORDER BY TABLE_NAME, COLUMN_ID
GO



--#########################################################
--##### 자동 통계 정보 _WA_Sys_ 삭제
--#########################################################
SELECT OBJECT_NAME(OBJECT_ID), NAME, CONCAT('DROP STATISTICS ',OBJECT_NAME(OBJECT_ID),'.',NAME) DROP_STMT
--SELECT *
  FROM SYS.STATS
 WHERE 1=1
   AND AUTO_CREATED = 1 
   AND OBJECT_ID IN (SELECT OBJECT_ID FROM SYS.ALL_OBJECTS WHERE TYPE='U')
GO


--#########################################################
--##### MANUAL 통계 정보 삭제
--#########################################################
SELECT OBJECT_NAME(OBJECT_ID), NAME, CONCAT('DROP STATISTICS ',OBJECT_NAME(OBJECT_ID),'.',NAME) DROP_STMT
--SELECT *
  FROM SYS.STATS
 WHERE 1=1
   AND AUTO_CREATED = 0
   AND OBJECT_ID IN (SELECT OBJECT_ID FROM SYS.ALL_OBJECTS WHERE TYPE='U')
   AND NAME NOT LIKE 'IX%'
   AND NAME NOT LIKE 'PK%'
GO


SELECT A.OBJECT_ID
 , OBJECT_NAME(A.OBJECT_ID) AS TABLE_NAME
 , A.STATS_ID
 , A.STATS_COLUMN_ID
 , A.COLUMN_ID
 , B.NAME AS COLUMN_NAME
 , C.*
 FROM SYS.STATS_COLUMNS A
 JOIN SYS.ALL_COLUMNS B
 ON A.OBJECT_ID = B.OBJECT_ID
 AND A.COLUMN_ID = B.COLUMN_ID
 CROSS APPLY SYS.DM_DB_STATS_HISTOGRAM(A.OBJECT_ID, A.STATS_ID) C
 WHERE 1=1
 AND A.OBJECT_ID=OBJECT_ID('CM_MENU_M')
 ORDER BY A.OBJECT_ID, A.COLUMN_ID, A.STATS_ID, C.STEP_NUMBER
GO




--#########################################################
--##### 1:1 MIG 대상 데이터 적재
--#########################################################
--운영에서
USE MIG
GO

SELECT *
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'M1SRC'
ORDER BY TABLE_NAME
GO

DROP TABLE IF EXISTS #TAB1 ;
SELECT * INTO #TAB1
FROM LS_PROD2DEV.ERP.DBO.TOBE_TABLE_MAPPING_DBA ;
GO

SELECT *
FROM #TAB1
ORDER BY TOBE_TABLE_NAME, TOBE_COLUMN_NAME ;


DROP TABLE IF EXISTS #TAB2
SELECT A.TOBE_TABLE_NAME
, A.ASIS_TABLE_NAME
, STRING_AGG(A.TOBE_COLUMN_NAME,',') TOBE_COLUMN 
, STRING_AGG(A.ASIS_COLUMN_NAME,',') ASIS_COLUMN 
INTO #TAB2
FROM #TAB1 A
JOIN INFORMATION_SCHEMA.TABLES B
ON A.ASIS_TABLE_NAME = B.TABLE_NAME
GROUP BY A.TOBE_TABLE_NAME, A.ASIS_TABLE_NAME
ORDER BY A.TOBE_TABLE_NAME
GO


SELECT TOBE_TABLE_NAME
, ASIS_TABLE_NAME
, CONCAT('INSERT INTO ERP.DBO.',TOBE_TABLE_NAME,'(',TOBE_COLUMN,') SELECT ',ASIS_COLUMN,' FROM MIG.M1SRC.',ASIS_TABLE_NAME) STMT
FROM #TAB2 A
JOIN INFORMATION_SCHEMA.TABLES B
ON A.TOBE_TABLE_NAME = B.TABLE_NAME
ORDER BY TOBE_TABLE_NAME
GO


USE ERP
GO

INSERT INTO ERP.DBO.CM_BBS_CMNT_D(BBS_SE_CD,CMNT_CNTN,CMNT_NO,FILE_GRP_NO,MOD_DTTM,MOD_ID,MOD_MENU_ID,PSTG_NO,REG_DTTM,REG_ID,REG_MENU_ID,UPR_CMNT_NO) SELECT BLLT_KD,RPLY_CTNT,RPLY_SQOR,FILE_ID,UPDT_DTTM,UPDT_ID,UPDT_PG_ID,BLLT_SEQ_1,INPUT_DTTM,INPUT_ID,INPUT_PG_ID,ORG_RPLY_SQOR FROM MIG.M1SRC.CM_BLLT_RPLY
GO
...



--#########################################################
--##### QA-DEV 비교
--#########################################################
--(1) 오브젝트 존재유무

DROP TABLE IF EXISTS #DISTINCT_QA_DEV ;

CREATE TABLE #DISTINCT_QA_DEV
( DB_NAME             VARCHAR(100)
, SCHEMA_NAME         VARCHAR(100)
, OBJECT_TYPE         VARCHAR(100)
, OBJECT_NAME         VARCHAR(100)
, COLUMN_NAME         VARCHAR(1000)
, ERROR_TYPE          VARCHAR(100)
, QA_EXISTS           VARCHAR(10)
, DEV_EXISTS          VARCHAR(10)
) ;


-- 테이블
INSERT INTO #DISTINCT_QA_DEV
SELECT DB_NAME() AS DB_NAME
, SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME
, A.TYPE_DESC AS OBJECT_TYPE
, A.NAME AS OBJECT_NAME
, NULL AS COLUMN_NAME
, '테이블 미 존재' AS ERROR_TYPE
, 'Y' AS QA_EXISTS
, '-' AS DEV_EXISTS 
FROM ERP.SYS.ALL_OBJECTS A
LEFT OUTER JOIN LS_DEV_FILADBA.ERP.SYS.ALL_OBJECTS B
ON A.SCHEMA_ID = B.SCHEMA_ID
AND A.TYPE_DESC = B.TYPE_DESC
AND A.NAME = B.NAME
WHERE 1=1
AND A.TYPE IN ('U') 
AND A.SCHEMA_ID NOT IN (SCHEMA_ID('SYS'))
AND A.NAME NOT LIKE 'ZZ%' 
AND B.NAME IS NULL
UNION ALL
SELECT DB_NAME() AS DB_NAME
, SCHEMA_NAME(B.SCHEMA_ID) AS SCHEMA_NAME
, B.TYPE_DESC AS OBJECT_TYPE
, B.NAME AS OBJECT_NAME
, NULL AS COLUMN_NAME
, '테이블 미 존재' AS ERROR_TYPE
, '-' AS QA_EXISTS
, 'Y' AS DEV_EXISTS
FROM ERP.SYS.ALL_OBJECTS A
RIGHT OUTER JOIN LS_DEV_FILADBA.ERP.SYS.ALL_OBJECTS B
ON A.SCHEMA_ID = B.SCHEMA_ID
AND A.TYPE_DESC = B.TYPE_DESC
AND A.NAME = B.NAME
WHERE 1=1
AND B.TYPE IN ('U') 
AND B.SCHEMA_ID NOT IN (SCHEMA_ID('SYS'))
AND B.NAME NOT LIKE 'ZZ%' 
AND A.NAME IS NULL ;


-- 뷰
INSERT INTO #DISTINCT_QA_DEV
SELECT DB_NAME() AS DB_NAME
, SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME
, A.TYPE_DESC AS OBJECT_TYPE
, A.NAME AS OBJECT_NAME
, NULL AS COLUMN_NAME
, '뷰 미 존재' AS ERROR_TYPE
, 'Y' AS QA_EXISTS
, '-' AS DEV_EXISTS 
FROM ERP.SYS.ALL_OBJECTS A
LEFT OUTER JOIN LS_DEV_FILADBA.ERP.SYS.ALL_OBJECTS B
ON A.SCHEMA_ID = B.SCHEMA_ID
AND A.TYPE_DESC = B.TYPE_DESC
AND A.NAME = B.NAME
WHERE 1=1
AND A.TYPE IN ('V') 
AND A.SCHEMA_ID NOT IN (SCHEMA_ID('SYS'), SCHEMA_ID('INFORMATION_SCHEMA'))
AND B.NAME IS NULL
UNION ALL
SELECT DB_NAME() AS DB_NAME
, SCHEMA_NAME(B.SCHEMA_ID) AS SCHEMA_NAME
, B.TYPE_DESC AS OBJECT_TYPE
, B.NAME AS OBJECT_NAME
, NULL AS COLUMN_NAME
, '뷰 미 존재' AS ERROR_TYPE
, '-' AS QA_EXISTS
, 'Y' AS DEV_EXISTS
FROM ERP.SYS.ALL_OBJECTS A
RIGHT OUTER JOIN LS_DEV_FILADBA.ERP.SYS.ALL_OBJECTS B
ON A.SCHEMA_ID = B.SCHEMA_ID
AND A.TYPE_DESC = B.TYPE_DESC
AND A.NAME = B.NAME
WHERE 1=1
AND B.TYPE IN ('V') 
AND B.SCHEMA_ID NOT IN (SCHEMA_ID('SYS'), SCHEMA_ID('INFORMATION_SCHEMA'))
AND A.NAME IS NULL ;


-- 함수
INSERT INTO #DISTINCT_QA_DEV
SELECT DB_NAME() AS DB_NAME
, SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME
, A.TYPE_DESC AS OBJECT_TYPE
, A.NAME AS OBJECT_NAME
, NULL AS COLUMN_NAME
, '함수 미 존재' AS ERROR_TYPE
, 'Y' AS QA_EXISTS
, '-' AS DEV_EXISTS 
FROM ERP.SYS.ALL_OBJECTS A
LEFT OUTER JOIN LS_DEV_FILADBA.ERP.SYS.ALL_OBJECTS B
ON A.SCHEMA_ID = B.SCHEMA_ID
AND A.TYPE_DESC = B.TYPE_DESC
AND A.NAME = B.NAME
WHERE 1=1
AND A.TYPE IN ('AF', 'FN', 'FS', 'IF', 'TF') 
AND A.SCHEMA_ID NOT IN (SCHEMA_ID('SYS'), SCHEMA_ID('INFORMATION_SCHEMA'))
AND B.NAME IS NULL
UNION ALL
SELECT DB_NAME() AS DB_NAME
, SCHEMA_NAME(B.SCHEMA_ID) AS SCHEMA_NAME
, B.TYPE_DESC AS OBJECT_TYPE
, B.NAME AS OBJECT_NAME
, NULL AS COLUMN_NAME
, '함수 미 존재' AS ERROR_TYPE
, '-' AS QA_EXISTS
, 'Y' AS DEV_EXISTS
FROM ERP.SYS.ALL_OBJECTS A
RIGHT OUTER JOIN LS_DEV_FILADBA.ERP.SYS.ALL_OBJECTS B
ON A.SCHEMA_ID = B.SCHEMA_ID
AND A.TYPE_DESC = B.TYPE_DESC
AND A.NAME = B.NAME
WHERE 1=1
AND B.TYPE IN ('AF', 'FN', 'FS', 'IF', 'TF') 
AND B.SCHEMA_ID NOT IN (SCHEMA_ID('SYS'), SCHEMA_ID('INFORMATION_SCHEMA'))
AND A.NAME IS NULL ;


-- 프로시저
INSERT INTO #DISTINCT_QA_DEV
SELECT DB_NAME() AS DB_NAME
, SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME
, A.TYPE_DESC AS OBJECT_TYPE
, A.NAME AS OBJECT_NAME
, NULL AS COLUMN_NAME
, '프로시저 미 존재' AS ERROR_TYPE
, 'Y' AS QA_EXISTS
, '-' AS DEV_EXISTS 
FROM ERP.SYS.ALL_OBJECTS A
LEFT OUTER JOIN LS_DEV_FILADBA.ERP.SYS.ALL_OBJECTS B
ON A.SCHEMA_ID = B.SCHEMA_ID
AND A.TYPE_DESC = B.TYPE_DESC
AND A.NAME = B.NAME
WHERE 1=1
AND A.TYPE IN ('P', 'PC', 'X')
AND A.SCHEMA_ID NOT IN (SCHEMA_ID('SYS'), SCHEMA_ID('INFORMATION_SCHEMA'))
AND B.NAME IS NULL
UNION ALL
SELECT DB_NAME() AS DB_NAME
, SCHEMA_NAME(B.SCHEMA_ID) AS SCHEMA_NAME
, B.TYPE_DESC AS OBJECT_TYPE
, B.NAME AS OBJECT_NAME
, NULL AS COLUMN_NAME
, '프로시저 미 존재' AS ERROR_TYPE
, '-' AS QA_EXISTS
, 'Y' AS DEV_EXISTS
FROM ERP.SYS.ALL_OBJECTS A
RIGHT OUTER JOIN LS_DEV_FILADBA.ERP.SYS.ALL_OBJECTS B
ON A.SCHEMA_ID = B.SCHEMA_ID
AND A.TYPE_DESC = B.TYPE_DESC
AND A.NAME = B.NAME
WHERE 1=1
AND B.TYPE IN ('P', 'PC', 'X')
AND B.SCHEMA_ID NOT IN (SCHEMA_ID('SYS'), SCHEMA_ID('INFORMATION_SCHEMA'))
AND A.NAME IS NULL ;


-- 시퀀스
INSERT INTO #DISTINCT_QA_DEV
SELECT DB_NAME() AS DB_NAME
, SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME
, A.TYPE_DESC AS OBJECT_TYPE
, A.NAME AS OBJECT_NAME
, NULL AS COLUMN_NAME
, '시퀀스 미 존재' AS ERROR_TYPE
, 'Y' AS QA_EXISTS
, '-' AS DEV_EXISTS 
FROM ERP.SYS.ALL_OBJECTS A
LEFT OUTER JOIN LS_DEV_FILADBA.ERP.SYS.ALL_OBJECTS B
ON A.SCHEMA_ID = B.SCHEMA_ID
AND A.TYPE_DESC = B.TYPE_DESC
AND A.NAME = B.NAME
WHERE 1=1
AND A.TYPE IN ('SO')
AND A.SCHEMA_ID NOT IN (SCHEMA_ID('SYS'), SCHEMA_ID('INFORMATION_SCHEMA'))
AND B.NAME IS NULL
UNION ALL
SELECT DB_NAME() AS DB_NAME
, SCHEMA_NAME(B.SCHEMA_ID) AS SCHEMA_NAME
, B.TYPE_DESC AS OBJECT_TYPE
, B.NAME AS OBJECT_NAME
, NULL AS COLUMN_NAME
, '시퀀스 미 존재' AS ERROR_TYPE
, '-' AS QA_EXISTS
, 'Y' AS DEV_EXISTS
FROM ERP.SYS.ALL_OBJECTS A
RIGHT OUTER JOIN LS_DEV_FILADBA.ERP.SYS.ALL_OBJECTS B
ON A.SCHEMA_ID = B.SCHEMA_ID
AND A.TYPE_DESC = B.TYPE_DESC
AND A.NAME = B.NAME
WHERE 1=1
AND B.TYPE IN ('SO')
AND B.SCHEMA_ID NOT IN (SCHEMA_ID('SYS'), SCHEMA_ID('INFORMATION_SCHEMA'))
AND A.NAME IS NULL ;



-- 인덱스
DROP TABLE IF EXISTS #INDEX_QA ;
SELECT DB_NAME() AS DB_NAME
     , SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME
     , A.NAME AS TABLE_NAME
     , B.NAME AS INDEX_NAME
	 , B.TYPE_DESC           INTO #INDEX_QA
FROM ERP.SYS.ALL_OBJECTS A
JOIN ERP.SYS.INDEXES B
ON A.OBJECT_ID = B.OBJECT_ID
WHERE A.TYPE='U' 
AND B.TYPE_DESC NOT IN ('HEAP') ;

DROP TABLE IF EXISTS #INDEX_DEV ;
SELECT DB_NAME() AS DB_NAME
     , SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME
     , A.NAME AS TABLE_NAME
     , B.NAME AS INDEX_NAME
	 , B.TYPE_DESC           INTO #INDEX_DEV
FROM LS_DEV_FILADBA.ERP.SYS.ALL_OBJECTS A
JOIN LS_DEV_FILADBA.ERP.SYS.INDEXES B
ON A.OBJECT_ID = B.OBJECT_ID
WHERE A.TYPE='U' 
AND B.TYPE_DESC NOT IN ('HEAP') ;

INSERT INTO #DISTINCT_QA_DEV
SELECT QA.DB_NAME
, QA.SCHEMA_NAME
, 'INDEX:'+QA.TYPE_DESC AS OBJECT_TYPE
, QA.INDEX_NAME AS OBJECT_NAME
, NULL AS COLUMN_NAME
, '인덱스 미 존재' AS ERROR_TYPE
, 'Y' AS QA_EXISTS
, '-' AS DEV_EXISTS 
FROM #INDEX_QA QA
LEFT OUTER JOIN #INDEX_DEV DEV
ON QA.DB_NAME = DEV.DB_NAME
AND QA.SCHEMA_NAME = DEV.SCHEMA_NAME
AND QA.TABLE_NAME = DEV.TABLE_NAME
AND QA.INDEX_NAME = DEV.INDEX_NAME
WHERE DEV.INDEX_NAME IS NULL
UNION ALL
SELECT DEV.DB_NAME
, DEV.SCHEMA_NAME
, 'INDEX:'+DEV.TYPE_DESC AS OBJECT_TYPE
, DEV.INDEX_NAME AS OBJECT_NAME
, NULL AS COLUMN_NAME
, '인덱스 미 존재' AS ERROR_TYPE
, '-' AS QA_EXISTS
, 'Y' AS DEV_EXISTS 
FROM #INDEX_QA QA
RIGHT OUTER JOIN #INDEX_DEV DEV
ON QA.DB_NAME = DEV.DB_NAME
AND QA.SCHEMA_NAME = DEV.SCHEMA_NAME
AND QA.TABLE_NAME = DEV.TABLE_NAME
AND QA.INDEX_NAME = DEV.INDEX_NAME
WHERE QA.INDEX_NAME IS NULL;



-- 인덱스 컬럼(#TEMP 사용)
DROP TABLE IF EXISTS #IDX_INFO_QA ;
SELECT DB_NAME() DB_NAME
      ,SCHEMA_NAME(SCHEMA_ID) SCHEMA_NAME
      ,B.NAME TABLE_NAME
	  , A.OBJECT_ID
	  , A.NAME INDEX_NAME
	  , A.INDEX_ID
	  , COL_NAME(C.OBJECT_ID,COLUMN_ID) COLUMN_NAME 
	  , KEY_ORDINAL [NO]
      , PARTITION_ORDINAL
	  , CASE WHEN IS_DESCENDING_KEY = 1 THEN '(-)' 
		     WHEN IS_DESCENDING_KEY = 0 THEN '' END  [DES]
	  , IS_INCLUDED_COLUMN
	  , A.TYPE_DESC
	  , CASE WHEN A.IS_UNIQUE = 1 THEN 'UNIQUE'
	         WHEN A.IS_UNIQUE = 0 THEN '' END UNIQUENESS
	  , CASE WHEN A.IS_UNIQUE_CONSTRAINT = 1 THEN 'UNIQUE KEY'
	         WHEN A.IS_UNIQUE_CONSTRAINT = 0 THEN '' END 
      + CASE WHEN A.IS_PRIMARY_KEY =1 THEN 'PRIMARY KEY'
	         WHEN A.IS_PRIMARY_KEY =0 THEN '' END [KEY] INTO #IDX_INFO_QA	  
FROM ERP.SYS.INDEXES A
	JOIN ERP.SYS.OBJECTS B ON A.OBJECT_ID = B.OBJECT_ID
	JOIN ERP.SYS.INDEX_COLUMNS C ON A.OBJECT_ID = C.OBJECT_ID AND A.INDEX_ID = C.INDEX_ID
WHERE B.TYPE = 'U' ;

DROP TABLE IF EXISTS #IDX_INFO_DEV ;
SELECT DB_NAME() DB_NAME
      ,SCHEMA_NAME(SCHEMA_ID) SCHEMA_NAME
      ,B.NAME TABLE_NAME
	  , A.OBJECT_ID
	  , A.NAME INDEX_NAME
	  , A.INDEX_ID
	  , COL_NAME(C.OBJECT_ID,C.COLUMN_ID) COLUMN_NAME 
	  , KEY_ORDINAL [NO]
      , PARTITION_ORDINAL
	  , CASE WHEN IS_DESCENDING_KEY = 1 THEN '(-)' 
		     WHEN IS_DESCENDING_KEY = 0 THEN '' END  [DES]
	  , IS_INCLUDED_COLUMN
	  , A.TYPE_DESC
	  , CASE WHEN A.IS_UNIQUE = 1 THEN 'UNIQUE'
	         WHEN A.IS_UNIQUE = 0 THEN '' END UNIQUENESS
	  , CASE WHEN A.IS_UNIQUE_CONSTRAINT = 1 THEN 'UNIQUE KEY'
	         WHEN A.IS_UNIQUE_CONSTRAINT = 0 THEN '' END 
      + CASE WHEN A.IS_PRIMARY_KEY =1 THEN 'PRIMARY KEY'
	         WHEN A.IS_PRIMARY_KEY =0 THEN '' END [KEY] INTO #IDX_INFO_DEV
FROM LS_DEV_FILADBA.ERP.SYS.INDEXES A
	JOIN LS_DEV_FILADBA.ERP.SYS.OBJECTS B ON A.OBJECT_ID = B.OBJECT_ID
	JOIN LS_DEV_FILADBA.ERP.SYS.INDEX_COLUMNS C ON A.OBJECT_ID = C.OBJECT_ID AND A.INDEX_ID = C.INDEX_ID
WHERE B.TYPE = 'U' ;


DROP TABLE IF EXISTS #IDX_INFO_DEV_AGG ;
SELECT 
	 DB_NAME, SCHEMA_NAME, TABLE_NAME, INDEX_NAME, INDEX_ID, TYPE_DESC, UNIQUENESS,  [KEY]
	, STUFF(
			(
				SELECT 
					', ',+CAST(COLUMN_NAME AS VARCHAR(100)) + ' ' + [DES] 
				FROM #IDX_INFO_DEV A2 
				WHERE A2.TABLE_NAME = B2.TABLE_NAME AND A2.INDEX_NAME = B2.INDEX_NAME
				AND A2.IS_INCLUDED_COLUMN = 0
				ORDER BY TABLE_NAME, INDEX_NAME, [NO]
				FOR XML PATH('')
			 ),1,1,''
		  ) COLUMN_NAME
	, ISNULL(STUFF(
			(
				SELECT 
					', ',+CAST(COLUMN_NAME AS VARCHAR(100)) + ' ' 
				FROM #IDX_INFO_DEV A2 
				WHERE A2.TABLE_NAME = B2.TABLE_NAME AND A2.INDEX_NAME = B2.INDEX_NAME
				AND A2.IS_INCLUDED_COLUMN = 1
				ORDER BY TABLE_NAME, INDEX_NAME, [NO]
				FOR XML PATH('')
			 ),1,1,''
		  ), '') INCLUDED_COLUMN INTO #IDX_INFO_DEV_AGG
FROM #IDX_INFO_DEV B2 
	JOIN LS_DEV_FILADBA.ERP.SYS.STATS B WITH (NOLOCK) ON B2.OBJECT_ID = B.OBJECT_ID
GROUP BY DB_NAME, SCHEMA_NAME, TABLE_NAME, INDEX_NAME, INDEX_ID, TYPE_DESC, UNIQUENESS,  [KEY] ;


DROP TABLE IF EXISTS #IDX_INFO_QA_AGG;
SELECT 
	 DB_NAME, SCHEMA_NAME, TABLE_NAME, INDEX_NAME, INDEX_ID, TYPE_DESC, UNIQUENESS,  [KEY]
	, STUFF(
			(
				SELECT 
					', ',+CAST(COLUMN_NAME AS VARCHAR(100)) + ' ' + [DES] 
				FROM #IDX_INFO_QA A2 
				WHERE A2.TABLE_NAME = B2.TABLE_NAME AND A2.INDEX_NAME = B2.INDEX_NAME
				AND A2.IS_INCLUDED_COLUMN = 0
				ORDER BY TABLE_NAME, INDEX_NAME, [NO]
				FOR XML PATH('')
			 ),1,1,''
		  ) COLUMN_NAME
	, ISNULL(STUFF(
			(
				SELECT 
					', ',+CAST(COLUMN_NAME AS VARCHAR(100)) + ' ' 
				FROM #IDX_INFO_QA A2 
				WHERE A2.TABLE_NAME = B2.TABLE_NAME AND A2.INDEX_NAME = B2.INDEX_NAME
				AND A2.IS_INCLUDED_COLUMN = 1
				ORDER BY TABLE_NAME, INDEX_NAME, [NO]
				FOR XML PATH('')
			 ),1,1,''
		  ), '') INCLUDED_COLUMN INTO #IDX_INFO_QA_AGG
FROM #IDX_INFO_QA B2 
	JOIN LS_DEV_FILADBA.ERP.SYS.STATS B WITH (NOLOCK) ON B2.OBJECT_ID = B.OBJECT_ID
GROUP BY DB_NAME, SCHEMA_NAME, TABLE_NAME, INDEX_NAME, INDEX_ID, TYPE_DESC, UNIQUENESS,  [KEY] ;

INSERT INTO #DISTINCT_QA_DEV
SELECT A.DB_NAME
, A.SCHEMA_NAME
, 'INDEX:COLUMN' AS OBJECT_TYPE
, A.INDEX_NAME
, A.COLUMN_NAME
, '인덱스 컬럼 불일치' AS ERROR_TYPE
, '-' AS QA_EXISTS
, 'Y' AS DEV_EXISTS 
FROM #IDX_INFO_DEV_AGG A
LEFT OUTER JOIN #IDX_INFO_QA_AGG B
ON A.DB_NAME = B.DB_NAME
AND A.SCHEMA_NAME = B.SCHEMA_NAME
AND A.TABLE_NAME = B.TABLE_NAME
AND A.INDEX_NAME = B.INDEX_NAME
AND A.COLUMN_NAME = B.COLUMN_NAME
--AND A.INCLUDED_COLUMN = B.INCLUDED_COLUMN 
WHERE 1=1
AND A.COLUMN_NAME IS NOT NULL
AND B.COLUMN_NAME IS NULL
UNION ALL
SELECT B.DB_NAME
, B.SCHEMA_NAME
, 'INDEX:COLUMN' AS OBJECT_TYPE
, B.INDEX_NAME
, B.COLUMN_NAME
, '인덱스 컬럼 불일치' AS ERROR_TYPE
, 'Y' AS QA_EXISTS
, '-' AS DEV_EXISTS
FROM #IDX_INFO_DEV_AGG A
RIGHT OUTER JOIN #IDX_INFO_QA_AGG B
ON A.DB_NAME = B.DB_NAME
AND A.SCHEMA_NAME = B.SCHEMA_NAME
AND A.TABLE_NAME = B.TABLE_NAME
AND A.INDEX_NAME = B.INDEX_NAME
AND A.COLUMN_NAME = B.COLUMN_NAME
--AND A.INCLUDED_COLUMN = B.INCLUDED_COLUMN 
WHERE 1=1
AND B.COLUMN_NAME IS NOT NULL
AND A.COLUMN_NAME IS NULL ;


ALTER PROCEDURE PR_DBA_GAPINFO_DEV
(@I_DB_NAME VARCHAR(10))
AS
SET NOCOUNT ON;
/******************************************************************************
[프로그램명]
PR_DBA_GAPINFO_DEV
[설명]
개발 DB-QA DB간 오브젝트 GAP 분석
[파라미터]
@I_DB_NAME     VARCHAR   DB명

[VERSIONS]
----------  ---------------  ------------------------------------
2024-05-08  강현호           최초 작성

[TEST/EXCUTE]
(1) PR_DBA_GAPINFO_DEV 'ERP'
(2) PR_DBA_GAPINFO_DEV @I_DB_NAME='ERP'
******************************************************************************/
BEGIN
    BEGIN TRY

		DECLARE @V_SQL_TABLE          VARCHAR(2000)
		      , @V_SQL_VIEW           VARCHAR(2000)
			  , @V_SQL_FUNCTION       VARCHAR(2000)
			  , @V_SQL_PROCEDURE      VARCHAR(2000)
			  , @V_SQL_SEQUENCE       VARCHAR(2000)
			  , @V_SQL_INDEX          VARCHAR(2000)
			  , @V_SQL_DROP           VARCHAR(500)
			  , @V_SQL_INDEX_COLUMN   VARCHAR(2000) ;

	    DROP TABLE IF EXISTS #DISTINCT_QA_DEV ;
		
		CREATE TABLE #DISTINCT_QA_DEV
		( DB_NAME             VARCHAR(100)
		, SCHEMA_NAME         VARCHAR(100)
		, OBJECT_TYPE         VARCHAR(100)
		, OBJECT_NAME         VARCHAR(100)
		, COLUMN_NAME         VARCHAR(1000)
		, ERROR_TYPE          VARCHAR(100)
		, QA_EXISTS           VARCHAR(10)
		, DEV_EXISTS          VARCHAR(10)
		) ;

		CREATE TABLE #INDEX_QA
		( DB_NAME             VARCHAR(100)
		, SCHEMA_NAME         VARCHAR(100)
		, TABLE_NAME          VARCHAR(100)
		, INDEX_NAME          VARCHAR(100)
		, TYPE_DESC           VARCHAR(100)
		) ;

		CREATE TABLE #INDEX_DEV
		( DB_NAME             VARCHAR(100)
		, SCHEMA_NAME         VARCHAR(100)
		, TABLE_NAME          VARCHAR(100)
		, INDEX_NAME          VARCHAR(100)
		, TYPE_DESC           VARCHAR(100)
		) ;

		CREATE TABLE #INDEX_INFO_QA
		( DB_NAME             VARCHAR(100)
		, SCHEMA_NAME         VARCHAR(100)
		, TABLE_NAME          VARCHAR(100)
		, OBJECT_ID           VARCHAR(20)
		, INDEX_NAME          VARCHAR(100)
		, INDEX_ID            VARCHAR(10)
		, COLUMN_NAME         VARCHAR(100)
		, NO                  VARCHAR(10)
		, PARTITION_ORDINAL   VARCHAR(10)
		, DES                 VARCHAR(10)
		, IS_INCLUDED_COLUMN  VARCHAR(100)
		, TYPE_DESC           VARCHAR(100)
		, UNIQUENESS          VARCHAR(100)
		, [KEY]               VARCHAR(100)
		) ;

		CREATE TABLE #INDEX_INFO_DEV
		( DB_NAME             VARCHAR(100)
		, SCHEMA_NAME         VARCHAR(100)
		, TABLE_NAME          VARCHAR(100)
		, OBJECT_ID           VARCHAR(20)
		, INDEX_NAME          VARCHAR(100)
		, INDEX_ID            VARCHAR(10)
		, COLUMN_NAME         VARCHAR(100)
		, NO                  VARCHAR(10)
		, PARTITION_ORDINAL   VARCHAR(10)
		, DES                 VARCHAR(10)
		, IS_INCLUDED_COLUMN  VARCHAR(100)
		, TYPE_DESC           VARCHAR(100)
		, UNIQUENESS          VARCHAR(100)
		, [KEY]               VARCHAR(100)
		) ;

		CREATE TABLE #INDEX_INFO_DEV_AGG
		( DB_NAME             VARCHAR(100)
		, SCHEMA_NAME         VARCHAR(100)
		, TABLE_NAME          VARCHAR(100)
		, INDEX_NAME          VARCHAR(100)
		, INDEX_ID            VARCHAR(10)
		, TYPE_DESC           VARCHAR(100)
		, UNIQUENESS          VARCHAR(100)
		, [KEY]               VARCHAR(100)
		, COLUMN_NAME         VARCHAR(2000)		
		, IS_INCLUDED_COLUMN  VARCHAR(100)		
		) ;

		CREATE TABLE #INDEX_INFO_QA_AGG
		( DB_NAME             VARCHAR(100)
		, SCHEMA_NAME         VARCHAR(100)
		, TABLE_NAME          VARCHAR(100)
		, INDEX_NAME          VARCHAR(100)
		, INDEX_ID            VARCHAR(10)
		, TYPE_DESC           VARCHAR(100)
		, UNIQUENESS          VARCHAR(100)
		, [KEY]               VARCHAR(100)
		, COLUMN_NAME         VARCHAR(2000)		
		, IS_INCLUDED_COLUMN  VARCHAR(100)		
		) ;
		
		-- 테이블
		SET @V_SQL_TABLE 
		= 'INSERT INTO #DISTINCT_QA_DEV
		SELECT '''+@I_DB_NAME+''' AS DB_NAME
		, SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME
		, A.TYPE_DESC AS OBJECT_TYPE
		, A.NAME AS OBJECT_NAME
		, NULL AS COLUMN_NAME
		, ''테이블 미 존재'' AS ERROR_TYPE
		, ''Y'' AS QA_EXISTS
		, ''-'' AS DEV_EXISTS 
		FROM '+@I_DB_NAME+'.SYS.ALL_OBJECTS A
		LEFT OUTER JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.ALL_OBJECTS B
		ON A.SCHEMA_ID = B.SCHEMA_ID
		AND A.TYPE_DESC = B.TYPE_DESC
		AND A.NAME = B.NAME
		WHERE 1=1
		AND A.TYPE IN (''U'') 
		AND A.SCHEMA_ID NOT IN (SCHEMA_ID(''SYS''))
		AND A.NAME NOT LIKE ''ZZ\_%'' ESCAPE ''\''
		AND B.NAME IS NULL
		UNION ALL
		SELECT '''+@I_DB_NAME+''' AS DB_NAME
		, SCHEMA_NAME(B.SCHEMA_ID) AS SCHEMA_NAME
		, B.TYPE_DESC AS OBJECT_TYPE
		, B.NAME AS OBJECT_NAME
		, NULL AS COLUMN_NAME
		, ''테이블 미 존재'' AS ERROR_TYPE
		, ''-'' AS QA_EXISTS
		, ''Y'' AS DEV_EXISTS
		FROM '+@I_DB_NAME+'.SYS.ALL_OBJECTS A
		RIGHT OUTER JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.ALL_OBJECTS B
		ON A.SCHEMA_ID = B.SCHEMA_ID
		AND A.TYPE_DESC = B.TYPE_DESC
		AND A.NAME = B.NAME
		WHERE 1=1
		AND B.TYPE IN (''U'') 
		AND B.SCHEMA_ID NOT IN (SCHEMA_ID(''SYS''))
		AND B.NAME NOT LIKE ''ZZ\_%'' ESCAPE ''\''
		AND A.NAME IS NULL' ;
        EXEC(@V_SQL_TABLE);

		-- 뷰
		SET @V_SQL_VIEW 
		= 'INSERT INTO #DISTINCT_QA_DEV
		SELECT '''+@I_DB_NAME+''' AS DB_NAME
		, SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME
		, A.TYPE_DESC AS OBJECT_TYPE
		, A.NAME AS OBJECT_NAME
		, NULL AS COLUMN_NAME
		, ''뷰 미 존재'' AS ERROR_TYPE
		, ''Y'' AS QA_EXISTS
		, ''-'' AS DEV_EXISTS 
		FROM '+@I_DB_NAME+'.SYS.ALL_OBJECTS A
		LEFT OUTER JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.ALL_OBJECTS B
		ON A.SCHEMA_ID = B.SCHEMA_ID
		AND A.TYPE_DESC = B.TYPE_DESC
		AND A.NAME = B.NAME
		WHERE 1=1
		AND A.TYPE IN (''V'') 
		AND A.SCHEMA_ID NOT IN (SCHEMA_ID(''SYS''), SCHEMA_ID(''INFORMATION_SCHEMA''))
		AND B.NAME IS NULL
		UNION ALL
		SELECT '''+@I_DB_NAME+''' AS DB_NAME
		, SCHEMA_NAME(B.SCHEMA_ID) AS SCHEMA_NAME
		, B.TYPE_DESC AS OBJECT_TYPE
		, B.NAME AS OBJECT_NAME
		, NULL AS COLUMN_NAME
		, ''뷰 미 존재'' AS ERROR_TYPE
		, ''-'' AS QA_EXISTS
		, ''Y'' AS DEV_EXISTS
		FROM '+@I_DB_NAME+'.SYS.ALL_OBJECTS A
		RIGHT OUTER JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.ALL_OBJECTS B
		ON A.SCHEMA_ID = B.SCHEMA_ID
		AND A.TYPE_DESC = B.TYPE_DESC
		AND A.NAME = B.NAME
		WHERE 1=1AND B.TYPE IN (''V'') 
		AND B.SCHEMA_ID NOT IN (SCHEMA_ID(''SYS''), SCHEMA_ID(''INFORMATION_SCHEMA''))
		AND A.NAME IS NULL ';
        EXEC(@V_SQL_VIEW);

		-- 함수
		SET @V_SQL_FUNCTION 
		= 'INSERT INTO #DISTINCT_QA_DEV
		  SELECT '''+@I_DB_NAME+''' AS DB_NAME
		  , SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME
		  , A.TYPE_DESC AS OBJECT_TYPE
		  , A.NAME AS OBJECT_NAME
		  , NULL AS COLUMN_NAME
		  , ''함수 미 존재'' AS ERROR_TYPE
		  , ''Y'' AS QA_EXISTS
		  , ''-'' AS DEV_EXISTS 
		  FROM '+@I_DB_NAME+'.SYS.ALL_OBJECTS A
		  LEFT OUTER JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.ALL_OBJECTS B
		  ON A.SCHEMA_ID = B.SCHEMA_ID
		  AND A.TYPE_DESC = B.TYPE_DESC
		  AND A.NAME = B.NAME
		  WHERE 1=1
		  AND A.TYPE IN (''AF'', ''FN'', ''FS'', ''IF'', ''TF'') 
		  AND A.SCHEMA_ID NOT IN (SCHEMA_ID(''SYS''), SCHEMA_ID(''INFORMATION_SCHEMA''))
		  AND B.NAME IS NULL
		  UNION ALL
		  SELECT '''+@I_DB_NAME+''' AS DB_NAME
		  , SCHEMA_NAME(B.SCHEMA_ID) AS SCHEMA_NAME
		  , B.TYPE_DESC AS OBJECT_TYPE
		  , B.NAME AS OBJECT_NAME
		  , NULL AS COLUMN_NAME
		  , ''함수 미 존재'' AS ERROR_TYPE
		  , ''-'' AS QA_EXISTS
		  , ''Y'' AS DEV_EXISTS
		  FROM '+@I_DB_NAME+'.SYS.ALL_OBJECTS A
		  RIGHT OUTER JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.ALL_OBJECTS B
		  ON A.SCHEMA_ID = B.SCHEMA_ID
		  AND A.TYPE_DESC = B.TYPE_DESC
		  AND A.NAME = B.NAME
		  WHERE 1=1
		  AND B.TYPE IN (''AF'', ''FN'', ''FS'', ''IF'', ''TF'') 
		  AND B.SCHEMA_ID NOT IN (SCHEMA_ID(''SYS''), SCHEMA_ID(''INFORMATION_SCHEMA''))
		  AND A.NAME IS NULL';
        EXEC(@V_SQL_FUNCTION);

        -- 프로시저
		SET @V_SQL_PROCEDURE
		= 'INSERT INTO #DISTINCT_QA_DEV
		  SELECT '''+@I_DB_NAME+''' AS DB_NAME
		  , SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME
		  , A.TYPE_DESC AS OBJECT_TYPE
		  , A.NAME AS OBJECT_NAME
		  , NULL AS COLUMN_NAME
		  , ''프로시저 미 존재'' AS ERROR_TYPE
		  , ''Y'' AS QA_EXISTS
		  , ''-'' AS DEV_EXISTS 
		  FROM '+@I_DB_NAME+'.SYS.ALL_OBJECTS A
		  LEFT OUTER JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.ALL_OBJECTS B
		  ON A.SCHEMA_ID = B.SCHEMA_ID
		  AND A.TYPE_DESC = B.TYPE_DESC
		  AND A.NAME = B.NAME
		  WHERE 1=1
		  AND A.TYPE IN (''P'', ''PC'', ''X'')
		  AND A.SCHEMA_ID NOT IN (SCHEMA_ID(''SYS''), SCHEMA_ID(''INFORMATION_SCHEMA''))
		  AND B.NAME IS NULL
		  UNION ALL
		  SELECT '''+@I_DB_NAME+''' AS DB_NAME
		  , SCHEMA_NAME(B.SCHEMA_ID) AS SCHEMA_NAME
		  , B.TYPE_DESC AS OBJECT_TYPE
		  , B.NAME AS OBJECT_NAME
		  , NULL AS COLUMN_NAME
		  , ''프로시저 미 존재'' AS ERROR_TYPE
		  , ''-'' AS QA_EXISTS
		  , ''Y'' AS DEV_EXISTS
		  FROM '+@I_DB_NAME+'.SYS.ALL_OBJECTS A
		  RIGHT OUTER JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.ALL_OBJECTS B
		  ON A.SCHEMA_ID = B.SCHEMA_ID
		  AND A.TYPE_DESC = B.TYPE_DESC
		  AND A.NAME = B.NAME
		  WHERE 1=1
		  AND B.TYPE IN (''P'', ''PC'', ''X'')
		  AND B.SCHEMA_ID NOT IN (SCHEMA_ID(''SYS''), SCHEMA_ID(''INFORMATION_SCHEMA''))
		  AND A.NAME IS NULL';
        EXEC(@V_SQL_PROCEDURE);

        -- 시퀀스
		SET @V_SQL_SEQUENCE
		= 'INSERT INTO #DISTINCT_QA_DEV
		  SELECT '''+@I_DB_NAME+''' AS DB_NAME
		  , SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME
		  , A.TYPE_DESC AS OBJECT_TYPE
		  , A.NAME AS OBJECT_NAME
		  , NULL AS COLUMN_NAME
		  , ''시퀀스 미 존재'' AS ERROR_TYPE
		  , ''Y'' AS QA_EXISTS
		  , ''-'' AS DEV_EXISTS 
		  FROM '+@I_DB_NAME+'.SYS.ALL_OBJECTS A
		  LEFT OUTER JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.ALL_OBJECTS B
		  ON A.SCHEMA_ID = B.SCHEMA_ID
		  AND A.TYPE_DESC = B.TYPE_DESC
		  AND A.NAME = B.NAME
		  WHERE 1=1
		  AND A.TYPE IN (''SO'')
		  AND A.SCHEMA_ID NOT IN (SCHEMA_ID(''SYS''), SCHEMA_ID(''INFORMATION_SCHEMA''))
		  AND B.NAME IS NULL
		  UNION ALL
		  SELECT '''+@I_DB_NAME+''' AS DB_NAME
		  , SCHEMA_NAME(B.SCHEMA_ID) AS SCHEMA_NAME
		  , B.TYPE_DESC AS OBJECT_TYPE
		  , B.NAME AS OBJECT_NAME
		  , NULL AS COLUMN_NAME
		  , ''시퀀스 미 존재'' AS ERROR_TYPE
		  , ''-'' AS QA_EXISTS
		  , ''Y'' AS DEV_EXISTS
		  FROM '+@I_DB_NAME+'.SYS.ALL_OBJECTS A
		  RIGHT OUTER JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.ALL_OBJECTS B
		  ON A.SCHEMA_ID = B.SCHEMA_ID
		  AND A.TYPE_DESC = B.TYPE_DESC
		  AND A.NAME = B.NAME
		  WHERE 1=1
		  AND B.TYPE IN (''SO'')
		  AND B.SCHEMA_ID NOT IN (SCHEMA_ID(''SYS''), SCHEMA_ID(''INFORMATION_SCHEMA''))
		  AND A.NAME IS NULL';
        EXEC(@V_SQL_SEQUENCE);

		
		-- 인덱스
		SET @V_SQL_INDEX
		= 'INSERT INTO #INDEX_QA
		SELECT '''+@I_DB_NAME+''' AS DB_NAME
		, SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME
		, A.NAME AS TABLE_NAME
		, B.NAME AS INDEX_NAME
		, B.TYPE_DESC AS TYPE_DESC 
		FROM '+@I_DB_NAME+'.SYS.ALL_OBJECTS A
		JOIN '+@I_DB_NAME+'.SYS.INDEXES B
		ON A.OBJECT_ID = B.OBJECT_ID
		WHERE A.TYPE=''U'' 
		AND B.TYPE_DESC NOT IN (''HEAP'')';		
        EXEC(@V_SQL_INDEX);
	
		SET @V_SQL_INDEX
		= 'INSERT INTO #INDEX_DEV
		SELECT '''+@I_DB_NAME+''' AS DB_NAME
		, SCHEMA_NAME(A.SCHEMA_ID) AS SCHEMA_NAME
		, A.NAME AS TABLE_NAME
		, B.NAME AS INDEX_NAME
		, B.TYPE_DESC AS TYPE_DESC
		FROM LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.ALL_OBJECTS A
		JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.INDEXES B
		ON A.OBJECT_ID = B.OBJECT_ID
		WHERE A.TYPE=''U'' 
		AND B.TYPE_DESC NOT IN (''HEAP'')';		
		EXEC(@V_SQL_INDEX);

		SET @V_SQL_INDEX
		= 'INSERT INTO #DISTINCT_QA_DEV
		SELECT QA.DB_NAME
		, QA.SCHEMA_NAME
		, ''INDEX:''+QA.TYPE_DESC AS OBJECT_TYPE
		, QA.INDEX_NAME AS OBJECT_NAME
		, NULL AS COLUMN_NAME
		, ''인덱스 미 존재'' AS ERROR_TYPE
		, ''Y'' AS QA_EXISTS
		, ''-'' AS DEV_EXISTS 
		FROM #INDEX_QA QA
		LEFT OUTER JOIN #INDEX_DEV DEV
		ON QA.DB_NAME = DEV.DB_NAME
		AND QA.SCHEMA_NAME = DEV.SCHEMA_NAME
		AND QA.TABLE_NAME = DEV.TABLE_NAME
		AND QA.INDEX_NAME = DEV.INDEX_NAME
		WHERE DEV.INDEX_NAME IS NULL
		UNION ALL
		SELECT DEV.DB_NAME
		, DEV.SCHEMA_NAME
		, ''INDEX:''+DEV.TYPE_DESC AS OBJECT_TYPE
		, DEV.INDEX_NAME AS OBJECT_NAME
		, NULL AS COLUMN_NAME
		, ''인덱스 미 존재'' AS ERROR_TYPE
		, ''-'' AS QA_EXISTS
		, ''Y'' AS DEV_EXISTS 
		FROM #INDEX_QA QA
		RIGHT OUTER JOIN #INDEX_DEV DEV
		ON QA.DB_NAME = DEV.DB_NAME
		AND QA.SCHEMA_NAME = DEV.SCHEMA_NAME
		AND QA.TABLE_NAME = DEV.TABLE_NAME
		AND QA.INDEX_NAME = DEV.INDEX_NAME
		WHERE QA.INDEX_NAME IS NULL';
		EXEC(@V_SQL_INDEX);		

		-- 인덱스 컬럼(#TEMP 사용)
		SET @V_SQL_INDEX_COLUMN
		= 'INSERT INTO #INDEX_INFO_QA
		SELECT '''+@I_DB_NAME+''' AS DB_NAME
		, SCHEMA_NAME(SCHEMA_ID) SCHEMA_NAME
		, B.NAME TABLE_NAME
		, A.OBJECT_ID
		, A.NAME INDEX_NAME
		, A.INDEX_ID
		, COL_NAME(C.OBJECT_ID,COLUMN_ID) COLUMN_NAME 
		, KEY_ORDINAL [NO]
		, PARTITION_ORDINAL
		, CASE WHEN IS_DESCENDING_KEY = 1 THEN ''(-)'' 
		WHEN IS_DESCENDING_KEY = 0 THEN '''' END  [DES]
		, IS_INCLUDED_COLUMN
		, A.TYPE_DESC
		, CASE WHEN A.IS_UNIQUE = 1 THEN ''UNIQUE''
		WHEN A.IS_UNIQUE = 0 THEN '''' END UNIQUENESS
		, CASE WHEN A.IS_UNIQUE_CONSTRAINT = 1 THEN ''UNIQUE KEY''
		WHEN A.IS_UNIQUE_CONSTRAINT = 0 THEN '''' END 
		+ CASE WHEN A.IS_PRIMARY_KEY =1 THEN ''PRIMARY KEY''
		WHEN A.IS_PRIMARY_KEY =0 THEN '''' END [KEY] 
		FROM '+@I_DB_NAME+'.SYS.INDEXES A
		JOIN '+@I_DB_NAME+'.SYS.OBJECTS B 
		ON A.OBJECT_ID = B.OBJECT_ID
		JOIN '+@I_DB_NAME+'.SYS.INDEX_COLUMNS C 
		ON A.OBJECT_ID = C.OBJECT_ID 
		AND A.INDEX_ID = C.INDEX_ID
		WHERE B.TYPE = ''U'' ';
		--PRINT @V_SQL_INDEX_COLUMN ;
		EXEC (@V_SQL_INDEX_COLUMN);
		--SELECT TOP(10) * FROM #INDEX_INFO_QA ;

		SET @V_SQL_INDEX_COLUMN
		= 'INSERT INTO #INDEX_INFO_DEV
		SELECT '''+@I_DB_NAME+''' AS DB_NAME
		,SCHEMA_NAME(SCHEMA_ID) SCHEMA_NAME
		, B.NAME TABLE_NAME
		, A.OBJECT_ID
		, A.NAME INDEX_NAME
		, A.INDEX_ID
		, COL_NAME(C.OBJECT_ID,C.COLUMN_ID) COLUMN_NAME 
		, KEY_ORDINAL [NO]
		, PARTITION_ORDINAL
		, CASE WHEN IS_DESCENDING_KEY = 1 THEN ''(-)'' 
		WHEN IS_DESCENDING_KEY = 0 THEN '''' END  [DES]
		, IS_INCLUDED_COLUMN
		, A.TYPE_DESC
		, CASE WHEN A.IS_UNIQUE = 1 THEN ''UNIQUE''
		WHEN A.IS_UNIQUE = 0 THEN '''' END UNIQUENESS
		, CASE WHEN A.IS_UNIQUE_CONSTRAINT = 1 THEN ''UNIQUE KEY''
		WHEN A.IS_UNIQUE_CONSTRAINT = 0 THEN '''' END 
		+ CASE WHEN A.IS_PRIMARY_KEY =1 THEN ''PRIMARY KEY''
		WHEN A.IS_PRIMARY_KEY =0 THEN '''' END [KEY] 
		FROM LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.INDEXES A
		JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.OBJECTS B 
		ON A.OBJECT_ID = B.OBJECT_ID
		JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.INDEX_COLUMNS C 
		ON A.OBJECT_ID = C.OBJECT_ID 
		AND A.INDEX_ID = C.INDEX_ID
		WHERE B.TYPE = ''U'' ';
		--PRINT @V_SQL_INDEX_COLUMN ;
		EXEC (@V_SQL_INDEX_COLUMN);
		--SELECT TOP(10) * FROM #INDEX_INFO_DEV ;

		SET @V_SQL_INDEX_COLUMN
		= 'INSERT INTO #INDEX_INFO_DEV_AGG
		SELECT DB_NAME, SCHEMA_NAME, TABLE_NAME, INDEX_NAME, INDEX_ID, TYPE_DESC, UNIQUENESS,  [KEY]
		, STUFF((SELECT '', '',+CAST(COLUMN_NAME AS VARCHAR(100)) + '' '' + [DES] 
				FROM #INDEX_INFO_DEV A2 
				WHERE A2.TABLE_NAME = B2.TABLE_NAME AND A2.INDEX_NAME = B2.INDEX_NAME
				AND A2.IS_INCLUDED_COLUMN = 0
				ORDER BY TABLE_NAME, INDEX_NAME, [NO]
				FOR XML PATH('''')
			 ),1,1,''''
		  ) COLUMN_NAME
        , ISNULL(STUFF((SELECT '', '',+CAST(COLUMN_NAME AS VARCHAR(100)) + '' '' 
				FROM #INDEX_INFO_DEV A2 
				WHERE A2.TABLE_NAME = B2.TABLE_NAME AND A2.INDEX_NAME = B2.INDEX_NAME
				AND A2.IS_INCLUDED_COLUMN = 1
				ORDER BY TABLE_NAME, INDEX_NAME, [NO]
				FOR XML PATH('''')
			 ),1,1,''''
		  ), '''') INCLUDED_COLUMN 
        FROM #INDEX_INFO_DEV B2 
		JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.STATS B WITH (NOLOCK) 
		ON B2.OBJECT_ID = B.OBJECT_ID
		GROUP BY DB_NAME, SCHEMA_NAME, TABLE_NAME, INDEX_NAME, INDEX_ID, TYPE_DESC, UNIQUENESS,  [KEY] ';
		--PRINT @V_SQL_INDEX_COLUMN ;
		EXEC (@V_SQL_INDEX_COLUMN);
		--SELECT TOP(10) * FROM #INDEX_INFO_DEV_AGG ;


		SET @V_SQL_INDEX_COLUMN
		= 'INSERT INTO #INDEX_INFO_QA_AGG
		SELECT DB_NAME, SCHEMA_NAME, TABLE_NAME, INDEX_NAME, INDEX_ID, TYPE_DESC, UNIQUENESS,  [KEY]
		, STUFF((SELECT '', '',+CAST(COLUMN_NAME AS VARCHAR(100)) + '' '' + [DES] 
				FROM #INDEX_INFO_QA A2 
				WHERE A2.TABLE_NAME = B2.TABLE_NAME AND A2.INDEX_NAME = B2.INDEX_NAME
				AND A2.IS_INCLUDED_COLUMN = 0
				ORDER BY TABLE_NAME, INDEX_NAME, [NO]
				FOR XML PATH('''')),1,1,'''') COLUMN_NAME
        , ISNULL(STUFF((SELECT '', '',+CAST(COLUMN_NAME AS VARCHAR(100)) + '' '' 
				FROM #INDEX_INFO_QA A2 
				WHERE A2.TABLE_NAME = B2.TABLE_NAME AND A2.INDEX_NAME = B2.INDEX_NAME
				AND A2.IS_INCLUDED_COLUMN = 1
				ORDER BY TABLE_NAME, INDEX_NAME, [NO]
				FOR XML PATH('''')),1,1,''''), '''') INCLUDED_COLUMN 
        FROM #INDEX_INFO_QA B2 
		JOIN LS_DEV_FILADBA.'+@I_DB_NAME+'.SYS.STATS B WITH (NOLOCK) 
		ON B2.OBJECT_ID = B.OBJECT_ID
		GROUP BY DB_NAME, SCHEMA_NAME, TABLE_NAME, INDEX_NAME, INDEX_ID, TYPE_DESC, UNIQUENESS,  [KEY] ';
		--PRINT @V_SQL_INDEX_COLUMN ;
		EXEC (@V_SQL_INDEX_COLUMN);
		--SELECT TOP(10) * FROM #INDEX_INFO_QA_AGG ;

		SET @V_SQL_INDEX_COLUMN
		= 'INSERT INTO #DISTINCT_QA_DEV
		SELECT A.DB_NAME
		, A.SCHEMA_NAME
		, ''INDEX:COLUMN'' AS OBJECT_TYPE
		, A.INDEX_NAME
		, A.COLUMN_NAME
		, ''인덱스 컬럼 불일치'' AS ERROR_TYPE
		, ''-'' AS QA_EXISTS
		, ''Y'' AS DEV_EXISTS 
		FROM #INDEX_INFO_DEV_AGG A
		LEFT OUTER JOIN #INDEX_INFO_QA_AGG B
		ON A.DB_NAME = B.DB_NAME
		AND A.SCHEMA_NAME = B.SCHEMA_NAME
		AND A.TABLE_NAME = B.TABLE_NAME
		AND A.INDEX_NAME = B.INDEX_NAME
		AND A.COLUMN_NAME = B.COLUMN_NAME
		--AND A.INCLUDED_COLUMN = B.INCLUDED_COLUMN 
		WHERE 1=1
		AND A.COLUMN_NAME IS NOT NULL
		AND B.COLUMN_NAME IS NULL
		UNION ALL
		SELECT B.DB_NAME
		, B.SCHEMA_NAME
		, ''INDEX:COLUMN'' AS OBJECT_TYPE
		, B.INDEX_NAME
		, B.COLUMN_NAME
		, ''인덱스 컬럼 불일치'' AS ERROR_TYPE
		, ''Y'' AS QA_EXISTS
		, ''-'' AS DEV_EXISTS
		FROM #INDEX_INFO_DEV_AGG A
		RIGHT OUTER JOIN #INDEX_INFO_QA_AGG B
		ON A.DB_NAME = B.DB_NAME
		AND A.SCHEMA_NAME = B.SCHEMA_NAME
		AND A.TABLE_NAME = B.TABLE_NAME
		AND A.INDEX_NAME = B.INDEX_NAME
		AND A.COLUMN_NAME = B.COLUMN_NAME
		--AND A.INCLUDED_COLUMN = B.INCLUDED_COLUMN 
		WHERE 1=1
		AND B.COLUMN_NAME IS NOT NULL
		AND A.COLUMN_NAME IS NULL';
		--PRINT @V_SQL_INDEX_COLUMN ;
		EXEC (@V_SQL_INDEX_COLUMN);
		
		SELECT * FROM #DISTINCT_QA_DEV ;
		
	END TRY	
	BEGIN CATCH
	    PRINT ERROR_NUMBER();
		PRINT ERROR_MESSAGE();		
	END CATCH
END


'


--#########################################################
--##### 함수, 프로시저 동기화
--#########################################################
--CRM
SELECT 'DROP '+ROUTINE_TYPE+' '+ROUTINE_NAME
FROM (SELECT ROUTINE_NAME, ROUTINE_TYPE
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE IN ('PROCEDURE','FUNCTION') 
INTERSECT
SELECT ROUTINE_NAME, ROUTINE_TYPE
FROM LS_QA2DEV.CRM.INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE IN ('PROCEDURE','FUNCTION') ) A

--ERP FICO
SELECT 'DROP '+ROUTINE_TYPE+' '+ROUTINE_NAME
FROM (SELECT ROUTINE_NAME, ROUTINE_TYPE
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE IN ('PROCEDURE','FUNCTION') 
AND ( ROUTINE_NAME LIKE 'PR_CO%' OR ROUTINE_NAME LIKE 'PR_FI%' OR ROUTINE_NAME LIKE 'FN_CO%' OR ROUTINE_NAME LIKE 'FN_FI%')
INTERSECT
SELECT ROUTINE_NAME, ROUTINE_TYPE
FROM LS_QA2DEV.ERP.INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE IN ('PROCEDURE','FUNCTION') 
AND ( ROUTINE_NAME LIKE 'PR_CO%' OR ROUTINE_NAME LIKE 'PR_FI%' OR ROUTINE_NAME LIKE 'FN_CO%' OR ROUTINE_NAME LIKE 'FN_FI%')
) A


--개발 신규(QA에서)
SELECT ROUTINE_NAME, ROUTINE_TYPE
FROM LS_QA2DEV.ERP.INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE IN ('PROCEDURE','FUNCTION') 
--AND ( ROUTINE_NAME LIKE 'PR_CO%' OR ROUTINE_NAME LIKE 'PR_FI%' OR ROUTINE_NAME LIKE 'FN_CO%' OR ROUTINE_NAME LIKE 'FN_FI%')
EXCEPT
SELECT ROUTINE_NAME, ROUTINE_TYPE
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE IN ('PROCEDURE','FUNCTION') 






--#########################################################
--##### DBA INDEX 인덱스 생성
--#########################################################
-- 운영DB에서 SP_CREATESTATS 완료 후 
-- 운영DB에서 아래 쿼리 실행 결과를 개발DB에서 수행

WITH COL_COMMENTS
AS
(SELECT A.TABLE_CATALOG AS [DB_NAME]
     , A.TABLE_SCHEMA AS [SCHEMA_NAME]
     , A.TABLE_NAME
     , C.VALUE TABLE_COMMENT
     , A.COLUMN_NAME
     , B.VALUE COLUMN_COMMENT
     , A.COLUMN_DEFAULT AS [DEFAULT_VALUE]
     , A.IS_NULLABLE
     , A.DATA_TYPE
     , CASE WHEN A.DATA_TYPE IN ('CHAR','VARCHAR','NVARCHAR','NCHAR','TEXT') THEN CONVERT(VARCHAR, A.CHARACTER_MAXIMUM_LENGTH)
            WHEN A.DATA_TYPE IN ('INT','FLOAT','NUMERIC','BIGINT') THEN CONVERT(VARCHAR, A.NUMERIC_PRECISION) + ',' + CONVERT(VARCHAR, A.NUMERIC_SCALE)
            WHEN A.DATA_TYPE IN ('DATE','DATETIME','DATETIME2','DATETIMEOFFSET') THEN CONVERT(VARCHAR, A.DATETIME_PRECISION)
            WHEN A.DATA_TYPE IN ('VARBINARY') THEN '' END AS [DATA_LEN]
  FROM INFORMATION_SCHEMA.COLUMNS A
  LEFT JOIN SYS.EXTENDED_PROPERTIES B
    ON B.MAJOR_ID = OBJECT_ID(A.TABLE_NAME)
   AND B.MINOR_ID = A.ORDINAL_POSITION
  LEFT JOIN (SELECT OBJECT_ID(OBJNAME) TABLE_ID
                  , VALUE
               FROM ::FN_LISTEXTENDEDPROPERTY(NULL,'USER','DBO','TABLE',NULL,NULL,NULL)) C
                 ON C.TABLE_ID=OBJECT_ID(A.TABLE_NAME)
)
SELECT G.*
, 'CREATE INDEX IX_'+TABLE_NAME+'_DBA_'+CONVERT(VARCHAR,INDEX_SEQ)+' ON '+TABLE_NAME+'('+COLUMN_NAME+')' AS CREATE_INDEX_STMT
FROM (SELECT D.OBJECT_ID
     , D.TABLE_NAME
	 , F.TABLE_COMMENT
	 , D.STATS_ID
	 , D.STATS_NAME
	 , D.COLUMN_ID
	 , D.COLUMN_NAME
	 , F.COLUMN_COMMENT
	 , D.DENSITY
	 , E.UNFILTERED_ROWS
	 , D.DENSITY * E.UNFILTERED_ROWS SELECTIVITY
	 , ROW_NUMBER() OVER(PARTITION BY D.TABLE_NAME ORDER BY D.COLUMN_ID) INDEX_SEQ
  FROM (SELECT A.OBJECT_ID
             , OBJECT_NAME(A.OBJECT_ID) AS TABLE_NAME
			 , A.STATS_ID
			 , C.NAME AS STATS_NAME
			 --, A.STATS_COLUMN_ID
			 , A.COLUMN_ID
			 , B.NAME AS COLUMN_NAME
			 --, C.*
			 , 1.0/(sum(D.distinct_range_rows)+count(D.distinct_range_rows)) DENSITY			 
          FROM SYS.STATS_COLUMNS A
		  JOIN SYS.ALL_COLUMNS B
		    ON A.OBJECT_ID = B.OBJECT_ID
		   AND A.COLUMN_ID = B.COLUMN_ID
		  JOIN SYS.STATS C
		    ON A.OBJECT_ID = C.OBJECT_ID
		   AND A.STATS_ID = C.STATS_ID
		 CROSS APPLY SYS.DM_DB_STATS_HISTOGRAM(A.OBJECT_ID, A.STATS_ID) D
         WHERE 1=1
		 --AND A.OBJECT_ID=OBJECT_ID('CM_MENU_M')
		 GROUP 
		    BY A.OBJECT_ID
			 , OBJECT_NAME(A.OBJECT_ID) 
			 , A.STATS_ID
			 , C.NAME
			 , A.COLUMN_ID
			 , B.NAME ) D
  JOIN COL_COMMENTS F
    ON D.TABLE_NAME = F.TABLE_NAME
   AND D.COLUMN_NAME = F.COLUMN_NAME
  CROSS APPLY SYS.dm_db_stats_properties(D.OBJECT_ID, D.STATS_ID) E
  WHERE 1=1
    AND D.TABLE_NAME IN (SELECT NAME FROM SYS.ALL_OBJECTS WHERE TYPE='U')
	AND D.COLUMN_NAME NOT IN ('REG_MENU_ID','REG_ID','REG_DTTM','MOD_MENU_ID','MOD_ID','MOD_DTTM')
    AND DENSITY <= 0.01
	AND D.DENSITY * E.UNFILTERED_ROWS < 1000) G
 ORDER BY TABLE_NAME, COLUMN_ID
GO



--#########################################################
--##### MISSING INDEX
--#########################################################
SELECT *
FROM (
SELECT DB_NAME(MID.database_id) AS DB_NAME
     , MIGS.group_handle	
	 , MIGS.unique_compiles	
	 , OBJECT_NAME(MID.OBJECT_ID) AS TABLE_NAME
	 , ROUND(CONVERT (decimal (28, 1), migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) ),0) AS ESTIMATED_IMPROVEMENT, ROUND(MIGS.avg_total_user_cost * MIGS.avg_user_impact * (MIGS.user_seeks + MIGS.user_scans),0) AS TOTAL_COST
	 , MID.equality_columns	
	 , MID.inequality_columns	
	 , MID.included_columns	
	 , MIGS.user_seeks	
	 --, MISQ.USER_SEEKS AS MISQ_USER_SEEKS
	 , MIGS.user_scans	
	 --, MISQ.USER_SCANS AS MISQ_USER_SCANS
	 , MIGS.last_user_seek	
	 --, MISQ.last_user_seek AS MISQL_last_user_seek	 
	 , MIGS.last_user_scan	
	 --, MISQ.last_user_scan AS MISQL_last_user_scan
	 , MIGS.avg_user_impact	
	 --0, MISQ.avg_user_impact	MISQ_avg_user_impact	
	 , MIGS.avg_total_user_cost
	 --, MISQ.avg_total_user_cost AS MISQ_avg_total_user_cost
	 --, CASE WHEN MIGS.avg_total_user_cost	= MISQ.avg_total_user_cost  THEN '' ELSE 'DIFF' END AS COMP_MIGS_MISQ
	 , MIGS.system_seeks	
	 , MIGS.system_scans	
	 , MIGS.last_system_seek	
	 , MIGS.last_system_scan	
	 , MIGS.avg_total_system_cost	
	 , MIGS.avg_system_impact	
	 , MID.statement	
	 , MIC.column_id	
	 , MIC.column_name	
	 , MIC.column_usage	
	 ,'==============================' AS SEP1
	 ,    SUBSTRING
    (
            sql_text.text,
            misq.last_statement_start_offset / 2 + 1,
            (
            CASE misq.last_statement_start_offset
                WHEN -1 THEN DATALENGTH(sql_text.text)
                ELSE misq.last_statement_end_offset
            END - misq.last_statement_start_offset
            ) / 2 + 1
    ) AS SQL_TEXT
	,'==============================' AS SEP2
	--, MISQ.*
	--,'==============================' AS SEP3
	 ,'CREATE INDEX [IX_' + OBJECT_NAME(MID.OBJECT_ID,MID.database_id) + '_'
	   + REPLACE(REPLACE(REPLACE(ISNULL(MID.equality_columns,''),', ','_'),'[',''),']','') 
	   + CASE WHEN MID.equality_columns IS NOT NULL AND MID.inequality_columns IS NOT NULL THEN '_'
	     ELSE '' END
       + REPLACE(REPLACE(REPLACE(ISNULL(MID.inequality_columns,''),', ','_'),'[',''),']','')
	   + ']'
	   + ' ON ' + MID.statement
	   + ' (' + ISNULL (MID.equality_columns,'')
	   + CASE WHEN MID.equality_columns IS NOT NULL AND MID.inequality_columns IS NOT NULL THEN ',' ELSE '' END
	   + ISNULL (MID.inequality_columns, '')
	   + ')'
	   + ISNULL (' INCLUDE (' + MID.included_columns + ')', '') AS CREATE_STATEMENT
  FROM sys.dm_db_missing_index_group_stats MIGS WITH(NOLOCK)
  JOIN sys.dm_db_missing_index_groups MIG WITH(NOLOCK)
    ON MIGS.GROUP_HANDLE = MIG.INDEX_GROUP_HANDLE
  LEFT OUTER JOIN sys.dm_db_missing_index_group_stats_query AS MISQ
    ON MIGS.GROUP_HANDLE = MISQ.GROUP_HANDLE
  JOIN sys.dm_db_missing_index_details MID WITH(NOLOCK) 
    ON MIG.INDEX_HANDLE = MID.INDEX_HANDLE
 CROSS APPLY SYS.DM_DB_MISSING_INDEX_COLUMNS(MID.INDEX_HANDLE) MIC
 CROSS APPLY sys.dm_exec_sql_text(MISQ.last_sql_handle) AS sql_text
 ) A
 WHERE DB_NAME IN ('ERP','CRM')
   --AND TABLE_NAME = 'WM_OUT_D'
   AND TOTAL_COST >= 100000
 ORDER BY TABLE_NAME, TOTAL_COST
GO



--#########################################################
--##### MISSING INDEX 개선 효과 TOP 10
--#########################################################
SELECT TOP 10 
    SUBSTRING
    (
            sql_text.text,
            misq.last_statement_start_offset / 2 + 1,
            (
            CASE misq.last_statement_start_offset
                WHEN -1 THEN DATALENGTH(sql_text.text)
                ELSE misq.last_statement_end_offset
            END - misq.last_statement_start_offset
            ) / 2 + 1
    ),
    misq.*
FROM sys.dm_db_missing_index_group_stats_query AS misq
CROSS APPLY sys.dm_exec_sql_text(misq.last_sql_handle) AS sql_text
ORDER BY misq.avg_total_user_cost * misq.avg_user_impact * (misq.user_seeks + misq.user_scans) DESC; 


SELECT *
FROM sys.dm_db_missing_index_group_stats_query AS misq
group_handle	
query_hash	
query_plan_hash	
last_sql_handle	
last_statement_start_offset	
last_statement_end_offset	
last_statement_sql_handle	
user_seeks	
user_scans	
last_user_seek	
last_user_scan	
avg_total_user_cost	
avg_user_impact	
system_seeks	
system_scans	
last_system_seek	
last_system_scan	
avg_total_system_cost	
avg_system_impact



SELECT COUNT(*) 
FROM BATCH_JOB_EXECUTION JE  
JOIN BATCH_STEP_EXECUTION SE 
ON SE.JOB_EXECUTION_ID = JE.JOB_EXECUTION_ID 
WHERE JE.JOB_INSTANCE_ID =  @P0 
AND SE.STEP_NAME =  @P1
GO

PR_DBA_TABINFO BATCH_JOB_EXECUTION

SELECT JOB_EXECUTION_ID, START_TIME, END_TIME, STATUS, EXIT_CODE, EXIT_MESSAGE, CREATE_TIME, LAST_UPDATED, VERSION 
FROM BATCH_JOB_EXECUTION E 
WHERE JOB_INSTANCE_ID =  @P0 
AND JOB_EXECUTION_ID IN (SELECT MAX(JOB_EXECUTION_ID) FROM BATCH_JOB_EXECUTION E2 WHERE E2.JOB_INSTANCE_ID =  @P1 )
GO

SELECT SE.STEP_EXECUTION_ID, SE.STEP_NAME, SE.START_TIME, SE.END_TIME, SE.STATUS, SE.COMMIT_COUNT, SE.READ_COUNT, SE.FILTER_COUNT, SE.WRITE_COUNT, SE.EXIT_CODE, SE.EXIT_MESSAGE, SE.READ_SKIP_COUNT, SE.WRITE_SKIP_COUNT, SE.PROCESS_SKIP_COUNT, SE.ROLLBACK_COUNT, SE.LAST_UPDATED, SE.VERSION, SE.CREATE_TIME, JE.JOB_EXECUTION_ID, JE.START_TIME, JE.END_TIME, JE.STATUS, JE.EXIT_CODE, JE.EXIT_MESSAGE, JE.CREATE_TIME, JE.LAST_UPDATED, JE.VERSION 
FROM BATCH_JOB_EXECUTION JE  
JOIN BATCH_STEP_EXECUTION SE 
ON SE.JOB_EXECUTION_ID = JE.JOB_EXECUTION_ID 
WHERE JE.JOB_INSTANCE_ID =  @P0 
AND SE.STEP_NAME =  @P1  
ORDER BY SE.CREATE_TIME DESC, SE.STEP_EXECUTION_ID DESC
GO



--#########################################################
--##### DB 용량, DB SIZE 조회
--#########################################################
SELECT 
 b.groupname AS 'File Group'
 , Name
 , [Filename]
 , CONVERT (Decimal(15,2),ROUND(a.Size/128.000,2))  [할당된 용량 (MB)]
 , CONVERT (Decimal(15,2)
 , ROUND(FILEPROPERTY(a.Name,'SpaceUsed')/128.000,2)) AS [사용중인 용량 (MB)]
 , CONVERT (Decimal(15,2)
 , ROUND((a.Size-FILEPROPERTY(a.Name,'SpaceUsed'))/128.000,2)) AS [사용가능한 용량 (MB)] 
FROM dbo.sysfiles a (NOLOCK) 
JOIN sysfilegroups b (NOLOCK) ON a.groupid = b.groupid 
ORDER BY b.groupname




--#########################################################
--##### 텍스트 TEXT로 QUERY ID 찾기
--#########################################################

SELECT *
FROM SYS.QUERY_STORE_QUERY A
JOIN SYS.QUERY_STORE_QUERY_TEXT B
ON A.QUERY_TEXT_ID = B.QUERY_TEXT_ID
WHERE B.QUERY_SQL_TEXT LIKE '%수출입진행현황%'
ORDER BY A.LAST_EXECUTION_TIME DESC
GO


--#########################################################
--##### SYSTEM SP 시스템 SP 등록하기
--#########################################################
EXECUTE [sys].[sp_MS_marksystemobject] 'sp_GetDDL';
GRANT EXECUTE ON dbo.sp_GetDDL TO PUBLIC;
GO
* 주의 : 프로시저명은 반드시 SP_XXX로 해야함


--#########################################################
--##### 최종 접속 일시 확인
--#########################################################
SELECT S.LOGINAME, MAX(S.LOGIN_TIME) LOGIN_TIME
FROM sys.sysprocesses S, sys.dm_exec_connectionS C
WHERE S.spid = C.session_id GROUP BY S.LOGINAME ;



--#########################################################
--##### 특정 프로그램 접속 차단 (트리거)
--#########################################################

CREATE TRIGGER Block_SSMS
ON ALL SERVER FOR LOGON
AS
 BEGIN
  IF (APP_NAME() LIKE '%SQL Server Management Studio%' 
      AND SUSER_NAME() != 'sa')     
         ROLLBACK
 END


--#########################################################
--##### 함수 종속성 확인
--#########################################################
USE 데이터베이스명
GO
-- Get all of the dependency information
SELECT OBJECT_NAME(sed.referencing_id) AS referencing_entity_name,
    o.type_desc AS referencing_desciption,
    COALESCE(COL_NAME(sed.referencing_id, sed.referencing_minor_id), '(n/a)') AS referencing_minor_id,
    sed.referencing_class_desc, sed.referenced_class_desc,
    sed.referenced_server_name, sed.referenced_database_name, sed.referenced_schema_name,
    sed.referenced_entity_name,
    COALESCE(COL_NAME(sed.referenced_id, sed.referenced_minor_id), '(n/a)') AS referenced_column_name,
    sed.is_caller_dependent, sed.is_ambiguous
-- from the two system tables sys.sql_expression_dependencies and sys.object
FROM sys.sql_expression_dependencies AS sed
INNER JOIN sys.objects AS o ON sed.referencing_id = o.object_id
-- on the function dbo.ufnGetProductDealerPrice
WHERE sed.referencing_id = OBJECT_ID('함수명');
GO

--#########################################################
--##### 랜덤 패스워드 생성, 랜덤 비밀번호 생성
--#########################################################
SELECT dbo.GeneratePassword() AS 'NewPassword';



--#########################################################
--##### 인덱스 파일그룹, 파일 그룹, INDEX FILEGROUP, FILE GROUP
--#########################################################
SELECT *
--SELECT INDEX_NAME
FROM (
SELECT OBJECT_NAME(i.[object_id]) AS OBJECT_NAME
 ,i.[index_id] AS INDEX_ID
 ,i.[name] AS INDEX_NAME
 ,i.[type_desc] AS INDEX_TYPE
 ,i.[data_space_id] AS DATABASE_SPACE_ID
 ,f.[name] AS FILE_GROUP
 ,d.[physical_name] AS FILE_NAME
FROM [sys].[indexes] i
INNER JOIN [sys].[filegroups] f
 ON f.[data_space_id] = i.[data_space_id]
INNER JOIN [sys].[database_files] d
 ON f.[data_space_id] = d.[data_space_id]
INNER JOIN [sys].[data_spaces] s
 ON f.[data_space_id] = s.[data_space_id]
WHERE OBJECTPROPERTY(i.[object_id], 'IsUserTable') = 1 ) A
WHERE 1=1
AND (INDEX_TYPE = 'CLUSTERED' AND FILE_GROUP <> 'PRIMARY')
--AND (INDEX_TYPE = 'NONCLUSTERED' AND FILE_GROUP = 'PRIMARY')
;



--#########################################################
--##### 대량 작업 용 백업 스크립트
--#########################################################
-- (0) 데이터 백업
REC 테이블명
* 백업 테이블명 : ZZ_테이블명_YYYYMMDD

-- (1) PK명, PK 컬럼, PK COLUMN 조회, PK 백업
SELECT 'ALTER TABLE '+TABLE_NAME+' DROP CONSTRAINT '+CONSTRAINT_NAME AS 'DROP_CONST_STMT'
, 'ALTER TABLE '+TABLE_NAME+' ADD CONSTRAINT '+CONSTRAINT_NAME+' PRIMARY KEY('+KEY_COLUMN+')' AS 'CREATE_CONST_STMT'
, TABLE_NAME
, CONSTRAINT_NAME
, KEY_COLUMN	
FROM (SELECT TABLE_NAME, CONSTRAINT_NAME, STRING_AGG(COLUMN_NAME,', ') WITHIN GROUP(ORDER BY ORDINAL_POSITION) KEY_COLUMN
        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
		WHERE TABLE_NAME IN
		(,'WM_OUT_D'
		,'WM_OUT_OPEN_D'
		,'WM_STGDS_D'
		,'WM_STGDS_IN_D'
		,'WM_STGDS_IN_SETL_M'
		,'WM_STGDS_M'
		,'WM_STGDS_OUT_D'
		,'WM_STGDS_RTNG_REQ_D'
		,'WM_STGDS_RTNG_REQ_M')
		GROUP BY TABLE_NAME, CONSTRAINT_NAME) A 
GO


-- (2) 인덱스 DDL, 인덱스 백업, 인덱스 컬럼 전체 (딕셔너리 DICTIONARY 활용)
WITH IDX_INFO
    ( DB_NM, SCHEMA_NM, TBL_NM, OBJECT_ID,  IDX_NM, IDX_ID, COL_NM, [NO], PARTITION_ORDINAL, [DES]
    , IS_INCLUDED_COLUMN, TYPE_DESC, [UNIQUE], [KEY], FGNAME
	) 
AS
(
SELECT DB_NAME() DB_NM
      ,SCHEMA_NAME(SCHEMA_ID) SCHEMA_NM
      ,B.NAME TBL_NM
	  , A.OBJECT_ID
	  , A.NAME IDX_NM
	  , A.INDEX_ID
	  , COL_NAME(C.OBJECT_ID,COLUMN_ID) COL_NM 
	  , KEY_ORDINAL [NO]
      , PARTITION_ORDINAL
	  , CASE WHEN IS_DESCENDING_KEY = 1 THEN '(-)' 
		     WHEN IS_DESCENDING_KEY = 0 THEN '' END  [DES]
	  , IS_INCLUDED_COLUMN
	  , A.TYPE_DESC
	  , CASE WHEN A.IS_UNIQUE = 1 THEN 'UNIQUE'
	         WHEN A.IS_UNIQUE = 0 THEN '' END [UNIQUE]
	  , CASE WHEN A.IS_UNIQUE_CONSTRAINT = 1 THEN 'UNIQUE KEY'
	         WHEN A.IS_UNIQUE_CONSTRAINT = 0 THEN '' END 
      + CASE WHEN A.IS_PRIMARY_KEY =1 THEN 'PRIMARY KEY'
	         WHEN A.IS_PRIMARY_KEY =0 THEN '' END [KEY]
	  , FG.GROUPNAME FGNAME
FROM SYS.INDEXES A
	JOIN SYS.OBJECTS B ON A.OBJECT_ID = B.OBJECT_ID
	JOIN SYS.INDEX_COLUMNS C ON A.OBJECT_ID = C.OBJECT_ID AND A.INDEX_ID = C.INDEX_ID
	JOIN SYSINDEXES IFG ON A.OBJECT_ID = IFG.ID AND A.INDEX_ID = IFG.INDID
	LEFT OUTER JOIN SYS.SYSFILEGROUPS AS FG ON IFG.GROUPID=FG.GROUPID 
WHERE B.TYPE = 'U' 
AND B.NAME IN
('IF_PN_PLM_APRL_MOLD_RCV_M'
,'IF_PN_PLM_CM_CD_RCV_M'
,'IF_PN_PLM_CTGR_RCV_M'
,'IF_PN_PLM_FW_MOLD_RCV_M'
,'IF_PN_PLM_LAST_RCV_M'
,'IF_PN_PLM_MTRL_CLR_RCV_M'
,'IF_PN_PLM_MTRL_RCV_M'
,'IF_PN_PLM_SIZE_DEF_RCV_M'
,'IF_PN_PLM_SIZE_REL_RCV_M'
,'IF_PN_PLM_STYL_CLR_RCV_M'
,'IF_PN_PLM_STYL_RCV_M'
,'IF_PN_PLM_STYL_SIZE_SKU_RCV_M'
,'IF_PN_PLM_STYL_SPEC_CHT_RCV_M'
,'PN_MAIN_STYL_CLR_M_NEW'
,'PN_MAIN_STYL_M_NEW'
,'PN_PLM_CM_CD_M'
,'PN_SIZE_DEF_M'
,'PN_SIZE_REL_M'
,'PN_STYL_SIZE_SKU_M'
,'PN_STYL_SPEC_CHT_M')
)
SELECT 'DROP INDEX '+TRIM(IDX_NM COLLATE Korean_Wansung_CI_AS)+' ON '+TBL_NM AS DROP_STMT
     , 'CREATE '+[UNIQUE]+' '+TYPE_DESC+' INDEX '+TRIM(IDX_NM COLLATE Korean_Wansung_CI_AS)+' ON '+TBL_NM+'('+TRIM([COLUMN])+')' AS CREATE_STMT 
     , DB_NM, SCHEMA_NM, TBL_NM, IDX_NM, IDX_ID, TYPE_DESC, [UNIQUE], [KEY], [COLUMN], [INCLUDED_COLUMN], FGNAME
FROM (SELECT DB_NM, SCHEMA_NM, TBL_NM, IDX_NM, IDX_ID, TYPE_DESC, [UNIQUE],  [KEY]
	, STUFF(
			(
				SELECT 
					', ',+CAST(COL_NM AS VARCHAR(100)) + ' ' + [DES] 
				FROM IDX_INFO A2 
				WHERE A2.TBL_NM = B2.TBL_NM AND A2.IDX_NM = B2.IDX_NM
				AND A2.IS_INCLUDED_COLUMN = 0
				ORDER BY TBL_NM, IDX_NM, [NO]
				FOR XML PATH('')
			 ),1,1,''
		  ) [COLUMN]
	, ISNULL(STUFF(
			(
				SELECT 
					', ',+CAST(COL_NM AS VARCHAR(100)) + ' ' 
				FROM IDX_INFO A2 
				WHERE A2.TBL_NM = B2.TBL_NM AND A2.IDX_NM = B2.IDX_NM
				AND A2.IS_INCLUDED_COLUMN = 1
				ORDER BY TBL_NM, IDX_NM, [NO]
				FOR XML PATH('')
			 ),1,1,''
		  ), '') [INCLUDED_COLUMN]
   , FGNAME
FROM IDX_INFO B2 
	JOIN SYS.STATS B WITH (NOLOCK) ON B2.OBJECT_ID = B.OBJECT_ID
WHERE 1=1
AND TBL_NM IN 
('IF_PN_PLM_APRL_MOLD_RCV_M'
,'IF_PN_PLM_CM_CD_RCV_M'
,'IF_PN_PLM_CTGR_RCV_M'
,'IF_PN_PLM_FW_MOLD_RCV_M'
,'IF_PN_PLM_LAST_RCV_M'
,'IF_PN_PLM_MTRL_CLR_RCV_M'
,'IF_PN_PLM_MTRL_RCV_M'
,'IF_PN_PLM_SIZE_DEF_RCV_M'
,'IF_PN_PLM_SIZE_REL_RCV_M'
,'IF_PN_PLM_STYL_CLR_RCV_M'
,'IF_PN_PLM_STYL_RCV_M'
,'IF_PN_PLM_STYL_SIZE_SKU_RCV_M'
,'IF_PN_PLM_STYL_SPEC_CHT_RCV_M'
,'PN_MAIN_STYL_CLR_M_NEW'
,'PN_MAIN_STYL_M_NEW'
,'PN_PLM_CM_CD_M'
,'PN_SIZE_DEF_M'
,'PN_SIZE_REL_M'
,'PN_STYL_SIZE_SKU_M'
,'PN_STYL_SPEC_CHT_M')
AND TYPE_DESC = 'NONCLUSTERED'
GROUP BY DB_NM, SCHEMA_NM, TBL_NM, IDX_NM, IDX_ID, TYPE_DESC, [UNIQUE],  [KEY], FGNAME) A
ORDER BY DB_NM, SCHEMA_NM, TBL_NM, IDX_ID
GO


-- (3)  조회, 권한 백업

SELECT A.*
FROM (
SELECT USER_NAME(GRANTEE_PRINCIPAL_ID) AS GRANTEE
    , CASE CLASS WHEN 1 THEN 'OBJECT' WHEN 0 THEN 'ALL' END CLASS
	, SCHEMA_NAME(SCHEMA_ID) AS SCHEMA_NAME
	, B.NAME AS OBJECT_NAME
	, B.TYPE
	, PERMISSION_NAME
	,A.CLASS_DESC
	, STATE_DESC
	, CASE WHEN B.NAME IS NOT NULL 
		--THEN CASE STATE WHEN 'W' THEN 'USE ' + DB_NAME() + '; ' + LEFT(STATE_DESC, CHARINDEX('_', STATE_DESC)-1) + ' ' + PERMISSION_NAME + ' ON ' + SCHEMA_NAME(SCHEMA_ID) + '.' + B.NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) + ' WITH GRANT OPTION;' COLLATE KOREAN_WANSUNG_CI_AS
		--				ELSE 'USE ' + DB_NAME() + '; ' + STATE_DESC + ' ' + PERMISSION_NAME + ' ON ' + SCHEMA_NAME(SCHEMA_ID) + '.' + B.NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) + ';'    COLLATE KOREAN_WANSUNG_CI_AS END
        THEN CASE STATE WHEN 'W' THEN LEFT(STATE_DESC, CHARINDEX('_', STATE_DESC)-1) + ' ' + PERMISSION_NAME + ' ON ' + SCHEMA_NAME(SCHEMA_ID) + '.' + B.NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) + ' WITH GRANT OPTION;' COLLATE KOREAN_WANSUNG_CI_AS
						ELSE STATE_DESC + ' ' + PERMISSION_NAME + ' ON ' + SCHEMA_NAME(SCHEMA_ID) + '.' + B.NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) + ';'    COLLATE KOREAN_WANSUNG_CI_AS END
		--ELSE CASE STATE WHEN 'W' THEN 'USE ' + DB_NAME() + '; ' + LEFT(STATE_DESC, CHARINDEX('_', STATE_DESC)-1) + ' ' + PERMISSION_NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) + ' WITH GRANT OPTION;'
		--				ELSE 'USE ' + DB_NAME() + '; ' + STATE_DESC + ' ' + PERMISSION_NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) END
        ELSE CASE STATE WHEN 'W' THEN LEFT(STATE_DESC, CHARINDEX('_', STATE_DESC)-1) + ' ' + PERMISSION_NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) + ' WITH GRANT OPTION;'
						ELSE STATE_DESC + ' ' + PERMISSION_NAME + ' TO ' + USER_NAME(GRANTEE_PRINCIPAL_ID) END
		END AS SCRIPT
FROM SYS.DATABASE_PERMISSIONS A WITH (NOLOCK)
	LEFT JOIN SYS.OBJECTS B WITH(NOLOCK) ON A.MAJOR_ID = B.OBJECT_ID
	JOIN SYS.DATABASE_PRINCIPALS C WITH (NOLOCK) ON A.GRANTEE_PRINCIPAL_ID = C.PRINCIPAL_ID
WHERE MAJOR_ID >= 0 AND  A.TYPE <>'CO' 
AND GRANTEE_PRINCIPAL_ID <> 0 
AND C.PRINCIPAL_ID > 4
AND USER_NAME(GRANTEE_PRINCIPAL_ID) NOT LIKE '%MS_%'
--AND USER_NAME(GRANTEE_PRINCIPAL_ID) LIKE 'P_CJSPRJ_KDH%'
--AND PERMISSION_NAME ='CONTROL' -- 암복호화 권한 조회
) A
WHERE 1=1
AND OBJECT_NAME IN 
('IF_PN_PLM_APRL_MOLD_RCV_M'
,'IF_PN_PLM_CM_CD_RCV_M'
,'IF_PN_PLM_CTGR_RCV_M'
,'IF_PN_PLM_FW_MOLD_RCV_M'
,'IF_PN_PLM_LAST_RCV_M'
,'IF_PN_PLM_MTRL_CLR_RCV_M'
,'IF_PN_PLM_MTRL_RCV_M'
,'IF_PN_PLM_SIZE_DEF_RCV_M'
,'IF_PN_PLM_SIZE_REL_RCV_M'
,'IF_PN_PLM_STYL_CLR_RCV_M'
,'IF_PN_PLM_STYL_RCV_M'
,'IF_PN_PLM_STYL_SIZE_SKU_RCV_M'
,'IF_PN_PLM_STYL_SPEC_CHT_RCV_M'
,'PN_MAIN_STYL_CLR_M_NEW'
,'PN_MAIN_STYL_M_NEW'
,'PN_PLM_CM_CD_M'
,'PN_SIZE_DEF_M'
,'PN_SIZE_REL_M'
,'PN_STYL_SIZE_SKU_M'
,'PN_STYL_SPEC_CHT_M')
ORDER BY GRANTEE, A.CLASS
GO





XP_READERRORLOG 0,1,NULL,NULL,NULL,NULL,'DESC'






SELECT DISTINCT SQL
FROM DBA_SESSIONS_DETAIL
WHERE DATECHECKED BETWEEN CONVERT(DATETIME,'20241021 08:00:00') AND GETDATE()
AND SQL NOT LIKE '%JOIN%'
AND LOGIN NOT IN ('kestra','EAIINF','TUNE','NT AUTHORITY\SYSTEM','NT SERVICE\SQLSERVERAGENT')
AND LOGIN NOT LIKE 'P\_%' ESCAPE '\'
AND SQL NOT LIKE 'SELECT MSG_SE_CD+''.''+TSK_SE_CD%'
AND SQL NOT LIKE ' OPEN cur%'
AND SQL NOT LIKE ' FETCH NEXT FROM%'
 AND SQL NOT LIKE ' COMMIT TR%'
AND PROGRAM NOT LIKE 'DBeaver%'
AND PROGRAM NOT LIKE 'Microsoft SQL Server Management Studio%'
AND DBNAME IN ('ERP','CRM') ;

'
  
  
  
--#########################################################
--##### FN_SA_GET_PRCE  함수 집계 테이블
--#########################################################  
DROP TABLE IF EXISTS ZZ_FN_SA_GET_PRCE;
SELECT STYL.COMP_CD
, STYL.BRND_CD
, STYL.STYL_CD
, CLR.CLR_CD
, FN.*
INTO ZZ_FN_SA_GET_PRCE
FROM PN_BRND_M BRND
JOIN PN_MAIN_STYL_M STYL
ON BRND.COMP_CD = STYL.COMP_CD
AND BRND.BRND_CD = STYL.BRND_CD
LEFT JOIN PN_MAIN_STYL_CLR_M CLR
ON STYL.COMP_CD = CLR.COMP_CD
AND STYL.STYL_CD = CLR.STYL_CD
CROSS APPLY ERP.DBO.FN_SA_GET_PRCE(STYL.COMP_CD, STYL.BRND_CD, 'S', CONVERT(VARCHAR(8), GETDATE(), 112), STYL.BRND_CD , STYL.STYL_CD, CLR.CLR_CD, '1', '', '', '', 'kr' ) FN



--#########################################################
--##### 튜닝 대상 추출
--#########################################################  
SELECT *
FROM (SELECT TRANSACTIONS
, MAX(EXEC_TIME) MAX_EXEC_DATETIME
, COUNT(*) CNT
, AVG(ELAPSED_TIME) AS AVG_ELAPSED_TIME_SEC
, MAX(ELAPSED_TIME) AS MAX_ELAPSED_TIME_SEC
, MAX(ELAPSED_TIME) - AVG(ELAPSED_TIME) AS GAP_MAX_AVG_TIME_SEC
FROM ZZ_TRANSACTION_STATS
GROUP BY TRANSACTIONS ) A
WHERE AVG_ELAPSED_TIME_SEC >= 10
AND CNT >= 10
ORDER BY CNT DESC ;



--#########################################################
--##### DB 오브젝트 비교 SP_DBA_GAPDB
--#########################################################  
USE ERP
GO

DROP TABLE IF EXISTS #RESULT ;

CREATE TABLE #RESULT
(DB_NAME	 VARCHAR(500)
,SCHEMA_NAME	 VARCHAR(500)
,OBJECT_TYPE	 VARCHAR(500)
,OBJECT_NAME	 VARCHAR(500)
,COLUMN_NAME	 VARCHAR(500)
,ERROR_TYPE	 VARCHAR(500)
,LOCAL_EXISTS	 VARCHAR(500)
,REMOTE_EXISTS VARCHAR(500)
) ;

INSERT INTO #RESULT EXEC SP_DBA_GAPDB ERP, ERP, LS_MIG2PROD

SELECT *
FROM #RESULT
--WHERE OBJECT_TYPE LIKE '%TABLE%'





--#########################################################
--##### DB 사용자 비교
--#########################################################  
-- ERP
SELECT NAME
FROM LS_MIG2PROD.ERP.sys.database_principals
WHERE TYPE_DESC = 'SQL_USER'
EXCEPT
SELECT NAME
FROM ERP_TT.sys.database_principals
WHERE TYPE_DESC = 'SQL_USER';

-- CRM
SELECT NAME
FROM LS_MIG2PROD.CRM.sys.database_principals
WHERE TYPE_DESC = 'SQL_USER'
EXCEPT
SELECT NAME
FROM CRM_TT.sys.database_principals
WHERE TYPE_DESC = 'SQL_USER'



--#########################################################
--##### 함수, 프로시저 삭제
--#########################################################  

SELECT CASE WHEN ROUTINE_TYPE='FUNCTION' THEN 'DROP FUNCTION '
       ELSE 'DROP PROCEDURE ' END + ROUTINE_NAME
FROM INFORMATION_SCHEMA.ROUTINES
WHERE 1=1
AND ROUTINE_TYPE IN ('FUNCTION','PROCEDURE')
AND ROUTINE_NAME NOT LIKE '%DBA%'
AND ROUTINE_NAME NOT LIKE '%RPO%'
ORDER BY ROUTINE_TYPE, ROUTINE_NAME ;




--#########################################################
--##### 암호화
--#########################################################  

SECUREDB.DBSAC.ENC(데이터,'aes256')
SECUREDB.DBSAC.DEC(데이터,'aes256')




-- 암호화 대상 확인
DROP TABLE IF EXISTS #ENC_INFO;    
CREATE TABLE #ENC_INFO    
(TABLE_NAME  VARCHAR(100)    
,COLUMN_NAME VARCHAR(100)    
);    

    
INSERT INTO #ENC_INFO VALUES('EM_EMP_BACNT_CHG_APLY_M','ACNO');    
INSERT INTO #ENC_INFO VALUES('EM_EMP_BACNT_D','ACNO');    
INSERT INTO #ENC_INFO VALUES('EM_EMP_BACNT_REG_APLY_D','ACNO');    
INSERT INTO #ENC_INFO VALUES('EM_EMP_FMLY_D','PIN');    
INSERT INTO #ENC_INFO VALUES('EM_EMP_FMLY_REG_APLY_D','PIN');    
INSERT INTO #ENC_INFO VALUES('EM_EMP_PINFO_CHG_APLY_M','PIN');    
INSERT INTO #ENC_INFO VALUES('EM_EMP_PINFO_D','PIN');    
INSERT INTO #ENC_INFO VALUES('EM_TRICOR_EMP_DATA_M','ACNO');    
INSERT INTO #ENC_INFO VALUES('EM_TRICOR_EMP_DATA_M','HKID_NO');    
INSERT INTO #ENC_INFO VALUES('EM_TRICOR_EMP_DATA_M','PPNO');    
INSERT INTO #ENC_INFO VALUES('FI_CMS_BACNT_CNFM_D','ACNO');    
INSERT INTO #ENC_INFO VALUES('FI_CUST_M','RRNO');    
INSERT INTO #ENC_INFO VALUES('FI_CUST_PYMT_BACNT_D','ACNO');    
INSERT INTO #ENC_INFO VALUES('FI_CUST_REQ_M','RRNO');    
INSERT INTO #ENC_INFO VALUES('FI_CUST_REQ_PYMT_BACNT_D','ACNO');    
INSERT INTO #ENC_INFO VALUES('FI_PYMT_TRGT_DATA_D','PYMT_ACNO');    
INSERT INTO #ENC_INFO VALUES('FI_PYMT_TRGT_OCSLP_D','PYMT_ACNO');    
INSERT INTO #ENC_INFO VALUES('IF_PY_EMP_DATA_D','RRNO');    
INSERT INTO #ENC_INFO VALUES('IF_PY_FMLY_DATA_D','RRNO');    
INSERT INTO #ENC_INFO VALUES('IF_PY_PYRSLT_DATA_M','RRNO');    
INSERT INTO #ENC_INFO VALUES('IF_PY_SALAC_DATA_D','SAL_ACNO');    


WITH EXCEPT_TABLE
AS
(SELECT TBL_NM, COL_NM
   FROM CM_ENC_CALL_H
  WHERE 1=1
    AND COL_NM NOT LIKE '%FILE%'
    AND COL_NM IS NOT NULL
    AND COL_NM NOT IN ('MSG_CNTN')
 EXCEPT
 SELECT TABLE_NAME, COLUMN_NAME
   FROM #ENC_INFO
)
SELECT ET.TBL_NM, ET.COL_NM, MAX(REG_DTTM) MAX_REG_DTTM, MAX(MOD_DTTM) MAX_MOD_DTTM
  FROM EXCEPT_TABLE ET
  JOIN CM_ENC_CALL_H CH
    ON ET.TBL_NM = CH.TBL_NM
   AND ET.COL_NM = CH.COL_NM
 WHERE 1=1
   AND TRIM(ET.TBL_NM) NOT IN ('TABLE','TABLE_NAME', '', 'ENC_TB')
   AND ET.COL_NM NOT IN ('MSG_CD')
 GROUP BY ET.TBL_NM, ET.COL_NM ;
 
 
 
 
--#########################################################
--##### BAD SQL TOP, TOP SQL
--#########################################################  
SELECT A.*
FROM (SELECT SQL
, LEFT(PARENT_QUERY,200) PARENT_QUERY
, HOSTNAME
, PROGRAM
, MAX([Dur2(s)]) MAX_ELAPSED_TIME_SEC
, AVG([Dur2(s)]) AVG_ELAPSED_TIME_SEC
, COUNT(*) AS CNT
FROM MONITOR.DBO.DBA_SESSIONS_DETAIL
WHERE DATECHECKED >= CONVERT(DATETIME,'20241202 00:00:00')
AND SQL IS NOT NULL
GROUP BY SQL, LEFT(PARENT_QUERY,200), HOSTNAME, PROGRAM
) A
WHERE 1=1
AND A.CNT >= 10
AND AVG_ELAPSED_TIME_SEC > 5
AND PROGRAM LIKE '%JDBC%'
ORDER BY CNT DESC, MAX_ELAPSED_TIME_SEC DESC



--#########################################################
--##### 프로시저, 함수 소스 수정 SP_DBA_HELPTEXTS
--#########################################################  
USE ERP
GO

DROP TABLE IF EXISTS #SOURCE ;
CREATE TABLE #SOURCE(SEQ INT IDENTITY(1,1), TEXT VARCHAR(MAX))

INSERT INTO #SOURCE(TEXT) EXEC SP_DBA_HELPTEXTS ERP
GO

SELECT REPLACE(TEXT,'CREATE PROC','ALTER PROC') FROM #SOURCE ORDER BY SEQ ;



--#########################################################
--##### 마스킹 여부 확인하기 MASKING
--#########################################################  
SELECT 'SELECT '+COLUMN_NAME+CHAR(13)
       + '  FROM '+TABLE_NAME+CHAR(13)
	   + ' WHERE '+COLUMN_NAME+' IS NOT NULL '+CHAR(13)
	   + '   AND '+COLUMN_NAME+' NOT LIKE ''$.%'''+CHAR(13)
	   + '   AND '+COLUMN_NAME+' NOT LIKE ''%*%'''+CHAR(13)
	   + '   AND '+COLUMN_NAME+' <> '''''+CHAR(13) AS SELECT_STMT
FROM ERP.INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME LIKE '%RRNO%'
AND TABLE_NAME NOT LIKE 'ZZ%'
ORDER BY TABLE_NAME ;



--#########################################################
--##### LOCK LEVEL 확인(ROW LEVEL, TABLE LEVEL)
--#########################################################  
SELECT 
    tl.request_session_id AS SessionID,
    tl.resource_type AS ResourceType,
    tl.resource_associated_entity_id AS ResourceID,
    tl.request_mode AS LockType,
    tl.request_status AS LockStatus,
    er.status AS RequestStatus,
    er.command AS Command,
    es.login_name AS LoginName,
    es.host_name AS HostName
FROM sys.dm_tran_locks AS tl
JOIN sys.dm_exec_requests AS er ON tl.request_session_id = er.session_id
JOIN sys.dm_exec_sessions AS es ON tl.request_session_id = es.session_id;




SELECT
    request_session_id AS SPID,
    resource_type AS ResourceType,
    resource_database_id AS DatabaseID,
	DB_NAME(resource_database_id) AS DB_NAME,
    resource_associated_entity_id AS ResourceID,
	CASE WHEN resource_type = 'OBJECT' THEN OBJECT_NAME(resource_associated_entity_id)
	ELSE '' END AS OBJECT_NAME,
    request_mode AS LockType,
    request_status AS LockStatus
FROM sys.dm_tran_locks
WHERE 1=1
--AND resource_type IN ('RID', 'PAGE')
--AND resource_type = 'OBJECT'
AND DB_NAME(resource_database_id) NOT IN ('tempdb') 
--AND request_mode NOT IN ('S','IS','Sch-S') 



--#########################################################
--##### FLUSH PLAN CACHE
--#########################################################  
DBCC FREEPROCCACHE (0x06001B00EEB59514D0DD5EE28E01000001000000000000000000000000000000000000000000000000000000);

--아래 쿼리로 plan_handle 찾은다음 DBCC FREEPROCCACHE 로 plan cache에서 삭제
SELECT
    decp.plan_handle,
    dest.text AS SQL_Text
	--COUNT(*) AS CNT
FROM
    sys.dm_exec_cached_plans AS decp
CROSS APPLY
    sys.dm_exec_sql_text(decp.plan_handle) AS dest
WHERE
    dest.text LIKE N'%TOP%100%FN_PN_GET_BRND_VAL%PAGE_ROW_NUMBER%'    -- 여기에 찾고 싶은 SQL 텍스트의 일부를 입력
--GROUP BY decp.plan_handle



--#########################################################
--##### SELECT 건수
--#########################################################  
SELECT 'SELECT '''+TABLE_NAME+''' AS TABLE_NAME, COUNT(*) AS CNT FROM ERP.DBO.'+TABLE_NAME+' UNION ALL', 'ERP' DBNAME, TABLE_NAME
FROM ERP.INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME NOT LIKE 'ZZ%'
UNION ALL
SELECT 'SELECT '''+TABLE_NAME+''' AS TABLE_NAME, COUNT(*) AS CNT FROM CRM.DBO.'+TABLE_NAME+' UNION ALL', 'CRM' DBNAME, TABLE_NAME
FROM CRM.INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME NOT LIKE 'ZZ%'
ORDER BY DBNAME, TABLE_NAME ;



--#########################################################
--##### 시퀀스 값 증가(운영과 QA중 높은 값 + 100)
--#########################################################  

WITH W_QA_SEQ
AS
(SELECT * 
FROM LS_PROD2QA.ERP.SYS.sequences)
SELECT PRD.NAME
, CASE WHEN PRD.current_value >= QA.CURRENT_VALUE THEN PRD.current_value ELSE QA.current_value END MAX_CURRENT_VALUE
, PRD.current_value
, QA.current_value
FROM ERP.SYS.sequences PRD
LEFT JOIN W_QA_SEQ QA
ON PRD.NAME=QA.NAME
ORDER BY PRD.NAME ;

WITH W_QA_SEQ
AS
(SELECT * 
FROM LS_PROD2QA.CRM.SYS.sequences)
SELECT PRD.NAME
, CASE WHEN PRD.current_value >= QA.CURRENT_VALUE THEN PRD.current_value ELSE QA.current_value END MAX_CURRENT_VALUE
, PRD.current_value
, QA.current_value
FROM CRM.SYS.sequences PRD
LEFT JOIN W_QA_SEQ QA
ON PRD.NAME=QA.NAME
ORDER BY PRD.NAME ;



--#########################################################
--##### 로그인 삭제
--#########################################################  
DECLARE @LoginName NVARCHAR(128) = 'DWAPP';
DECLARE @spid INT;

DECLARE login_sessions CURSOR FOR
SELECT session_id
FROM sys.dm_exec_sessions
WHERE login_name = @LoginName;

OPEN login_sessions;

FETCH NEXT FROM login_sessions INTO @spid;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC ('KILL ' + @spid);
    FETCH NEXT FROM login_sessions INTO @spid;
END;

CLOSE login_sessions;
DEALLOCATE login_sessions;

DROP LOGIN DWAPP;

   
   

--#########################################################
--##### 운영 DB 개인사용자용 계정 생성, 권한 부여
--#########################################################  

CREATE TABLE DA_AUTH_LIST
(USER_NM		VARCHAR(100)
,ACNT_NM		VARCHAR(100)
,BIZ_NM			VARCHAR(100)
,BIZ_DTL_NM		VARCHAR(100)
,PSWD			VARCHAR(100)
,DB_NM			VARCHAR(100)
,USER_TP		VARCHAR(100)
,PINFO_HDLG_YN	VARCHAR(1)
);

-- LOGIN & DB USER 생성
SELECT 'USE master;
CREATE LOGIN '+ACNT_NM+' WITH PASSWORD='''+SECUREDB.DBSAC.DEC(PSWD,'aes256')+''', DEFAULT_DATABASE=['+DB_NM+'], CHECK_EXPIRATION=ON, CHECK_POLICY=ON;
USE '+DB_NM+';
CREATE USER '+ACNT_NM+' FOR LOGIN '+ACNT_NM
FROM DA_AUTH_LIST 
WHERE DB_NM IN ('CRM','ERP')
UNION ALL
SELECT 'USE master;
CREATE LOGIN '+ACNT_NM+' WITH PASSWORD='''+SECUREDB.DBSAC.DEC(PSWD,'aes256')+''', DEFAULT_DATABASE=['+DB_NM+'], CHECK_EXPIRATION=ON, CHECK_POLICY=ON;
USE CRM_DW;
CREATE USER '+ACNT_NM+' FOR LOGIN '+ACNT_NM+'
USE ERP;
CREATE USER '+ACNT_NM+' FOR LOGIN '+ACNT_NM
FROM DA_AUTH_LIST 
WHERE DB_NM IN ('ERP_DW')



-- GRANT 일반테이블 조회권한
SELECT 'USE '+DB_NM+';
ALTER ROLE RL_RO_NPRI ADD MEMBER '+ACNT_NM
FROM DA_AUTH_LIST ;

-- GRANT 개인정보테이블 조회권한
SELECT 'USE '+DB_NM+';
ALTER ROLE RL_RO_PRI ADD MEMBER '+ACNT_NM
FROM DA_AUTH_LIST 
WHERE PINFO_HDLG_YN='Y'

-- GRANT 설계자(DESIGNER) RW 권한
SELECT 'USE '+DB_NM+';
ALTER ROLE RL_RW_'+BIZ_NM+' ADD MEMBER '+ACNT_NM
FROM DA_AUTH_LIST 
WHERE USER_TP='DESIGNER'
AND BIZ_NM NOT IN ('ARCHITECTURE')

-- GRANT 설계자(DESIGNER) execute 권한
SELECT 'USE '+DB_NM+';
ALTER ROLE db_executor ADD MEMBER '+ACNT_NM
FROM DA_AUTH_LIST 
WHERE USER_TP='DESIGNER'
AND BIZ_NM NOT IN ('ARCHITECTURE')


-- GRANT 관리자(DBA) sysadmin 권한
SELECT 'USE master;
ALTER SERVER ROLE sysadmin ADD MEMBER '+ACNT_NM
FROM DA_AUTH_LIST 
WHERE USER_TP='DBA'

-- GRANT 설계자(DESIGNER) 로깅테이블 write 권한
USE ERP;
SELECT 'USE '+DB_NM+'LOG;
CREATE USER '+ACNT_NM+' FOR LOGIN '+ACNT_NM+'
ALTER ROLE db_datawriter ADD MEMBER '+ACNT_NM
FROM DA_AUTH_LIST 
WHERE USER_TP='DESIGNER'




--#########################################################
--##### 함수, 프로시저 수정 권한, ALTER 권한
--#########################################################  
USE CRM; 
SELECT 'USE CRM;GRANT ALTER ON OBJECT::'+ROUTINE_NAME+' TO P_CRM'
FROM INFORMATION_SCHEMA.ROUTINES
WHERE LEFT(ROUTINE_NAME,6) IN ('FN_CR_','FN_CS_','FN_EB_','PR_CR_','PR_CS_','PR_EB_')
OR LEFT(ROUTINE_NAME,9) IN ('up_IF_CR_', 'up_IF_CS_', 'up_IF_EB_')
UNION ALL
SELECT 'USE CRM;GRANT ALTER ON OBJECT::'+ROUTINE_NAME+' TO P_SCM'
FROM INFORMATION_SCHEMA.ROUTINES
WHERE LEFT(ROUTINE_NAME,6) IN ('PR_SA_','PR_SP_','PR_WM_')



USE ERP;

SELECT DISTINCT ROUTINE_TYPE, LEFT(ROUTINE_NAME,6)
FROM INFORMATION_SCHEMA.ROUTINES
ORDER BY 1,2 ;



--P_CM
--FN_CM_
--PR_CM_
USE ERP;
SELECT 'USE ERP;GRANT ALTER ON OBJECT::'+ROUTINE_NAME+' TO P_CM;'
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME LIKE 'FN\_CM\_%' ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_CM\_%' ESCAPE '\'
OR ROUTINE_NAME LIKE 'up\_IF\_CM%' ESCAPE '\'
ORDER BY 1 ;
'

--P_FCM
--FN_CO_
--FN_FI_
--PR_CO_
--PR_FI_
USE ERP;
SELECT 'USE ERP;GRANT ALTER ON OBJECT::'+ROUTINE_NAME+' TO P_FCM;'
FROM INFORMATION_SCHEMA.ROUTINES
WHERE 
ROUTINE_NAME LIKE 'FN\_CO\_%' ESCAPE '\'
OR ROUTINE_NAME LIKE 'FN\_FI\_%' ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_CO\_%' ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_FI\_%' ESCAPE '\'
OR ROUTINE_NAME LIKE 'up\_IF\_FI\_%' ESCAPE '\'
ORDER BY 1 ;
'

--P_CRM
--FN_EB_
--PR_EB_
USE ERP;
SELECT 'USE ERP;GRANT ALTER ON OBJECT::'+ROUTINE_NAME+' TO P_CRM;'
FROM INFORMATION_SCHEMA.ROUTINES
WHERE 
ROUTINE_NAME LIKE 'FN\_EB\_%' ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_EB\_%' ESCAPE '\'
ORDER BY 1 ;
'

--P_SCM
--FN_EI_
--FN_PN_
--FN_PP_
--FN_SA_
--FN_SP_
--FN_WM_
--PR_EI_
--PR_PN_
--PR_PO_
--PR_PP_
--PR_SA_
--PR_SM_
--PR_SP_
--PR_WM_
USE ERP;
SELECT 'USE ERP;GRANT ALTER ON OBJECT::'+ROUTINE_NAME+' TO P_SCM;'
FROM INFORMATION_SCHEMA.ROUTINES
WHERE 
   ROUTINE_NAME LIKE 'FN\_EI\_%'    ESCAPE '\'
OR ROUTINE_NAME LIKE 'FN\_PN\_%'    ESCAPE '\'
OR ROUTINE_NAME LIKE 'FN\_PP\_%'    ESCAPE '\'
OR ROUTINE_NAME LIKE 'FN\_SA\_%'    ESCAPE '\'
OR ROUTINE_NAME LIKE 'FN\_SP\_%'    ESCAPE '\'
OR ROUTINE_NAME LIKE 'FN\_WM\_%'    ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_EI\_%'    ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_PN\_%'    ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_PO\_%'    ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_PP\_%'    ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_SA\_%'    ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_SM\_%'    ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_SP\_%'    ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_WM\_%'    ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_IF\_EI%'  ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_IF\_PN%'  ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_IF\_PP%'  ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_IF\_SA%'  ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_IF\_WM%'  ESCAPE '\'
OR ROUTINE_NAME LIKE 'up\_IF\_EI%'  ESCAPE '\'
OR ROUTINE_NAME LIKE 'up\_IF\_PN%'  ESCAPE '\'
OR ROUTINE_NAME LIKE 'up\_IF\_PO%'  ESCAPE '\'
OR ROUTINE_NAME LIKE 'up\_IF\_PP%'  ESCAPE '\'
OR ROUTINE_NAME LIKE 'up\_IF\_SA%'  ESCAPE '\'
ORDER BY 1 ;
'

--P_HR
--FN_EM_
--FN_HR_
--PR_EM_
--PR_HR_
USE ERP;
SELECT 'USE ERP;GRANT ALTER ON OBJECT::'+ROUTINE_NAME+' TO P_HR;'
FROM INFORMATION_SCHEMA.ROUTINES
WHERE 
   ROUTINE_NAME LIKE 'FN\_EM\_%'  ESCAPE '\'
OR ROUTINE_NAME LIKE 'FN\_HR\_%'  ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_EM\_%'  ESCAPE '\'
OR ROUTINE_NAME LIKE 'PR\_HR\_%'  ESCAPE '\'
ORDER BY 1 ;
'

--DWAPP
USE ERP;
SELECT 'USE ERP;GRANT ALTER ON OBJECT::'+ROUTINE_NAME+' TO P_DW;'
FROM INFORMATION_SCHEMA.ROUTINES
WHERE 
   ROUTINE_NAME LIKE 'up\_IF\_DW\_%'  ESCAPE '\'
'




--#########################################################
--##### BINARY, VARBINARY 검색
--#########################################################  
SELECT *
FROM MONITOR.DBO.DBA_SESSIONS_DETAIL
WHERE PLAN_HANDLE = CONVERT(VARBINARY,0x06000100CA962819703473B98601000001000000000000000000000000000000000000000000000000000000)


--#########################################################
--##### PLAN_ID를 여러개 가지는 QUERY_ID의 PLAN_HANDLE FLUSH
--#########################################################  

DROP TABLE IF EXISTS #TEMP;

WITH MULTI_PLAN_ID
AS
(SELECT QUERY_ID, COUNT(DISTINCT PLAN_ID) AS CNT_PLAN
FROM sys.query_store_plan
GROUP BY QUERY_ID
HAVING COUNT(DISTINCT PLAN_ID) > 1
)
SELECT DISTINCT QSP.QUERY_PLAN_HASH
INTO #TEMP
FROM sys.query_store_plan QSP
JOIN MULTI_PLAN_ID MPI
ON QSP.QUERY_ID = MPI.QUERY_ID

SELECT DISTINCT 'DBCC FREEPROCCACHE (', PLAN_HANDLE, ')'
FROM SYS.DM_EXEC_QUERY_STATS DEQS
JOIN #TEMP TMP
ON DEQS.QUERY_PLAN_HASH = TMP.QUERY_PLAN_HASH




--#########################################################
--##### SQL TEXT 일부를 입력받아 PLAN_HANDLE 찾기
--#########################################################  


SELECT 
    cp.plan_handle,
    st.text AS sql_text,
    cp.usecounts,
    cp.size_in_bytes
FROM 
    sys.dm_exec_cached_plans AS cp
CROSS APPLY 
    sys.dm_exec_sql_text(cp.plan_handle) AS st
WHERE 
    st.text LIKE '%WITH FCM_SLP AS%'
ORDER BY 
    cp.usecounts DESC;
	
	

--#########################################################
--##### QUERY STORE에서 TEXT로 PLAN_HANDLE 찾기 (FOR DBCC FREEPROCCACHE)
--#########################################################  

SELECT TEXTX.QUERY_TEXT_ID
     , QUERYX.QUERY_ID
	 , PLANX.PLAN_ID
	 , QSTATS.PLAN_HANDLE
	 , QSTATS.STATEMENT_SQL_HANDLE
	 , QSTATS.SQL_HANDLE
	 , TEXTX.QUERY_SQL_TEXT
  FROM SYS.QUERY_STORE_QUERY_TEXT TEXTX
  JOIN SYS.QUERY_STORE_QUERY QUERYX
    ON TEXTX.QUERY_TEXT_ID = QUERYX.QUERY_TEXT_ID
  JOIN SYS.QUERY_STORE_PLAN PLANX
    ON QUERYX.QUERY_ID = PLANX.QUERY_ID
  JOIN SYS.DM_EXEC_QUERY_STATS QSTATS
	ON TEXTX.STATEMENT_SQL_HANDLE = QSTATS.STATEMENT_SQL_HANDLE
 WHERE TEXTX.query_sql_text LIKE '%이동요청번호 채번%'
 ORDER BY QSTATS.statement_sql_handle
 
 


SELECT TEXT.*
     , '****************' SEP1
     , QSTATS.*
  FROM SYS.query_store_query_text TEXT
  JOIN SYS.dm_exec_query_stats QSTATS
--ON TEXT.statement_sql_handle = QSTATS.sql_handle
    ON TEXT.statement_sql_handle = QSTATS.statement_sql_handle
 WHERE TEXT.QUERY_SQL_TEXT LIKE '%WITH W_BDGTAUTH%'
   AND TEXT.QUERY_SQL_TEXT NOT LIKE '%QUERY_STORE%'
   AND TEXT.QUERY_SQL_TEXT NOT LIKE '%MONITOR%'
 ORDER BY QSTATS.LAST_EXECUTION_TIME ;
 
 

SELECT DMSTATS.PLAN_HANDLE
, '--------  QUERY --------' SEP1
, QUERY.query_id
, QUERY.query_text_id
, QUERY.batch_sql_handle
, QUERY.query_hash
, QUERY.initial_compile_start_time
, QUERY.last_compile_start_time
, QUERY.last_execution_time
, QUERY.count_compiles
, QUERY.avg_compile_duration
, QUERY.last_compile_duration
, '--------  PLANX --------' SEP2
, PLANX.plan_id
, PLANX.query_id
, PLANX.query_plan_hash
, PLANX.query_plan
, PLANX.is_parallel_plan
, PLANX.force_failure_count
, PLANX.last_force_failure_reason
, PLANX.last_force_failure_reason_desc
, PLANX.count_compiles
, PLANX.initial_compile_start_time
, PLANX.last_compile_start_time
, PLANX.last_execution_time
, PLANX.avg_compile_duration
, PLANX.last_compile_duration
, PLANX.plan_forcing_type
, PLANX.plan_forcing_type_desc
, PLANX.has_compile_replay_script
, PLANX.is_optimized_plan_forcing_disabled
, PLANX.plan_type
, PLANX.plan_type_desc
, '--------  TEXT --------' SEP3
, TEXT.query_text_id
, TEXT.query_sql_text
, TEXT.statement_sql_handle
, TEXT.is_part_of_encrypted_module
, TEXT.has_restricted_text
  FROM SYS.query_store_query_text TEXT
  LEFT JOIN sys.query_store_query AS QUERY
  	ON TEXT.query_text_id = QUERY.query_text_id
  LEFT JOIN sys.query_store_plan AS PLANX 
  	ON PLANX.query_id = QUERY.query_id
  LEFT JOIN SYS.DM_EXEC_QUERY_STATS DMSTATS
    ON DMSTATS.QUERY_PLAN_HASH = PLANX.QUERY_PLAN_HASH
 WHERE TEXT.QUERY_SQL_TEXT LIKE '%WITH W_BDGTAUTH%'
   AND TEXT.QUERY_SQL_TEXT NOT LIKE '%QUERY_STORE%'
   AND TEXT.QUERY_SQL_TEXT NOT LIKE '%MONITOR%'
ORDER BY QUERY.last_execution_time DESC 


SELECT QS.PLAN_HANDLE
     , QS.QUERY_PLAN_HASH
	 , CP.CACHEOBJTYPE
	 , CP.OBJTYPE
  FROM SYS.DM_EXEC_QUERY_STATS AS QS
  JOIN SYS.DM_EXEC_CACHED_PLANS AS CP
    ON QS.PLAN_HANDLE = CP.PLAN_HANDLE
 WHERE QS.QUERY_PLAN_HASH = CONVERT(VARBINARY, 0x7B58C7BEB5A3BBFF)
	

SELECT *
FROM SYS.DM_EXEC_QUERY_STATS
WHERE QUERY_PLAN_HASH IN (SELECT QUERY_PLAN_HASH
                            FROM SYS.QUERY_STORE_PLAN
						   WHERE QUERY_ID=53552)
						   
						   
						   
						   
						   



--#########################################################
--##### QUERY STORE를 이용해 인덱스를 사용하는 쿼리 SQL 찾기
--#########################################################  
SELECT 
    QSQ.QUERY_ID,
    QSQ.QUERY_TEXT_ID,
    QSQT.QUERY_SQL_TEXT,
    QSP.PLAN_ID,
    QSP.QUERY_PLAN
FROM
    SYS.QUERY_STORE_QUERY QSQ
JOIN
    SYS.QUERY_STORE_QUERY_TEXT QSQT ON QSQT.QUERY_TEXT_ID = QSQ.QUERY_TEXT_ID
JOIN
    SYS.QUERY_STORE_PLAN QSP ON QSQ.QUERY_ID = QSP.QUERY_ID
WHERE
    QSP.QUERY_PLAN LIKE '%IX_PN_MAIN_STYL_M_TUNE_01%';




--#########################################################
--##### Buffer Cache Hit Ratio
--#########################################################  
DECLARE @hitRatio INT, @hitRatioBase INT;

-- Query to get the values
SELECT 
    @hitRatio = MAX(CASE WHEN counter_name = 'Buffer cache hit ratio' THEN cntr_value END),
    @hitRatioBase = MAX(CASE WHEN counter_name = 'Buffer cache hit ratio base' THEN cntr_value END)
FROM 
    sys.dm_os_performance_counters
WHERE 
    object_name = 'SQLServer:Buffer Manager'
    AND counter_name IN ('Buffer cache hit ratio', 'Buffer cache hit ratio base');

-- Calculate the percentage
SELECT 
    CAST(@hitRatio AS FLOAT) / @hitRatioBase * 100 AS BufferCacheHitRatioPercentage;
	
	
	
--#########################################################
--##### Page Life Expectancy(PLE)
--#########################################################  

SELECT 
    object_name,
    counter_name,
    cntr_value AS PageLifeExpectancy_sec
FROM 
    sys.dm_os_performance_counters
WHERE 
    object_name = 'SQLServer:Buffer Manager'
    AND counter_name = 'Page life expectancy';
	



--#########################################################
--##### Catalog를 이용하여 테이블 건수(num_rows) 조회
--#########################################################  	
SELECT 
    T.NAME AS TABLENAME
	, SUM(P.ROWS) AS NUM_ROWS
FROM 
    SYS.TABLES T
JOIN 
    SYS.PARTITIONS P ON T.OBJECT_ID = P.OBJECT_ID
WHERE 
    P.INDEX_ID IN (0, 1) -- 0: HEAP, 1: CLUSTERED INDEX
GROUP BY 
    T.NAME
ORDER BY 
    NUM_ROWS DESC;
	
	


--#########################################################
--##### Catalog를 이용하여 테이블 건수(num_rows) 조회
--#########################################################
SELECT 
    T.NAME AS TABLE_NAME
	, SUM(P.ROWS) AS NUM_ROWS
FROM ERP.SYS.TABLES T
JOIN ERP.SYS.PARTITIONS P 
ON T.OBJECT_ID = P.OBJECT_ID
WHERE P.INDEX_ID IN (0, 1) -- 0: HEAP, 1: CLUSTERED INDEX
GROUP BY T.NAME


--#########################################################
--##### DA_EMERGENCY_LIST 정보 조회
--#########################################################
WITH ERP_TABLE_COMMENTS
AS
(SELECT DB_NAME() AS DB_NAME
     , O.NAME AS TABLE_NAME
     , CAST(p.value AS sql_variant) AS TABLE_COMMENTS
  FROM ERP.DBO.SYSOBJECTS O (NOLOCK)
  LEFT OUTER JOIN ERP.sys.extended_properties p 
    ON p.major_id=O.ID
   AND p.class=1
 WHERE 1=1
   AND P.minor_id=0
)
, ERP_TABLE_ROWS
AS
(SELECT 
    T.NAME AS TABLE_NAME
	, SUM(P.ROWS) AS NUM_ROWS
FROM ERP.SYS.TABLES T
JOIN ERP.SYS.PARTITIONS P 
ON T.OBJECT_ID = P.OBJECT_ID
WHERE P.INDEX_ID IN (0, 1) -- 0: HEAP, 1: CLUSTERED INDEX
GROUP BY T.NAME
)
,CRM_TABLE_COMMENTS
AS
(SELECT DB_NAME() AS DB_NAME
     , O.NAME AS TABLE_NAME
     , CAST(p.value AS sql_variant) AS TABLE_COMMENTS
  FROM CRM.DBO.SYSOBJECTS O (NOLOCK)
  LEFT OUTER JOIN CRM.sys.extended_properties p 
    ON p.major_id=O.ID
   AND p.class=1
 WHERE 1=1
   AND P.minor_id=0
)
, CRM_TABLE_ROWS
AS
(SELECT 
    T.NAME AS TABLE_NAME
	, SUM(P.ROWS) AS NUM_ROWS
FROM CRM.SYS.TABLES T
JOIN CRM.SYS.PARTITIONS P 
ON T.OBJECT_ID = P.OBJECT_ID
WHERE P.INDEX_ID IN (0, 1) -- 0: HEAP, 1: CLUSTERED INDEX
GROUP BY T.NAME
)
SELECT EMER_LIST.TABLE_NAME
     , ERP_COMM.TABLE_COMMENTS
	 , ERP_TROWS.NUM_ROWS
     , STRING_AGG(LEFT(CONVERT(VARCHAR(100),EMER_LIST.BACKUP_TIME),8), ', ') BACKUP_TIME
	 , COUNT(*) NUM_BACKUP
FROM DA_EMERGENCY_LIST EMER_LIST
LEFT JOIN ERP_TABLE_COMMENTS ERP_COMM
  ON EMER_LIST.TABLE_NAME = ERP_COMM.TABLE_NAME
LEFT JOIN ERP_TABLE_ROWS ERP_TROWS
  ON EMER_LIST.TABLE_NAME = ERP_TROWS.TABLE_NAME
WHERE EMER_LIST.TABLE_NAME NOT LIKE 'CR%'
AND EMER_LIST.TABLE_NAME NOT LIKE 'EB%'
AND EMER_LIST.TABLE_NAME NOT LIKE 'CS%'
GROUP BY EMER_LIST.TABLE_NAME, ERP_COMM.TABLE_COMMENTS, ERP_TROWS.NUM_ROWS
UNION ALL
SELECT EMER_LIST.TABLE_NAME
     , CRM_COMM.TABLE_COMMENTS
	 , CRM_TROWS.NUM_ROWS
     , STRING_AGG(LEFT(CONVERT(VARCHAR(100),EMER_LIST.BACKUP_TIME),8), ', ') BACKUP_TIME
	 , COUNT(*) NUM_BACKUP
FROM DA_EMERGENCY_LIST EMER_LIST
LEFT JOIN CRM_TABLE_COMMENTS CRM_COMM
  ON EMER_LIST.TABLE_NAME = CRM_COMM.TABLE_NAME
LEFT JOIN CRM_TABLE_ROWS CRM_TROWS
  ON EMER_LIST.TABLE_NAME = CRM_TROWS.TABLE_NAME
WHERE EMER_LIST.TABLE_NAME LIKE 'CR%'
OR EMER_LIST.TABLE_NAME LIKE 'EB%'
OR EMER_LIST.TABLE_NAME LIKE 'CS%'
GROUP BY EMER_LIST.TABLE_NAME, CRM_COMM.TABLE_COMMENTS, CRM_TROWS.NUM_ROWS
ORDER BY EMER_LIST.TABLE_NAME ;



--#########################################################
--##### 데드락 Dead Lock 조회
--#########################################################
SELECT 
    *
FROM sys.fn_xe_file_target_read_file(
    'system_health*.xel', 
    NULL, 
    NULL, 
    NULL
)
WHERE object_name = 'xml_deadlock_report'


SELECT CAST(event_data AS XML) AS DeadlockEventXML
FROM sys.fn_xe_file_target_read_file(
    N'system_health*.xel', 
    NULL, 
    NULL, 
    NULL
)
WHERE object_name = 'xml_deadlock_report'
ORDER BY timestamp_utc DESC;


-- 데드락 추적 플래그 활성화
DBCC TRACEON(1222, -1);

-- 확장 이벤트를 통한 모니터링
CREATE EVENT SESSION deadlock_monitor ON SERVER 
ADD EVENT sqlserver.xml_deadlock_report;





--#########################################################
--##### SNAPSHOT 스냅샷 만들기
--#########################################################
SP_HELPFILE로 데이터파일 모두 확인 후 아래내용 수정

--ERP(개발)
CREATE DATABASE ERP_SNAPSHOT_06251440
ON 
(
    NAME = ERP_DATA, 
    FILENAME = 'E:\ERPDB\BACKUP\SNAPSHOT\ERP_DATA.ss'
),
(
    NAME = ERP_DATA_01, 
    FILENAME = 'E:\ERPDB\BACKUP\SNAPSHOT\ERP_DATA_01.ss'
),
(
    NAME = ERP_DATA_02, 
    FILENAME = 'E:\ERPDB\BACKUP\SNAPSHOT\ERP_DATA_02.ss'
),
(
    NAME = ERP_DATA_03, 
    FILENAME = 'E:\ERPDB\BACKUP\SNAPSHOT\ERP_DATA_03.ss'
),
(
    NAME = ERP_DATA_SAN_01, 
    FILENAME = 'E:\ERPDB\BACKUP\SNAPSHOT\ERP_DATA_SAN_01.ss'
),
(
    NAME = ERP_IDX_01, 
    FILENAME = 'E:\ERPDB\BACKUP\SNAPSHOT\ERP_IDX_01.ss'
),
(
    NAME = ERP_IDX_02, 
    FILENAME = 'E:\ERPDB\BACKUP\SNAPSHOT\ERP_IDX_02.ss'
)
AS SNAPSHOT OF ERP;





--#########################################################
--##### SQL 실행 시간 계산 (seconde), 소요시간 계산, 소요 시간, 실행 시간
--#########################################################


DECLARE @STDT	DATETIME ;
DECLARE @EDDT	DATETIME ;

SET @STDT = GETDATE();

--SQL

SET @EDDT = GETDATE();
SELECT CONVERT(NUMERIC(6,3),DATEDIFF(ms,@STDT,@EDDT)/CONVERT(NUMERIC(8,3),1000)) ;





--#########################################################
--##### Lock Tree (gemini)
--#########################################################

WITH Blockers (SPID, Blocked, Level, Batch, WaitType, LastWaitType, SQLText, QueryPlan)
AS (
    -- Anchor Member: Find all session that are blocking others
    SELECT
        r.session_id AS SPID,
        r.blocking_session_id AS Blocked,
        CAST(REPLICATE('0', 4 - LEN(CAST(r.session_id AS VARCHAR))) + CAST(r.session_id AS VARCHAR) AS VARCHAR(1000)) AS Level,
        REPLACE(REPLACE(t.text, CHAR(10), ' '), CHAR(13), ' ') AS Batch,
        r.wait_type AS WaitType,
        r.last_wait_type AS LastWaitType,
        SUBSTRING(t.text, (r.statement_start_offset / 2) + 1,
                  ((CASE r.statement_end_offset
                      WHEN -1 THEN DATALENGTH(t.text)
                      ELSE r.statement_end_offset
                  END - r.statement_start_offset) / 2) + 1) AS SQLText,
        qp.query_plan
    FROM
        sys.dm_exec_requests r
    INNER JOIN
        sys.dm_exec_sessions s ON r.session_id = s.session_id
    OUTER APPLY
        sys.dm_exec_sql_text(r.sql_handle) AS t
    OUTER APPLY
        sys.dm_exec_query_plan(r.plan_handle) AS qp
    WHERE
        r.blocking_session_id = 0 -- Top-level blockers (they are not blocked by anyone)
        AND r.session_id IN (SELECT blocking_session_id FROM sys.dm_exec_requests WHERE blocking_session_id <> 0) -- But they ARE blocking someone

    UNION ALL

    -- Recursive Member: Find sessions blocked by the blockers
    SELECT
        r.session_id AS SPID,
        r.blocking_session_id AS Blocked,
        CAST(REPLICATE('0', 4 - LEN(CAST(r.session_id AS VARCHAR))) + CAST(r.session_id AS VARCHAR) AS VARCHAR(1000)) AS Level,
        REPLACE(REPLACE(t.text, CHAR(10), ' '), CHAR(13), ' ') AS Batch,
        r.wait_type AS WaitType,
        r.last_wait_type AS LastWaitType,
        SUBSTRING(t.text, (r.statement_start_offset / 2) + 1,
                  ((CASE r.statement_end_offset
                      WHEN -1 THEN DATALENGTH(t.text)
                      ELSE r.statement_end_offset
                  END - r.statement_start_offset) / 2) + 1) AS SQLText,
        qp.query_plan
    FROM
        sys.dm_exec_requests r
    INNER JOIN
        sys.dm_exec_sessions s ON r.session_id = s.session_id
    OUTER APPLY
        sys.dm_exec_sql_text(r.sql_handle) AS t
    OUTER APPLY
        sys.dm_exec_query_plan(r.plan_handle) AS qp
    INNER JOIN
        Blockers b ON r.blocking_session_id = b.SPID
)
SELECT
    SPID,
    Blocked,
    REPLICATE('|   ', LEN(Level)/4 - 1) + CASE WHEN LEN(Level)/4 - 1 = 0 THEN '' ELSE '|-- ' END + CAST(SPID AS VARCHAR) AS SessionTree,
    Batch,
    SQLText,
    WaitType,
    LastWaitType
FROM
    Blockers
ORDER BY
    Level;
	
	
--#########################################################
--##### tempdb 사용량
--#########################################################
use tempdb
Select cast((SUM (cast(user_object_reserved_page_count as bigint)) * 8.0  +
SUM (cast(internal_object_reserved_page_count as bigint)) * 8.0  +
SUM (cast(version_store_reserved_page_count as bigint)) * 8.0  +
SUM (CAST(mixed_extent_page_count as bigint)) * 8.0  +
SUM (cast(unallocated_extent_page_count as bigint)) * 8.0) / 1024 as numeric(10,2)) as totalspace_mb,
cast(SUM (cast(user_object_reserved_page_count as bigint)) * 8.0 / 1024 as numeric(10,2)) as user_objects_mb,
cast(SUM (cast(internal_object_reserved_page_count as bigint)) * 8.0 / 1024 as numeric(10,2)) as internal_objects_mb,
cast(SUM (cast(version_store_reserved_page_count as bigint)) * 8.0 / 1024 as numeric(10,2)) as version_store_mb,
cast(SUM (CAST(mixed_extent_page_count as bigint)) * 1.0 / 1024 as numeric(10,2)) as mixed_mb,
cast(SUM (cast(unallocated_extent_page_count as bigint)) * 8.0 / 1024 as numeric(10,2)) as freespace_mb
From sys.dm_db_file_space_usage with(nolock)
Where database_id = 2


--#########################################################
--##### tempdb 세션 구문별 사용량
--#########################################################
select    t1.session_id, 
                     t1.request_id, 
                     t1.task_alloc,
                    t1.task_dealloc,
                    SUBSTRING(qt.text,t2.statement_start_offset/2, 
                                (case when t2.statement_end_offset = -1 
                                then len(convert(nvarchar(max), qt.text)) * 2 
                                else t2.statement_end_offset end - t2.statement_start_offset)/2) 
                     as query_text,
                     qt.text as full_query_text
from     (
                                select session_id, request_id,
                                          sum(internal_objects_alloc_page_count) as task_alloc,
                                          sum (internal_objects_dealloc_page_count) as task_dealloc
                                from sys.dm_db_task_space_usage with(nolock)
                                group by session_id, request_id
                     ) as t1 
                     inner join sys.dm_exec_requests as t2
                                on t1.session_id = t2.session_id and t1.request_id = t2.request_id
        cross apply sys.dm_exec_sql_text(t2.sql_handle) as qt
order by t1.task_alloc DESC






--#########################################################
--##### QUERY STORE에서 PN_MAIN_STYL_M 조인하는 쿼리 찾기
--#########################################################

select COUNT(DISTINCT qsq.query_id)
--psq.query_id
--, qt.query_sql_text
FROM 
    sys.query_store_query AS qsq
JOIN 
    sys.query_store_query_text AS qt ON qsq.query_text_id = qt.query_text_id
JOIN 
    sys.query_store_plan AS qsp ON qsq.query_id = qsp.query_id
WHERE 
    qt.query_sql_text LIKE '$join%pn_main_styl_m%on%styl_cd%'
	or qt.query_sql_text LIKE '$join%pn_main_styl_m%and%styl_cd%'
	or qt.query_sql_text LIKE '%from%pn_main_styl_m%on%styl_cd%'
	or qt.query_sql_text LIKE '%from%pn_main_styl_m%and%styl_cd%';
	
	
	
	
--#########################################################
--##### PLM_STYL_CD가 PK에 포함되지 않은 테이블 목록 조회
--#########################################################	
WITH NON_PK_TBL
AS
(
SELECT TABLE_NAME
  FROM INFORMATION_SCHEMA.COLUMNS
 WHERE COLUMN_NAME = 'PLM_STYL_CD'
   AND TABLE_NAME NOT LIKE 'ZZ%' EXCEPT
SELECT DISTINCT TABLENAME
  FROM (
SELECT T.NAME AS TABLENAME
     , C.NAME AS COLUMNNAME
     , C.COLUMN_ID AS COLUMN_ID
  FROM SYS.INDEXES I
  JOIN SYS.INDEX_COLUMNS IC
    ON I.OBJECT_ID = IC.OBJECT_ID
   AND I.INDEX_ID = IC.INDEX_ID
  JOIN SYS.COLUMNS C
    ON IC.OBJECT_ID = C.OBJECT_ID
   AND IC.COLUMN_ID = C.COLUMN_ID
  JOIN SYS.TABLES T
    ON I.OBJECT_ID = T.OBJECT_ID
 WHERE I.IS_PRIMARY_KEY = 1) A
 WHERE COLUMNNAME='PLM_STYL_CD'
)
SELECT OBJECT_NAME(O.OBJECT_ID) AS TABLE_NAME
     , EP.VALUE AS TABLEDESCRIPTION
  FROM SYS.EXTENDED_PROPERTIES EP
  JOIN SYS.OBJECTS O
    ON EP.MAJOR_ID = O.OBJECT_ID
 WHERE EP.NAME = 'MS_DESCRIPTION'
   AND EP.MINOR_ID = 0
   AND O.NAME IN
  (
      SELECT TABLE_NAME
        FROM NON_PK_TBL
  )
  
  
--#########################################################
--##### LOCK CONFLICE, LOCK 충돌
--#########################################################	
--<< SESSION 1 >>
USE ERP
GO

DROP TABLE IF EXISTS TEST ;
CREATE TABLE TEST (COLA VARCHAR(100), COLB VARCHAR(100));
INSERT INTO TEST VALUES('111','AAA')
INSERT INTO TEST VALUES('222','AAA')
INSERT INTO TEST VALUES('333','AAA')

BEGIN TRAN
UPDATE TEST SET COLB='BBB' WHERE COLA='222';


--<< SESSION 2 >>
USE ERP
GO

BEGIN TRAN
UPDATE TEST SET COLB='B2B2B2' WHERE COLA='222';



--#########################################################
--##### 바인드 변수, BIND VARIABLE, PARAMETER, 파라미터 캡쳐, CAPTURE
--#########################################################	
USE ERP  --< 데이터베이스명
GO

CREATE EVENT SESSION [CaptureSQLParams] ON SERVER
ADD EVENT sqlserver.rpc_completed(
    ACTION(sqlserver.sql_text, sqlserver.client_hostname, sqlserver.username)
    WHERE (sqlserver.database_name = 'ERP')   --< 데이터베이스명
),
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.sql_text, sqlserver.client_hostname, sqlserver.username)
    WHERE (sqlserver.database_name = 'ERP')   --< 데이터베이스명
)
ADD TARGET package0.event_file(SET filename=N'E:\XE\CaptureSQLParams.xel')   --< 이벤트 파일, 에러가 발생하면 폴더가 만들어 져 있는지 화인
WITH (MAX_MEMORY=4096KB, EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS);
GO

ALTER EVENT SESSION [CaptureSQLParams] ON SERVER STATE = START;



SELECT 
    CAST(x.event_data AS XML).value('(event/@name)[1]', 'nvarchar(100)') AS event_name,
    CAST(x.event_data AS XML).value('(event/data[@name="statement"]/value)[1]', 'nvarchar(max)') AS sql_text,  --< 파라미터 확인할 수 있는 컬럼
    CAST(x.event_data AS XML).value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS captured_sql,
    CAST(x.event_data AS XML).value('(event/action[@name="username"]/value)[1]', 'nvarchar(100)') AS username,
    CAST(x.event_data AS XML).value('(event/action[@name="client_hostname"]/value)[1]', 'nvarchar(100)') AS client_host
FROM 
    sys.fn_xe_file_target_read_file(
        'E:\XE\CaptureSQLParams*.xel', NULL, NULL, NULL
    ) AS x;
	
	
DROP EVENT SESSION [CaptureSQLParams] ON SERVER ;





--#########################################################
--##### LOCK ESCALATION 확인
--#########################################################	
-- Lock Escalation 카운터 확인
SELECT 
    cntr_value as 'Lock Escalations/sec'
FROM sys.dm_os_performance_counters 
WHERE counter_name = 'Lock Escalations/sec'
AND object_name = 'SQLServer:Locks'


-- 현재 활성화된 Lock 정보(LOCK ESCALATION 확인용)
SELECT 
    tl.request_session_id,
    tl.resource_database_id,
    DB_NAME(tl.resource_database_id) as database_name,
    tl.resource_type,
    tl.resource_subtype,
    tl.request_mode,
    tl.request_status,
    wt.blocking_session_id,
    OBJECT_NAME(p.object_id) as table_name
FROM sys.dm_tran_locks tl
LEFT JOIN sys.dm_os_waiting_tasks wt 
    ON tl.lock_owner_address = wt.resource_address
LEFT JOIN sys.partitions p 
    ON p.hobt_id = tl.resource_associated_entity_id
WHERE tl.resource_type IN ('TABLE', 'PAGE', 'KEY', 'RID')
ORDER BY tl.request_session_id, tl.resource_type

