/* =====================================================================
   SZHP housing assistance - sample data for a DEMO database.

   ! DO NOT RUN THIS AGAINST A REAL ENVIRONMENT !

   It INSERTs applicants and applications. MOEI holds live records, so
   running it there would add fabricated rows to production data. It is
   meant only for a throwaway copy used to demonstrate the form.

   The guard below refuses to run unless the database name ends in _DEMO.
   Remove it only if you know exactly where you are connected.
   ===================================================================== */

SET NOCOUNT ON;

/* RAISERROR takes a variable, not a function call, as a %s argument. */
DECLARE @db SYSNAME = DB_NAME();
IF @db NOT LIKE '%[_]DEMO'
BEGIN
    RAISERROR ('Refusing to seed: the current database (%s) is not a _DEMO database. See the header.', 16, 1, @db);
    SET NOEXEC ON;
END
GO

/* Codes below are the ones that really occur in MOEI.dbo, so the demo shows
   the same vocabulary the portal does:
     ASSISTANCE_TYPE     HA | FA
     ASSISTANCE_PURPOSE  CONSTRUCT | PURCHASE | MAINTENANCE
     AWARDED_AID_TYPE    LOAN | GRANT | HF
     HOUSING_OWNERSHIP   WITH_RELATIVES | WITH_RENT | OWNS_DWELLING | ...
     FAMILY_BOOK_EMIRATE numeric emirate code 1-7
     STATUS              DRAFT | SUBMITTED | UNDERREVIEW | APPROVED | ... */

DELETE FROM dbo.COMMON_REQUEST_HISTORY        WHERE REQUEST_ID LIKE 'MSZHP_DEMO%';
DELETE FROM dbo.MOEI_SZHP_HOUSING_APPLICATIONS WHERE APPLICATION_ID LIKE 'MSZHP_DEMO%';
DELETE FROM dbo.MOEI_APPLICANT_FAMILY          WHERE APPLICANT LIKE 'MMOEI_DEMO%';
DELETE FROM dbo.MOEI_APPLICANT_EMPLOYER        WHERE EMP_APPLICANT LIKE 'MMOEI_DEMO%';
DELETE FROM dbo.MOEI_APPLICANTS                WHERE USER_ID LIKE 'MMOEI_DEMO%';
GO

/* ------------------------------------------------------------ applicants */

INSERT INTO dbo.MOEI_APPLICANTS
    (USER_ID, EMIRATES_ID, FULLNAME_EN, FULLNAME_AR, EMAIL_ID, MOBILE_NO, GENDER,
     MARITAL_STATUS, DATE_OF_BIRTH, FAMILY_NO, TOWN_NO, APPLICANT_EMIRATE_ID,
     REGION_EN, REGION_AR, NO_OF_DEPENDENT, IS_ACTIVE, CREATED_DATE)
VALUES
    ('MMOEI_DEMO001', '784-1985-1234567-1', 'Ahmed Saeed Al Mansoori', N'أحمد سعيد المنصوري',
     'ahmed.mansoori@example.ae', '0501234567', 'MALE', 'MARRIED', '1985-03-12',
     'FB-1001', 'TN-4001', '4', 'Ajman', N'عجمان', 3, 1, DATEADD(DAY, -400, GETDATE())),

    ('MMOEI_DEMO002', '784-1992-7654321-2', 'Noura Abdullah Al Zaabi', N'نورة عبدالله الزعابي',
     'noura.zaabi@example.ae', '0559876543', 'FEMALE', 'DIVORCED', '1992-11-02',
     'FB-1002', 'TN-3002', '3', 'Sharjah', N'الشارقة', 2, 1, DATEADD(DAY, -300, GETDATE())),

    ('MMOEI_DEMO003', '784-1979-2223334-3', 'Khalifa Juma Al Nuaimi', N'خليفة جمعة النعيمي',
     'khalifa.nuaimi@example.ae', '0526667788', 'MALE', 'MARRIED', '1979-06-21',
     'FB-1003', 'TN-6003', '6', 'Ras Al Khaimah', N'رأس الخيمة', 4, 1, DATEADD(DAY, -200, GETDATE()));
GO

/* ------------------------------------------------------- family members */

/* RELATIONSHIP, MARITAL_STATUS and AGE are what the eligibility rule counts:
   unmarried daughters, sons aged <= 24, and wives. */
INSERT INTO dbo.MOEI_APPLICANT_FAMILY
    (ID, APPLICANT, FULLNAME_EN, RELATIONSHIP, MARITAL_STATUS, AGE, DATE_OF_BIRTH, GENDER, IS_ACTIVE)
VALUES
    ('FAM_DEMO001', 'MMOEI_DEMO001', 'Mariam Khalid Al Mansoori', 'WIFE',     'MARRIED', 37, '1988-07-04', 'FEMALE', 1),
    ('FAM_DEMO002', 'MMOEI_DEMO001', 'Saeed Ahmed Al Mansoori',   'SON',      'SINGLE',  13, '2012-01-19', 'MALE',   1),
    ('FAM_DEMO003', 'MMOEI_DEMO001', 'Fatima Ahmed Al Mansoori',  'DAUGHTER', 'SINGLE',  10, '2015-09-28', 'FEMALE', 1),

    ('FAM_DEMO004', 'MMOEI_DEMO002', 'Hamad Rashid Al Zaabi',     'SON',      'SINGLE',   9, '2016-05-11', 'MALE',   1),
    ('FAM_DEMO005', 'MMOEI_DEMO002', 'Alia Rashid Al Zaabi',      'DAUGHTER', 'SINGLE',   6, '2019-02-23', 'FEMALE', 1),

    ('FAM_DEMO006', 'MMOEI_DEMO003', 'Shamsa Ali Al Nuaimi',      'WIFE',     'MARRIED', 42, '1983-04-15', 'FEMALE', 1),
    ('FAM_DEMO007', 'MMOEI_DEMO003', 'Juma Khalifa Al Nuaimi',    'SON',      'SINGLE',  17, '2008-10-02', 'MALE',   1),
    ('FAM_DEMO008', 'MMOEI_DEMO003', 'Hessa Khalifa Al Nuaimi',   'DAUGHTER', 'SINGLE',  14, '2011-12-30', 'FEMALE', 1),
    ('FAM_DEMO009', 'MMOEI_DEMO003', 'Moza Saif Al Nuaimi',       'MOTHER',   'WIDOWED', 74, '1951-01-08', 'FEMALE', 1);
GO

/* ------------------------------------------------------------- employers */

/* ANNUAL_INCOME, so the eligibility check sees 24,000 / 14,500 / 18,000 a
   month once the service divides by 12. */
INSERT INTO dbo.MOEI_APPLICANT_EMPLOYER
    (EMP_ID, EMP_APPLICANT, EMPLOYER_NAME, DESIGNATION, SECTOR, WORK_CATEGORY,
     ANNUAL_INCOME, START_DATE, IS_ACTIVE, EMP_CREATED_DATE)
VALUES
    ('EMP_DEMO001', 'MMOEI_DEMO001', 'Ministry of Energy and Infrastructure', 'Civil Engineer',
     'Government', 'FULL_TIME', 288000, '2012-02-01', 1, DATEADD(DAY, -400, GETDATE())),
    ('EMP_DEMO002', 'MMOEI_DEMO002', 'Emirates Steel', 'Accountant',
     'Private', 'FULL_TIME', 174000, '2016-09-15', 1, DATEADD(DAY, -300, GETDATE())),
    ('EMP_DEMO003', 'MMOEI_DEMO003', 'UAE Armed Forces', 'Technician',
     'Military', 'FULL_TIME', 216000, '2005-04-01', 1, DATEADD(DAY, -200, GETDATE()));
GO

/* ---------------------------------------------------------- applications */

INSERT INTO dbo.MOEI_SZHP_HOUSING_APPLICATIONS
    (APPLICATION_ID, APPLICATION_NO, REFERENCE_NO, APPLICANT, REQUEST_TYPE, STATUS, SOURCE,
     AID_TYPE, ASSISTANCE_TYPE, ASSISTANCE_PURPOSE, MARITAL_STATUS, MARITAL_CATEGORY,
     NO_OF_WIVES, NO_OF_CHILDREN, MARRIAGE_DATE, FAMILY_BOOK_EMIRATE, REGION,
     HOUSING_OWNERSHIP, LOCATION, YEARS_OF_STAYING, LAND_FOR_CONSTRUCTION,
     TECHNICAL_CONSITION, DWELLING_YOC, CONSTRUCTION_AREA_SQ_FEET,
     NO_OF_OCCUPANTS, NO_OF_ROOMS, NO_OF_COUNCILS, NO_OF_BATHROOMS, NO_OF_KITCHENS, NO_OF_BED_ROOMS,
     RECEIVED_HOUSING_AID, AWARDED_AID_AMOUNT, AWARDED_AID_TYPE, AWARDED_ASSISTANCE_TYPE,
     AWARDED_ASSISTANCE_PURPOSE, APPROVAL_DATE, CREATED_BY, CREATED_DATE, UPDATED_DATE)
VALUES
    /* approved */
    ('MSZHP_DEMO001', '900001', 'SZHP/2026/900001', 'MMOEI_DEMO001', 'SZHP', 'APPROVED', 'Website',
     'GRANT', 'HA', 'CONSTRUCT', 'MARRIED', 'MARRIED',
     1, 2, '2010-04-12', '4', 'Ajman',
     'WITH_RENT', 'Al Rawda 3', 8, 'Y',
     'POOR', '1998', 5400,
     5, 4, 1, 2, 1, 3,
     'N', 1200000, 'GRANT', 'HA',
     'CONSTRUCT', DATEADD(DAY, -4, GETDATE()), 'MMOEI_DEMO001',
     DATEADD(DAY, -30, GETDATE()), DATEADD(DAY, -4, GETDATE())),

    /* under review - note the spelling the live data actually uses */
    ('MSZHP_DEMO002', '900002', 'SZHP/2026/900002', 'MMOEI_DEMO002', 'SZHP', 'UNDERREVIEW', 'Website',
     NULL, 'FA', 'PURCHASE', 'DIVORCED', 'DIVORCED_WOMEN_WITH_CHILDREN',
     0, 2, NULL, '3', 'Sharjah',
     'WITH_RELATIVES', 'Al Majaz 2', 6, 'N',
     'AVERAGE', '2005', 2800,
     3, 3, 0, 2, 1, 2,
     'N', NULL, NULL, NULL,
     NULL, NULL, 'MMOEI_DEMO002',
     DATEADD(DAY, -9, GETDATE()), DATEADD(DAY, -3, GETDATE())),

    /* submitted, awaiting pickup */
    ('MSZHP_DEMO003', '900003', 'SZHP/2026/900003', 'MMOEI_DEMO003', 'SZHP', 'SUBMITTED', 'InternalPortal',
     NULL, 'HA', 'MAINTENANCE', 'MARRIED', 'MARRIED',
     1, 2, '2006-08-20', '6', 'Ras Al Khaimah',
     'OWNS_DWELLING', 'Al Dhait South', 14, 'N',
     'WORN_OUT', '1995', 4200,
     5, 5, 1, 3, 1, 4,
     'N', NULL, NULL, NULL,
     NULL, NULL, 'MMOEI_DEMO003',
     DATEADD(DAY, -2, GETDATE()), NULL),

    /* draft, still editable by the applicant */
    ('MSZHP_DEMO004', '900004', 'SZHP/2026/900004', 'MMOEI_DEMO002', 'SZHP', 'DRAFT', 'Website',
     NULL, 'HA', 'CONSTRUCT', 'DIVORCED', 'DIVORCED_WOMEN_WITH_CHILDREN',
     0, 2, NULL, '3', 'Sharjah',
     'WITH_RELATIVES', NULL, NULL, 'Y',
     'UNDEFINED', NULL, NULL,
     3, NULL, NULL, NULL, NULL, 3,
     'N', NULL, NULL, NULL,
     NULL, NULL, 'MMOEI_DEMO002',
     DATEADD(HOUR, -5, GETDATE()), NULL);
GO

/* ------------------------------------------------------------- history */

/* Only the latest row per request carries IS_ACTIVE = 1, matching the
   TASK_ACTION='QUEUED' AND IS_ACTIVE=1 convention the flows read. */
INSERT INTO dbo.COMMON_REQUEST_HISTORY
    (ID, REQUEST_ID, TASK_NAME, PROCESS_TYPE, TASK_ACTION, STATUS, PROCESS_STATUS,
     REQUEST_STATUS, COMMENTS, ACTED_BY, IS_ACTIVE, CREATED_DATE, COMPLETION_DATE)
VALUES
    ('HIST_DEMO001', 'MSZHP_DEMO001', 'Application Submitted', 'SZHP', 'SUBMIT', 'SUBMITTED', 'SUBMITTED',
     'SUBMITTED', 'Application submitted', 'MMOEI_DEMO001', 0, DATEADD(DAY, -30, GETDATE()), DATEADD(DAY, -21, GETDATE())),
    ('HIST_DEMO002', 'MSZHP_DEMO001', 'Technical Research', 'SZHP', 'QUEUED', 'UNDERREVIEW', 'UNDERREVIEW',
     'UNDERREVIEW', 'Documents verified, technical visit completed.', 'r.alhammadi', 0, DATEADD(DAY, -21, GETDATE()), DATEADD(DAY, -4, GETDATE())),
    ('HIST_DEMO003', 'MSZHP_DEMO001', 'Qarar Issued', 'SZHP', 'APPROVE', 'APPROVED', 'APPROVED',
     'APPROVED', 'Approved for a construction grant.', 'r.alhammadi', 1, DATEADD(DAY, -4, GETDATE()), NULL),

    ('HIST_DEMO004', 'MSZHP_DEMO002', 'Application Submitted', 'SZHP', 'SUBMIT', 'SUBMITTED', 'SUBMITTED',
     'SUBMITTED', 'Application submitted', 'MMOEI_DEMO002', 0, DATEADD(DAY, -9, GETDATE()), DATEADD(DAY, -3, GETDATE())),
    ('HIST_DEMO005', 'MSZHP_DEMO002', 'Social Research', 'SZHP', 'QUEUED', 'UNDERREVIEW', 'UNDERREVIEW',
     'UNDERREVIEW', 'Assigned to the social research team.', 's.alblooshi', 1, DATEADD(DAY, -3, GETDATE()), NULL),

    ('HIST_DEMO006', 'MSZHP_DEMO003', 'Application Submitted', 'SZHP', 'SUBMIT', 'SUBMITTED', 'SUBMITTED',
     'SUBMITTED', 'Application submitted', 'MMOEI_DEMO003', 1, DATEADD(DAY, -2, GETDATE()), NULL),

    ('HIST_DEMO007', 'MSZHP_DEMO004', 'Draft Created', 'SZHP', 'QUEUED', 'DRAFT', 'DRAFT',
     'DRAFT', 'Draft created', 'MMOEI_DEMO002', 1, DATEADD(HOUR, -5, GETDATE()), NULL);
GO

SET NOEXEC OFF;
GO

PRINT 'SZHP demo data loaded: 3 applicants, 4 applications, 7 history rows.';
GO
