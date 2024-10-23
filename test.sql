
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
