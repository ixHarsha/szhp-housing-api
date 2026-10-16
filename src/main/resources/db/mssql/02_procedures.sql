/* =====================================================================
   SZHP housing assistance - stored procedures.
   Every read and write the API performs goes through one of these.
   ===================================================================== */

USE [MOEI];
GO

/* ------------------------------------------------------- list (paged) */

IF OBJECT_ID('dbo.usp_SZHP_HousingApplication_List', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SZHP_HousingApplication_List;
GO
CREATE PROCEDURE dbo.usp_SZHP_HousingApplication_List
    @Applicant  NVARCHAR(50)  = NULL,   -- restrict to one applicant
    @Status     NVARCHAR(60)  = NULL,
    @Search     NVARCHAR(150) = NULL,
    @Offset     INT           = 0,
    @PageSize   INT           = 10,
    @TotalCount INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    /* The live STATUS column holds three spellings of the same state
       (UNDERREVIEW, UNDER_REVIEW, APPLICATIONUNDERREVIEW), so a filter on
       any one of them has to match all three or rows go missing. */
    DECLARE @StatusSet TABLE (VALUE NVARCHAR(60));
    IF @Status IS NOT NULL AND @Status <> N'ALL'
    BEGIN
        IF @Status IN (N'UNDERREVIEW', N'UNDER_REVIEW', N'APPLICATIONUNDERREVIEW')
            INSERT INTO @StatusSet VALUES (N'UNDERREVIEW'), (N'UNDER_REVIEW'), (N'APPLICATIONUNDERREVIEW');
        ELSE IF @Status = N'CANCELLED'
            INSERT INTO @StatusSet VALUES (N'CANCELLED'), (N'CANCELLED_BY_MOEI'), (N'CANCELLED_BY_APPLICANT');
        ELSE
            INSERT INTO @StatusSet VALUES (@Status);
    END

    SELECT @TotalCount = COUNT(*)
    FROM   dbo.MOEI_SZHP_HOUSING_APPLICATIONS h
    LEFT JOIN dbo.MOEI_APPLICANTS a ON a.USER_ID = h.APPLICANT
    WHERE (@Applicant IS NULL OR h.APPLICANT = @Applicant)
      AND (@Status IS NULL OR @Status = N'ALL' OR h.STATUS IN (SELECT VALUE FROM @StatusSet))
      AND (@Search IS NULL OR @Search = N''
           OR h.APPLICATION_NO LIKE N'%' + @Search + N'%'
           OR h.APPLICATION_ID LIKE N'%' + @Search + N'%'
           OR h.REFERENCE_NO   LIKE N'%' + @Search + N'%'
           OR a.EMIRATES_ID    LIKE N'%' + @Search + N'%'
           OR a.FULLNAME_EN    LIKE N'%' + @Search + N'%');

    SELECT  h.APPLICATION_ID,
            h.APPLICATION_NO,
            h.REFERENCE_NO,
            h.APPLICANT,
            a.FULLNAME_EN       AS APPLICANT_NAME_EN,
            a.EMIRATES_ID,
            h.REQUEST_TYPE,
            h.AID_TYPE,
            h.ASSISTANCE_TYPE,
            h.REGION,
            a.REGION_EN,
            h.STATUS,
            h.AWARDED_AID_AMOUNT,
            h.CREATED_DATE,
            h.UPDATED_DATE
    FROM    dbo.MOEI_SZHP_HOUSING_APPLICATIONS h
    LEFT JOIN dbo.MOEI_APPLICANTS a ON a.USER_ID = h.APPLICANT
    WHERE (@Applicant IS NULL OR h.APPLICANT = @Applicant)
      AND (@Status IS NULL OR @Status = N'ALL' OR h.STATUS IN (SELECT VALUE FROM @StatusSet))
      AND (@Search IS NULL OR @Search = N''
           OR h.APPLICATION_NO LIKE N'%' + @Search + N'%'
           OR h.APPLICATION_ID LIKE N'%' + @Search + N'%'
           OR h.REFERENCE_NO   LIKE N'%' + @Search + N'%'
           OR a.EMIRATES_ID    LIKE N'%' + @Search + N'%'
           OR a.FULLNAME_EN    LIKE N'%' + @Search + N'%')
    ORDER BY h.CREATED_DATE DESC, h.APPLICATION_ID DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

/* ---------------------------------------------------------------- get */

IF OBJECT_ID('dbo.usp_SZHP_HousingApplication_Get', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SZHP_HousingApplication_Get;
GO
CREATE PROCEDURE dbo.usp_SZHP_HousingApplication_Get
    @ApplicationId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  h.*,
            a.USER_ID              AS APPLICANT_USER_ID,
            a.EMIRATES_ID          AS APPLICANT_EMIRATES_ID,
            a.FULLNAME_EN,
            a.FULLNAME_AR,
            a.EMAIL_ID,
            a.MOBILE_NO,
            a.MOBILE_NO2,
            a.ADDRESS,
            a.POBOX_NO,
            a.GENDER,
            a.QUALIFICATION,
            a.DATE_OF_BIRTH,
            a.FAMILY_NO,
            a.TOWN_NO,
            a.APPLICANT_EMIRATE_ID,
            a.REGION_EN,
            a.REGION_AR,
            a.NO_OF_DEPENDENT,
            e.EMP_ID,
            e.EMPLOYER_NAME,
            e.DESIGNATION,
            e.SECTOR,
            e.WORK_CATEGORY,
            e.ANNUAL_INCOME,
            e.START_DATE,
            e.END_DATE
    FROM    dbo.MOEI_SZHP_HOUSING_APPLICATIONS h
    LEFT JOIN dbo.MOEI_APPLICANTS a ON a.USER_ID = h.APPLICANT
    /* An applicant can have several employer rows; the active one is the
       one the form shows. */
    OUTER APPLY (
        SELECT TOP (1) *
        FROM   dbo.MOEI_APPLICANT_EMPLOYER x
        WHERE  x.EMP_APPLICANT = h.APPLICANT
        ORDER BY CASE WHEN x.IS_ACTIVE = 1 THEN 0 ELSE 1 END, x.START_DATE DESC
    ) e
    WHERE   h.APPLICATION_ID = @ApplicationId;
END
GO

/* ------------------------------------------------------- family members */

IF OBJECT_ID('dbo.usp_SZHP_ApplicantFamily_List', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SZHP_ApplicantFamily_List;
GO
CREATE PROCEDURE dbo.usp_SZHP_ApplicantFamily_List
    @Applicant NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  ID, APPLICANT, FULLNAME_EN, FULLNAME_AR, RELATIONSHIP,
            MARITAL_STATUS, AGE, DATE_OF_BIRTH, GENDER, EMIRATES_ID,
            SPECIAL_NEEDS, IS_ACTIVE
    FROM    dbo.MOEI_APPLICANT_FAMILY
    WHERE   APPLICANT = @Applicant
    ORDER BY ID;
END
GO

/* --------------------------------------------------------- eligibility */

IF OBJECT_ID('dbo.usp_SZHP_Applicant_Eligibility', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SZHP_Applicant_Eligibility;
GO
CREATE PROCEDURE dbo.usp_SZHP_Applicant_Eligibility
    @Applicant      NVARCHAR(50),
    @CurrentSalary  DECIMAL(18, 2)
AS
BEGIN
    SET NOCOUNT ON;

    /* The programme's own rule, kept as written in the flow services:
       eligible when the salary is under 15,000, or when there is at least
       one counted dependant and the per-dependant share is under 3,000.
       Dependants are unmarried daughters, sons aged 24 or under, and wives. */
    SELECT CASE
             WHEN @CurrentSalary < 15000
               OR ( ( COUNT(CASE WHEN T2.RELATIONSHIP = 'DAUGHTER' AND T2.MARITAL_STATUS = 'SINGLE' THEN 1 END)
                    + COUNT(CASE WHEN T2.RELATIONSHIP = 'SON' AND T2.AGE <= 24 THEN 1 END)
                    + COUNT(CASE WHEN T2.RELATIONSHIP = 'WIFE' THEN 1 END) ) > 0
                  AND ( @CurrentSalary /
                        ( COUNT(CASE WHEN T2.RELATIONSHIP = 'DAUGHTER' AND T2.MARITAL_STATUS = 'SINGLE' THEN 1 END)
                        + COUNT(CASE WHEN T2.RELATIONSHIP = 'SON' AND T2.AGE <= 24 THEN 1 END)
                        + COUNT(CASE WHEN T2.RELATIONSHIP = 'WIFE' THEN 1 END) ) ) < 3000 )
             THEN 'Eligible' ELSE 'Not Eligible'
           END AS ELIGIBILITY
    FROM   dbo.MOEI_APPLICANTS T1
    LEFT JOIN dbo.MOEI_APPLICANT_FAMILY T2 ON T1.USER_ID = T2.APPLICANT
    WHERE  T1.USER_ID = @Applicant
    GROUP BY T1.USER_ID;
END
GO

/* ------------------------------------------------------------- insert */

IF OBJECT_ID('dbo.usp_SZHP_HousingApplication_Insert', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SZHP_HousingApplication_Insert;
GO
CREATE PROCEDURE dbo.usp_SZHP_HousingApplication_Insert
    @ApplicationId              NVARCHAR(50),
    @Applicant                  NVARCHAR(50),
    @RequestType                NVARCHAR(40)  = N'SZHP',
    @Status                     NVARCHAR(60),
    @Source                     NVARCHAR(60)  = N'Website',
    @AidType                    NVARCHAR(40)  = NULL,
    @AssistanceType             NVARCHAR(40)  = NULL,
    @AssistancePurpose          NVARCHAR(60)  = NULL,
    @AssistancePurposeCategory  NVARCHAR(60)  = NULL,
    @MaritalStatus              NVARCHAR(30)  = NULL,
    @MaritalCategory            NVARCHAR(60)  = NULL,
    @NoOfWives                  INT           = NULL,
    @NoOfChildren               INT           = NULL,
    @MarriageDate               DATE          = NULL,
    @DivorceDate                DATE          = NULL,
    @SpouseDeathDate            DATE          = NULL,
    @FamilyBookEmirate          NVARCHAR(10)  = NULL,
    @Region                     NVARCHAR(100) = NULL,
    @HousingOwnership           NVARCHAR(40)  = NULL,
    @Location                   NVARCHAR(300) = NULL,
    @LeaseRentalDate            DATE          = NULL,
    @YearsOfStaying             INT           = NULL,
    @LandForConstruction        NVARCHAR(20)  = NULL,
    @TechnicalConsition         NVARCHAR(40)  = NULL,
    @DwellingYOC                NVARCHAR(10)  = NULL,
    @ConstructionAreaSqFeet     DECIMAL(18,2) = NULL,
    @NoOfOccupants              INT           = NULL,
    @NoOfRooms                  INT           = NULL,
    @NoOfCouncils               INT           = NULL,
    @NoOfBathrooms              INT           = NULL,
    @NoOfKitchens               INT           = NULL,
    @NoOfBedRooms               INT           = NULL,
    @ReceivedHousingAid         NVARCHAR(10)  = NULL,
    @NoPrevHousingAsst          NVARCHAR(10)  = NULL,
    @CreatedBy                  NVARCHAR(100) = NULL,
    @ApplicationNo              NVARCHAR(50)  OUTPUT,
    @ReferenceNo                NVARCHAR(50)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    /* APPLICATION_NO is a running number in the live data, so take the next
       one above the current maximum rather than inventing a format. */
    SELECT @ApplicationNo = CONVERT(NVARCHAR(50),
             ISNULL(MAX(TRY_CONVERT(INT, APPLICATION_NO)), 0) + 1)
    FROM   dbo.MOEI_SZHP_HOUSING_APPLICATIONS WITH (UPDLOCK, HOLDLOCK);

    SET @ReferenceNo = CONCAT(N'SZHP/', CONVERT(NVARCHAR(4), YEAR(GETDATE())), N'/', @ApplicationNo);

    INSERT INTO dbo.MOEI_SZHP_HOUSING_APPLICATIONS
        (APPLICATION_ID, APPLICATION_NO, REFERENCE_NO, APPLICANT, REQUEST_TYPE, STATUS, SOURCE,
         AID_TYPE, ASSISTANCE_TYPE, ASSISTANCE_PURPOSE, ASSISTANCE_PURPOSE_CATEGORY,
         MARITAL_STATUS, MARITAL_CATEGORY, NO_OF_WIVES, NO_OF_CHILDREN,
         MARRIAGE_DATE, DIVORCE_DATE, SPOUSE_DEATH_DATE, FAMILY_BOOK_EMIRATE, REGION,
         HOUSING_OWNERSHIP, LOCATION, LEASE_RENTAL_DATE, YEARS_OF_STAYING, LAND_FOR_CONSTRUCTION,
         TECHNICAL_CONSITION, DWELLING_YOC, CONSTRUCTION_AREA_SQ_FEET,
         NO_OF_OCCUPANTS, NO_OF_ROOMS, NO_OF_COUNCILS, NO_OF_BATHROOMS, NO_OF_KITCHENS, NO_OF_BED_ROOMS,
         RECEIVED_HOUSING_AID, NO_PREV_HOUSING_ASST, CREATED_BY, CREATED_DATE)
    VALUES
        (@ApplicationId, @ApplicationNo, @ReferenceNo, @Applicant, @RequestType, @Status, @Source,
         @AidType, @AssistanceType, @AssistancePurpose, @AssistancePurposeCategory,
         @MaritalStatus, @MaritalCategory, @NoOfWives, @NoOfChildren,
         @MarriageDate, @DivorceDate, @SpouseDeathDate, @FamilyBookEmirate, @Region,
         @HousingOwnership, @Location, @LeaseRentalDate, @YearsOfStaying, @LandForConstruction,
         @TechnicalConsition, @DwellingYOC, @ConstructionAreaSqFeet,
         @NoOfOccupants, @NoOfRooms, @NoOfCouncils, @NoOfBathrooms, @NoOfKitchens, @NoOfBedRooms,
         @ReceivedHousingAid, @NoPrevHousingAsst, @CreatedBy, GETDATE());

    COMMIT TRANSACTION;
END
GO

/* ------------------------------------------------------------- update */

IF OBJECT_ID('dbo.usp_SZHP_HousingApplication_Update', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SZHP_HousingApplication_Update;
GO
CREATE PROCEDURE dbo.usp_SZHP_HousingApplication_Update
    @ApplicationId              NVARCHAR(50),
    @AidType                    NVARCHAR(40)  = NULL,
    @AssistanceType             NVARCHAR(40)  = NULL,
    @AssistancePurpose          NVARCHAR(60)  = NULL,
    @AssistancePurposeCategory  NVARCHAR(60)  = NULL,
    @MaritalStatus              NVARCHAR(30)  = NULL,
    @MaritalCategory            NVARCHAR(60)  = NULL,
    @NoOfWives                  INT           = NULL,
    @NoOfChildren               INT           = NULL,
    @MarriageDate               DATE          = NULL,
    @DivorceDate                DATE          = NULL,
    @SpouseDeathDate            DATE          = NULL,
    @FamilyBookEmirate          NVARCHAR(10)  = NULL,
    @Region                     NVARCHAR(100) = NULL,
    @HousingOwnership           NVARCHAR(40)  = NULL,
    @Location                   NVARCHAR(300) = NULL,
    @LeaseRentalDate            DATE          = NULL,
    @YearsOfStaying             INT           = NULL,
    @LandForConstruction        NVARCHAR(20)  = NULL,
    @TechnicalConsition         NVARCHAR(40)  = NULL,
    @DwellingYOC                NVARCHAR(10)  = NULL,
    @ConstructionAreaSqFeet     DECIMAL(18,2) = NULL,
    @NoOfOccupants              INT           = NULL,
    @NoOfRooms                  INT           = NULL,
    @NoOfCouncils               INT           = NULL,
    @NoOfBathrooms              INT           = NULL,
    @NoOfKitchens               INT           = NULL,
    @NoOfBedRooms               INT           = NULL,
    @ReceivedHousingAid         NVARCHAR(10)  = NULL,
    @NoPrevHousingAsst          NVARCHAR(10)  = NULL,
    @UpdatedByApplicant         NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.MOEI_SZHP_HOUSING_APPLICATIONS
       SET AID_TYPE                    = @AidType,
           ASSISTANCE_TYPE             = @AssistanceType,
           ASSISTANCE_PURPOSE          = @AssistancePurpose,
           ASSISTANCE_PURPOSE_CATEGORY = @AssistancePurposeCategory,
           MARITAL_STATUS              = @MaritalStatus,
           MARITAL_CATEGORY            = @MaritalCategory,
           NO_OF_WIVES                 = @NoOfWives,
           NO_OF_CHILDREN              = @NoOfChildren,
           MARRIAGE_DATE               = @MarriageDate,
           DIVORCE_DATE                = @DivorceDate,
           SPOUSE_DEATH_DATE           = @SpouseDeathDate,
           FAMILY_BOOK_EMIRATE         = @FamilyBookEmirate,
           REGION                      = @Region,
           HOUSING_OWNERSHIP           = @HousingOwnership,
           LOCATION                    = @Location,
           LEASE_RENTAL_DATE           = @LeaseRentalDate,
           YEARS_OF_STAYING            = @YearsOfStaying,
           LAND_FOR_CONSTRUCTION       = @LandForConstruction,
           TECHNICAL_CONSITION         = @TechnicalConsition,
           DWELLING_YOC                = @DwellingYOC,
           CONSTRUCTION_AREA_SQ_FEET   = @ConstructionAreaSqFeet,
           NO_OF_OCCUPANTS             = @NoOfOccupants,
           NO_OF_ROOMS                 = @NoOfRooms,
           NO_OF_COUNCILS              = @NoOfCouncils,
           NO_OF_BATHROOMS             = @NoOfBathrooms,
           NO_OF_KITCHENS              = @NoOfKitchens,
           NO_OF_BED_ROOMS             = @NoOfBedRooms,
           RECEIVED_HOUSING_AID        = @ReceivedHousingAid,
           NO_PREV_HOUSING_ASST        = @NoPrevHousingAsst,
           UPDATED_BY_APPLICANT        = @UpdatedByApplicant,
           UPDATED_DATE                = GETDATE()
     WHERE APPLICATION_ID = @ApplicationId;
END
GO

/* ------------------------------------------------------ status change */

IF OBJECT_ID('dbo.usp_SZHP_HousingApplication_ChangeStatus', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SZHP_HousingApplication_ChangeStatus;
GO
CREATE PROCEDURE dbo.usp_SZHP_HousingApplication_ChangeStatus
    @ApplicationId NVARCHAR(50),
    @ToStatus      NVARCHAR(60),
    @TaskName      NVARCHAR(200)  = NULL,
    @TaskAction    NVARCHAR(50),
    @Comments      NVARCHAR(1000) = NULL,
    @ActedBy       NVARCHAR(200),
    @HistoryId     NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @FromStatus NVARCHAR(60);

    BEGIN TRANSACTION;

    SELECT @FromStatus = STATUS
    FROM   dbo.MOEI_SZHP_HOUSING_APPLICATIONS WITH (UPDLOCK, ROWLOCK)
    WHERE  APPLICATION_ID = @ApplicationId;

    IF @FromStatus IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50001, 'Housing application not found.', 1;
    END

    UPDATE dbo.MOEI_SZHP_HOUSING_APPLICATIONS
       SET STATUS       = @ToStatus,
           UPDATED_DATE = GETDATE()
     WHERE APPLICATION_ID = @ApplicationId;

    /* Close the open task before opening the next one, matching the
       TASK_ACTION='QUEUED' AND IS_ACTIVE=1 convention the flows rely on. */
    UPDATE dbo.COMMON_REQUEST_HISTORY
       SET IS_ACTIVE       = 0,
           COMPLETION_DATE = GETDATE()
     WHERE REQUEST_ID = @ApplicationId
       AND IS_ACTIVE = 1;

    INSERT INTO dbo.COMMON_REQUEST_HISTORY
        (ID, REQUEST_ID, TASK_NAME, PROCESS_TYPE, TASK_ACTION, STATUS,
         PROCESS_STATUS, REQUEST_STATUS, COMMENTS, ACTED_BY, IS_ACTIVE, CREATED_DATE)
    VALUES
        (@HistoryId, @ApplicationId, @TaskName, N'SZHP', @TaskAction, @ToStatus,
         @ToStatus, @ToStatus, @Comments, @ActedBy, 1, GETDATE());

    COMMIT TRANSACTION;
END
GO

/* ------------------------------------------------------------ history */

IF OBJECT_ID('dbo.usp_SZHP_RequestHistory_List', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SZHP_RequestHistory_List;
GO
CREATE PROCEDURE dbo.usp_SZHP_RequestHistory_List
    @RequestId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  ID, REQUEST_ID, TASK_ID, TASK_NAME, PROCESS_TYPE, TASK_ACTION,
            STATUS, PROCESS_STATUS, REQUEST_STATUS, COMMENTS, ACTED_BY,
            ACCEPTED_BY, IS_ACTIVE, CREATED_DATE, COMPLETION_DATE
    FROM    dbo.COMMON_REQUEST_HISTORY
    WHERE   REQUEST_ID = @RequestId
    ORDER BY CREATED_DATE, ID;
END
GO
