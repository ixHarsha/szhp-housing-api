/* =====================================================================
   SZHP housing assistance - request attachments (Microsoft SQL Server)

   Supporting documents the applicant uploads with a request: Emirates ID,
   family book, salary certificate and so on.

   READ THIS BEFORE TRUSTING THE LAYOUT
   ------------------------------------
   Unlike 01_tables.sql, this table is NOT taken from the live MOEI.dbo
   schema - it is NEW, added for the demo. Its columns follow the
   IAttachment interface in SZHP-micro-ui (fileName, fileType, fileSize,
   attachmentTypeId, category, source, status, requestId, applicantId) so
   the JSON shape matches what the portal already uses.

   The file itself is stored inline as base64 in FILE_CONTENT. That is a
   deliberate demo-only choice; before going live, map this onto the real
   attachment table / document store and drop FILE_CONTENT.

   It creates one table and four procedures, and touches no existing table.
   Every statement is existence-guarded, so re-running it is harmless.
   ===================================================================== */

/* ---------------------------------------------------------------------
   This script does NOT switch database. It runs against whatever database
   the connection is already on, so choose it deliberately:

     sqlcmd ... -d SZHP_DEMO -i <this file>

   The check below refuses master/tempdb/model/msdb.
   --------------------------------------------------------------------- */

SELECT DB_NAME() AS creating_objects_in;

/* RAISERROR takes a variable, not a function call, as a %s argument. */
DECLARE @db SYSNAME = DB_NAME();
IF @db IN ('master', 'tempdb', 'model', 'msdb')
BEGIN
    RAISERROR ('Refusing to run against a system database (%s). Select the target database first.', 16, 1, @db);
    SET NOEXEC ON;
END
GO

/* ---------------------------------------------------------------- table */

IF OBJECT_ID('dbo.MOEI_SZHP_ATTACHMENTS', 'U') IS NULL
CREATE TABLE dbo.MOEI_SZHP_ATTACHMENTS (                 -- NEW (demo)
    ID                 NVARCHAR(50)   NOT NULL,          -- e.g. ATT_1a2b3c4d5e6f, assigned by the app
    REQUEST_ID         NVARCHAR(50)   NOT NULL,          -- -> MOEI_SZHP_HOUSING_APPLICATIONS.APPLICATION_ID
    APPLICANT_ID       NVARCHAR(50)   NULL,              -- -> MOEI_APPLICANTS.USER_ID
    ATTACHMENT_TYPE_ID NVARCHAR(50)   NOT NULL,          -- EMIRATES_ID | FAMILY_BOOK | SALARY_CERTIFICATE | ...
    CATEGORY           NVARCHAR(60)   NULL,              -- SZHP
    FILE_NAME          NVARCHAR(260)  NOT NULL,
    FILE_TYPE          NVARCHAR(100)  NULL,              -- MIME type, e.g. application/pdf
    FILE_SIZE          BIGINT         NULL,              -- bytes, before base64 encoding
    FILE_CONTENT       VARCHAR(MAX)   NOT NULL,          -- base64; demo storage only
    SOURCE             NVARCHAR(60)   NULL,              -- Website | InternalPortal
    STATUS             NVARCHAR(30)   NULL,              -- UPLOADED
    IS_ACTIVE          BIT            NOT NULL CONSTRAINT DF_MOEI_SZHP_ATTACHMENTS_ACTIVE DEFAULT (1),
    CREATED_BY         NVARCHAR(100)  NULL,
    CREATED_DATE       DATETIME       NULL,
    LAST_UPDATED_DATE  DATETIME       NULL,
    CONSTRAINT PK_MOEI_SZHP_ATTACHMENTS PRIMARY KEY (ID)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MOEI_SZHP_ATTACHMENTS_REQUEST')
CREATE INDEX IX_MOEI_SZHP_ATTACHMENTS_REQUEST
    ON dbo.MOEI_SZHP_ATTACHMENTS (REQUEST_ID, IS_ACTIVE)
    INCLUDE (ATTACHMENT_TYPE_ID, FILE_NAME, FILE_TYPE, FILE_SIZE, CREATED_DATE);
GO

/* ---------------------------------------------------------------- list */

/* Metadata only: FILE_CONTENT is left out so listing a request never drags
   every document across the wire. */
IF OBJECT_ID('dbo.usp_SZHP_Attachment_List', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SZHP_Attachment_List;
GO
CREATE PROCEDURE dbo.usp_SZHP_Attachment_List
    @RequestId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  ID, REQUEST_ID, APPLICANT_ID, ATTACHMENT_TYPE_ID, CATEGORY,
            FILE_NAME, FILE_TYPE, FILE_SIZE, SOURCE, STATUS,
            CREATED_DATE, LAST_UPDATED_DATE
    FROM    dbo.MOEI_SZHP_ATTACHMENTS
    WHERE   REQUEST_ID = @RequestId
      AND   IS_ACTIVE = 1
    ORDER BY CREATED_DATE, ID;
END
GO

/* ----------------------------------------------------------------- get */

IF OBJECT_ID('dbo.usp_SZHP_Attachment_Get', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SZHP_Attachment_Get;
GO
CREATE PROCEDURE dbo.usp_SZHP_Attachment_Get
    @RequestId    NVARCHAR(50),
    @AttachmentId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  ID, REQUEST_ID, APPLICANT_ID, ATTACHMENT_TYPE_ID, CATEGORY,
            FILE_NAME, FILE_TYPE, FILE_SIZE, SOURCE, STATUS,
            CREATED_DATE, LAST_UPDATED_DATE, FILE_CONTENT
    FROM    dbo.MOEI_SZHP_ATTACHMENTS
    WHERE   REQUEST_ID = @RequestId
      AND   ID = @AttachmentId
      AND   IS_ACTIVE = 1;
END
GO

/* -------------------------------------------------------------- insert */

IF OBJECT_ID('dbo.usp_SZHP_Attachment_Insert', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SZHP_Attachment_Insert;
GO
CREATE PROCEDURE dbo.usp_SZHP_Attachment_Insert
    @AttachmentId     NVARCHAR(50),
    @RequestId        NVARCHAR(50),
    @ApplicantId      NVARCHAR(50)  = NULL,
    @AttachmentTypeId NVARCHAR(50),
    @Category         NVARCHAR(60)  = N'SZHP',
    @FileName         NVARCHAR(260),
    @FileType         NVARCHAR(100) = NULL,
    @FileSize         BIGINT        = NULL,
    @FileContent      VARCHAR(MAX),
    @Source           NVARCHAR(60)  = N'Website',
    @CreatedBy        NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.MOEI_SZHP_ATTACHMENTS
        (ID, REQUEST_ID, APPLICANT_ID, ATTACHMENT_TYPE_ID, CATEGORY,
         FILE_NAME, FILE_TYPE, FILE_SIZE, FILE_CONTENT, SOURCE, STATUS,
         IS_ACTIVE, CREATED_BY, CREATED_DATE, LAST_UPDATED_DATE)
    VALUES
        (@AttachmentId, @RequestId, @ApplicantId, @AttachmentTypeId, @Category,
         @FileName, @FileType, @FileSize, @FileContent, @Source, N'UPLOADED',
         1, @CreatedBy, GETDATE(), GETDATE());
END
GO

/* -------------------------------------------------------------- delete */

/* Soft delete: the row stays for audit, it just stops being listed. */
IF OBJECT_ID('dbo.usp_SZHP_Attachment_Delete', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SZHP_Attachment_Delete;
GO
CREATE PROCEDURE dbo.usp_SZHP_Attachment_Delete
    @RequestId    NVARCHAR(50),
    @AttachmentId NVARCHAR(50),
    @Deleted      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.MOEI_SZHP_ATTACHMENTS
       SET IS_ACTIVE         = 0,
           STATUS            = N'DELETED',
           LAST_UPDATED_DATE = GETDATE()
     WHERE REQUEST_ID = @RequestId
       AND ID = @AttachmentId
       AND IS_ACTIVE = 1;

    SET @Deleted = @@ROWCOUNT;
END
GO

SET NOEXEC OFF;
GO
