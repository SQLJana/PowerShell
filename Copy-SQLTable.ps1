<#
#######################
#
.SYNOPSIS
    Copies tables from source to target SQL instance. Optionally creates indexes. Can pass in a huge string of tables separated by newline/comma/semi-colon

.DESCRIPTION
    It is usually a pain to copy with the UI wizard to copy data for specific tables especially
        if it included copying the indexes too! This function eases the pain!

.INPUTS
    Source and target information and table list to copy

.OUTPUTS
    None
 
.EXAMPLE
 
    #
    #Paste in an input list of tables in the format schemaname.tablename
    # ..Dont worry as the function is smart enough to convert the string into a proper array of tables and elimiate duplicates
    #
    $tableNamesRawString = @"
[ITA].[Combined_ITAActual7d.Lond2018Q4Sec]
[ITA].[Combined_ITAGrouped1.Lond2018Q4_NewDated]
[ITA].[Combined_ITAActual6.Migrated2018Q4Sec]
[ITA].[Combined_ITAActual22018Q4]
[ITA].[Combined_ITAGrouped3.Lond2018Q4Sec.Tree]
[ITA].[Combined_ITAActual52018Q4Sec]
[ITA].[Combined_ITAActual12018Q4Sec]
[ITA].[Combined_ITAActual7b2018Q4]
[ITA].[Combined_ITAGrouped1.NZ2018Q4Sec]
[ITA].[Joint_ITAActual8a2018Q4]
[ITA].[Combined_ITAGrouped3.Lond2018Q4.NewDated]
[ITA].[Combined_ITAActual6.MigratedNull2018Q4_Rerun]
[ITA].[Combined_ITAActual6.MigratedNull2018Q4]
"@
 
    [string] $sourceInstance = 'MySourceServer\SourceInstance'
    [string] $sourceDB = 'SourceDatatabaseName'
    [string] $destInstance = 'MyDestServer\DestInstance'
    [string] $destDB = 'DestinationDBName'  #JanaArchiveTest
    [bool] $SkipIfTargetTableExists = $true
    [bool] $DropIfTargetTableExists = $false
    [bool] $copyIndexes = $true
    [bool] $copyData = $true
    [string[]] $tables = $tableNamesRawString
    $sourceQueryTimeout =  60
    $bulkCopyBatchSize = 10000
    $bulkCopyTimeout = 120000
 
    $results = Copy-SQLTable `
        -SourceInstance $sourceInstance `
        -SourceDB $sourceDB `
        -DestInstance $destInstance `
        -DestDB $destDB `
        -SkipIfTargetTableExists: $SkipIfTargetTableExists `
        -DropIfTargetTableExists: $DropIfTargetTableExists `
        -CopyIndexes: $copyIndexes `
        -CopyData: $copyData `
        -Tables $tables `
        -SourceQueryTimeout $sourceQueryTimeout `
        -BulkCopyBatchSize $bulkCopyBatchSize `
        -BulkCopyTimeout $bulkCopyTimeout `
        -Verbose
 
    $results |
        Export-Csv -LiteralPath "\\usvNZcifs02\tare_systems\Infrastructure\DBA_Team\Projects\SQLServer\Actuarial\ExpStageArchive.$((Get-Date).ToString('yyyyMMddHHmmss')).csv" -NoTypeInformation
   
    $results |
        ogv
 
.EXAMPLE
 
    [string] $sourceInstance = 'MySourceServer\SourceInstance'
    [string] $sourceDB = 'SourceDatatabaseName'
    [string] $destInstance = 'MyDestServer\DestInstance'
    [string] $destDB = 'DestinationDBName'  #JanaArchiveTest
        [bool] $SkipIfTargetTableExists = $true
        [bool] $DropIfTargetTableExists = $true
        [bool] $copyIndexes = $true
        [bool] $copyData = $true
        [string[]] $tables = @('dbo.T_STA_DWH_SEC_INDUSTRY_RPT_DQM',
                    'dbo.T_STA_MAS_SEC_INDUSTRY',
                    'dbo.T_STA_DWH_SEC_CALC_RPT_DQM',
                    'dbo.T_STA_MAS_SEC_CALC',
                    'dbo.T_REF_MAS_CLASS_DESC',
                    'dbo.T_REF_MAS_CLASS_MAP',
                    'dbo.T_REF_MAS_CLASSIFICATION_CATEGORY',
                    'dbo.T_DYN_MAS_SAP_ACC_ENTRY',
                    'dbo.T_STA_DWH_SECURITIES_RPT_DQM',
                    'dbo.T_STA_MAS_SEC_CLASS',
                    'dbo.T_STA_MAS_SECURITIES',
                    'dbo.T_REF_MAS_COUNTRY',
                    'dbo.T_REF_MAS_CURRENCY',
                    'dbo.T_STA_BPS_SEC',
                    'dbo.T_STA_BPS_ULT',
                    'dbo.T_STA_DQM_SEC_CALC_CONTROL_RPT',
                    'dbo.T_STA_DQM_SEC_INDUSTRY_CONTROL_RPT',
                    'dbo.T_STA_DQM_SECURITY_CONTROL_RPT',
                    'dbo.T_STA_MAS_ISSUER')
        $sourceQueryTimeout =  60
        $bulkCopyBatchSize = 10000
        $bulkCopyTimeout = 120000
 
        Copy-SQLTable `
            -SourceInstance $sourceInstance `
            -SourceDB $sourceDB `
            -DestInstance $destInstance `
            -DestDB $destDB `
            -SkipIfTargetTableExists: $SkipIfTargetTableExists `
            -DropIfTargetTableExists: $DropIfTargetTableExists `
            -CopyIndexes: $copyIndexes `
            -CopyData: $copyData `
            -Tables $tables `
            -SourceQueryTimeout $sourceQueryTimeout `
            -BulkCopyBatchSize $bulkCopyBatchSize `
            -BulkCopyTimeout $bulkCopyTimeout `
            -Verbose
 
.EXAMPLE
 
    #Copies constraints and recreates target table if it already exists
    #....allows watching row-counts in Verbose output
 
    Copy-SQLTable `
        -SourceInstance '(local)' `
        -SourceDB 'DataStudio4' `
        -DestInstance '(local)' `
        -DestDB Test  `
        -Tables @('dbo.QueryText') `
        -CopyConstraints: $true `
        -DropIfTargetTableExists: $true `
        -BulkCopyBatchSize 1000 `
        -Verbose
  
.NOTES
  
Version History
    v1.0  - Jun 12, 2017. Jana Sattainathan [Twitter: @SQLJana] [Blog: sqljana.wordpress.com]
    v1.1  - Mar 09, 2021. Jana Sattainathan - Accounted for square brackets, dots in table names, get target row count, return object with status and more error handling
    v1.2  - Mar 30, 2021. Jana Sattainathan - Added support for row count progress output via progress bar and verbose output.
 
.LINK
    sqljana.wordpress.com
#
#>
 
function Copy-SQLTable
{
    [CmdletBinding()]
    param(
 
        [Parameter(Mandatory=$true)]
        [string] $SourceInstance,
 
        [Parameter(Mandatory=$true)]
        [string] $SourceDB,       
        
        [Parameter(Mandatory=$true)]
        [string] $DestInstance,
       
        [Parameter(Mandatory=$true)]
        [string] $DestDB,
       
        [Parameter(Mandatory=$false)]
        [switch] $SkipIfTargetTableExists = $false,  #Skips everything if dest table already exists. Will append if parameter is $false and table exists
 
        [Parameter(Mandatory=$false)]
        [switch] $DropIfTargetTableExists = $false,
 
        [Parameter(Mandatory=$false)]
        [switch] $CopyConstraints = $true,
 
        [Parameter(Mandatory=$false)]
        [switch] $CopyIndexes = $true,       
 
        [Parameter(Mandatory=$false)]
        [switch] $CopyData = $true,
 
        [Parameter(Mandatory=$true)]
        [string[]] $Tables,
 
        [Parameter(Mandatory=$false)]
        [int] $SourceQueryTimeout = 600,  #10 minutes
 
        [Parameter(Mandatory=$false)]
        [int] $BulkCopyBatchSize = 10000,
 
        [Parameter(Mandatory=$false)]
        [int] $BulkCopyTimeout = 600      #10 minutes

    )

    [string] $fn = $MyInvocation.MyCommand
    [string] $stepName = "Begin [$fn]"  
 
    [string] $sourceConnString = "Data Source=$SourceInstance;Initial Catalog=$SourceDB;Integrated Security=True;"
    [string] $destConnString = "Data Source=$DestInstance;Initial Catalog=$DestDB;Integrated Security=True;"
    [int] $counter = 0
    [string[]] $inputTablesRefinedArray = ''
    [Hashtable] $allSourceTables = @{}
    [Hashtable] $allDestTables = @{}
    [Hashtable] $givenTables = @{}
    [Hashtable] $givenTablesMissingInSource = @{}
    [bool] $tableExistsInDest = $false
    [int] $copiedRowCount = 0
    [int] $sourceRowCount = 0
    [int] $destRowCount = 0
    [int] $sourceIndexCount = 0
    [int] $destIndexCount = 0
    [int] $sourceDataSize = 0
    [int] $destDataSize = 0
    [int] $sourceIndexSize = 0
    [int] $destIndexSize = 0
    [bool] $sourceIsCompressed = $false
    [bool] $destIsCompressed = $false
    [bool] $skipTable = $false
   
    [DateTime] $StartDate = (Get-Date)
    [DateTime] $EndDate = (Get-Date)
    [TimeSpan] $Duration = [System.TimeSpan]::MinValue
 
    $stepName = "[$fn]: Setup c# extension method block for row count capture after copy"
    #---------------------------------------------------------------
    Write-Verbose $stepName
 
    #BEGIN: For RowCount
    #Source: https://blog.netnerds.net/2015/05/getting-total-number-of-rows-copied-in-sqlbulkcopy-using-powershell/
    # Thanks user601543 @ http://stackoverflow.com/questions/1188384/sqlbulkcopy-row-count-when-complete   
    $source = 'namespace System.Data.SqlClient
    {   
           using Reflection;
 
           public static class SqlBulkCopyExtension
           {
                  const String _rowsCopiedFieldName = "_rowsCopied";
                  static FieldInfo _rowsCopiedField = null;
 
                  public static int RowsCopiedCount(this SqlBulkCopy bulkCopy)
                  {
                         if (_rowsCopiedField == null) _rowsCopiedField = typeof(SqlBulkCopy).GetField(_rowsCopiedFieldName, BindingFlags.NonPublic | BindingFlags.GetField | BindingFlags.Instance);           
                         return (int)_rowsCopiedField.GetValue(bulkCopy);
                  }
           }
    }
    '
 
    Add-Type -ReferencedAssemblies 'System.Data.dll' -TypeDefinition $source
    $null = [Reflection.Assembly]::LoadWithPartialName("System.Data")
    #END: For RowCount
 
    try
    {   
 
        $stepName = "[$fn]: Import SQLPS module and initialize source connection"
        #---------------------------------------------------------------
        Write-Verbose $stepName
        
        Import-Module 'SQLPS'
        $sourceServer = New-Object Microsoft.SqlServer.Management.Smo.Server $SourceInstance
        $sourceDatabase = $sourceServer.Databases[$SourceDB]
        $sourceConn  = New-Object System.Data.SqlClient.SQLConnection($sourceConnString)
        $sourceConn.Open()
 
        $destServer = New-Object Microsoft.SqlServer.Management.Smo.Server $DestInstance
        $destDatabase = $destServer.Databases[$DestDB]
 
 
        $stepName = "[$fn]: Validate parameter values"
        #---------------------------------------------------------------
        Write-Verbose $stepName
 
        #Basically, we are doing the follwing
        # 1) Convert arrary to string
        # 2) Split the string into array again based on CR, LF, comma and semicolon
        # 3) Trim leading/trailing spaces
        # 4) Elimiate items that are empty strings
        # 5) Select the unique items by eliminating duplicates
        # 6) Final value is a string array
        $inputTablesRefinedArray = ($Tables | Out-String).Split("`r").Split("`n").Split(',').Split(';') |
                                    foreach { $_.Trim() } |
                                    Where-Object {$_.Length -gt 0} |
                                    Select-Object -Unique
 
 
        $stepName = "[$fn]: Validate parameter values"
        #---------------------------------------------------------------
        Write-Verbose $stepName
    
        #Source database full table list
        $counter = 0
        foreach($table in $sourceDatabase.Tables)
        {
            $counter = $counter + 1
            Write-Progress -Activity "Collecting source tables:" `
                        -PercentComplete ([int](100 * $counter / $sourceDatabase.Tables.Count)) `
                        -CurrentOperation ("Completed {0}% of the tables" -f ([int](100 * $counter / $sourceDatabase.Tables.Count))) `
                        -Status ("Working on table: [{0}]" -f $table.Name) `
                        -Id 1
 
            $tableName = $table.Name
            $schemaName = $table.Schema
            $tableAndSchema = "$schemaName.$tableName"
            $tableAndSchemaQuoted = "[$schemaName].[$tableName]"
 
            #This is all the tables in the source instance Key=Schema.Table & Value=[Schema].[Table]
            $allSourceTables[$tableAndSchema] = $tableAndSchemaQuoted           
        }
 
        #Dest database full table list
        $counter = 0
        foreach($table in $destDatabase.Tables)
        {
            $counter = $counter + 1
            Write-Progress -Activity "Collecting destination tables:" `
                        -PercentComplete ([int](100 * $counter / $destDatabase.Tables.Count)) `
                        -CurrentOperation ("Completed {0}% of the tables" -f ([int](100 * $counter / $destDatabase.Tables.Count))) `
                        -Status ("Working on table: [{0}]" -f $table.Name) `
                        -Id 1
            $tableName = $table.Name
            $schemaName = $table.Schema
            $tableAndSchema = "$schemaName.$tableName"
            $tableAndSchemaQuoted = "[$schemaName].[$tableName]"
 
            #This is all the tables in the dest instance Key=Schema.Table & Value=[Schema].[Table]
            $allDestTables[$tableAndSchema] = $tableAndSchemaQuoted           
        }
 
        #Given tables list
        $counter = 0
        foreach($curTableName in $inputTablesRefinedArray)
        {
            $counter = $counter + 1
            Write-Progress -Activity "Validation progress:" `
                        -PercentComplete ([int](100 * $counter / $inputTablesRefinedArray.Count)) `
                        -CurrentOperation ("Completed {0}% of the tables" -f ([int](100 * $counter / $inputTablesRefinedArray.Count))) `
                        -Status ("Working on table: {0}" -f $curTableName) `
                        -Id 1
 
            if ($curTableName.ToString().Trim().Length -gt 0)
            {
                $schemaName = $curTableName.Split('.')[0].Replace('[','').Replace(']','')  #strip []
                $tableName = ($curTableName.Split('.')[1..100] -join '.').Replace('[','').Replace(']','')  #Remove "SchemaName." at the beginning and strip []
 
                $tableAndSchema = "$schemaName.$tableName"
                $tableAndSchemaQuoted = "[$schemaName].[$tableName]"
 
                #This is all the given tables with Key=Schema.Table & Value=[Schema].[Table]
                $givenTables[$tableAndSchema] = $tableAndSchemaQuoted
 
                #Given table is missing in source instance (mis-spelled?! or bad input)
                if (-not ($allSourceTables.Values -contains $givenTables[$tableAndSchema]))
                {
                    $givenTablesMissingInSource[$tableAndSchema] = $tableAndSchemaQuoted
                }
            }
 
        }
 
        #Stop if one or more tables are missing in the source database instance
        if ($givenTablesMissingInSource.Count -gt 0)
        {           
            Write-Error ("Tables to copy are missing in the source database instance: {0}." -f ($givenTablesMissingInSource.Values | Out-String))           
 
            Throw "One or more table(s) specified for copy are missing in source."
        }
 
 
        $stepName = "[$fn]: Loop through tables and copy"
        #---------------------------------------------------------------
        Write-Verbose $stepName
 
        $counter = 0
 
        foreach($tableAndSchema in $givenTables.Values)
        {           
            $StartDate = Get-Date
 
            $schemaName = $tableAndSchema.Split('.')[0].Replace('[','').Replace(']','')  #strip []
            $tableName = ($tableAndSchema.Split('.')[1..100] -join '.').Replace('[','').Replace(']','')  #Remove "SchemaName." at the beginning and strip []
            $tableExistsInDest = ($allDestTables.Values -contains $tableAndSchema)
            $skipTable = (($tableExistsInDest -eq $true) -and ($SkipIfTargetTableExists -eq $true))
            $copiedRowCount = 0
            $sourceRowCount = 0
            $destRowCount = 0
            $sourceIndexCount = 0
            $destIndexCount = 0
            $destDataSize = 0
            $destIndexSize = 0
            $sourceIsCompressed = $false
            $destIsCompressed = $false
 
            $stepName = "[$fn]: Starting on table: $tableAndSchema"
            #--------------------------------------------       
            Write-Verbose "[$fn]: ---------------------------------------------------------------"
            Write-Verbose $stepName 
            Write-Verbose "[$fn]: ---------------------------------------------------------------"
           
            try
            {
 
                $stepName = "[$fn]: Get source row count"
                #--------------------------------------------       
                Write-Verbose $stepName 
 
                #Table object from the SMO object model (from source)
                $table = ($sourceDatabase.Tables | where {($_.schema -eq $schemaName) -and  ($_.name -eq $tableName)})           
 
                if ($null -eq $table)
                {
                    Throw "Error accessing the Table object in SMO for table {0} from source." -f $tableAndSchema
                }
                else
                {
                    $sourceRowCount = $table.RowCount                  
                    $sourceIndexCount = $table.Indexes.Count
                    $sourceDataSize = $table.DataSpaceUsed
                    $sourceIndexSize = $table.IndexSpaceUsed
                    $sourceIsCompressed = $table.HasCompressedPartitions
                }
                       
 
                $stepName = "[$fn]: Assemble source/target information"
                #--------------------------------------------       
                Write-Verbose $stepName 
 
                #To get the list of all parameters:
                #(Get-Command Invoke-SQLBackupAndOrRestore).Parameters.Keys
 
                #In case the consumer of this function needs to record details, we return a nicely packaged return object for each execution
                $returnObj = New-Object PSObject
 
                $returnObj | Add-Member -NotePropertyName 'ExecutionHostName' -NotePropertyValue $env:COMPUTERNAME
                $returnObj | Add-Member -NotePropertyName 'SourceInstance' -NotePropertyValue $SourceInstance
                $returnObj | Add-Member -NotePropertyName 'SourceDB' -NotePropertyValue $SourceDB
                $returnObj | Add-Member -NotePropertyName 'SourceSchemaName' -NotePropertyValue $schemaName
                $returnObj | Add-Member -NotePropertyName 'SourceTableName' -NotePropertyValue $tableName
                $returnObj | Add-Member -NotePropertyName 'SourceSchemaTableName' -NotePropertyValue $tableAndSchema
                $returnObj | Add-Member -NotePropertyName 'DestInstance' -NotePropertyValue $DestInstance
                $returnObj | Add-Member -NotePropertyName 'DestDB' -NotePropertyValue $DestDB
                $returnObj | Add-Member -NotePropertyName 'DestSchemaName' -NotePropertyValue $schemaName
                $returnObj | Add-Member -NotePropertyName 'DestTableName' -NotePropertyValue $tableName
                $returnObj | Add-Member -NotePropertyName 'DestSchemaTableName' -NotePropertyValue $tableAndSchema
                $returnObj | Add-Member -NotePropertyName 'SkipIfTargetTableExists' -NotePropertyValue $SkipIfTargetTableExists
                $returnObj | Add-Member -NotePropertyName 'DropIfTargetTableExists' -NotePropertyValue $DropIfTargetTableExists
                $returnObj | Add-Member -NotePropertyName 'CopyIndexes' -NotePropertyValue $CopyIndexes
                $returnObj | Add-Member -NotePropertyName 'CopyData' -NotePropertyValue $CopyData
                $returnObj | Add-Member -NotePropertyName 'SourceQueryTimeout' -NotePropertyValue $SourceQueryTimeout
                $returnObj | Add-Member -NotePropertyName 'BulkCopyBatchSize' -NotePropertyValue $BulkCopyBatchSize
                $returnObj | Add-Member -NotePropertyName 'BulkCopyTimeout' -NotePropertyValue $BulkCopyTimeout
 
                #These will be updated
                $returnObj | Add-Member -NotePropertyName 'TableExistsInDest' -NotePropertyValue $tableExistsInDest
                $returnObj | Add-Member -NotePropertyName 'SourceRowCount' -NotePropertyValue $sourceRowCount
                $returnObj | Add-Member -NotePropertyName 'CopiedRowCount' -NotePropertyValue 0
                $returnObj | Add-Member -NotePropertyName 'DestRowCount' -NotePropertyValue 0
                $returnObj | Add-Member -NotePropertyName 'SourceIndexCount' -NotePropertyValue $sourceIndexCount
                $returnObj | Add-Member -NotePropertyName 'DestIndexCount' -NotePropertyValue 0
                $returnObj | Add-Member -NotePropertyName 'SourceDataSize' -NotePropertyValue $sourceDataSize
                $returnObj | Add-Member -NotePropertyName 'DestDataSize' -NotePropertyValue 0
                $returnObj | Add-Member -NotePropertyName 'SourceIndexSize' -NotePropertyValue $sourceIndexSize
                $returnObj | Add-Member -NotePropertyName 'DestIndexSize' -NotePropertyValue 0
                $returnObj | Add-Member -NotePropertyName 'SourceIsCompressed' -NotePropertyValue $sourceIsCompressed
                $returnObj | Add-Member -NotePropertyName 'DestIsCompressed' -NotePropertyValue $false
               
 
                $returnObj | Add-Member -NotePropertyName 'StartDate' -NotePropertyValue $StartDate
                $returnObj | Add-Member -NotePropertyName 'EndDate' -NotePropertyValue $EndDate
                $returnObj | Add-Member -NotePropertyName 'Duration' -NotePropertyValue $Duration
                $returnObj | Add-Member -NotePropertyName 'Status' -NotePropertyValue 'PENDING'
                $returnObj | Add-Member -NotePropertyName 'StatusMessage' -NotePropertyValue 'N/A'
 
 
                $counter = $counter + 1
                Write-Progress -Activity "Copy progress:" `
                            -PercentComplete ([int](100 * $counter / $inputTablesRefinedArray.Count)) `
                            -CurrentOperation ("Completed {0}% of the tables" -f ([int](100 * $counter / $inputTablesRefinedArray.Count))) `
                            -Status ("Working on table: {0}" -f $tableAndSchema) `
                            -Id 1
 
                if ($skipTable -eq $false)
                {
                    $stepName = "[$fn]: Create schema [$schemaName] in target if it does not exist"
                    #---------------------------------------------------------------
                    Write-Verbose $stepName
 
                    $schemaScript = "IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = '$schemaName')
                                        BEGIN
                                            EXEC('CREATE SCHEMA $schemaName')
                                        END"
 
                    Invoke-Sqlcmd `
                                -ServerInstance $DestInstance `
                                -Database $DestDB `
                                -Query $schemaScript
 
                    if ($DropIfTargetTableExists -eq $true)
                    {
                        $stepName = "[$fn]: Drop table $tableAndSchema in target if it exists"
                        #---------------------------------------------------------------
                        Write-Verbose $stepName
 
                        $schemaScript = "IF EXISTS (SELECT 1 WHERE OBJECT_ID('$tableAndSchema') IS NOT NULL)
                                            BEGIN
                                                EXEC('DROP TABLE $tableAndSchema')
                                            END"
 
                        Invoke-Sqlcmd `
                                    -ServerInstance $DestInstance `
                                    -Database $DestDB `
                                    -Query $schemaScript
                    }
 
 
                    #Create table only if asked to or if table is missing in Dest. Otherwise, the user may want to append to existing table
                    if (($DropIfTargetTableExists -eq $true) -or ($tableExistsInDest -eq $false))
                    {
 
                        $stepName = "[$fn]: Scripting default scripting options - default"
                        #----------------------------
                        $scriptingCreateOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
                        Write-Verbose $stepName

                        $scriptingCreateOptions.ExtendedProperties = $true; # Script Extended Properties

                        #$scriptingCreateOptions.DriAllConstraints = $true   # to include referential constraints in the script
                        #$scriptingCreateOptions.NoCollation = $false; # Use default collation
                        #$scriptingCreateOptions.SchemaQualify = $true; # Qualify objects with schema names
                        #$scriptingCreateOptions.ScriptSchema = $true; # Script schema
                        #$scriptingCreateOptions.IncludeDatabaseContext = $true;
                        #$scriptingCreateOptions.EnforceScriptingOptions = $true;
                        #$scriptingCreateOptions.Indexes= $true # Yup, these would be nice
                        #$scriptingCreateOptions.Triggers= $true # This should be included when scripting a database               
 
                        $stepName = "[$fn]: Create constraints"
                        #---------------------------------------------------------------
                        Write-Verbose $stepName

                        #Copy constraints
                        if ($CopyConstraints -eq $true)
                        {
                            $scriptingCreateOptions.DRIAll= $true     #All the constraints (check/PK/FK..)
                        }
                        else
                        {
                            $scriptingCreateOptions.DRIAll= $false
                        }

                        $stepName = "[$fn]: Get the source table script for $tableAndSchema and create in target"
                        #---------------------------------------------------------------
                        Write-Verbose $stepName
 
                        $tablescript = ($table.Script($scriptingCreateOptions) | Out-String)
                       
                        Invoke-Sqlcmd `
                                    -ServerInstance $DestInstance `
                                    -Database $DestDB `
                                    -Query $tablescript
                    }
 
 
                    #Only copy if needed. There may be a need to just copy table structures!               
 
                    if ($CopyData -eq $true)
                    {
                        $stepName = "[$fn]: Get data reader for source table"
                        #---------------------------------------------------------------
                        Write-Verbose $stepName
 
                        $sql = “SELECT * FROM $tableAndSchema"
                        $sqlCommand = New-Object system.Data.SqlClient.SqlCommand($sql, $sourceConn)
                        $sqlCommand.CommandTimeout = $SourceQueryTimeout
                        [System.Data.SqlClient.SqlDataReader] $sqlReader = $sqlCommand.ExecuteReader()
 
                        $stepName = "[$fn]: Copy data from source to destination for table"
                        #---------------------------------------------------------------
                        Write-Verbose $stepName
 
                        $bulkCopy = New-Object Data.SqlClient.SqlBulkCopy($destConnString, [System.Data.SqlClient.SqlBulkCopyOptions]::KeepIdentity)
                        $bulkCopy.DestinationTableName = $tableAndSchema
                        $bulkCopy.BulkCopyTimeOut = $BulkCopyTimeout
                       $bulkCopy.BatchSize = $BulkCopyBatchSize
                        $bulkCopy.NotifyAfter = $BulkCopyBatchSize
                        $bulkCopy.Add_SqlRowscopied({Write-Verbose "$($args[1].RowsCopied) rows copied" ;
                                                     Write-Progress -Activity "Copying data:" `
                                                            -PercentComplete ([int](100 * $args[1].RowsCopied / $returnObj.SourceRowCount)) `
                                                            -CurrentOperation ("Completed {0}% of the rows" -f ([int](100 * $args[1].RowsCopied / $returnObj.SourceRowCount))) `
                                                            -Status ("Table: [{0}]" -f $tableAndSchema) `
                                                            -Id 2})
                        $bulkCopy.WriteToServer($sqlReader)
                        $sqlReader.Close()
                        $bulkCopy.Close()
 
                        $stepName = "[$fn]: Get copied row count"
                        #---------------------------------------------------------------
                        Write-Verbose $stepName   
                             
                        # "Note: This count does not take into consideration the number of rows actually inserted when Ignore Duplicates is set to ON."
                        $copiedRowCount = [System.Data.SqlClient.SqlBulkCopyExtension]::RowsCopiedCount($bulkcopy)
                        Write-Verbose "$copiedRowCount total rows written"
                    }
 
 
                    #Could do the index creations after the data load but clustered indexes need to be in first!
                    if ($CopyIndexes -eq $true)
                    {
                        #Only create indexes if table was recreated or if table did not exist in the first place
                        if (($DropIfTargetTableExists -eq $true) -or ($tableExistsInDest -eq $false))
                        {
 
                            $stepName = "[$fn]: Create indexes for $tableAndSchema in target"
                            #---------------------------------------------------------------
                            Write-Verbose $stepName                
 
                            foreach($index in $table.Indexes )
                            {
                                Write-Verbose "Creating index [$($index.Name)] for $tableAndSchema"
 
                                $indexScript = ($index.script() | Out-String)
 
                                Invoke-Sqlcmd `
                                    -ServerInstance $DestInstance `
                                    -Database $DestDB `
                                    -Query $indexScript `
                                    -QueryTimeout 0
                            }
                        }
                    }
 
 
                }   #if $skipTable
 
 
                $stepName = "[$fn]: Get current dest row count"
                #---------------------------------------------------------------
                #Table object from the SMO object model (from dest)
                $destDatabase.Tables.Refresh()
                $table = ($destDatabase.Tables | where {($_.schema -eq $schemaName) -and  ($_.name -eq $tableName)})
                $destRowCount = $table.RowCount
                $destIndexCount = $table.Indexes.Count
                $destDataSize = $table.DataSpaceUsed
                $destIndexSize = $table.IndexSpaceUsed
                $destIsCompressed = $table.HasCompressedPartitions
 
 
                $stepName = "[$fn]: Update status information"
                #---------------------------------------------------------------
                Write-Verbose $stepName                
 
                $EndDate = Get-Date
                $Duration = (New-TimeSpan -Start $StartDate -End $EndDate)
 
                $returnObj.CopiedRowCount = $copiedRowCount
                $returnObj.DestRowCount = $destRowCount
                $returnObj.DestIndexCount = $destIndexCount
                $returnObj.DestDataSize = $destDataSize
                $returnObj.DestIndexSize = $destIndexSize
                $returnObj.DestIsCompressed = $destIsCompressed               
                $returnObj.StartDate = $StartDate
                $returnObj.EndDate = $EndDate
                $returnObj.Duration = $Duration
                $returnObj.Status = 'COMPLETE'
                $returnObj.StatusMessage = ''
 
                if ($returnObj.SourceRowCount -ne $returnObj.DestRowCount)
                {
                    $returnObj.Status = 'COMPLETE_WITH_WARNING'
                    $returnObj.StatusMessage = 'WARNING: The source and destination row counts do not match!'
                }
            }
            catch
            {
                [Exception]$ex = $_.Exception
                $err = "Unable to copy table: {0}. Error in step: `"{1}]`" `n{2}" -f `
                            $tableAndSchema, $stepName, $ex.Message
 
               
                $stepName = "[$fn]: Update status information"
                #---------------------------------------------------------------
                Write-Verbose $stepName                
 
                $EndDate = Get-Date
                $Duration = (New-TimeSpan -Start $StartDate -End $EndDate)
 
                $returnObj.CopiedRowCount = -1
                $returnObj.DestRowCount = $destRowCount
                $returnObj.DestIndexCount = $destIndexCount
                $returnObj.DestDataSize = $destDataSize
                $returnObj.DestIndexSize = $destIndexSize
                $returnObj.StartDate = $StartDate
                $returnObj.EndDate = $EndDate
                $returnObj.Duration = $Duration
                $returnObj.Status = 'EXCEPTION'
                $returnObj.StatusMessage = $err
            }
 
 
            #Return object for caller
            $returnObj
 
        }
 
 
        Write-Verbose 'Cleanup'
        #---------------------------------------------------------------
 
        $sourceConn.Close()
 
 
    }
    catch
    {
        [Exception]$ex = $_.Exception
        Throw "Unable to copy table(s). Error in step: `"{0}]`" `n{1}" -f `
                        $stepName, $ex.Message
    }
    finally
    {
        #Return value if any
    }
}  
