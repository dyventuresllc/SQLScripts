USE _DB1
GO

CREATE PROCEDURE dbo.sp_BillingDeleteWorkspace
		@WID INT,
		@RBDD_ColumnName NVARCHAR(20),
		@MonthEndDate NVARCHAR(20)
AS
	DECLARE @Server VARCHAR(100), @SQL NVARCHAR(MAX);

/*Billing Table*/
SET @SQL = N'
			UPDATE rb
			SET rb.' + @RBDD_ColumnName + ' = ''' + @MonthEndDate + '''	
			FROM _DB1.dbo.RelativityBilling rb
			WHERE rb.ArtifactID = @WID'
EXECUTE sp_executesql @sql,N'@WID INT', @WID = @WID;   

/*Workspace Table*/
SET @SQL = N'
			UPDATE rw
			SET rw.Deleted_Date = ''' + @MonthEndDate  + '''
			FROM _DB1.dbo.relativityWorkspaces rw
			WHERE rw.ArtifactID = @WID' 
EXECUTE sp_executesql @sql,N'@WID INT', @WID = @WID;   

SET @SQL=N'
	SELECT
		rw.ArtifactID, rw.[Relativity Case Name], rw.[Case Status], rw.Created_Date, rw.Deleted_Date, ' + @RBDD_ColumnName + '
	FROM _DB1.dbo.RelativityBilling rb
	JOIN _DB1.dbo.RelativityWorkspaces rw
	ON rw.ArtifactID = rb.ArtifactID
	AND rw.ArtifactID = @WID'
EXECUTE sp_executesql @sql,N'@WID INT', @WID = @WID;   

