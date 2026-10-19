# SZHP Housing Assistance — API

Backend for the external housing assistance request form. Java 21, Spring Boot
3.5, JdbcTemplate calling **T-SQL stored procedures** on **Microsoft SQL
Server**. No other database is supported.

The UI lives in a separate repository and talks to this service over `/api`.

> No authentication. See [No sign-in](#no-sign-in).

## Run

```bash
SZHP_DB_URL='jdbc:sqlserver://<host>:1433;databaseName=MOEI;encrypt=true;trustServerCertificate=true' \
SZHP_DB_USER='<user>' \
SZHP_DB_PASSWORD='<password>' \
mvn spring-boot:run            # http://localhost:8080
```

```bash
mvn clean package
java -jar target/szhp-housing-api-1.0.0-SNAPSHOT.jar
```

| Variable | Default | Purpose |
|---|---|---|
| `SZHP_DB_URL` | `…databaseName=MOEI…` on localhost | JDBC URL |
| `SZHP_DB_USER` / `SZHP_DB_PASSWORD` | empty | Credentials — never commit them |
| `SERVER_PORT` | `8080` | HTTP port |

## Database

Everything lives in **`MOEI.dbo`**.

| Table | Role |
|---|---|
| `MOEI_SZHP_HOUSING_APPLICATIONS` | The request |
| `MOEI_APPLICANTS` | Applicant |
| `MOEI_APPLICANT_FAMILY` | Dependants — drives eligibility |
| `MOEI_APPLICANT_EMPLOYER` | Employment and income |
| `COMMON_REQUEST_HISTORY` | Task and status history |

Primary keys are **application-assigned strings**, not identity columns:
`APPLICATION_ID` looks like `MSZHP_100005`, `COMMON_REQUEST_HISTORY.ID` is an
`NVARCHAR(50)`. `IdGenerator` mints them in that shape.

Existing spellings are preserved deliberately — `TECHNICAL_CONSITION`,
`DESCISION_BATCH_NO`, `NO_OF_COUNCILS`, and in the JSON `technicalConsition`,
`receviedHousingAID`, `desigination`, `constructionAreSqFeet`,
`noOfChildrens`. **Renaming any of them changes the contract.**

### Scripts

```bash
sqlcmd -S <host> -d <database> -U <user> -P <password> -i src/main/resources/db/mssql/01_tables.sql
sqlcmd -S <host> -d <database> -U <user> -P <password> -i src/main/resources/db/mssql/02_procedures.sql
```

Neither script switches database — they run against whatever the connection is
already on, and refuse to run against `master`, `tempdb`, `model` or `msdb`.
Pass `-d` deliberately, or set the active database in your client. Each prints
`creating_objects_in` as its first result set; check it before reading on.

`01_tables.sql` is guarded by existence checks, so on the real database it is a
no-op; run it only to stand up an equivalent elsewhere.

`03_sample_data.sql` loads three applicants and four applications covering
draft, submitted, under review and approved, so the form has something to show.
**It INSERTs records and refuses to run unless the database name ends in
`_DEMO`** — never point it at MOEI.

```bash
sqlcmd -S <host> -d SZHP_DEMO -U <user> -P <password> -i src/main/resources/db/mssql/03_sample_data.sql
```

`04_attachments.sql` creates `MOEI_SZHP_ATTACHMENTS` and its four procedures.
**This table is new, not taken from the live schema** — its columns follow
`IAttachment`, and it stores each file base64-encoded in `FILE_CONTENT`. That is
demo storage: before going live, map it onto the real attachment table or
document store. It touches no existing table, and is existence-guarded.

```bash
sqlcmd -S <host> -d SZHP_DEMO -U <user> -P <password> -i src/main/resources/db/mssql/04_attachments.sql
```

> **The column-to-table split in `01_tables.sql` is inferred.** The names come
> from the webMethods adapter `getHousingApplicationById`, whose output is a
> JOIN across the application, applicant and employer tables, so *which* table
> each column sits on is a judgement call. Every one is marked `-- INFERRED`,
> as are the types and lengths. `COMMON_REQUEST_HISTORY` is the exception: it
> was read from the live catalog and is exact. **Check the inferred ones against
> your schema before running anything against a real environment.**

### Procedures

`usp_SZHP_HousingApplication_List` / `_Get` / `_Insert` / `_Update` /
`_ChangeStatus`, `usp_SZHP_ApplicantFamily_List`,
`usp_SZHP_Applicant_Eligibility`, `usp_SZHP_RequestHistory_List`, and
`usp_SZHP_Attachment_List` / `_Get` / `_Insert` / `_Delete` (soft delete).

`_List` expands a status filter across the spellings that really occur, so
filtering on "under review" also matches `UNDER_REVIEW` and
`APPLICATIONUNDERREVIEW` instead of silently dropping rows.

`_ChangeStatus` closes the open task (`TASK_ACTION='QUEUED' AND IS_ACTIVE=1`)
before opening the next, matching the convention the flow services rely on.

## Eligibility

Not reimplemented — `usp_SZHP_Applicant_Eligibility` runs the programme's own
rule, as written in the flow services:

```
eligible when salary < 15,000
         or (dependants > 0 and salary / dependants < 3,000)
dependants = unmarried daughters + sons aged <= 24 + wives
```

The column is `ANNUAL_INCOME` while the rule compares a monthly figure, so the
service divides by 12 before calling. **Confirm that is the intended reading** —
if the rule already expects the annual value, drop the division in
`HousingApplicationService.monthlySalary`.

## API

| Method | Path | Notes |
|---|---|---|
| `GET` | `/api/housing-applications` | `?status=&search=&pageNo=&pageSize=` |
| `GET` | `/api/housing-applications/{id}` | Full detail incl. family and eligibility |
| `GET` | `/api/housing-applications/{id}/history` | Request timeline |
| `POST` | `/api/housing-applications?submit=` | Create as draft or submit |
| `PUT` | `/api/housing-applications/{id}?submit=` | Update a draft or returned request |
| `POST` | `/api/housing-applications/{id}/submit` | Submit an existing draft |
| `GET` | `/api/housing-applications/{id}/attachments` | Document list (`IAttachment[]`, no content) |
| `POST` | `/api/housing-applications/{id}/attachments` | Multipart: `attachmentTypeId`, `file` |
| `GET` | `/api/housing-applications/{id}/attachments/{attachmentId}` | Download the file |
| `DELETE` | `/api/housing-applications/{id}/attachments/{attachmentId}` | Remove a document |

Responses serialize `IHousingApplicationDetails` unchanged; the detail response
also carries `attachments`, as `IHousingApplicationDetails` declares. Errors are
`{status, error, message, timestamp}` — 404 missing, 409 rule or state
violation, 400 bad input, 413 file too large.

## Attachments

Document types: `EMIRATES_ID`, `FAMILY_BOOK`, `SALARY_CERTIFICATE`,
`LEASE_CONTRACT`, `LAND_OWNERSHIP`, `OTHER` (`AttachmentType`). **A request
cannot be submitted until it has an Emirates ID and a Family Book** — that
applies to every submit path, so `POST ?submit=true` on a brand-new request is
rejected: save a draft, upload, then submit.

PDF, JPG and PNG only, up to 5 MB, at most 20 per request. The leading bytes
must match the extension, and the stored MIME type comes from the extension,
never from the client. Documents can be added or removed only while the
request is `DRAFT` or `RETURNED`.

## Status

Only `DRAFT` and `RETURNED` are editable; anything else is rejected with 409.
`ApplicationStatus` recognises the live spellings rather than normalising them.

## No sign-in

The applicant id arrives in `X-Applicant-Id` and is trusted. In the portal it
comes from the shell's token. **This is not a security control** and must be
replaced before the service is exposed.

## Tests

```bash
mvn test
```

Covers the status rules, id generation, the attachment rules, and a full context
load that validates all twelve stored-procedure parameter declarations.

The tests do not touch a database. All four scripts have been run against a
SQL Server 2022 `SZHP_DEMO` database and every endpoint exercised there; they
have **not** been run against the real MOEI schema, so the `-- INFERRED`
columns are still unconfirmed.
