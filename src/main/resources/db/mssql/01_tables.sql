/* =====================================================================
   SZHP housing assistance - table definitions (Microsoft SQL Server)

   These mirror the live tables in MOEI.dbo. On the real database the
   tables already exist and this script does nothing: every statement is
   guarded by an existence check, so it is safe to run there.

   Run it only to stand up an equivalent database elsewhere.

   READ THIS BEFORE TRUSTING THE LAYOUT
   ------------------------------------
   The column names are taken verbatim from the webMethods adapter
   MOEISZHPMgmt/adapters/housingApplications/getHousingApplicationById,
   whose output is a JOIN across the application, applicant and employer
   tables. Which column sits on which table is therefore INFERRED, and
   every inference is marked  -- INFERRED  below. Types and lengths are
   inferred too, except on COMMON_REQUEST_HISTORY, which was read from
   the live catalog and is exact.

   Existing spellings are preserved on purpose, typos included
   (TECHNICAL_CONSITION, DESCISION_BATCH_NO, NO_OF_COUNCILS): renaming
   them would break the service contract.
   ===================================================================== */

USE [MOEI];
GO

/* ----------------------------------------------------------- applicant */

IF OBJECT_ID('dbo.MOEI_APPLICANTS', 'U') IS NULL
CREATE TABLE dbo.MOEI_APPLICANTS (
    USER_ID              NVARCHAR(50)   NOT NULL,   -- e.g. MMOEI_19853045999
    UUID                 NVARCHAR(50)   NULL,       -- INFERRED
    EMIRATES_ID          NVARCHAR(30)   NULL,
    FULLNAME_EN          NVARCHAR(200)  NULL,
    FULLNAME_AR          NVARCHAR(200)  NULL,
    EMAIL_ID             NVARCHAR(150)  NULL,
    MOBILE_NO            NVARCHAR(25)   NULL,
    MOBILE_NO2           NVARCHAR(25)   NULL,       -- INFERRED
    ADDRESS              NVARCHAR(300)  NULL,       -- INFERRED
    POBOX_NO             NVARCHAR(30)   NULL,       -- INFERRED
    GENDER               NVARCHAR(20)   NULL,       -- INFERRED
    QUALIFICATION        NVARCHAR(100)  NULL,       -- INFERRED
    MARITAL_STATUS       NVARCHAR(30)   NULL,       -- INFERRED
    DATE_OF_BIRTH        DATE           NULL,       -- INFERRED
    FAMILY_NO            NVARCHAR(50)   NULL,
    TOWN_NO              NVARCHAR(50)   NULL,
    APPLICANT_EMIRATE_ID NVARCHAR(10)   NULL,
    REGION_EN            NVARCHAR(100)  NULL,
    REGION_AR            NVARCHAR(100)  NULL,
    NO_OF_DEPENDENT      INT            NULL,       -- INFERRED
    IS_ACTIVE            BIT            NULL,
    CREATED_DATE         DATETIME       NULL,
    CONSTRAINT PK_MOEI_APPLICANTS PRIMARY KEY (USER_ID)
);
GO

IF OBJECT_ID('dbo.MOEI_APPLICANT_FAMILY', 'U') IS NULL
CREATE TABLE dbo.MOEI_APPLICANT_FAMILY (
    ID             NVARCHAR(50)  NOT NULL,
    APPLICANT      NVARCHAR(50)  NOT NULL,   -- -> MOEI_APPLICANTS.USER_ID
    FULLNAME_EN    NVARCHAR(200) NULL,       -- INFERRED
    FULLNAME_AR    NVARCHAR(200) NULL,       -- INFERRED
    RELATIONSHIP   NVARCHAR(40)  NULL,       -- WIFE | SON | DAUGHTER | ...
    MARITAL_STATUS NVARCHAR(30)  NULL,
    AGE            INT           NULL,
    DATE_OF_BIRTH  DATE          NULL,       -- INFERRED
    GENDER         NVARCHAR(20)  NULL,       -- INFERRED
    EMIRATES_ID    NVARCHAR(30)  NULL,       -- INFERRED
    SPECIAL_NEEDS  NVARCHAR(10)  NULL,       -- INFERRED
    IS_ACTIVE      BIT           NULL,       -- INFERRED
    CONSTRAINT PK_MOEI_APPLICANT_FAMILY PRIMARY KEY (ID)
);
GO

/* RELATIONSHIP, MARITAL_STATUS and AGE are confirmed: the eligibility
   query in the flow services reads exactly these three. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MOEI_APPLICANT_FAMILY_APPLICANT')
CREATE INDEX IX_MOEI_APPLICANT_FAMILY_APPLICANT ON dbo.MOEI_APPLICANT_FAMILY (APPLICANT);
GO

IF OBJECT_ID('dbo.MOEI_APPLICANT_EMPLOYER', 'U') IS NULL
CREATE TABLE dbo.MOEI_APPLICANT_EMPLOYER (
    EMP_ID        NVARCHAR(50)   NOT NULL,
    EMP_APPLICANT NVARCHAR(50)   NOT NULL,  -- -> MOEI_APPLICANTS.USER_ID
    EMPLOYER_NAME NVARCHAR(200)  NULL,
    DESIGNATION   NVARCHAR(150)  NULL,
    SECTOR        NVARCHAR(100)  NULL,
    WORK_CATEGORY NVARCHAR(100)  NULL,
    ANNUAL_INCOME DECIMAL(18, 2) NULL,
    START_DATE    DATE           NULL,
    END_DATE      DATE           NULL,
    IS_ACTIVE     BIT            NULL,
    EMP_CREATED_DATE DATETIME    NULL,
    CONSTRAINT PK_MOEI_APPLICANT_EMPLOYER PRIMARY KEY (EMP_ID)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MOEI_APPLICANT_EMPLOYER_APPLICANT')
CREATE INDEX IX_MOEI_APPLICANT_EMPLOYER_APPLICANT ON dbo.MOEI_APPLICANT_EMPLOYER (EMP_APPLICANT);
GO

/* -------------------------------------------- housing application (main) */

IF OBJECT_ID('dbo.MOEI_SZHP_HOUSING_APPLICATIONS', 'U') IS NULL
CREATE TABLE dbo.MOEI_SZHP_HOUSING_APPLICATIONS (
    APPLICATION_ID             NVARCHAR(50)   NOT NULL,  -- e.g. MSZHP_100005, assigned by the app
    APPLICATION_NO             NVARCHAR(50)   NULL,      -- e.g. 65349
    REFERENCE_NO               NVARCHAR(50)   NULL,
    APPLICANT                  NVARCHAR(50)   NOT NULL,  -- -> MOEI_APPLICANTS.USER_ID
    REQUEST_TYPE               NVARCHAR(40)   NULL,      -- always 'SZHP' in the live data
    STATUS                     NVARCHAR(60)   NULL,
    SOURCE                     NVARCHAR(60)   NULL,      -- InternalPortal | Website | ...

    /* assistance */
    AID_TYPE                   NVARCHAR(40)   NULL,      -- LOAN | GRANT
    ASSISTANCE_TYPE            NVARCHAR(40)   NULL,      -- HA | FA
    ASSISTANCE_PURPOSE         NVARCHAR(60)   NULL,      -- CONSTRUCT | PURCHASE | MAINTENANCE
    ASSISTANCE_PURPOSE_CATEGORY NVARCHAR(60)  NULL,

    /* social status */
    MARITAL_STATUS             NVARCHAR(30)   NULL,      -- MARRIED | WIDOWED | DIVORCED | ABSOLUTE | SINGLE
    MARITAL_CATEGORY           NVARCHAR(60)   NULL,
    NO_OF_WIVES                INT            NULL,
    NO_OF_CHILDREN             INT            NULL,
    MARRIAGE_DATE              DATE           NULL,
    DIVORCE_DATE               DATE           NULL,
    SPOUSE_DEATH_DATE          DATE           NULL,
    FATHER_DEATH_DATE          DATE           NULL,
    MOTHER_DEATH_DATE          DATE           NULL,
    FAMILY_BOOK_EMIRATE        NVARCHAR(10)   NULL,      -- numeric emirate code 1-7
    REGION                     NVARCHAR(100)  NULL,
    EMIRATE                    NVARCHAR(10)   NULL,      -- INFERRED

    /* current housing */
    HOUSING_OWNERSHIP          NVARCHAR(40)   NULL,      -- WITH_RELATIVES | WITH_RENT | ...
    LOCATION                   NVARCHAR(300)  NULL,
    LEASE_RENTAL_DATE          DATE           NULL,
    YEARS_OF_STAYING           INT            NULL,
    LAND_FOR_CONSTRUCTION      NVARCHAR(20)   NULL,
    TECHNICAL_CONSITION        NVARCHAR(40)   NULL,      -- existing spelling
    DWELLING_YOC               NVARCHAR(10)   NULL,
    CONSTRUCTION_AREA_SQ_FEET  DECIMAL(18, 2) NULL,
    NO_OF_OCCUPANTS            INT            NULL,
    NO_OF_ROOMS                INT            NULL,
    NO_OF_COUNCILS             INT            NULL,      -- majlis; existing spelling
    NO_OF_BATHROOMS            INT            NULL,
    NO_OF_KITCHENS             INT            NULL,
    NO_OF_BED_ROOMS            INT            NULL,
    RECEIVED_HOUSING_AID       NVARCHAR(10)   NULL,
    NO_PREV_HOUSING_ASST       NVARCHAR(10)   NULL,
    LATITUDE                   NVARCHAR(50)   NULL,
    LONGITUDE                  NVARCHAR(50)   NULL,
    POD                        NVARCHAR(50)   NULL,

    /* award / decision */
    AWARDED_AID_AMOUNT         DECIMAL(18, 2) NULL,
    AWARDED_AID_TYPE           NVARCHAR(40)   NULL,      -- LOAN | GRANT | HF
    AWARDED_ASSISTANCE_TYPE    NVARCHAR(40)   NULL,      -- HA | FA
    AWARDED_ASSISTANCE_PURPOSE NVARCHAR(60)   NULL,
    AWARDED_PURPOSE_CATEGORY   NVARCHAR(60)   NULL,
    AWARDED_NO_OF_BED_ROOMS    INT            NULL,
    AWARDED_MESSAGE            NVARCHAR(1000) NULL,
    DECISION_DATE              DATETIME       NULL,
    DESCISION_BATCH_NO         NVARCHAR(50)   NULL,      -- existing spelling
    APPROVAL_DATE              DATETIME       NULL,
    REJECTION_REASON           NVARCHAR(500)  NULL,
    RETURN_REASON              NVARCHAR(500)  NULL,

    /* workflow and cross-references */
    PROCESS_INSTANCE_ID        NVARCHAR(100)  NULL,
    TECHNICAL_RESEARCHERID     NVARCHAR(50)   NULL,
    SOCIAL_RESEARCHERID        NVARCHAR(50)   NULL,
    TECH_VISIT_STATUS          NVARCHAR(60)   NULL,
    SOCIAL_VISIT_STATUS        NVARCHAR(60)   NULL,
    HOUSING_REQ_STDY_TEAM_ID   NVARCHAR(50)   NULL,
    EMERGENCY_VISIT_REQ_ID     NVARCHAR(50)   NULL,
    RECONSIDER_REQ_ID          NVARCHAR(50)   NULL,
    INITIATIVE_SYSTEM_ID       NVARCHAR(50)   NULL,
    EXTERNAL_QARAR             NVARCHAR(50)   NULL,
    EXT_QARAR_ISSUED_DATE      DATETIME       NULL,
    QARAR_HOUSING_STATUS       NVARCHAR(60)   NULL,
    FAST_FORWARD               NVARCHAR(10)   NULL,
    FF_COMMENTS                NVARCHAR(1000) NULL,
    AGREEMENT_ID               NVARCHAR(50)   NULL,
    BANK_ID                    NVARCHAR(50)   NULL,
    FILE_NO                    NVARCHAR(50)   NULL,
    FILE_TYPE                  NVARCHAR(20)   NULL,

    /* audit */
    CREATED_BY                 NVARCHAR(100)  NULL,
    CREATED_DATE               DATETIME       NULL,
    UPDATED_DATE               DATETIME       NULL,
    UPDATED_BY_APPLICANT       NVARCHAR(100)  NULL,

    CONSTRAINT PK_MOEI_SZHP_HOUSING_APPLICATIONS PRIMARY KEY (APPLICATION_ID)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SZHP_HOUSING_APPL_APPLICANT')
CREATE INDEX IX_SZHP_HOUSING_APPL_APPLICANT ON dbo.MOEI_SZHP_HOUSING_APPLICATIONS (APPLICANT);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SZHP_HOUSING_APPL_STATUS')
CREATE INDEX IX_SZHP_HOUSING_APPL_STATUS ON dbo.MOEI_SZHP_HOUSING_APPLICATIONS (STATUS, CREATED_DATE DESC);
GO

/* ------------------------------------------------- request history (exact) */

/* Read from the live catalog, so this one is not inferred. */
IF OBJECT_ID('dbo.COMMON_REQUEST_HISTORY', 'U') IS NULL
CREATE TABLE dbo.COMMON_REQUEST_HISTORY (
    REQUEST_ID       NVARCHAR(50)   NOT NULL,
    TASK_ID          NVARCHAR(50)   NULL,
    TASK_NAME        NVARCHAR(200)  NULL,
    PROCESS_TYPE     NVARCHAR(50)   NULL,
    TASK_ACTION      NVARCHAR(50)   NOT NULL,
    STATUS           NVARCHAR(50)   NULL,
    COMMENTS         NVARCHAR(1000) NULL,
    CREATED_DATE     DATETIME       NULL,
    ID               NVARCHAR(50)   NOT NULL,
    IS_ACTIVE        BIT            NULL,
    ACTED_BY         NVARCHAR(200)  NULL,
    ACCEPTED_BY      NVARCHAR(100)  NULL,
    PROCESS_MODEL_ID NVARCHAR(200)  NULL,
    INTERFACE_ID     VARCHAR(100)   NULL,
    PARENT_REQ_ID    NVARCHAR(100)  NULL,
    PROCESS_STATUS   NVARCHAR(100)  NULL,
    REQUEST_STATUS   NVARCHAR(100)  NULL,
    COMPLETION_DATE  DATETIME       NULL,
    CONSTRAINT LD_COMMON_REQUEST_HISTORY_PK PRIMARY KEY (ID)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_COMMON_REQUEST_HISTORY_REQUEST')
CREATE INDEX IX_COMMON_REQUEST_HISTORY_REQUEST ON dbo.COMMON_REQUEST_HISTORY (REQUEST_ID, CREATED_DATE);
GO
