B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=4.19
@EndOfDesignText@
'Class module
Sub Class_Globals
	Private pool As ConnectionPool
	Private DB As SQL
	#If DBF
	Private H2 As SQL
	Private DriverClass2 As String
	Private JdbcUrl2 As String
	#End If
	Private batch As List
	Private commands As Map
	Private Prefix As String
	Private DriverClass As String
	Private JdbcUrl As String
	Public DBType As String
	Private DBDir As String
	Private DBName As String
	Private User As String
	Private Password As String
End Sub

Public Sub Initialize
	LoadDatabase
	LoadQueries
	CheckDatabase
End Sub

' Use for common queries with key starts with SQL.
Public Sub GetCommand (Key As String) As String
	If commands.ContainsKey("SQL." & Key) = False Then
		Log("*** Command not found: " & Key)
	End If
	Return commands.Get("SQL." & Key)
End Sub

' Use for DB specific queries with key starts with Prefix.SQL.
Public Sub GetCommand2 (Key As String) As String
	If commands.ContainsKey(Prefix & ".SQL." & Key) = False Then
		Log("*** Command not found: " & Key)
	End If
	Return commands.Get(Prefix & ".SQL." & Key)
End Sub

Public Sub GetConnection As SQL
	Select DBType.ToLowerCase
		Case "sqlite"
			DB.InitializeSQLite(DBDir, DBName, False)
			Return DB
		Case "dbf"
			DB.Initialize(DriverClass, JdbcUrl)
			#If DBF
			H2.Initialize(DriverClass2, JdbcUrl2)
			#End If
			Return DB
		Case Else
			Return pool.GetConnection
	End Select
End Sub

#If DBF
' H2 database
Public Sub GetConnection2 As SQL
	Return H2
End Sub
#End If

Private Sub LoadDatabase
	#If MSSQL
	DBType = "SQL Server"
	#Else If MySQL
	DBType = "MySQL"
	#Else If Firebird
	DBType = "Firebird"
	#Else If Postgresql
	DBType = "Postgresql"
	#Else If DBF
	DBType = "DBF"
	#Else
	DBType = "SQLite"
	#End If
	
	If DBType = "SQL Server" Then
		Prefix = "MSSQL"
	Else
		Prefix = DBType
	End If

	Dim TempMap As Map = File.ReadMap(File.DirAssets, "config.properties")
	For Each Key As String In TempMap.Keys
		If Key.StartsWith(Prefix) = False Then Continue
		Select Key
			Case Prefix & ".DriverClass"
				DriverClass = TempMap.Get(Key)
			Case Prefix & ".JdbcUrl"
				JdbcUrl = TempMap.Get(Key)
			#If DBF			
			Case Prefix & ".DriverClass2"
				DriverClass2 = TempMap.Get(Key)
			Case Prefix & ".JdbcUrl2"
				JdbcUrl2 = TempMap.Get(Key)
			#End If
			Case Prefix & ".DBDir"
				DBDir = TempMap.Get(Key)
				If DBDir.Trim = "" Then DBDir = File.DirApp
			Case Prefix & ".DBName"
				DBName = TempMap.Get(Key)
			Case Prefix & ".User"
				User = TempMap.Get(Key)
			Case Prefix & ".Password"
				Password = TempMap.Get(Key)
		End Select
	Next
End Sub

Private Sub LoadQueries
	Dim TempMap As Map = File.ReadMap(File.DirAssets, "config.properties")
	If TempMap.IsInitialized Then
		commands.Initialize
		For Each Key As String In TempMap.Keys
			' DB Type Specific
			#If MSSQL
			If Key.StartsWith("MSSQL.SQL.") Then
				commands.Put(Key, TempMap.Get(Key))
			End If
			#Else If MySQL
			If Key.StartsWith("MySQL.SQL.") Then
				commands.Put(Key, TempMap.Get(Key))
			End If
			#Else If Firebird
			If Key.StartsWith("Firebird.SQL.") Then
				commands.Put(Key, TempMap.Get(Key))
			End If
			#Else If Postgresql
			If Key.StartsWith("Postgresql.SQL.") Then
				commands.Put(Key, TempMap.Get(Key))
			End If
			#Else If DBF
			If Key.StartsWith("DBF.SQL.") Then
				commands.Put(Key, TempMap.Get(Key))
			End If
			#Else
			If Key.StartsWith("SQLite.SQL.") Then
				commands.Put(Key, TempMap.Get(Key))
			End If
			#End If
			' Common SQL Queries
			If Key.StartsWith("SQL.") Then
				commands.Put(Key, TempMap.Get(Key))
			End If
		Next
		'#If DEBUG
		'For Each Key As String In commands.Keys
		'	Log(commands.Get(Key))
		'Next
		'#End If
	End If
End Sub

Private Sub CheckDatabase
	Try
		Dim DBFound As Boolean
		Log($"Checking database..."$)
		Select DBType.ToLowerCase
			Case "sqlite"
				Dim Prefix As String = "SQLite"
				If File.Exists(DBDir, DBName) Then
					DBFound = True
				End If
			Case "mysql"
				Dim Prefix As String = "MySQL"
				pool.Initialize(DriverClass, JdbcUrl.Replace(DBName, "information_schema"), User, Password)
				Dim con As SQL = GetConnection
				If con.IsInitialized Then
					Dim strSQL As String = GetCommand2("CHECK_DATABASE")
					Dim res As ResultSet = con.ExecQuery2(strSQL, Array As String(DBName))
					Do While res.NextRow
						DBFound = True
					Loop
					res.Close
				End If
			Case "sql server"
				Dim Prefix As String = "MSSQL"
				pool.Initialize(DriverClass, JdbcUrl.Replace(DBName, "master"), User, Password)
				Dim con As SQL = GetConnection
				If con.IsInitialized Then
					Dim strSQL As String = GetCommand2("CHECK_DATABASE")
					Dim res As ResultSet = con.ExecQuery2(strSQL, Array As String(DBName))
					Do While res.NextRow
						DBFound = True
					Loop
					res.Close
				End If
			Case Else ' Skip for untested databases
				Log($"${DBType.ToLowerCase} skipped..."$)
				Return
		End Select
		
		If DBFound Then
			Log("Database found!")
		Else
			Log("Creating database...")
			batch.Initialize
			Select DBType.ToLowerCase
				Case "sqlite"
					Dim con As SQL
					con.InitializeSQLite(DBDir, DBName, True)
					con.ExecNonQuery("PRAGMA journal_mode = wal")
				Case "mysql", "sql server"
					ConAddSQLQueryReplaceDBName(con, "CREATE_DATABASE", "{DBNAME}", DBName)
					ConAddSQLQueryReplaceDBName(con, "USE_DATABASE", "{DBNAME}", DBName)
			End Select
			ConAddSQLQuery2(con, "CREATE_TABLE_TBL_CATEGORY")
			ConAddSQLQuery(con, "INSERT_DUMMY_TBL_CATEGORY")
			ConAddSQLQuery2(con, "CREATE_TABLE_TBL_PRODUCTS")
			ConAddSQLQuery(con, "INSERT_DUMMY_TBL_PRODUCTS")
			
			'#If DEBUG
			'For Each qry As String In batch
			'	Log(qry)
			'Next
			'#End If
			
			Dim CreateDB As Object = con.ExecNonQueryBatch("SQL")
			Wait For (CreateDB) SQL_NonQueryComplete (Success As Boolean)
			If Success Then
				Log("Database is created successfully!")
			Else
				Log("Database creation failed!")
			End If
			CloseDB(con)
		End If
		Select DBType.ToLowerCase
			Case "sqlite", "dbf"
				Return
			Case Else ' "mysql", "sql server", "firebird", "postgresql"
				pool.Initialize(DriverClass, JdbcUrl, User, Password)
		End Select
	Catch
		LogError(LastException)
		CloseDB(con)
		Log("Error creating database!")
		Log("Application is terminated.")
		ExitApplication
	End Try
End Sub

Private Sub CloseDB (con As SQL)
	If con <> Null And con.IsInitialized Then con.Close
End Sub

' Add common query to create database batch with key starts with SQL.
Private Sub ConAddSQLQuery (Comm As SQL, Key As String)
	Dim strSQL As String = GetCommand(Key)
	If strSQL <> "" Then Comm.AddNonQueryToBatch(strSQL, Null)
	batch.Add(strSQL)
End Sub

' Add DB specific query to create database batch with key starts with Prefix.SQL.
Private Sub ConAddSQLQuery2 (Comm As SQL, Key As String)
	Dim strSQL As String = GetCommand2(Key)
	If strSQL <> "" Then Comm.AddNonQueryToBatch(strSQL, Null)
	batch.Add(strSQL)
End Sub

' Add DB specific query to create database batch with key starts with Prefix.SQL.
Private Sub ConAddSQLQueryReplaceDBName (Comm As SQL, Key As String, Val1 As String, Val2 As String)
	Dim strSQL As String = GetCommand2(Key).As(String).Replace(Val1, Val2)
	If strSQL <> "" Then Comm.AddNonQueryToBatch(strSQL, Null)
	batch.Add(strSQL)
End Sub