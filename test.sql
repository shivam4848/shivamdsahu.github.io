
CREATE PROCEDURE GetFilteredFileDetails
    @jsonFilter NVARCHAR(MAX) -- Input JSON string
AS
BEGIN
    -- Declare variables
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM dbo.ai_sq_axiomdata WHERE 1 = 1 '; -- Base query
    DECLARE @key NVARCHAR(255), @value NVARCHAR(255);
    DECLARE @paramList NVARCHAR(MAX) = N'';  -- To store dynamic parameter definitions
    DECLARE @paramValues NVARCHAR(MAX) = N''; -- To store parameter values for sp_executesql
    
    -- Use OPENJSON to extract key-value pairs from the JSON
    DECLARE @jsonTable TABLE (
        [Key] NVARCHAR(255),
        [Value] NVARCHAR(MAX)
    );

    -- Insert JSON key-value pairs into a table
    INSERT INTO @jsonTable ([Key], [Value])
    SELECT [Key], [Value]
    FROM OPENJSON(@jsonFilter);

    -- Loop through the key-value pairs from the JSON
    DECLARE json_cursor CURSOR FOR
    SELECT [Key], [Value] FROM @jsonTable;

    OPEN json_cursor;

    FETCH NEXT FROM json_cursor INTO @key, @value;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Dynamically build the WHERE clause based on key-value pairs
        SET @sql = @sql + N' AND ' + @key + N' = @' + @key + ' ';
        
        -- Add the key-value pair as a parameter to be passed in sp_executesql
        SET @paramList = @paramList + N'@' + @key + N' NVARCHAR(MAX), ';
        SET @paramValues = @paramValues + N'@' + @key + N' = ''' + @value + N''', ';

        -- Fetch the next key-value pair
        FETCH NEXT FROM json_cursor INTO @key, @value;
    END;

    -- Close and deallocate cursor
    CLOSE json_cursor;
    DEALLOCATE json_cursor;

    -- Remove trailing commas from parameter lists
    SET @paramList = LEFT(@paramList, LEN(@paramList) - 2);
    SET @paramValues = LEFT(@paramValues, LEN(@paramValues) - 2);

    -- Execute the dynamically constructed SQL with parameters
    EXEC sp_executesql @sql, @paramList, @paramValues;
END;





CREATE PROCEDURE dbo.InsertUploadedFiles
    @JsonInput NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @JobId INT;
    DECLARE @BatchId INT;

    -- Step 1: Insert a new job trigger and get the Job_Id and Batch_ID
    INSERT INTO dbo.ai_sq_jobTrigger (Submission_num, StartDate, EndDate, Job_status)
    VALUES ('AUTO_GENERATED_SUBMISSION_NUM', GETDATE(), NULL, 'uploaded');

    -- Get the newly created Job_Id
    SET @JobId = SCOPE_IDENTITY();

    -- Optionally, generate a new Batch_ID (if needed)
    SET @BatchId = (SELECT ISNULL(MAX(Batch_ID), 0) + 1 FROM dbo.ai_sq_jobTrigger);

    -- Step 2: Parse the JSON input and insert records
    DECLARE @FileDetail NVARCHAR(255);
    DECLARE @ObjectId NVARCHAR(100);
    DECLARE @ByteObject VARBINARY(MAX);
    DECLARE @UploadedFileName NVARCHAR(255);
    DECLARE @FileSource NVARCHAR(100);
    DECLARE @SavedFilePath NVARCHAR(255);
    DECLARE @SavedFileName NVARCHAR(255);
    DECLARE @ContentType NVARCHAR(255);
    DECLARE @DocClass NVARCHAR(255);
    DECLARE @OBU NVARCHAR(100);
    DECLARE @AccountName NVARCHAR(255);
    DECLARE @AccountNumber NVARCHAR(255);

    -- Step 3: Iterate through the JSON array
    DECLARE @JSONTable TABLE (
        Object_Id NVARCHAR(100),
        Byte_object VARBINARY(MAX),
        UploadedFileName NVARCHAR(255),
        File_source NVARCHAR(100),
        SavedFilePath NVARCHAR(255),
        SavedFileName NVARCHAR(255),
        ContentType NVARCHAR(255),
        Doc_Class NVARCHAR(255),
        OBU NVARCHAR(100),
        AccountName NVARCHAR(255),
        AccountNumber NVARCHAR(255)
    );

    -- Insert JSON data into a temporary table for processing
    INSERT INTO @JSONTable (Object_Id, Byte_object, UploadedFileName, File_source, SavedFilePath, SavedFileName, ContentType, Doc_Class, OBU, AccountName, AccountNumber)
    SELECT 
        JSON_VALUE(value, '$.Object_Id') AS Object_Id,
        CAST(JSON_VALUE(value, '$.Byte_object') AS VARBINARY(MAX)) AS Byte_object,
        JSON_VALUE(value, '$.UploadedFileName') AS UploadedFileName,
        JSON_VALUE(value, '$.File_source') AS File_source,
        JSON_VALUE(value, '$.SavedFilePath') AS SavedFilePath,
        JSON_VALUE(value, '$.SavedFileName') AS SavedFileName,
        JSON_VALUE(value, '$.ContentType') AS ContentType,
        JSON_VALUE(value, '$.Doc_Class') AS Doc_Class,
        JSON_VALUE(value, '$.OBU') AS OBU,
        JSON_VALUE(value, '$.AccountName') AS AccountName,
        JSON_VALUE(value, '$.AccountNumber') AS AccountNumber
    FROM OPENJSON(@JsonInput) AS value;

    -- Step 4: Insert the uploaded files into the ai_sq_userUploadedFile and ai_sq_fileDetails tables
    INSERT INTO dbo.ai_sq_userUploadedFile (Object_Id, Byte_object, Submission_num)
    OUTPUT INSERTED.Object_Id INTO @JSONTable (Object_Id)
    SELECT Object_Id, Byte_object, 'AUTO_GENERATED_SUBMISSION_NUM' FROM @JSONTable;

    INSERT INTO dbo.ai_sq_fileDetails (Object_Id, Job_Id, UploadedFileName, File_source, SavedFilePath, SavedFileName, ModifyDate, CreateDate, ContentType, Doc_Class, OBU, AccountName, AccountNumber)
    SELECT 
        Object_Id, 
        @JobId,
        UploadedFileName, 
        File_source, 
        SavedFilePath, 
        SavedFileName, 
        GETDATE(), 
        GETDATE(), 
        ContentType, 
        Doc_Class, 
        OBU, 
        AccountName, 
        AccountNumber
    FROM @JSONTable;

    -- Optional: Return the Job_Id and Batch_Id
    SELECT @JobId AS JobId, @BatchId AS BatchId;
END


DECLARE @Base64String NVARCHAR(MAX) = 'SGVsbG8gd29ybGQ=';  -- This is 'Hello world' in Base64
DECLARE @BinaryData VARBINARY(MAX);

-- Convert Base64 string to binary
SET @BinaryData = CAST('' AS XML).value('xs:base64Binary(sql:variable("@Base64String"))', 'VARBINARY(MAX)');

-- Now @BinaryData contains the binary representation of the Base64 string
SELECT @BinaryData AS BinaryData;
