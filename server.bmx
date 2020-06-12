'Framework brl.blitz
Import brl.standardio
Import brl.stream
Import brl.socket
Import brl.linkedlist
Import brl.glmax2d

Import "imports/sfTCP.bmx"

SeedRnd MilliSecs()
Global currentLag = 0

?Threaded
Global networkMutex:TMutex = CreateMutex()
Global endInputThreadMutex:TMutex = CreateMutex()
Local thread:TThread = CreateThread(InputThread, "")
Global endInputThreadBool = False
Try
?' Not Threaded
AppTitle = "A Galaxy At War: Empires ::: Alpha Test ::: Server"
Graphics 480, 240
'?
server = New TServer.Create(TSocket.CreateTCP(), DEFAULTPORT)
If Not server.Start()
	Print(CurrentDate() + " " + CurrentTime() + " [INFO] Failed to start server")
	server = Null
Else
	TPrint "[INFO] Server Started on " + DEFAULTPORT
End If

? Not Threaded

curGame.gID = 102
If Not curGame.LoadFromFile()
	curGame.CreateStarfield(0, 0, 200, 100, 2)
'	curGame.CreateStarfield(0, 0, 50, 50)
	
	For Local num:Int = 0 To 10
		curGame.CreateStarfield(Rand(-100, 100), Rand(-100, 100), Rand(20, 30), Rnd(15, 35), 2)
	Next
		
	curGame.SaveToFile()
	TPrint "[INFO] Created new map"
EndIf
?

Global playGame = False
If curGame Then If curGame.players.Count() > 2 Then
	playGame = True
End If

Local serverUpdateTime:Int = MilliSecs(), msmax:Int, msmid:Float, lastServerStartTry%=MilliSecs()
While (Not AppTerminate()) And (Not endInputThreadBool)
?Threaded
	networkMutex.Lock()
?' Not Threaded
	serverUpdateTime = MilliSecs()
'?
	If server Then
		If server.m_socket Then server.Update()
	ElseIf MilliSecs()- lastServerStartTry > 5000
		lastServerStartTry = MilliSecs()
		server = New TServer.Create(TSocket.CreateTCP(), DEFAULTPORT)
		If Not server.Start()
			Print(CurrentDate() + " " + CurrentTime() + " [INFO] Failed to start server")
			server = Null
		Else
			TPrint "[INFO] Server Started on " + DEFAULTPORT+"!"
		End If
	EndIf
	
?Threaded
	networkMutex.Unlock()
? 'Not Threaded
	serverUpdateTime = MilliSecs() - serverUpdateTime
	If msmax < serverUpdateTime Then msmax = serverUpdateTime
	If serverUpdateTime > 0 Then msmid = (msmid + serverUpdateTime) / 2.0
	DrawText "UT: " + serverUpdateTime + "ms   H:" + msmax + " M:" + msmid, 0, 0
	If server Then
		Local printTime:Int = False
		If serverUpdateTime > 1000 Then TPrint "[WARNING] Unusual amount of time required for update! " + serverUpdateTime ; printTime = True
		
		If Not playGame Then SetColor 255,0,0
		DrawText "Players: " + server.m_clients.Count() + "    PG:" + playGame, 0, 16
		SetColor 255,255,255
		Local scCount:Int = 0
		For Local tc:TServerClient = EachIn server.m_clients
			Local tcPrint:String = tc.name
			DrawText tc.name, 24 + (scCount * 72), 16 * (2)
			For Local ii:Int = 0 Until server.hiccupChecks.Length Step 2
				If tc.hiccupChecks[ii] > tc.hiccupChecks[ii + 1] Then tc.hiccupChecks[ii + 1] = tc.hiccupChecks[ii] 'scCount
				DrawText ii + ":", 0, 16 * (3 + (ii))
				DrawText tc.hiccupChecks[ii], 24 + (scCount * 72), 16 * (3 + (ii))
				DrawText tc.hiccupChecks[ii + 1], 24 + (scCount * 72), 16 * (3 + (ii + 1))
				tcPrint:+" ,"+ii + "=" + tc.hiccupChecks[ii + 1]
			Next
			If printTime Then Print tcPrint
			scCount:+1
		Next
		
	End If
	
	
	If server Then
		Local xxtime:Float = (Int(MilliSecs() * 0.1) Mod GraphicsWidth())
		If server.gamePaused
			xxtime = 32
		EndIf
		DrawLine xxtime Mod (GraphicsWidth() / 16), 0, xxtime Mod (GraphicsWidth() / 16), 32
		DrawLine xxtime, 32, xxtime, GraphicsHeight()
	EndIf
	Flip;Cls
	
'	If KeyHit(KEY_SPACE) Then If playGame = False Then
'		playGame = True
'			TPrint "[INFO] Game Updates Resumed"
'	Else
'		playGame = False
'			TPrint "[INFO] Game Updates Stopped"
'	EndIf
'?Threaded
'	networkMutex.Lock()
'?
'	If server Then 
'		server.gamePaused = False
'		If playGame = False Then server.gamePaused = True
'	EndIf
'?Threaded
'	networkMutex.Unlock()
'?
	
	Delay currentLag ' Take some time for other things.
Wend
?Threaded
Catch e:Object
	TPrint "[ERROR] Exception: " + e.ToString()
End Try
?

?Threaded
If endInputThreadBool = False And thread.Running() Then
	endInputThreadMutex.Lock()
	endInputThreadBool = True
	endInputThreadMutex.Unlock()
EndIf
TPrint "[SERVER] Waiting for Input Thread to Die... (Press Enter!)"
thread.wait() '' Wait for it to DIE
?
If server Then server.Disconnect() ;TPrint "[INFO] Disconnected Properly!"
curGame.SaveToFile
End
''---------------'''------------------------'''''----------------------------'''-------------

?Threaded
Function InputThread:Object(data:Object)

	Local Getinput$ = Input(Data.ToString())
	While Lower(Getinput) <> "exit"
		LockMutex endInputThreadMutex
		If endInputThreadBool Then Exit
		UnlockMutex endInputThreadMutex
		
		Getinput:String = Input(data.ToString())
		Local cilentNames:String = ""
		Local command:String[] = Getinput.Split(" ")
		Print CurrentDate() + " " + CurrentTime() + ": " + Getinput
		Select Lower(command[0])
			Case "setlag"
				networkMutex.Lock()
				If command.Length > 1 Then currentLag = Int(command[1])
				If currentLag < 1 Then currentLag = 1
				If currentLag > 50 Then currentLag = 50
				networkMutex.Unlock()
				
			Case "setport"
				networkMutex.Lock()
				If command.Length > 1 Then DEFAULTPORT = Int(command[1])
				networkMutex.Unlock()
				
			Case "restart"
				networkMutex.Lock()
				TPrint "[SERVER] Restarting on port: " + DEFAULTPORT
				server = New TServer.Create(TSocket.CreateTCP(), DEFAULTPORT)
				If Not server.Start()
					Print(CurrentDate() + " " + CurrentTime() + " [INFO] Failed to start server")
					server = Null
				Else
					TPrint "[INFO] Server Started on " + DEFAULTPORT
				End If
				networkMutex.Unlock()
				
			Case "togglegame"
				networkMutex.Lock()
				If playGame = False Then
					playGame = True
					If server Then
						server.gamePaused = False
						server.lastUpdate = MilliSecs()
					EndIf
				Else
					playGame = False
					If server Then
						server.gamePaused = True
						server.lastUpdate = MilliSecs()
					EndIf
				EndIf
				
				If server Then
					If server.gamePaused Then
						TPrint "[INFO] Game Updates Stopped"
						playGame = False
					Else
						TPrint "[INFO] Game Updates Resumed"
						playGame = True
					End If
				End If
				networkMutex.Unlock()
				
			Case "loadgame"
				networkMutex.Lock()
				If command.Length = 2 Then
					curGame.SaveToFile()
					curGame = New TGame
					curGame.gID = Int(command[1])
					curGame.LoadFromFile()
				Else
					TPrint "[Game] Unrecongized command argument amount. Expecting 1 arguments"
				End If
				networkMutex.Unlock()
				
			Case "savegame"
				networkMutex.Lock()
				If command.Length = 2 Then
					curGame.gID = Int(command[1])
				EndIf
				curGame.SaveToFile()
				TPrint "[Saved]"
				networkMutex.Unlock()
				
			Case "createstarfield"
				networkMutex.Lock()
				Select command.Length
					Case 3
						curGame.CreateStarfield(0, 0, Int(command[1]), Float(command[2]))
					Case 4
						curGame.CreateStarfield(0, 0, Int(command[1]), Float(command[2]), Float(command[3]))
					Case 6
						curGame.CreateStarfield(Int(command[4]), Int(command[5]), Int(command[1]), Float(command[2]), Float(command[3]))
					Default
						TPrint "[Game] Unrecongized command argument amount. Expecting 3,4, or 6 arguments"
				End Select
				networkMutex.Unlock()
				
			Case "randomstarfield"
				networkMutex.Lock()
				
				Select command.Length
					Case 2
					'	curGame.CreateStarfield(0, 0, Int(command[1]), Float(command[2]))
						curGame.CreateStarfield(Rand(-Int(command[1]), Int(command[1])), Rand(-Int(command[1]), Int(command[1])), Rand(20, 30), Rnd(15, 35), 2)
						TPrint "[Game] Creating 1 variable random starfield"
					Case 6
					'	curGame.CreateStarfield(Int(command[4]), Int(command[5]), Int(command[1]), Float(command[2]), Float(command[3]))
						curGame.CreateStarfield(Rand(-Int(command[1]), Int(command[1])), Rand(-Int(command[1]), Int(command[1])), Rand(Int(command[2]), Int(command[3])), Rnd(Int(command[4]), Int(command[5])), 2)
						TPrint "[Game] Creating 5 variable random starfield"
					Default
						curGame.CreateStarfield(Rand(-100, 100), Rand(-100, 100), Rand(20, 30), Rnd(15, 35), 2)
						TPrint "[Game] Creating default random starfield"
				End Select
				networkMutex.Unlock()
			
			Case "say"
				networkMutex.Lock()
				server.SendBroadcast("[Server] " + Getinput.Replace(command[0] + " ", ""))
				networkMutex.Unlock()
				
			Case "newacc"
				networkMutex.Lock()
				If command.Length = 3 Then
					command[2] = MD5(command[2])
					command[1] = Account.cleanName(command[1])
					If Account.Find(command[1]) <> Null Then
						TPrint "[ERROR] Username '" + command[1] + "' already exists!"
					Else
						Account.Create(command[1], command[2])
						Account.SaveToFile()
						TPrint "[INFO] Added account '" + command[1] + "' with password '" + command[2] + "'!"
					End If
				Else
					TPrint "[ERROR] You can not pass more or less than 2 args to 'newacc'!"
				End If
				networkMutex.Unlock()
				
			Case "changepass"
				networkMutex.Lock()
				If command.Length = 3 Then
					command[2] = MD5(command[2])
					command[1] = Account.cleanName(command[1])
					If Account.Find(command[1]) <> Null Then
						Account.Find(command[1]).pass = command[2]
						Account.SaveToFile()
						TPrint "[INFO] Changed account's '" + command[1] + "' password to '" + command[2] + "'!"
					Else
						TPrint "[ERROR] Username '" + command[1] + "' doesn't exists!"
					End If
				Else
					TPrint "[ERROR] You can not pass more or less than 2 args to 'newacc'!"
				End If
				networkMutex.Unlock()
				
			Case "setstatus"
				networkMutex.Lock()
				If command.Length = 3 Then
					command[1] = Account.cleanName(command[1])
					If Account.Find(command[1]) <> Null Then
						Account.Find(command[1]).stat = Int(command[2])
						Account.SaveToFile()
						TPrint "[INFO] Changed account's '" + command[1] + "' status to '" + command[2] + "'!"
					Else
						TPrint "[ERROR] Username '" + command[1] + "' doesn't exists!"
					End If
				Else
					TPrint "[ERROR] You can not pass more or less than 2 args to 'setstatus'!"
				End If
				networkMutex.Unlock()
				
			Case "ban"
				networkMutex.Lock()
				If command.Length = 2 Then
					command[1] = Account.cleanName(command[1])
					If Account.Find(command[1]) <> Null Then
						Account.Find(command[1]).stat = -1'Int(command[2])
						Account.SaveToFile()
						TPrint "[INFO] Changed account's '" + command[1] + "' status to -1!"
					Else
						TPrint "[ERROR] Username '" + command[1] + "' doesn't exists!"
					End If
				Else
					TPrint "[ERROR] Invalid number of args sent to 'ban'!"
				End If
				networkMutex.Unlock()
				
			Case "kick"
				networkMutex.Lock()
				Local reason:String = ""
				If command.Length <= 3
					If command.Length = 3 Then reason = command[2]
					For Local Client:TServerClient = EachIn server.m_clients
						If Client.name.ToLower() = command[1].ToLower() Then
							server.Kick Client, reason
						End If
					Next
				Else
					TPrint "[ERROR] Invalid number of args sent to 'kick'!"
				End If
				networkMutex.Unlock()
				
			Case "list"
				networkMutex.Lock()
				For Client:TServerClient = EachIn server.m_clients
					cilentNames:+Client.name + " "
				Next
				TPrint "[INFO] " + server.m_clients.Count() + " Clients Connected: " + cilentNames
				networkMutex.Unlock()
				
			Case "alist"
				networkMutex.Lock()
				For Local acc:Account = EachIn Account.accountList
					cilentNames:+acc.name + " "
				Next
				TPrint "[INFO] #" + Account.accountList.Count() + " Accounts"
				Print cilentNames
				networkMutex.Unlock()
				
			Case "vlist"
				networkMutex.Lock()
				Local cnt:Int = 0
				For client:TServerClient = EachIn server.m_clients
					cnt:+1
					If Client.acc Then
						Print cnt + ": " + Client.name + "~t[Ping " + Client.pingDelta + "]~tAuth:" + Client.auth + "~tStatus:" + Client.acc.stat
					Else
						Print cnt + ": " + Client.name + "~t[Ping " + Client.pingDelta + "]~tAuth:" + Client.auth
					EndIf
				Next
				TPrint "[INFO] Clients Connected: " + server.m_clients.Count()
				networkMutex.Unlock()
		End Select
	Wend
	Print ""
	Print "[SERVER] Input Thread Finished"
	endInputThreadMutex.Lock()
	endInputThreadBool = True
	endInputThreadMutex.Unlock()
End Function
?