USE EDDS1062585

SELECT * FROM eddsdbo.SearchTermsReport WHERE [Name] like '20240108%'
--2212209

SELECT * FROM eddsdbo.SearchTermsReportObjectsField
WHERE SearchTermsReportArtifactID = 2212209


SELECT COUNT(DISTINCT x.controlnumber)
FROM
(
SELECT
	a1.TextIdentifier, a1.ArtifactID, f.f2212303ArtifactID, d.ControlNumber, d.BeginBates
INTO #temp
FROM eddsdbo.f2212303f2212304 f
JOIN eddsdbo.Artifact a1
ON f.f2212304ArtifactID = a1.ArtifactID
JOIN eddsdbo.Document d
ON d.ArtifactID = f.f2212303ArtifactID

) x
--5820
--without family


SELECT 
		u.ControlNumber, 
		STUFF(( SELECT '; ' + FullName
				FROM #Update u2
				WHERE u.ControlNumber = u2.ControlNumber
		ORDER BY FullName
		FOR XML PATH ('')),1,1,'') AS 'AllCustodian',
		u.XF_ADMIN
		FROM #Update u 
		GROUP BY u.ControlNumber, u.XF_ADMIN

		SELECT * FROM #temp

SELECT
	t1.ControlNumber, t1.BeginBates,
		STUFF(( SELECT '; ' + t2.TextIdentifier
				FROM #temp t2
				WHERE t2.ControlNumber = t1.ControlNumber
				ORDER BY t2.TextIdentifier
				FOR XML PATH ('')),1,1,'') AS 'Search Term(s)'	
FROM #temp t1
GROUP BY t1.ControlNumber, t1.BeginBates
