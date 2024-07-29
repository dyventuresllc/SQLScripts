USE EDDS1027462

--SELECT * FROM eddsdbo.Production
--PROD002 v2
--8877069

SELECT
	f.FileID, f.[Guid], f.DocumentArtifactID, pdf.BatesNumber, f.[Filename], f.[Order], f.[Type], f.[Rotation], f.Identifier, f.[Location] AS [Original Location], f.Size, f.Details, f.Billable, f.Location AS [New Location]
--INTO dbo.ImageUpdate_240723
FROM eddsdbo.[File] f
JOIN eddsdbo.ProductionDocumentFile_8877069 pdf  --8877069 | PROD002 V2
ON pdf.DocumentArtifactID = f.DocumentArtifactID
AND pdf.ProducedFileID = f.FileID
WHERE f.DocumentArtifactID 
	IN
(
	SELECT
		d.artifactid
	FROM eddsdbo.document d
	JOIN eddsdbo.zcodeartifact_1000334 ca
	ON d.artifactid = ca.AssociatedArtifactID
	AND ca.CodeArtifactID = 14555175 -- Tagged Documents in UI
)
AND f.[Type] = 3 -- Production Images
AND f.Details.value('(/productionid)[1]','int') = 8877069  -- Production ArtifactID

/*SELECT * FROM dbo.ImageUpdate_240723
UPDATE dbo.ImageUpdate_240723 SET [New Location] = ''
*/

--Path below is the location of the tiff images on the server
UPDATE x
SET x.[New Location] =  
	CONCAT('\\files.t017.dect035000.relativity.one\T017\Files\EDDS1027462\_ReplacementImages\8877069\', x.BatesNumber,LOWER(REVERSE(SUBSTRING(REVERSE(x.filename),1,CHARINDEX('.',REVERSE(x.filename))))))
FROM dbo.ImageUpdate_240723 x

SELECT DISTINCT LOWER(REVERSE(SUBSTRING(REVERSE(x.filename),1,CHARINDEX('.',REVERSE(x.filename))))) FROM dbo.ImageUpdate_240723 x

update f
SET f.[Location] = x.[New Location]
FROM [V03500017W01969\DECT03500017W01].EDDS1027462.eddsdbo.[File] f
JOIN [V03500017W01969\DECT03500017W01].EDDS1027462.dbo.ImageUpdate_240723 x
ON x.FileID = f.FileID
AND x.Guid = f.Guid
