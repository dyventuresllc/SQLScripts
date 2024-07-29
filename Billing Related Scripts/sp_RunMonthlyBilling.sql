USE [_DB1]
GO

/****** Object:  StoredProcedure [dbo].[sp_RunMonthlyBilling]    Script Date: 7/27/2024 4:12:11 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_RunMonthlyBilling]
		@BFS_ColumnName NVARCHAR(10),
		@BPS_ColumnName NVARCHAR(10),
		@BAS_ColumnName NVARCHAR(10),
		@BUC_ColumnName NVARCHAR(10),
		@BUL_ColumnName NVARCHAR(10),
		@BTU_ColumnName NVARCHAR(10),
		@BPC_ColumnName NVARCHAR(10),
		@MonthStartDate NVARCHAR(20),
		@MonthEndDate NVARCHAR(20)
AS
	DECLARE @Server VARCHAR(100), @WID INT, @SQL NVARCHAR(MAX);

UPDATE rw
	SET rw.[Client Name] = ec.ClientName,
		rw.[Client Number] = ec.ClientNumber,
		rw.[Matter Name] = ec.MatterName,
		rw.[Matter Number] = ec.MatterNumber
FROM EDDS.eddsdbo.ExtendedCase ec 
	JOIN _DB1.dbo.RelativityWorkspaces rw
ON rw.ArtifactID = ec.ArtifactID
WHERE rw.[Matter Number] != ec.MatterNumber

UPDATE rw
	SET rw.[Relativity Case Name] = ec.[Name]
FROM EDDS.eddsdbo.ExtendedCase ec 
	JOIN _DB1.dbo.RelativityWorkspaces rw
ON rw.ArtifactID = ec.ArtifactID
WHERE rw.[Relativity Case Name] != ec.[Name]

--New Cases
INSERT INTO _DB1.dbo.RelativityWorkspaces 
(ArtifactID, [Relativity Case Name], [Client Name], [Client Number], [Matter Number], [Matter Name], [Case Status], Created_Date)
SELECT ArtifactID, Name, ClientName, ClientNumber, MatterNumber, MatterName, StatusName, CreatedOn
    FROM EDDS.eddsdbo.ExtendedCase ec 
WHERE ArtifactID NOT IN (SELECT DISTINCT ArtifactID FROM _DB1.dbo.RelativityWorkspaces)
AND ec.MatterNumber NOT IN ('Relativity Template','QE Template','QE Internal')
AND ec.StatusName NOT IN ('Processing Only')

INSERT INTO _DB1.dbo.RelativityBilling (ArtifactID) 
SELECT ArtifactID FROM _DB1.dbo.RelativityWorkspaces
WHERE ArtifactID NOT IN (SELECT DISTINCT ArtifactID FROM _DB1.dbo.RelativityBilling)

--Total Billable File Size
SET @SQL = N'
UPDATE rb
SET rb.' + @BFS_ColumnName + ' = NULL
FROM _DB1.dbo.RelativityBilling rb;'
EXECUTE sp_executesql @sql;

SET @SQL = N'
IF OBJECT_ID(''tempdb..#Temp'') IS NOT NULL
DROP TABLE #Temp

;WITH CTE (CaseArtifactID, DateKey, ColdStorageState, [Total Billable File Size In GB])
AS 
(
    SELECT
        BillableSize.CaseArtifactID, DateKey, ColdStorageState, max([Total Billable File Size In GB])
    FROM
    (
        SELECT 
            cs.CaseArtifactID, cs.DateKey, cs.ColdStorageState, cs.[timestamp], cast(cs.TotalBillableFileSize/(1024.00*1024.00*1024.00) as decimal (10,2)) ''Total Billable File Size In GB''
        FROM EDDS.eddsdbo.CaseStatistics cs WITH (NOLOCK)
        LEFT JOIN EDDS.eddsdbo.ExtendedCase ec WITH (NOLOCK)
            ON ec.ArtifactID = cs.CaseArtifactID
        WHERE 
            cs.[timestamp] BETWEEN CONVERT(DATETIME,''' + @MonthStartDate + ''') AND CONVERT(DATETIME, ''' + @MonthEndDate + ''')
    ) AS BillableSize
    JOIN _DB1.dbo.RelativityBilling rb
    ON rb.ArtifactID = BillableSize.CaseArtifactID
    GROUP BY CaseArtifactID, DateKey, ColdStorageState
)

SELECT 
    *
INTO #Temp 
FROM CTE 

UPDATE rb
SET rb.' + @BFS_ColumnName + ' = t.[Total Billable File Size In GB]
FROM _DB1.dbo.RelativityBilling rb
JOIN #temp t
ON t.CaseArtifactID = rb.ArtifactID
WHERE rb.' + @BAS_ColumnName + ' IS NULL;'
EXECUTE sp_executesql @sql;

--Published Document Size
IF OBJECT_ID('tempdb..#ProcessingWorkspaces') IS NOT NULL
DROP TABLE #ProcessingWorkspaces

IF OBJECT_ID('_DB1.dbo.BillingProcessing_Temp') IS NOT NULL
DELETE FROM _DB1.dbo.BillingProcessing_Temp

SET @SQL = N'
            UPDATE rb
            SET rb.' + @BPS_ColumnName + ' = NULL
            FROM _DB1.dbo.RelativityBilling rb'
EXECUTE sp_executesql @SQL

SELECT
	eca.CaseArtifactID, ec.DBLocation
INTO #ProcessingWorkspaces
FROM EDDS.eddsdbo.ExtendedCaseApplication eca WITH (NOLOCK)
JOIN EDDS.eddsdbo.ExtendedCase ec WITH (NOLOCK)
	ON ec.ArtifactID = eca.CaseArtifactID
WHERE eca.ApplicationName = 'Processing'
	AND eca.IsInstalled = 1
	AND eca.CaseArtifactID != -1

DECLARE db_cursor CURSOR FOR
    SELECT  
    pw.DBLocation,
    pw.CaseArtifactID
FROM #ProcessingWorkspaces pw
OPEN db_cursor 
FETCH NEXT FROM db_cursor INTO @Server, @WID

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'                            
                ;WITH CTE (CaseArtifactID, [Published Document Size In GB])
                AS 
                (
                    SELECT 
                        @WID, CAST((SUM(PublishedSize.Publisheddocumentsize)/(1024.00*1024.00*1024.00)) as decimal(10,2)) AS ''Published Document Size In GB''
                    FROM
                    (
                        SELECT 
                            ArtifactID, ProcessingDataSource, Publisheddocumentsize, Publisheddocuments, CreatedOn
                        FROM OPENQUERY 
                            ([' + @Server + '],
                                ''SELECT pds.ArtifactID, pds.ProcessingDataSource, pds.Publisheddocumentsize, pds.Publisheddocuments, a.CreatedOn
                                FROM EDDS' + CONVERT(VARCHAR,@WID) + '.eddsdbo.ProcessingDataSource pds
                                JOIN EDDS' + CONVERT(VARCHAR,@WID) + '.eddsdbo.Artifact a
                                    ON a.ArtifactID = pds.ArtifactID
                                WHERE a.CreatedOn BETWEEN CONVERT(DATETIME,''''' + @MonthStartDate + ''''') AND CONVERT(DATETIME, ''''' + @MonthEndDate + ''''')'')
                    ) AS PublishedSize
                )
                
                INSERT INTO _DB1.dbo.BillingProcessing_Temp (CaseArtifactID, [Published Document Size In GB])
                SELECT CaseArtifactID, [Published Document Size In GB] FROM CTE'
    EXECUTE sp_executesql @sql,N'@WID INT', @WID = @WID;    
    FETCH NEXT FROM db_cursor INTO @Server, @WID
END
CLOSE db_cursor
DEALLOCATE db_cursor

SET @SQL = N'
            UPDATE rb
            SET rb.' + @BPS_ColumnName + ' = bpt.[Published Document Size In GB]
            FROM _DB1.dbo.RelativityBilling rb
            JOIN _DB1.dbo.BillingProcessing_Temp bpt
                ON rb.ArtifactID = bpt.CaseArtifactID
            WHERE bpt.[Published Document Size In GB] IS NOT NULL'
EXECUTE sp_executesql @SQL

--User Info
IF OBJECT_ID('tempdb..#TempUsersInfo') IS NOT NULL
DROP TABLE #TempUsersInfo

IF OBJECT_ID('_DB1.dbo.billingUserInfo') IS NOT NULL
DELETE FROM _DB1.dbo.billingUserInfo

SET @SQL= N'
            UPDATE rb
                SET		
	            rb.' + @BUC_ColumnName +' = NULL,
	            rb.' + @BUL_ColumnName +' = NULL
            FROM _DB1.dbo.RelativityBilling rb;'
EXECUTE sp_executesql @SQL

SELECT DISTINCT
	x.CaseArtifactID, 
	x.EmailAddress,
	x.UserName
INTO #TempUsersInfo
FROM
	(
	SELECT 
		u.[EmailAddress], g.[Name], gcg.[CaseArtifactID], rw.[Relativity Case Name], CONCAT(u.LastName, ', ',u.FirstName) 'UserName'
	FROM EDDS.eddsdbo.[GroupCaseGroup] gcg
	JOIN [_DB1].[dbo].[RelativityWorkspaces] rw ON gcg.CaseArtifactID = rw.artifactID
	JOIN EDDS.eddsdbo.[Group] g ON gcg.GroupArtifactID = g.ArtifactID
	JOIN EDDS.eddsdbo.[GroupUser] gu on gu.GroupArtifactID = g.ArtifactID
	JOIN EDDS.eddsdbo.[User] u on u.ArtifactID = gu.UserArtifactID
	WHERE 
		g.Name NOT IN ('System Administrators','R1-Support','QE_LTAS_ADMIN','Automated Workflows Application','QE_EDS_MIGRATION_ADMIN','QE_LTAS_RESTRICTED_ADMIN','QE_LTAS_LOCKBOX')
		AND u.EmailAddress NOT LIKE '%previewUser%' AND u.EmailAddress NOT LIKE '%relativity.com%' AND u.EmailAddress NOT LIKE '%kcura.com%'
		AND u.RelativityAccess = 1
	) x

	INSERT INTO _DB1.dbo.billingUserInfo 
		(CaseArtifactID,[Count of User],[Email List])
	SELECT 
		a.CaseArtifactID, a.[Count of User],b.[User List]
	FROM
		(
		SELECT 
			CaseArtifactID, COUNT(UserName) 'Count of User'
		FROM #TempUsersInfo
		GROUP BY CaseArtifactID
		) as a
	JOIN 
		(SELECT 
		tui.CaseArtifactID, 
		STUFF(( SELECT '; ' + UserName 
				FROM #TempUsersInfo tui2
				WHERE tui2.CaseArtifactID = tui.CaseArtifactID
		ORDER BY UserName
		FOR XML PATH ('')),1,1,'') AS 'User List'
		FROM #TempUsersInfo tui 
		GROUP BY tui.CaseArtifactID
		) as b
	ON a.CaseArtifactID = b.CaseArtifactID

SET @SQL= N'
            UPDATE rb
                SET		
	            rb.' + @BUC_ColumnName +' = bui.[Count of User],
	            rb.' + @BUL_ColumnName +' = bui.[Email List]
            FROM _DB1.dbo.RelativityBilling rb
            JOIN _DB1.dbo.billingUserInfo bui
            ON rb.ArtifactID = bui.CaseArtifactID'
EXECUTE sp_executesql @SQL

--Translations 
IF OBJECT_ID('tempdb..#TranslationWorkspaces') IS NOT NULL
DROP TABLE #TranslationWorkspaces

IF OBJECT_ID('_DB1.dbo.BillingTranslationsTemp') IS NOT NULL
DELETE FROM _DB1.dbo.BillingTranslationsTemp

SET @SQL= N'
            UPDATE rb
            SET	rb.' + @BTU_ColumnName +' = NULL
            FROM _DB1.dbo.RelativityBilling rb;'
EXECUTE sp_executesql @SQL

SELECT
	eca.CaseArtifactID, ec.DBLocation
INTO #TranslationWorkspaces
FROM EDDS.eddsdbo.ExtendedCaseApplication eca WITH (NOLOCK)
JOIN EDDS.eddsdbo.ExtendedCase ec WITH (NOLOCK)
	ON ec.ArtifactID = eca.CaseArtifactID
WHERE eca.ApplicationName = 'RelativityOne Translate'
	AND eca.IsInstalled = 1
	AND eca.CaseArtifactID != -1

	DECLARE db_cursor CURSOR FOR
		SELECT
			CaseArtifactID, DBLocation
		FROM #TranslationWorkspaces
	OPEN db_cursor 
	FETCH NEXT FROM db_cursor INTO @WID, @Server

	WHILE @@FETCH_STATUS = 0
	BEGIN
			SET 
			@SQL = N'
				INSERT INTO _DB1.dbo.BillingTranslationsTemp (WorkspaceID, DateFormatted, CountOfDocuments, SumOfUnits)
				SELECT	@WID, x.DateFormatted, COUNT(x.ArtifactID) ''CountOfDocuments'', SUM(x.Units) ''SumOfUnits''
				FROM OPENQUERY ([' + @Server +'],''
					SELECT 
						td.ArtifactID, 
						FORMAT(a.CreatedOn,''''MM/dd/yyyy'''') as ''''DateFormatted'''',
						IIF ((CEILING(ROUND((LEN(td.translatedFileText)/25000.0),2))) = 0, 1, CEILING(ROUND((LEN(td.translatedFileText)/25000.0),2))) as ''''Units''''
					FROM EDDS' + CONVERT(VARCHAR,@WID) + '.EDDSDBO.translatedDocuments td
					JOIN EDDS' + CONVERT(VARCHAR,@WID) + '.EDDSDBO.Artifact a
					ON td.ArtifactID = a.ArtifactID
					WHERE a.CreatedOn BETWEEN CONVERT(DATETIME,''''' + @MonthStartDate + ''''') AND CONVERT(DATETIME, ''''' + @MonthEndDate + ''''')'')
					x
				GROUP BY x.DateFormatted'
			EXECUTE sp_executesql @sql,N'@WID VARCHAR(10)',@WID = @WID
			--SELECT @SQL
		FETCH NEXT FROM db_cursor INTO @WID, @Server
	END
	CLOSE db_cursor
	DEALLOCATE db_cursor

SET @SQL= N'
            UPDATE rb
                SET		
	            rb.' + @BTU_ColumnName +' = q.[TotalSumOfUnits]
            FROM _DB1.dbo.RelativityBilling rb
            JOIN
                (SELECT
	                WorkspaceID, Sum(SumOfUnits) ''TotalSumOfUnits''
                FROM _DB1.dbo.billingTranslationsTemp 
                GROUP BY WorkspaceID
                ) q
            ON q.WorkspaceID = rb.ArtifactID'
EXECUTE sp_executesql @SQL

--ImageCount
IF OBJECT_ID('_DB1.dbo.BillingImageTemp') IS NOT NULL
DELETE FROM _DB1.dbo.billingImageTemp

IF OBJECT_ID('tempdb..#ImagingWorkspaces') IS NOT NULL
DROP TABLE #ImagingWorkspaces

SET @SQL = N'
            UPDATE rb
            SET rb.' + @BPC_ColumnName + ' = NULL
            FROM _DB1.dbo.RelativityBilling rb;'
EXECUTE sp_executesql @SQL

SELECT
	eca.CaseArtifactID, ec.DBLocation
INTO #ImagingWorkspaces
FROM EDDS.eddsdbo.ExtendedCaseApplication eca WITH (NOLOCK)
JOIN EDDS.eddsdbo.ExtendedCase ec WITH (NOLOCK)
	ON ec.ArtifactID = eca.CaseArtifactID
WHERE eca.ApplicationName = 'Processing'
	AND eca.IsInstalled = 1
	AND eca.CaseArtifactID != -1

DECLARE db_cursor CURSOR FOR
    SELECT  
        CaseArtifactID,
        DBLocation
FROM #ImagingWorkspaces

OPEN db_cursor 
FETCH NEXT FROM db_cursor INTO @WID, @Server

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'
                INSERT INTO _DB1.dbo.billingImageTemp(ArtifactID, PageCount)                  
                SELECT
                    @WID, SUM(d.RelativityImageCount)
                FROM OPENQUERY ([' + @Server +'],''SELECT ArtifactID, RelativityImageCount FROM EDDS' + CONVERT(VARCHAR,@WID) + '.eddsdbo.Document WITH (NOLOCK) WHERE RelativityImageCount IS NOT NULL AND ProcessingFileId IS NOT NULL'') d
                JOIN 
                (
                SELECT 
                    DISTINCT ArtifactID
                FROM OPENQUERY ([' + @Server +'],''SELECT DISTINCT ArtifactID FROM EDDS' + CONVERT(VARCHAR,@WID) + '.eddsdbo.AuditRecord WITH (NOLOCK)
                WHERE 
                        [Action] = 13
                    AND [TimeStamp] BETWEEN CONVERT(DATETIME,''''' + @MonthStartDate + ''''') AND CONVERT(DATETIME, ''''' + @MonthEndDate + ''''')'')
                ) ic
                ON ic.ArtifactID = d.ArtifactID'
    EXECUTE sp_executesql @sql,N'@WID INT', @WID = @WID;    
    --SELECT @SQL
    FETCH NEXT FROM db_cursor INTO @WID, @Server
END
CLOSE db_cursor
DEALLOCATE db_cursor

--Total LinkedBillable File Size
SET @SQL = N'
IF OBJECT_ID(''_DB1.dbo.LinkedBillableTempData'') IS NOT NULL
DROP TABLE _DB1.dbo.LinkedBillableTempData

;WITH CTE (CaseArtifactID, [Total Linked Billable File Size In GB])
AS 
(
    SELECT
        LinkedBillableSize.CaseArtifactID, max([Total LinkedBillable File Size In GB])
    FROM
    (
        SELECT             
            crd.CaseArtifactID, cast(crd.LinkedTotalBillableFileSize/(1024.00*1024.00*1024.00) as decimal (10,2)) ''Total LinkedBillable File Size In GB''
        FROM EDDS.eddsdbo.CaseStatisticsRepoData crd WITH (NOLOCK)
        LEFT JOIN EDDS.eddsdbo.ExtendedCase ec WITH (NOLOCK)
            ON ec.ArtifactID = crd.CaseArtifactID
        WHERE 
            crd.[timestamp] BETWEEN CONVERT(DATETIME,''' + @MonthStartDate + ''') AND CONVERT(DATETIME, ''' + @MonthEndDate + ''')
        AND crd.[IsRepositoryWorkspace] = 1
    ) AS LinkedBillableSize
    JOIN _DB1.dbo.RelativityBilling rb
    ON rb.ArtifactID = LinkedBillableSize.CaseArtifactID
    GROUP BY CaseArtifactID
)

SELECT 
    rb.ArtifactID, c.[Total Linked Billable File Size In GB] ''Review Size'', '+ @BFS_ColumnName + ' - c.[Total Linked Billable File Size In GB] ''Repository Size''
INTO _DB1.dbo.LinkedBillableTempData
FROM CTE c
JOIN _DB1.dbo.RelativityBilling rb
ON c.CaseArtifactID = rb.ArtifactID'
EXECUTE sp_executesql @sql;

SET @SQL = N'
            UPDATE rb
            SET rb.' + @BPC_ColumnName + ' = it.[PageCount]
            FROM _DB1.dbo.RelativityBilling rb
            JOIN _DB1.dbo.billingImageTemp it
                ON rb.ArtifactID = it.ArtifactID
            WHERE it.[PageCount] IS NOT NULL'
EXECUTE sp_executesql @SQL

SET @SQL = N'
            UPDATE rw
                SET rw.[Relativity Case Name] = ec.[Name]
            FROM _DB1.dbo.RelativityWorkspaces rw
            JOIN EDDS.eddsdbo.extendedcase ec
                ON ec.ArtifactID = rw.ArtifactID
            WHERE rw.[Relativity Case Name] != ec.[Name]'
EXECUTE sp_executesql @SQL

SET @SQL = N'
            UPDATE rw
                SET rw.[Case Status] = ec.StatusName
            FROM _DB1.dbo.RelativityWorkspaces rw
            JOIN EDDS.eddsdbo.extendedcase ec
            ON rw.ArtifactID = ec.ArtifactID
            WHERE rw.[Case Status] != ec.StatusName'
EXECUTE sp_executesql @SQL

SET @SQL = N'
            UPDATE rw
                SET rw.[Case Status] = ''Deleted''
            FROM _DB1.dbo.RelativityWorkspaces rw
            LEFT JOIN EDDS.eddsdbo.extendedcase ec
            ON rw.ArtifactID = ec.ArtifactID
            WHERE ec.ArtifactID IS NULL
            AND rw.[Case Status] != ''Deleted'''
EXECUTE sp_executesql @SQL

SELECT 'Monthly Billing Run Is Complete'

GO
