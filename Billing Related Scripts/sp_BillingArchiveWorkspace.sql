USE [_DB1]
GO

/****** Object:  StoredProcedure [dbo].[sp_BillingArchiveWorkspace]    Script Date: 7/29/2024 12:18:15 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sp_BillingArchiveWorkspace]
		@WID INT,
		@BFS_ColumnName NVARCHAR(10),
		@BAS_ColumnName NVARCHAR(10),
		@RBDD_ColumnName NVARCHAR(20),
		@MonthEndDate NVARCHAR(20)
AS
		DECLARE @Server VARCHAR(100),@SQL NVARCHAR(MAX);

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

/*Update Archive Size -- update archive with review size*/
 SET @SQL = N'
 			UPDATE rb
 			SET rb.' +  @BAS_ColumnName + ' = ' + @BFS_ColumnName + '	
 			FROM _DB1.dbo.RelativityBilling rb
 			WHERE rb.ArtifactID = @WID 
			AND rb.' + @BAS_ColumnName + 'IS NULL'
 EXECUTE sp_executesql @sql,N'@WID INT', @WID = @WID;   

  SET @SQL = N'
            UPDATE rw
                SET rw.[Case Status] = ''Deleted''
            FROM _DB1.dbo.RelativityWorkspaces rw                       
            WHERE rw.ArtifactID = @WID
			AND rw.[Case Status] != ''Deleted'''
EXECUTE sp_executesql @SQL,N'@WID INT', @WID = @WID;   

SET @SQL=N'
	SELECT
		rw.ArtifactID, rw.[Relativity Case Name], rw.[Case Status], rw.Created_Date, rw.Deleted_Date, ' +  @BFS_ColumnName + ', ' + @BAS_ColumnName +',' + @RBDD_ColumnName + '
	FROM _DB1.dbo.RelativityBilling rb
	JOIN _DB1.dbo.RelativityWorkspaces rw
	ON rw.ArtifactID = rb.ArtifactID
	AND rw.ArtifactID = @WID'
EXECUTE sp_executesql @sql,N'@WID INT', @WID = @WID;   
GO
