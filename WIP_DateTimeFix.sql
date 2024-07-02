USE EDDS1860964

IF OBJECT_ID('tempdb..#Data') IS NOT NULL
DROP TABLE #Data

CREATE TABLE #Data
(
	ArtifactID INT PRIMARY KEY,
	ControlNumber VARCHAR(100),
	DateTimeFieldName VARCHAR(50),
	OldDateTimeValue DATETIME,
	OldTimeValue VARCHAR(20),
	NewDateTimeValue DATETIME,
	NewTimeValue VARCHAR(20)
)

CREATE TABLE #Fields
(
	DateTimeField VARCHAR()
	TimeField VARCHAR()
)

INSERT INTO #FIelds
VALUES	('CreatedDate_Time','CreateTime'),
		('LastModifiedDate_Time','LastModifiedTime'),
		('SentDate_Time', 'SentTime'),
		('ReceivedDate_Time','ReceivedTime')
SELECT LEN(LastModifiedDate_Time)

INSERT INTO #Data (ArtifactID, ControlNumber, DateTimeFieldName, OldDateTimeValue, OldTimeValue)
SELECT
	d.ArtifactID, d.ControlNumber, 'SentDate_Time', d.SentDate_Time, d.SentTime
FROM EDDSDBO.document d
WHERE d.ProcessingFileId IS NULL
	AND d.SentDate_Time IS NOT NULL
	AND d.SentTime IS NOT NULL
	AND CONVERT(VARCHAR, d.sentDate_Time,24) = '00:00:00'

INSERT INTO #Data (ArtifactID, ControlNumber, DateTimeFieldName, OldDateTimeValue, OldTimeValue)
SELECT
	d.ArtifactID, d.ControlNumber, 'Received Date_Time', d.ReceivedDate_Time, d.ReceivedTime
FROM EDDSDBO.document d
WHERE d.ProcessingFileId IS NULL
	AND d.ReceivedDate_Time IS NOT NULL
	AND d.ReceivedTime IS NOT NULL
	AND CONVERT(VARCHAR, d.ReceivedDate_Time,24) = '00:00:00'

INSERT INTO #Data (ArtifactID, ControlNumber, DateTimeFieldName, OldDateTimeValue, OldTimeValue)
SELECT
	d.ArtifactID, d.ControlNumber, 'Last Modified Date_Time', d.LastModifiedDate_Time, d.LastModifiedTime
FROM EDDSDBO.document d
WHERE d.ProcessingFileId IS NULL
	AND d.LastModifiedDate_Time IS NOT NULL
	AND d.LastModifiedTime IS NOT NULL
	AND CONVERT(VARCHAR, d.LastModifiedDate_Time,24) = '00:00:00'

--DELETE BAD ISH
DELETE FROM #Data
WHERE OldTimeValue LIKE '%þ%'

--Time is hh:mm:ss or h:mm:ss
UPDATE x
SET NewTimeValue = SUBSTRING(OldTimeValue,0,(LEN(OldTimeValue)-CHARINDEX(':', REVERSE(OldTimeValue))+4))
FROM #Data x
WHERE NewTimeValue IS NULL 
AND 
	LEN(OldTimeValue)-LEN(REPLACE(OldTimeValue,':','')) = 2
AND 
	LEN(OldTimeValue) BETWEEN 7 AND 8

--Time is hh:mm:ss AM
UPDATE x
SET NewTimeValue = SUBSTRING(OldTimeValue,0,(LEN(OldTimeValue)-CHARINDEX(':', REVERSE(OldTimeValue))+4))
FROM #Data x
WHERE NewTimeValue IS NULL 
AND 
	LEN(OldTimeValue)-LEN(REPLACE(OldTimeValue,':','')) = 2
AND 
	OldTimeValue like '%AM%' 
AND 
	CHARINDEX(':',OldTimeValue) = 3

--Time is h:mm:ss AM
UPDATE x
SET NewTimeValue = SUBSTRING(OldTimeValue,0,(LEN(OldTimeValue)-CHARINDEX(':', REVERSE(OldTimeValue))+4))
FROM #Data x
WHERE NewTimeValue IS NULL 
AND 
	LEN(OldTimeValue)-LEN(REPLACE(OldTimeValue,':','')) = 2
AND 
	OldTimeValue like '%AM%' 
AND 
	CHARINDEX(':',OldTimeValue) = 2

--Time is 12:??:?? PM
UPDATE x
SET NewTimeValue = SUBSTRING(OldTimeValue,0,(LEN(OldTimeValue)-CHARINDEX(':', REVERSE(OldTimeValue))+4))
FROM #Data x
WHERE NewTimeValue IS NULL 
AND 
	LEN(OldTimeValue)-LEN(REPLACE(OldTimeValue,':','')) = 2
AND 
	OldTimeValue like '%PM%' 
AND
	SUBSTRING(OldTimeValue,0,CHARINDEX(':',OldTimeValue)) = 12
AND
	(CHARINDEX(':',OldTimeValue) = 2
OR
	CHARINDEX(':',OldTimeValue) = 3)

--Time is [01 - 11]:??:?? PM
UPDATE x 
SET NewTimeValue = CONCAT(SUBSTRING(OldTimeValue,0,CHARINDEX(':',OldTimeValue)) + 12,':',SUBSTRING(RTRIM(LTRIM(SUBSTRING(OldTimeValue,0, CHARINDEX('PM',OldTimeValue)))),(CHARINDEX(':',RTRIM(LTRIM(SUBSTRING(OldTimeValue,0, CHARINDEX('PM',OldTimeValue)))))+1),(LEN(RTRIM(LTRIM(SUBSTRING(OldTimeValue,0, CHARINDEX('PM',OldTimeValue))))) - CHARINDEX(':',RTRIM(LTRIM(SUBSTRING(OldTimeValue,0, CHARINDEX('PM',OldTimeValue))))))))
FROM #Data x
WHERE NewTimeValue IS NULL 
AND 
	LEN(OldTimeValue)-LEN(REPLACE(OldTimeValue,':','')) = 2
AND 
	OldTimeValue like '%PM%' 
AND
	SUBSTRING(OldTimeValue,0,CHARINDEX(':',OldTimeValue)) < 12
AND
	(CHARINDEX(':',OldTimeValue) = 2
OR
	CHARINDEX(':',OldTimeValue) = 3)

--Time is [01 -11]:?? PM (no seconds) we are adding seconds
UPDATE x 
SET NewTimeValue =
	CONCAT(SUBSTRING(OldTimeValue,0,CHARINDEX(':',OldTimeValue)) + 12,':',SUBSTRING(RTRIM(LTRIM(SUBSTRING(OldTimeValue,0, CHARINDEX('PM',OldTimeValue)))),(CHARINDEX(':',RTRIM(LTRIM(SUBSTRING(OldTimeValue,0, CHARINDEX('PM',OldTimeValue)))))+1),(LEN(RTRIM(LTRIM(SUBSTRING(OldTimeValue,0, CHARINDEX('PM',OldTimeValue))))) - CHARINDEX(':',RTRIM(LTRIM(SUBSTRING(OldTimeValue,0, CHARINDEX('PM',OldTimeValue))))))),':00')
FROM #Data x
WHERE NewTimeValue IS NULL 
AND 
	LEN(OldTimeValue)-LEN(REPLACE(OldTimeValue,':','')) = 1
AND 
	OldTimeValue like '%PM%' 
AND
	SUBSTRING(OldTimeValue,0,CHARINDEX(':',OldTimeValue)) < 12
AND
	LEN(CONCAT(SUBSTRING(OldTimeValue,0,CHARINDEX(':',OldTimeValue)) + 12,':',SUBSTRING(RTRIM(LTRIM(SUBSTRING(OldTimeValue,0, CHARINDEX('PM',OldTimeValue)))),(CHARINDEX(':',RTRIM(LTRIM(SUBSTRING(OldTimeValue,0, CHARINDEX('PM',OldTimeValue)))))+1),(LEN(RTRIM(LTRIM(SUBSTRING(OldTimeValue,0, CHARINDEX('PM',OldTimeValue))))) - CHARINDEX(':',RTRIM(LTRIM(SUBSTRING(OldTimeValue,0, CHARINDEX('PM',OldTimeValue))))))))) = 5
AND
	(CHARINDEX(':',OldTimeValue) = 2
OR
	CHARINDEX(':',OldTimeValue) = 3)

--Time is ??:?? AM (no seconds) we are adding seconds
UPDATE x 
SET NewTimeValue =
		CASE 
			WHEN CHARINDEX(':',OldTimeValue) = 2 THEN CONCAT('0',SUBSTRING(OldTimeValue,0,(LEN(OldTimeValue)-CHARINDEX(':', REVERSE(OldTimeValue))+4)),':00')
			WHEN CHARINDEX(':',OldTimeValue) = 3 THEN CONCAT(SUBSTRING(OldTimeValue,0,(LEN(OldTimeValue)-CHARINDEX(':', REVERSE(OldTimeValue))+4)),':00')
		END
FROM #Data x
WHERE NewTimeValue IS NULL 
AND 
	LEN(OldTimeValue)-LEN(REPLACE(OldTimeValue,':','')) = 1
AND 
	OldTimeValue like '%AM%' 
AND 
	(CHARINDEX(':',OldTimeValue) = 2
OR
	CHARINDEX(':',OldTimeValue) = 3)

--Time is 12:?? PM (no seconds) we are adding seconds
UPDATE x 
SET NewTimeValue =
		CASE 
			WHEN CHARINDEX(':',OldTimeValue) = 2 THEN CONCAT('0',SUBSTRING(OldTimeValue,0,(LEN(OldTimeValue)-CHARINDEX(':', REVERSE(OldTimeValue))+4)),':00')
			WHEN CHARINDEX(':',OldTimeValue) = 3 THEN CONCAT(SUBSTRING(OldTimeValue,0,(LEN(OldTimeValue)-CHARINDEX(':', REVERSE(OldTimeValue))+4)),':00')
		END 
FROM #Data x
WHERE NewTimeValue IS NULL 
AND 
	LEN(OldTimeValue)-LEN(REPLACE(OldTimeValue,':','')) = 1
AND 
	OldTimeValue like '%PM%' 
AND
	SUBSTRING(OldTimeValue,0,CHARINDEX(':',OldTimeValue)) = 12
AND 
	(CHARINDEX(':',OldTimeValue) = 2
OR
	CHARINDEX(':',OldTimeValue) = 3)

--NULL OldTimeValue
UPDATE x
SET NewTimeValue = '00:00:00'
FROM #Data x
WHERE NewTimeValue IS NULL 
AND 
	OldTimeValue IS NULL

UPDATE x
SET NewDateTimeValue = CONCAT(CONVERT(DATE,OldDateTimeValue,104),' ',NewTimeValue)
FROM #Data x



