USE [_DB1]
GO
/****** Object:  StoredProcedure [dbo].[sp_LTASManagementWorkspace]    Script Date: 7/28/2024 3:25:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_LTASManagementWorkspace]
AS
DECLARE @SQL NVARCHAR(MAX),@Server NVARCHAR(75),@Db NVARCHAR(12),@StatusCodeTypeID NVARCHAR(8);

SET @Server =  (SELECT ec.DBLocation FROM EDDS.eddsdbo.ExtendedCase ec WHERE ec.[Name] = 'LTAS - WorkspaceManagement')
SET @Db = (SELECT CONCAT('EDDS',ec.ArtifactID) FROM EDDS.eddsdbo.ExtendedCase ec WHERE ec.[Name] = 'LTAS - WorkspaceManagement')

SET @SQL = N'
SET @StatusCodeTypeID1 = (SELECT * FROM OPENQUERY ([' + @Server +'],''SELECT TOP 1 CodeTypeID FROM ['+ @Db +'].eddsdbo.ExtendedCode ec WHERE ec.ObjectType =''''Workspaces'''' AND ec.CodeType = ''''CaseStatus''''''))'
EXECUTE sp_executesql @SQL, N'@StatusCodeTypeID1 NVARCHAR(8) OUTPUT', @StatusCodeTypeID1 = @StatusCodeTypeID OUT

--New Client
BEGIN
SET @SQL = N'
SELECT  DISTINCT
	ec.ClientNumber, ec.ClientName
FROM 
EDDS.Eddsdbo.ExtendedCase ec
WHERE ec.ClientNumber NOT IN 
(
	SELECT 
		DISTINCT ClientNumber
	FROM OPENQUERY(['+ @Server +'], 
	''SELECT * FROM [' + @Db +'].eddsdbo.client'') 
)
AND ec.ClientNumber NOT IN (''QE Template'',''Relativity Template'')'
EXECUTE sp_executesql @SQL
END

--New Matters
BEGIN
SET @SQL = N'
SELECT x.*, NEWID() FROM
(
	SELECT  DISTINCT
		ec.MatterNumber, ec.MatterName, ec.ClientNumber
	FROM 
	EDDS.Eddsdbo.ExtendedCase ec
	WHERE ec.MatterNumber NOT IN
	(
		SELECT 
			DISTINCT MatterNumber
		FROM OPENQUERY([' + @Server + '], 
		''SELECT * FROM [' + @Db + '].eddsdbo.matter'') 
	)
	AND ec.MatterNumber NOT IN (''QE Internal'',''QE Template'',''Relativity Template'')
) AS x'
EXECUTE sp_executesql @SQL
END

--New Workspaces
BEGIN
SET @SQL = N'
SELECT ''^1^|^WorkspaceArtifactID^|^WorkspaceCreatedBy^|^WorkspaceCreatedOn^|^WorkspaceName^|^Matter Number^|^MatterArtifactID^|^ClientNumber^|^ClientArtifactID^|^CaseTeam^|^LTASAnalyst^|^Status^'''
 + 'UNION' + '
SELECT DISTINCT
	CONCAT(''^2^|^'',report.WorkspaceArtifactID,''^|^'',report.WorkspaceCreatedBy,''^|^'', report.WorkspaceCreatedOn,''^|^'', report.WorkspaceName,''^|^'',report.Matter,''^|^'',report.MatterArtifactID, ''^|^'', report.Client, ''^|^'', report.ClientArtifactID, ''^|^'', report.CaseTeam, ''^|^'', report.LTASAnalyst, ''^|^'',report.StatusName,''^'')
FROM
(
	SELECT 
		ec.ArtifactID ''WorkspaceArtifactID'', ec.CreatedByName ''WorkspaceCreatedBy'', ec.CreatedOn ''WorkspaceCreatedOn'', ec.[Name] ''WorkspaceName'', ec.MatterNumber ''Matter'', matter.MatterArtifactID, ec.ClientNumber ''Client'', client.ClientArtifactID ,ec.Keywords ''CaseTeam'', ec.Notes ''LTASAnalyst'', ec.StatusName
	FROM EDDS.eddsdbo.ExtendedCase ec
	LEFT JOIN
	(
		SELECT 
			ArtifactID AS ClientArtifactID, ClientNumber AS ClientNumber
		FROM OPENQUERY([' + @server + '], 
		''SELECT ArtifactID, ClientNumber FROM [' + @Db +'].eddsdbo.Client'') 
	) AS client
	ON client.ClientNumber = ec.ClientNumber
	LEFT JOIN
	(
		SELECT 
			ArtifactID AS MatterArtifactID, MatterNumber AS MatterNumber
		FROM OPENQUERY([' + @server + '], 
		''SELECT ArtifactID, MatterNumber FROM [' + @Db + '].eddsdbo.matter'') 
	) AS matter
	ON matter.MatterNumber = ec.MatterNumber
	WHERE ec.ArtifactID NOT IN 
	(
		SELECT 
			DISTINCT WorkspaceArtifactID
		FROM OPENQUERY([' + @Server + '], 
		''SELECT * FROM [' + @Db +'].eddsdbo.Workspaces'') 
	)
	AND ec.MatterNumber NOT IN (''QE Internal'',''QE Template'',''Relativity Template'')
	AND ec.StatusName NOT IN (''Processing Only'')
) AS report
ORDER BY 1'
EXECUTE sp_executesql @SQL
END

--UPDATE: WorkspaceCreatedBy
BEGIN
SET @SQL = N'
;WITH CTE (WorkspaceArtifactID, WorkspaceCreatedBy, EDDSWorkspaceCreatedBy)
AS
(
	SELECT 
		w.WorkspaceArtifactID, w.WorkspaceCreatedBy, ec.CreatedByName
	FROM EDDS.eddsdbo.ExtendedCase ec
	JOIN
	(
		SELECT WorkspaceArtifactID, WorkspaceCreatedBy, WorkspaceCreatedOn, WorkspaceName, CaseTeam, LTASAnalyst	
		FROM OPENQUERY([' + @Server + '], 
		''SELECT * FROM [' + @Db + '].eddsdbo.Workspaces'') 
	) w
	ON w.WorkspaceArtifactID = ec.ArtifactID
	WHERE ec.CreatedByName != w.WorkspaceCreatedBy
)

UPDATE CTE SET WorkspaceCreatedBy = EDDSWorkspaceCreatedBy'
EXECUTE sp_executesql @SQL
END

--UPDATE: WorkspaceCreatedOn 
BEGIN
SET @SQL = N'
;WITH CTE (WorkspaceArtifactID, WorkspaceCreatedOn, EDDSWorkspaceCreatedOn)
AS
(
	SELECT 
		w.WorkspaceArtifactID, w.WorkspaceCreatedOn, ec.CreatedOn
	FROM EDDS.eddsdbo.ExtendedCase ec
	JOIN
	(
		SELECT WorkspaceArtifactID, WorkspaceCreatedBy, WorkspaceCreatedOn, WorkspaceName, CaseTeam, LTASAnalyst	
		FROM OPENQUERY([' + @Server + '], 
		''SELECT * FROM [' + @Db + '].eddsdbo.Workspaces'') 
	) w
	ON w.WorkspaceArtifactID = ec.ArtifactID
	WHERE ec.CreatedOn <> w.WorkspaceCreatedOn
)

UPDATE CTE SET WorkspaceCreatedOn = EDDSWorkspaceCreatedOn'
EXECUTE sp_executesql @SQL
END

--UPDATE: WorkspaceName
BEGIN
SET @SQL = N'
;WITH CTE (WorkspaceArtifactID, WorkspaceName, EDDSWorkspaceName)
AS
(
	SELECT 
		w.WorkspaceArtifactID, w.WorkspaceName, ec.[Name]
	FROM EDDS.eddsdbo.ExtendedCase ec
	JOIN
	(
		SELECT WorkspaceArtifactID, WorkspaceCreatedBy, WorkspaceCreatedOn, WorkspaceName, CaseTeam, LTASAnalyst	
		FROM OPENQUERY([' + @Server + '], 
		''SELECT * FROM ['+ @Db + '].eddsdbo.Workspaces'') 
	) w
	ON w.WorkspaceArtifactID = ec.ArtifactID
	WHERE ec.[Name] != w.WorkspaceName
)

UPDATE CTE SET WorkspaceName = EDDSWorkspaceName'
EXECUTE sp_executesql @SQL
END

--UPDATE: CaseTeam
BEGIN
SET @SQL = N'
;WITH CTE (WorkspaceArtifactID, WorkspaceCaseTeam, EDDSCaseTeam)
AS
(
	SELECT 
		w.WorkspaceArtifactID, w.CaseTeam, ec.Keywords
	FROM EDDS.eddsdbo.ExtendedCase ec
	JOIN
	(
		SELECT WorkspaceArtifactID, WorkspaceCreatedBy, WorkspaceCreatedOn, WorkspaceName, CaseTeam, LTASAnalyst	
		FROM OPENQUERY([' + @Server + '], 
		''SELECT * FROM ['+ @Db +'].eddsdbo.Workspaces'') 
	) w
	ON w.WorkspaceArtifactID = ec.ArtifactID
	WHERE ec.Keywords != w.CaseTeam
	OR (w.CaseTeam IS NULL AND ec.Keywords IS NOT NULL AND LEN(ec.Keywords) > 0)
)

UPDATE CTE SET WorkspaceCaseTeam = EDDSCaseTeam'
EXECUTE sp_executesql @SQL
END

--UPDATE: LTASAnalyst
BEGIN
SET @SQL = N'
;WITH CTE (WorkspaceArtifactID, WorkspaceLTASAnalyst, EDDSLTASAnalyst)
AS
(
	SELECT 
		w.WorkspaceArtifactID, w.LTASAnalyst, ec.Notes
	FROM EDDS.eddsdbo.ExtendedCase ec
	JOIN
	(
		SELECT WorkspaceArtifactID, WorkspaceCreatedBy, WorkspaceCreatedOn, WorkspaceName, CaseTeam, LTASAnalyst	
		FROM OPENQUERY([' + @Server +'], 
		''SELECT * FROM [' + @Db + '].eddsdbo.Workspaces'') 
	) w
	ON w.WorkspaceArtifactID = ec.ArtifactID
	WHERE ec.Notes != w.LTASAnalyst
	OR (w.LTASAnalyst IS NULL AND ec.Notes IS NOT NULL AND LEN(ec.Notes) > 0)
)
UPDATE CTE SET WorkspaceLTASAnalyst = EDDSLTASAnalyst'
EXECUTE sp_executesql @SQL
END

--UPDATE: Case Status
BEGIN
SET @SQL = N'
IF OBJECT_ID(''tempdb..#StatusTempinfo'') IS NOT NULL
DROP TABLE #StatusTempinfo;

SELECT 
	WorkspaceStatus.*, EDDSStatus.StatusName AS EDDSStatusCodeName
INTO #StatusTempinfo
FROM OPENQUERY 
([' + @Server + '], 
	''SELECT
		w.ArtifactID, w.WorkspaceArtifactID, CASE WHEN ca.CodeArtifactID <> 0 THEN ca.CodeArtifactID ELSE NULL END AS WorkspaceStatusCodeArtifactID, c.[Name] AS WorkspaceStatusCodeName
	FROM ['+ @Db +'].eddsdbo.Workspaces AS w   
	LEFT JOIN [' + @Db + '].eddsdbo.ZCodeArtifact_' + @StatusCodeTypeID +' AS ca    
		ON ca.AssociatedArtifactID = w.ArtifactID   
	LEFT JOIN [' + @Db + '].eddsdbo.code c     
	  ON c.ArtifactID = ca.CodeArtifactID''
) AS WorkspaceStatus
LEFT JOIN
(
	SELECT
		ec.ArtifactID, StatusName
	FROM EDDS.eddsdbo.ExtendedCase ec
) AS EDDSStatus
ON WorkspaceStatus.WorkspaceArtifactID = EDDSStatus.ArtifactID

DELETE FROM #StatusTempinfo
WHERE WorkspaceStatusCodeName = EDDSStatusCodeName;

DELETE FROM #StatusTempinfo
WHERE WorkspaceStatusCodeName = ''Deleted'' AND EDDSStatusCodeName IS NULL;

UPDATE x 
SET x.WorkspaceStatusCodeArtifactID = WorkspaceStatusLookUp.StatusCodeArtifactID
FROM #StatusTempinfo x
INNER JOIN
(
SELECT 
	*
FROM OPENQUERY ([' + @Server +'], 
	''SELECT ec.ArtifactID AS StatusCodeArtifactID, ec.Name AS StatusCodeName
	FROM [' + @Db + '].eddsdbo.ExtendedCode ec 
	WHERE ec.ObjectType like ''''Workspaces'''' AND ec.CodeType = ''''CaseStatus'''''')
) AS WorkspaceStatusLookUp
ON x.EDDSStatusCodeName = WorkspaceStatusLookup.StatusCodeName;

UPDATE x 
SET x.WorkspaceStatusCodeArtifactID = WorkspaceStatusLookUp.StatusCodeArtifactID
FROM #StatusTempinfo AS x
INNER JOIN
(
SELECT 
	*
FROM OPENQUERY ([' + @Server + '], 
	''SELECT ec.ArtifactID AS StatusCodeArtifactID, ec.Name AS StatusCodeName
	FROM [' + @Db + '].eddsdbo.ExtendedCode ec 
	WHERE ec.ObjectType like ''''Workspaces'''' AND ec.CodeType = ''''CaseStatus'''' AND ec.Name = ''''Deleted'''''')
) AS WorkspaceStatusLookUp
ON x.EDDSStatusCodeName IS NULL;

UPDATE oq
	SET oq.CodeArtifactID = UpdateData.Update_CodeArtifactID
	FROM OPENQUERY ([' + @Server + '],
	''SELECT CodeArtifactID, AssociatedArtifactID FROM [' + @Db + '].eddsdbo.ZCodeArtifact_' + @StatusCodeTypeID +''') AS oq 
	JOIN
	(
		SELECT 
			x.ArtifactID AS WorkspaceArtifactID , x.WorkspaceStatusCodeArtifactID AS Update_CodeArtifactID
		FROM #StatusTempinfo AS x  
		INNER JOIN OPENQUERY([' + @Server + '],''SELECT CodeArtifactID, AssociatedArtifactID FROM [' + @Db + '].eddsdbo.ZCodeArtifact_' + @StatusCodeTypeID  + ''') AS ca  
		ON ca.AssociatedArtifactID = x.ArtifactID
		AND ca.CodeArtifactID != x.WorkspaceStatusCodeArtifactID
	) AS UpdateData
	ON UpdateData.WorkspaceArtifactID = oq.AssociatedArtifactID;

	DELETE x 
	FROM #StatusTempinfo x 
	JOIN
		(
			SELECT 
				x.ArtifactID AS WorkspaceArtifactID , x.WorkspaceStatusCodeArtifactID AS Update_CodeArtifactID
			FROM #StatusTempinfo AS x  
			INNER JOIN OPENQUERY(['+ @Server +'],''SELECT CodeArtifactID, AssociatedArtifactID FROM [' +@Db + '].eddsdbo.ZCodeArtifact_' + @StatusCodeTypeID + ''') AS ca  
			ON ca.AssociatedArtifactID = x.ArtifactID
			AND ca.CodeArtifactID = x.WorkspaceStatusCodeArtifactID
		) ca
		ON ca.WorkspaceArtifactID = x.ArtifactID
		AND ca.Update_CodeArtifactID  = x.WorkspaceStatusCodeArtifactID;'

SET @SQL = @SQL + N'
INSERT OPENQUERY ([' + @Server + '],''SELECT CodeArtifactID, AssociatedArtifactID FROM [' + @Db +'].eddsdbo.ZCodeArtifact_' + @StatusCodeTypeID +''')
SELECT DISTINCT
	x.WorkspaceStatusCodeArtifactID, x.ArtifactID AS WorkspaceArtifactID
FROM #StatusTempinfo AS x
INNER JOIN OPENQUERY([' + @Server + '],''SELECT CodeArtifactID, AssociatedArtifactID FROM [' + @Db +'].eddsdbo.ZCodeArtifact_' + @StatusCodeTypeID + ''') AS ca
ON ca.CodeArtifactID != x.WorkspaceStatusCodeArtifactID AND ca.AssociatedArtifactID != x.ArtifactID
WHERE NOT EXISTS	(SELECT * 
					FROM OPENQUERY(['+ @Server + '],
					''SELECT CodeArtifactID, AssociatedArtifactID FROM [' + @Db + '].eddsdbo.ZCodeArtifact_' + @StatusCodeTypeID +''') as ca1 
					WHERE ca1.CodeArtifactID = x.WorkspaceStatusCodeArtifactID 
					AND ca1.AssociatedArtifactID = x.WorkspaceArtifactID);
'
EXECUTE sp_executesql @SQL
END
