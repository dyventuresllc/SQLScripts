USE EDDS1283389

SELECT * FROM eddsdbo.UsersInCase where FullName like '%ngu%'

SELECT 
	MIN(ar.[TimeStamp]), MAX(ar.[TimeStamp])
FROM eddsdbo.AuditRecord ar


SELECT 
COUNT(DISTINCT x.ArtifactID) 'Count of Documents', x.TimeStamp
FROM
(
SELECT * FROM EDDSDBO.AuditRecord ar WHERE ar.UserID = 1028156 and ar.TimeStamp BETWEEN '2023-02-03 19:15:50.463' AND '2023-02-03 19:15:50.790'  AND ar.Details like '%field id="1498674"%' AND ar.Action = 4
) x
GROUP BY x.TimeStamp ORDER BY 2 DESC

;WITH CTE (ControlNumber, xmlData, [Timestamp])
AS (
SELECT 
	d.controlnumber,
	CONVERT(XML,ar.Details),
	ar.[Timestamp]
FROM EDDSDBO.AuditRecord ar WITH (NOLOCK)
JOIN EDDSDBO.Document d WITH (NOLOCK)
ON d.ArtifactID = ar.ArtifactID
WHERE ar.UserID = 1098287
	--AND	ar.TimeStamp BETWEEN '2023-02-03 19:15:50.463' AND '2023-02-03 19:15:50.790' 
	--AND ar.Details like '%field id="1498674"%' AND ar.Action = 4
)
--SELECT * FROM CTE

SELECT 
carved_data.ControlNumber,
carved_data.fieldname,
carved_data.Timestamp,
c1.Name 'Set Choice Name',
c2.Name 'Unset Choice Name'
FROM 
(
	SELECT 
	c.ControlNumber,
	x.fld.value('@name','VARCHAR(100)') AS 'fieldname',
	x.fld.value('setChoice[1]', 'VARCHAR(100)') AS 'SetChoice',
	x.fld.value('unsetChoice[1]', 'VARCHAR(100)') AS 'UnSetChoice',
	c.[Timestamp]
	FROM CTE c
	OUTER APPLY c.xmlData.nodes('auditElement/field') as x(fld)
) carved_data
LEFT JOIN eddsdbo.Code c1 
ON carved_data.SetChoice = c1.ArtifactID
LEFT JOIN eddsdbo.Code c2
ON carved_data.UnSetChoice = c2.ArtifactID
ORDER BY 3 DESC



select distinct
MAX(x.TimeStamp), MIN(x.TimeStamp)
from
(
SELECT * FROM EDDSDBO.AuditRecord ar --WHERE ar.UserID = 1028156 and ar.TimeStamp BETWEEN '2023-02-03 19:15:50.463' AND '2023-02-03 19:15:50.790'  AND ar.Details like '%field id="1498674"%' AND ar.Action = 4
) x



select distinct
x.TimeStamp, count(x.artifactid)
from
(
SELECT * FROM EDDSDBO.AuditRecord ar WHERE ar.UserID = 1028156 AND ar.Details like '%field id="1498674"%' AND ar.Action = 4
) x
group by x.TimeStamp
order by 1 desc

