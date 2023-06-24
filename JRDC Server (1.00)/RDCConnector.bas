B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=4.19
@EndOfDesignText@
'Class module
Sub Class_Globals
	Private pool As ConnectionPool
	Private DebugQueries As Boolean
	Private commands As Map
End Sub

'Initializes the object. You can add parameters to this method if needed.
Public Sub Initialize
	pool.Initialize(Main.config.Get("DriverClass"), _
	Main.config.Get("JdbcUrl"), _
	Main.config.Get("User"), _
	Main.config.Get("Password"))
	#if DEBUG
	DebugQueries = True
	#else
	DebugQueries = False
	#end if
	LoadSQLCommands(Main.config)
	CheckDatabase
End Sub

Public Sub GetCommand (Key As String) As String
	If commands.ContainsKey("SQL." & Key) = False Then
		Log("*** Command not found: " & Key)
	End If
	Return commands.Get("SQL." & Key)
End Sub

Public Sub GetConnection As SQL
	If DebugQueries Then LoadSQLCommands(Main.config)
	If Main.config.Get("DriverClass").As(String).Contains("sqlite") Then
		Dim jdbc() As String = Regex.Split(":", Main.config.Get("JdbcUrl"))
		Dim sql As SQL
		If jdbc.Length > 2 Then sql.InitializeSQLite(File.DirApp, jdbc(2), False)
		Return sql
	Else
		Return pool.GetConnection
	End If
End Sub

Private Sub LoadSQLCommands (config As Map)
	Dim newCommands As Map
	newCommands.Initialize
	For Each k As String In config.Keys
		If k.StartsWith("SQL.") Then
			newCommands.Put(k, config.Get(k))
		End If
	Next
	commands = newCommands
End Sub

Private Sub CheckDatabase
	Try
		Dim con As SQL
		Dim DBName As String
		Dim DBType As String
		Dim DBFound As Boolean
		Log($"Checking database..."$)
		
		If Main.config.Get("DriverClass").As(String).Contains("sqlite") Then
			DBType = "sqlite"
			DBName = "test.db"
			Dim jdbc() As String = Regex.Split(":", Main.config.Get("JdbcUrl"))
			If jdbc.Length > 2 Then
				DBName = jdbc(2)
				If File.Exists(File.DirApp, DBName) Then
					DBFound = True
				End If
			End If
		End If
		
		If Main.config.Get("DriverClass").As(String).Contains("mysql") Then
			DBType = "mysql"
			DBName = "test"
			Dim JdbcUrl As String = Main.config.Get("JdbcUrl").As(String).Replace(DBName, "information_schema")
			pool.Initialize(Main.config.Get("DriverClass"), JdbcUrl, Main.config.Get("User"), Main.config.Get("Password"))
			con = GetConnection
			If con.IsInitialized Then
				Dim strSQL As String = GetCommand("CHECK_DATABASE")
				Dim res As ResultSet = con.ExecQuery2(strSQL, Array As String(DBName))
				Do While res.NextRow
					DBFound = True
				Loop
				res.Close
			End If
		End If
		
		If DBFound Then
			Log("Database found!")
		Else   ' Create database if not exist
			Log("Database not found!")
			Log("Creating database...")
			Select DBType
				Case "sqlite"
					con.InitializeSQLite(File.DirApp, DBName, True)
					con.ExecNonQuery("PRAGMA journal_mode = wal")
				Case "mysql"
					ConAddSQLQuery2(con, "CREATE_DATABASE", "{DBNAME}", DBName)
					ConAddSQLQuery2(con, "USE_DATABASE", "{DBNAME}", DBName)
			End Select
		
			ConAddSQLQuery(con, "CREATE_TABLE_TBL_CATEGORY")
			ConAddSQLQuery(con, "INSERT_DUMMY_TBL_CATEGORY")
			ConAddSQLQuery(con, "CREATE_TABLE_TBL_PRODUCTS")
			ConAddSQLQuery(con, "INSERT_DUMMY_TBL_PRODUCTS")
			Dim CreateDB As Object = con.ExecNonQueryBatch("SQL")
			Wait For (CreateDB) SQL_NonQueryComplete (Success As Boolean)
			If Success Then
				Log("Database is created successfully!")
			Else
				Log("Database creation failed!")
			End If
		End If
		CloseDB(con)
	Catch
		LogError(LastException)
		CloseDB(con)
		Log("Error creating database!")
		Log("Application is terminated.")
		ExitApplication
	End Try
End Sub

Public Sub CloseDB (con As SQL)
	If con <> Null And con.IsInitialized Then con.Close
End Sub

Private Sub ConAddSQLQuery (Comm As SQL, Key As String)
	Dim strSQL As String = GetCommand(Key)
	If strSQL <> "" Then Comm.AddNonQueryToBatch(strSQL, Null)
End Sub

Private Sub ConAddSQLQuery2 (Comm As SQL, Key As String, Val1 As String, Val2 As String)
	Dim strSQL As String = GetCommand(Key).As(String).Replace(Val1, Val2)
	If strSQL <> "" Then Comm.AddNonQueryToBatch(strSQL, Null)
End Sub