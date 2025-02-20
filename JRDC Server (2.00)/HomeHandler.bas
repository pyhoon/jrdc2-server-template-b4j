B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=4.19
@EndOfDesignText@
'Handler class
Sub Class_Globals
	Private Connection As Boolean
End Sub

Public Sub Initialize

End Sub

Sub Handle (req As ServletRequest, resp As ServletResponse)
	TestConnection
	resp.ContentType = "text/html"
	resp.Write(Homepage)
End Sub

Sub TestConnection
	Try
		Dim Con As SQL = Main.rdcConnector1.GetConnection
		Con.Close
		#If DBF
		Dim Con As SQL = Main.rdcConnector1.GetConnection2
		Con.Close
		#End If
		Connection = True
	Catch
		Log(LastException.Message)
		Connection = False
	End Try
End Sub

Sub Homepage As String
	Dim ConnectionMessage As String
	If Connection Then
		ConnectionMessage = "Connection successful."
	Else
		ConnectionMessage = "Error fetching connection."
	End If
	Dim Html As String = $"<!DOCTYPE html>
<html>
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>jRDC2 - Remote Database Connector</title>
	<link rel="icon" type="image/png" href="img/favicon-32x32.png" sizes="32x32" />
	<link href="https://fonts.googleapis.com/css?family=Karla:400" rel="stylesheet" type="text/css">

	<style type="text/css">
		html, body {
			background: #fff;
			background-image: url(img/cover.jpg);
			background-repeat: no-repeat;
			background-size: cover;
			text-align: center;
			color: whitesmoke;
			font-family: 'Lato', sans-serif;
			height: 100%;
			width: 100%;
			margin: 0;
			padding: 0;
			display: table;
			font-weight: 100;
			font-family: 'Karla';
		}

		.container {
			text-align: center;
			display: table-cell;
			vertical-align: middle;
		}

		.content {
			text-align: center;
			display: inline-block;
		}

		a {
			color: #0000b4;
		}

		.logo {
			width: 200px;
			height: 200px;
			animation: fadeinout 5s linear forwards;
			animation-iteration-count: infinite;			
		}

		@keyframes fadeinout {
			0%, 100% {
				opacity: 0.1; 
			}
			50% {
				opacity: 1; 
			}
		}

		.title {
			font-size: 90px;
		}

		.info {
			color: #b4b4b4;
		}
	</style>
</head>
<body>	
	<div class="container">
		<div class="content">
			<img class="logo" src="img/B4X.png" />
			<div class="title" title="jRDC2">jRDC2</div>
			<div class="info"><br />            
			Database type: ${Main.rdcConnector1.DBType}<br/>
			${ConnectionMessage}<br />
			jRDC2 Server (Template version = ${NumberFormat2(Main.VERSION, 1, 2, 2, False)})<br />			
            RemoteServer is running ($DateTime{DateTime.Now})<br />            
            </div>
		</div>
	</div>
</body>
</html>
<!-- Html code modified from: https://linuxhint.com/make-an-element-fade-in-and-fade-out/ -->"$
	Return Html
End Sub