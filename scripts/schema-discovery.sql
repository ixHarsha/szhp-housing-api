/* =====================================================================
   SZHP schema discovery  --  READ ONLY
   ---------------------------------------------------------------------
   Reads catalog views only. It creates no objects, changes no data and
   takes no locks beyond ordinary reads. Safe to run on any environment,
   but prefer DEV/UAT.

   HOW TO RUN
     sqlcmd -S <server> -d MOEI -U <user> -P <password> -W -s "|" \
            -i schema-discovery.sql -o szhp-schema.txt
   or in SSMS/DBeaver: open it, make sure the active database is MOEI,
   switch results to text, execute, then save the output.

   The database is MOEI and the schema is dbo (per the DBeaver breadcrumb
   master > MOEI > dbo). Section 0 lists every candidate table so the core
   list below can be corrected if a name is wrong.

   Send back szhp-schema.txt.

   WHAT IT RETURNS
     Sections 1-7  structure only (table, column, key, index metadata).
     Section 8     DISTINCT values of low-cardinality CODE columns only
                   (status/type/category style), so dropdown vocabulary is
                   known. Name, ID, email, phone, address, date and amount
                   columns are explicitly excluded.
     Section 9     names of procedures/views touching these tables.

   Nothing here returns applicant data. Section 8 is the only part that
   reads table contents at all -- please skim it before sending.
   ===================================================================== */

SET NOCOUNT ON;

/* ---------------------------------------------------------------------
   Switch to the database that holds the tables. This is here on purpose:
   relying on the client's active-database dropdown put the last two runs
   on master, which has two same-named but empty tables.
   Change MOEI below only if the locator script reported another name.
   --------------------------------------------------------------------- */
USE [MOEI];

SELECT DB_NAME() AS running_against;   -- must say MOEI

/* ---------------------------------------------------------------------
   0. Inventory: every candidate table with its row count. Cheap, and it
      shows which names really exist so the core list can be corrected.
   --------------------------------------------------------------------- */
PRINT '===== 0. CANDIDATE TABLE INVENTORY =====';
SELECT  s.name + '.' + t.name AS table_name,
        SUM(CASE WHEN p.index_id IN (0,1) THEN p.rows ELSE 0 END) AS approx_rows
FROM    sys.tables t
JOIN    sys.schemas s ON s.schema_id = t.schema_id
JOIN    sys.partitions p ON p.object_id = t.object_id
WHERE   t.name LIKE 'MOEI_SZHP%'
   OR   t.name LIKE 'MOEI_APPLICANT%'
   OR   t.name LIKE 'MOEI_UDP%'
   OR   t.name LIKE 'COMMON_REQUEST%'
   OR   t.name LIKE '%ATTACHMENT%'
GROUP BY s.name, t.name
ORDER BY table_name;

PRINT '';

/* ---------------------------------------------------------------------
   Which tables to profile in full. Adjust this list if a name differs.
   The LIKE patterns catch anything related that I have not named.
   --------------------------------------------------------------------- */
IF OBJECT_ID('tempdb..#t') IS NOT NULL DROP TABLE #t;
CREATE TABLE #t (object_id INT PRIMARY KEY, schema_name SYSNAME, table_name SYSNAME);

INSERT INTO #t (object_id, schema_name, table_name)
SELECT t.object_id, s.name, t.name
FROM   sys.tables t
JOIN   sys.schemas s ON s.schema_id = t.schema_id
WHERE  t.name IN (
         /* the housing assistance request flow */
         'MOEI_SZHP_HOUSING_APPLICATIONS',
         'MOEI_APPLICANTS',
         'MOEI_APPLICANT_FAMILY',
         'MOEI_APPLICANT_EMPLOYER',
         'COMMON_REQUEST_HISTORY',
         'COMMON_REQUEST_HISTORY_USER_MAPPING',
         /* lookups and supporting records */
         'MOEI_SZHP_ASSISTANCE_TYPES',
         'MOEI_SZHP_REJECTION_REASONS',
         'MOEI_SZHP_EDB_ATTACHMENT_TRACKER',
         'MOEI_SZHP_CANCEL_APPLICATION',
         'MOEI_SZHP_QARAR_HOUSING_APPLICATIONS',
         'MOEI_SZHP_WORK_PROGRESS_DETAILS',
         'MOEI_SZHP_REQUEST_VERSIONS'
       );

PRINT '===== 1. TABLES =====';
SELECT schema_name AS [schema], table_name AS [table] FROM #t ORDER BY 1, 2;

PRINT '';
PRINT '===== 2. COLUMNS =====';
SELECT  t.table_name                      AS [table],
        c.column_id                       AS ord,
        c.name                            AS [column],
        ty.name                           AS data_type,
        CASE WHEN ty.name IN ('varchar','char','varbinary','binary')
                  THEN CONVERT(VARCHAR(12), CASE c.max_length WHEN -1 THEN -1 ELSE c.max_length END)
             WHEN ty.name IN ('nvarchar','nchar')
                  THEN CONVERT(VARCHAR(12), CASE c.max_length WHEN -1 THEN -1 ELSE c.max_length / 2 END)
             WHEN ty.name IN ('decimal','numeric')
                  THEN CONVERT(VARCHAR(12), c.precision) + ',' + CONVERT(VARCHAR(12), c.scale)
             ELSE '' END                  AS [length_or_precision],
        CASE c.is_nullable WHEN 1 THEN 'YES' ELSE 'NO' END  AS nullable,
        CASE c.is_identity WHEN 1 THEN 'YES' ELSE '' END    AS is_identity,
        CASE c.is_computed WHEN 1 THEN 'YES' ELSE '' END    AS is_computed,
        ISNULL(dc.definition, '')         AS default_definition
FROM    #t t
JOIN    sys.columns c     ON c.object_id = t.object_id
JOIN    sys.types   ty    ON ty.user_type_id = c.user_type_id
LEFT JOIN sys.default_constraints dc ON dc.object_id = c.default_object_id
ORDER BY t.table_name, c.column_id;

PRINT '';
PRINT '===== 3. PRIMARY KEYS AND UNIQUE CONSTRAINTS =====';
SELECT  t.table_name AS [table], kc.name AS constraint_name, kc.type_desc AS kind,
        ic.key_ordinal AS ord, c.name AS [column]
FROM    #t t
JOIN    sys.key_constraints kc ON kc.parent_object_id = t.object_id
JOIN    sys.index_columns ic ON ic.object_id = t.object_id AND ic.index_id = kc.unique_index_id
JOIN    sys.columns c ON c.object_id = t.object_id AND c.column_id = ic.column_id
ORDER BY t.table_name, kc.name, ic.key_ordinal;

PRINT '';
PRINT '===== 4. FOREIGN KEYS =====';
SELECT  ps.name + '.' + pt.name AS from_table, pc.name AS from_column,
        rs.name + '.' + rt.name AS to_table,   rc.name AS to_column,
        fk.name AS fk_name, fk.delete_referential_action_desc AS on_delete
FROM    sys.foreign_keys fk
JOIN    sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
JOIN    sys.tables pt   ON pt.object_id = fk.parent_object_id
JOIN    sys.schemas ps  ON ps.schema_id = pt.schema_id
JOIN    sys.columns pc  ON pc.object_id = fkc.parent_object_id AND pc.column_id = fkc.parent_column_id
JOIN    sys.tables rt   ON rt.object_id = fk.referenced_object_id
JOIN    sys.schemas rs  ON rs.schema_id = rt.schema_id
JOIN    sys.columns rc  ON rc.object_id = fkc.referenced_object_id AND rc.column_id = fkc.referenced_column_id
WHERE   fk.parent_object_id IN (SELECT object_id FROM #t)
   OR   fk.referenced_object_id IN (SELECT object_id FROM #t)
ORDER BY from_table, fk_name, from_column;

PRINT '';
PRINT '===== 5. CHECK CONSTRAINTS  (often encode the allowed status values) =====';
SELECT  t.table_name AS [table], cc.name AS constraint_name, cc.definition
FROM    #t t
JOIN    sys.check_constraints cc ON cc.parent_object_id = t.object_id
ORDER BY t.table_name, cc.name;

PRINT '';
PRINT '===== 6. INDEXES =====';
SELECT  t.table_name AS [table], i.name AS index_name, i.type_desc AS kind,
        CASE i.is_unique WHEN 1 THEN 'UNIQUE' ELSE '' END AS uniqueness,
        ic.key_ordinal AS ord, c.name AS [column],
        CASE ic.is_included_column WHEN 1 THEN 'INCLUDED' ELSE 'KEY' END AS part
FROM    #t t
JOIN    sys.indexes i ON i.object_id = t.object_id AND i.type > 0
JOIN    sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN    sys.columns c ON c.object_id = t.object_id AND c.column_id = ic.column_id
WHERE   i.is_primary_key = 0
ORDER BY t.table_name, i.name, ic.is_included_column, ic.key_ordinal;

PRINT '';
PRINT '===== 7. ROW COUNTS =====';
SELECT  t.table_name AS [table], SUM(p.rows) AS approx_rows
FROM    #t t
JOIN    sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY t.table_name
ORDER BY t.table_name;

/* ---------------------------------------------------------------------
   8. Distinct values of CODE columns only.

   Included only when the column is textual, its name looks like a code
   (status/type/category/...), it is not on the personal-data deny list,
   and it holds 100 or fewer distinct values.
   --------------------------------------------------------------------- */
PRINT '';
PRINT '===== 8. DISTINCT CODE VALUES =====';

IF OBJECT_ID('tempdb..#c') IS NOT NULL DROP TABLE #c;
CREATE TABLE #c (id INT IDENTITY(1,1) PRIMARY KEY, schema_name SYSNAME, table_name SYSNAME, column_name SYSNAME);

INSERT INTO #c (schema_name, table_name, column_name)
SELECT t.schema_name, t.table_name, c.name
FROM   #t t
JOIN   sys.columns c  ON c.object_id = t.object_id
JOIN   sys.types   ty ON ty.user_type_id = c.user_type_id
WHERE  ty.name IN ('varchar','nvarchar','char','nchar')
  AND  c.is_computed = 0
  AND (c.name LIKE '%STATUS%'   OR c.name LIKE '%TYPE%'     OR c.name LIKE '%CATEGORY%'
    OR c.name LIKE '%PURPOSE%'  OR c.name LIKE '%REASON%'   OR c.name LIKE '%OWNERSHIP%'
    OR c.name LIKE '%SECTOR%'   OR c.name LIKE '%REGION%'   OR c.name LIKE '%EMIRATE%'
    OR c.name LIKE '%RELATION%' OR c.name LIKE '%CONSITION%' OR c.name LIKE '%CONDITION%'
    OR c.name LIKE '%SOURCE%'   OR c.name LIKE '%ACTION%'   OR c.name LIKE '%TASK_NAME%'
    OR c.name LIKE '%GENDER%'   OR c.name LIKE '%QUALIFICATION%')
  /* never read personal data */
  AND  c.name NOT LIKE '%NAME_AR%'  AND c.name NOT LIKE '%NAME_EN%'
  AND  c.name NOT LIKE '%FULLNAME%' AND c.name NOT LIKE '%APPLICANT_NAME%'
  AND  c.name NOT LIKE '%EMAIL%'    AND c.name NOT LIKE '%MOBILE%'
  AND  c.name NOT LIKE '%PHONE%'    AND c.name NOT LIKE '%ADDRESS%'
  AND  c.name NOT LIKE '%EMIRATES_ID%' AND c.name NOT LIKE '%PASSPORT%'
  AND  c.name NOT LIKE '%IBAN%'     AND c.name NOT LIKE '%ACCOUNT%'
  AND  c.name NOT LIKE '%EMPLOYER_NAME%' AND c.name NOT LIKE '%LOCATION%';

DECLARE @i INT = 1, @n INT = (SELECT ISNULL(MAX(id), 0) FROM #c);
DECLARE @sch SYSNAME, @tab SYSNAME, @col SYSNAME, @sql NVARCHAR(MAX);

WHILE @i <= @n
BEGIN
    SELECT @sch = schema_name, @tab = table_name, @col = column_name FROM #c WHERE id = @i;

    SET @sql = N'
      IF (SELECT COUNT(*) FROM (SELECT DISTINCT ' + QUOTENAME(@col) + N' AS v
                                FROM ' + QUOTENAME(@sch) + N'.' + QUOTENAME(@tab) + N'
                                WHERE ' + QUOTENAME(@col) + N' IS NOT NULL) x) BETWEEN 1 AND 100
      SELECT TOP (100)
             ''' + REPLACE(@tab, '''', '''''') + N''' AS [table],
             ''' + REPLACE(@col, '''', '''''') + N''' AS [column],
             CONVERT(NVARCHAR(200), ' + QUOTENAME(@col) + N') AS value,
             COUNT(*) AS occurrences
      FROM   ' + QUOTENAME(@sch) + N'.' + QUOTENAME(@tab) + N'
      WHERE  ' + QUOTENAME(@col) + N' IS NOT NULL
      GROUP BY CONVERT(NVARCHAR(200), ' + QUOTENAME(@col) + N')
      ORDER BY occurrences DESC;';

    BEGIN TRY
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        PRINT 'skipped ' + @tab + '.' + @col + ' -- ' + ERROR_MESSAGE();
    END CATCH

    SET @i = @i + 1;
END

PRINT '';
PRINT '===== 9. PROCEDURES AND VIEWS REFERENCING THESE TABLES (names only) =====';
SELECT DISTINCT o.type_desc AS kind, s.name + '.' + o.name AS object_name
FROM   sys.sql_expression_dependencies d
JOIN   sys.objects o ON o.object_id = d.referencing_id
JOIN   sys.schemas s ON s.schema_id = o.schema_id
WHERE  d.referenced_id IN (SELECT object_id FROM #t)
  AND  o.type IN ('P','V','FN','TF','IF')
ORDER BY kind, object_name;

DROP TABLE #c;
DROP TABLE #t;
PRINT '';
PRINT '===== END =====';
