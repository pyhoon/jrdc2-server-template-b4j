B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=10
@EndOfDesignText@
'Class module
Sub Class_Globals
	Public DBType As String
	Private DBDir As String 'ignore
	Private DBFile As String 'ignore
	Private DBName As String 'ignore
	Private JdbcUrl As String 'ignore
	Private DriverClass As String 'ignore
	Private User As String 'ignore
	Private Password As String 'ignore
	Private DB As SQL
	Private batch As List
	Private commands As Map
	#If DBF
	Private H2 As SQL
	Private JdbcUrl2 As String
	Private DriverClass2 As String
	#End If	
	#If MySQL or MSSQL or Postgresql
	Private pool As ConnectionPool
	#End If
End Sub

Public Sub Initialize

End Sub

' Use for common queries with key starts with SQL.
Public Sub GetCommand (Key As String) As String
	If commands.ContainsKey(Key) = False Then
		Log("*** Command not found: " & Key)
	End If
	Return commands.Get(Key)
End Sub

Public Sub GetConnection As SQL
	Select DBType
		Case "SQLite"
			DB.InitializeSQLite(DBDir, DBFile, False)
			Return DB
		Case "DBF"
			DB.Initialize(DriverClass, JdbcUrl.Replace("{DBDir}", DBDir))
			Return DB
		Case "Firebird"
			DB.Initialize2(DriverClass, JdbcUrl.Replace("{DBDir}", DBDir).Replace("{DBFile}", DBFile), User, Password)
			Return DB
		Case Else
			#If MySQL or MSSQL or Postgresql
			Return pool.GetConnection
			#Else
			Return DB
			#End If
	End Select
End Sub

#If DBF
' H2 database
Public Sub GetConnection2 As SQL
	H2.Initialize(DriverClass2, JdbcUrl2)
	Return H2
End Sub
#End If

Private Sub LoadQueries
	Dim queries As Map = File.ReadMap(File.DirAssets, "config.properties")
	If queries.IsInitialized Then
		commands.Initialize
		For Each Key As String In queries.Keys
			If Key.StartsWith(DBType & ".SQL.") Or Key.StartsWith("SQL.") Then
				commands.Put(Key, queries.Get(Key))
			End If
		Next
'		#If DEBUG
'		For Each Key As String In commands.Keys
'			Log(commands.Get(Key))
'		Next
'		#End If
	End If
End Sub

Public Sub CheckDatabase
	Try
		Dim DBFound As Boolean
		Log($"Checking database..."$)
		#If MSSQL
		DBType = "MSSQL"
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

		Dim config As Map = File.ReadMap(File.DirAssets, "config.properties")
		Select DBType
			Case "SQLite", "DBF", "Firebird"
				DBDir = config.Get(DBType & ".DBDir")
				DBFile = config.Get(DBType & ".DBFile")
				If DBDir.Trim = "" Then DBDir = File.DirApp
				If File.Exists(DBDir, DBFile) Then
					DBFound = True
				End If
			Case "MySQL", "MSSQL", "Postgresql"
				#If MySQL or MSSQL or Postgresql
				DBName = config.Get(DBType & ".DBName")
				JdbcUrl = config.Get(DBType & ".JdbcUrl")
				DriverClass = config.Get(DBType & ".DriverClass")
				User = config.Get(DBType & ".User")
				Password = config.Get(DBType & ".Password")
				#If MySQL or Postgresql
				Dim dbschema As String = "information_schema"
				#Else If MSSQL
				Dim dbschema As String = "master"
				#End If
				DB.Initialize2(DriverClass, JdbcUrl.Replace("{DBName}", dbschema), User, Password)
				If DB.IsInitialized Then
					LoadQueries
					Dim strSQL As String = GetCommand($"${DBType}.SQL.CHECK_DATABASE"$)
					Dim res As ResultSet = DB.ExecQuery2(strSQL, Array As String(DBName))
					Do While res.NextRow
						DBFound = True
					Loop
					res.Close
				End If
				#Else
				Return
				#End If
			Case Else
				Log($"Unable to check ${DBType}"$)
				Return
		End Select
		
		If DBFound Then
			Log("Database found!")
		Else
			Log("Creating database...")
			LoadQueries
			batch.Initialize
			Select DBType.ToLowerCase
				Case "sqlite"
					DB.InitializeSQLite(DBDir, DBFile, True)
					DB.ExecNonQuery("PRAGMA journal_mode = wal")
				Case "mysql", "mssql"
					ConAddSQLQuery(DB, $"${DBType}.SQL.CREATE_DATABASE"$)
					ConAddSQLQuery(DB, $"${DBType}.SQL.USE_DATABASE"$)
			End Select
			ConAddSQLQuery(DB, $"${DBType}.SQL.CREATE_TABLE_TBL_CATEGORY"$)
			ConAddSQLQuery(DB, $"SQL.INSERT_DUMMY_TBL_CATEGORY"$)
			ConAddSQLQuery(DB, $"${DBType}.SQL.CREATE_TABLE_TBL_PRODUCTS"$)
			ConAddSQLQuery(DB, $"SQL.INSERT_DUMMY_TBL_PRODUCTS"$)
			
'			#If DEBUG
'			For Each qry As String In batch
'				Log(qry)
'			Next
'			#End If
			
			Dim CreateDB As Object = DB.ExecNonQueryBatch("SQL")
			Wait For (CreateDB) SQL_NonQueryComplete (Success As Boolean)
			If Success Then
				Log("Database is created successfully!")
			Else
				Log("Database creation failed!")
			End If
			CloseDB
		End If
		Select DBType
			Case "MySQL", "MSSQL", "Postgresql"
				#If MySQL or MSSQL or Postgresql
				pool.Initialize(DriverClass, JdbcUrl.Replace("{DBName}", DBName), User, Password)
				#End If
		End Select
		Main.StartServer
	Catch
		LogError(LastException)
		CloseDB
		Log("Error creating database!")
		Log("Application is terminated.")
		ExitApplication
	End Try
End Sub

Private Sub CloseDB
	If DB <> Null And DB.IsInitialized Then DB.Close
End Sub

' Add common query to create database batch with key starts with SQL. or {DBType}.SQL.
Private Sub ConAddSQLQuery (Comm As SQL, Key As String)
	Dim strSQL As String = GetCommand(Key)
	strSQL = strSQL.Replace("{DBName}", DBName)
	Log(strSQL)
	'Comm.ExecNonQuery(strSQL) ' if not execute by batch (debug problematic query)
	If strSQL <> "" Then Comm.AddNonQueryToBatch(strSQL, Null)
	batch.Add(strSQL)
End Sub