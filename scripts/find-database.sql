/* =====================================================================
   Which database holds the SZHP tables?   READ ONLY, catalog views only.
   Run it from any connection; it inspects every database you can access.

     sqlcmd -S <server> -U <user> -P <password> -W -s "|" \
            -i find-database.sql -o where.txt
   =====================================================================*/
SET NOCOUNT ON;

SELECT DB_NAME() AS connected_to, SUSER_SNAME() AS login_name;

PRINT '';
PRINT '===== DATABASES VISIBLE TO THIS LOGIN =====';
SELECT name AS database_name, state_desc
FROM   sys.databases
WHERE  HAS_DBACCESS(name) = 1
ORDER BY name;

PRINT '';
PRINT '===== WHERE THE SZHP TABLES LIVE =====';
DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql = @sql + N'
SELECT ' + QUOTENAME(name, '''') + N' AS database_name,
       s.name AS [schema], t.name AS [table],
       (SELECT SUM(p.rows) FROM ' + QUOTENAME(name) + N'.sys.partitions p
         WHERE p.object_id = t.object_id AND p.index_id IN (0,1)) AS approx_rows
FROM   ' + QUOTENAME(name) + N'.sys.tables t
JOIN   ' + QUOTENAME(name) + N'.sys.schemas s ON s.schema_id = t.schema_id
WHERE  t.name LIKE ''MOEI_SZHP%''
   OR  t.name LIKE ''MOEI_APPLICANT%''
   OR  t.name LIKE ''MOEI_UDP%''
   OR  t.name LIKE ''COMMON_REQUEST%'';'
FROM   sys.databases
WHERE  HAS_DBACCESS(name) = 1
  AND  state = 0
  AND  name NOT IN ('tempdb','model');

EXEC sp_executesql @sql;
