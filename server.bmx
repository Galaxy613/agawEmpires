Framework brl.standardio
Import brl.stream
Import brl.socket
Import brl.linkedlist
Import brl.FileSystem

Import "imports/sfTCP.bmx"
Import "imports/INI_Interface.bmx"

SeedRnd MilliSecs()
Global currentLag = 0

Global settingsIni:INI_File = OpenINI("server-settings.ini")

If FileSize("server-settings.ini") =< 0 Or FileType("server-settings.ini") = 0 Then
	Notify( "Creating 'server-settings.ini' and closing, edit it to change defaults." )
	settingsIni.set("game_id", "100", "game")
	settingsIni.set("server_port", DEFAULTPORT, "network")
	
	settingsIni.save("server-settings.ini")
	End
EndIf

?Threaded
Global networkMutex:TMutex = CreateMutex()
Global endInputThreadMutex:TMutex = CreateMutex()
Local thread:TThread = CreateThread(InputThread, "")
Global endInputThreadBool = False
Try
?' Not Threaded
AppTitle = "A Galaxy At War: Empires ::: Alpha Test 2 ::: Server"
Graphics 480, 240
'?
server = New TServer.Create(TSocket.CreateTCP(), DEFAULTPORT)
If Not server.Start()
	Print(CurrentDate() + " " + CurrentTime() + " [START] Failed to start server")
	server = Null
Else
	TPrint "[START] Server Started on " + DEFAULTPORT
End If

curGame.gID = settingsIni.GetInteger("game_id", "game")
If Not curGame.LoadFromFile()
	TPrint "[START] Map does not exist for game ID: " + curGame.gID
	TPrint "[START] Please use the createstarfield and/or randomstarfield commands to create the map before users connect."
Else
	TPrint "[START] Successfully loaded map for game ID: " + curGame.gID
EndIf

server.gamePaused = True
If curGame Then If curGame.players.Count() > 2 Then
	server.gamePaused = False
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
		
		If server.gamePaused Then SetColor 255,0,0
		DrawText "Players: " + server.m_clients.Count() + "    Paused:" + server.gamePaused, 0, 16
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
settingsIni.save("server-settings.ini")
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
		Local Client:TServerClient
		Print CurrentDate() + " " + CurrentTime() + ": " + Getinput
		Select Lower(command[0])
			Case "help"
				networkMutex.Lock()
				If command.Length > 1 Then
					Select Lower(command[1])
					Case "exit"
						TPrint "exit"
						TPrint "Description: Exits the server safely."
					Case "setlag"
						TPrint "setLag lagMs"
						TPrint "Description: Set the milliseconds between server ticks."
					Case "setport"
						TPrint "setPort port"
						TPrint "Description: Set the server's port. Will NOT automatically restart the server."
					Case "restart"
						TPrint "restart"
						TPrint "Description: Restarts the server."
					Case "togglegame"
						TPrint "toggleGame"
						TPrint "Description: Toggles whether the game is paused."
					Case "loadgame"
						TPrint "loadGame gameId"
						TPrint "Description: Saves the current game ID and loads the given game ID."
					Case "savegame"
						TPrint "saveGame [gameId]"
						TPrint "Description: Saves the current game ID or if given a different game ID, sets the game ID and then saves."
					Case "createstarfield"
						TPrint "createStarfield numOfStars:Int, maxDist:Float, [minDist:Float = 5, [x = 0, y = 0]]"
						TPrint "Description: Creates a blob of stars around x and y."
					Case "randomstarfield"
						TPrint "randomStarfield [maxPostitionOffset, [minNumberOfStars, maxNumberOfStars, minMaxDist, maxMaxDist]]"
						TPrint "Description: Creates a random blob of stars. Defaults to maxPostitionOffset=100, minNumberOfStars=20, maxNumberOfStars=30, minMaxDist=15, maxMaxDist=35"
					Case "creategalaxy" 
						TPrint "createGalaxy -- NOT IMPLEMENTED" ''' TODO #11
						Continue ' CreateGalaxy(tType:Int, xx:Int = 0, yy:Int = 0)
						TPrint "Description: "
					Case "say"
						TPrint "say [...]"
						TPrint "Description: Broadcasts whatever you want to say to all users."
					Case "newacc"
						TPrint "newAcc username, password"
						TPrint "Description: Registers a new account. Password will automatically be encoded with MD5."
					Case "changepass"
						TPrint "changePass username, password"
						TPrint "Description: Overwrites the given username's password. Password will automatically be encoded with MD5."
					Case "setstatus"
						TPrint "setStatus username, status:Int"
						TPrint "Description: Sets the status of the given username. Known status: -1 Banned, 0 Normal, 1337 Admin"
					Case "ban"
						TPrint "ban username"
						TPrint "Description: Bans the given user and kicks them."
					Case "kick"
						TPrint "kick username"
						TPrint "Description: Kicks the given user from the server."
					Case "list"
						TPrint "list"
						TPrint "Description: Lists currently connected users."
					Case "alist"
						TPrint "aList"
						TPrint "Description: Lists the currently registered users."
					Case "vlist"
						TPrint "vList"
						TPrint "Description: Verbose version of 'list'."
					' Case ""
					' 	TPrint ""
					' 	TPrint "Description: "
					Default
						TPrint "Unrecognized command: "+command[1]
					EndSelect
				Else
					Local cmds : String = ""
					cmds = cmds + "exit" + ", "
					cmds = cmds + "setLag" + ", "
					cmds = cmds + "setPort" + ", "
					cmds = cmds + "restart" + ", "
					cmds = cmds + "toggleGame" + ", "
					cmds = cmds + "loadGame" + ", "
					cmds = cmds + "saveGame" + ", "
					cmds = cmds + "createStarfield" + ", "
					cmds = cmds + "randomStarfield" + ", "
					'cmds = cmds + "createGalaxy" + ", " ' TODO #11
					cmds = cmds + "say" + ", "
					cmds = cmds + "newAcc" + ", "
					cmds = cmds + "changePass" + ", "
					cmds = cmds + "setStatus" + ", "
					cmds = cmds + "ban" + ", "
					cmds = cmds + "kick" + ", "
					cmds = cmds + "list" + ", "
					cmds = cmds + "aList" + ", "
					cmds = cmds + "vList"
					
					TPrint "Commands: " + cmds
				EndIf
				
				networkMutex.Unlock()
			
			Case "setlag"
				networkMutex.Lock()
				If command.Length > 1 Then currentLag = Int(command[1])
				If currentLag < 1 Then currentLag = 1
				If currentLag > 50 Then currentLag = 50
				networkMutex.Unlock()
				
			Case "setport"
				networkMutex.Lock()
				If command.Length > 1 Then
					DEFAULTPORT = Int(command[1])
					settingsIni.set("server_port", DEFAULTPORT, "network")
				EndIf
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
				If server Then
					networkMutex.Lock()
					If server.gamePaused = False Then
						server.gamePaused = True
						TPrint "[INFO] Game Updates Stopped"
					Else
						server.gamePaused = False
						TPrint "[INFO] Game Updates Resumed"
					EndIf
					server.lastUpdate = MilliSecs()
					networkMutex.Unlock()
				EndIf
				
			Case "loadgame"
				networkMutex.Lock()
				If command.Length = 2 Then
					curGame.SaveToFile()
					curGame = New TGame
					curGame.gID = Int(command[1])
					settingsIni.set("game_id", curGame.gID, "game")
					curGame.LoadFromFile()
				Else
					TPrint "[Game] Unrecongized command argument amount. Expecting 1 arguments"
				End If
				networkMutex.Unlock()
				
			Case "savegame"
				networkMutex.Lock()
				If command.Length = 2 Then
					curGame.gID = Int(command[1])
					settingsIni.set("game_id", curGame.gID, "game")
				EndIf
				curGame.SaveToFile()
				TPrint "[Saved]"
				networkMutex.Unlock()
				
			Case "createstarfield" ' numOfStars:Int, maxDist:Float, [minDist:Float = 5, [x, y]]
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
				
			Case "ban" ' Ban given username for reason
				networkMutex.Lock()
				If command.Length = 2 Then
					command[1] = Account.cleanName(command[1])
					If Account.Find(command[1]) <> Null Then
						Account.Find(command[1]).stat = -1
						Account.SaveToFile()
						For Client = EachIn server.m_clients
							If Client.name.ToLower() = command[1].ToLower() Then
								server.Kick Client, "Banned"
							End If
						Next
						TPrint "[INFO] Changed account's '" + command[1] + "' status to -1!"
					Else
						TPrint "[ERROR] Username '" + command[1] + "' doesn't exists!"
					End If
				Else
					TPrint "[ERROR] Invalid number of args sent to 'ban'!"
				End If
				networkMutex.Unlock()
				
			Case "kick" ' Kick given username
				networkMutex.Lock()
				Local reason:String = ""
				If command.Length <= 3
					If command.Length = 3 Then reason = command[2]
					For Client = EachIn server.m_clients
						If Client.name.ToLower() = command[1].ToLower() Then
							server.Kick Client, reason
						End If
					Next
				Else
					TPrint "[ERROR] Invalid number of args sent to 'kick'!"
				End If
				networkMutex.Unlock()
				
			Case "list" ' list currently connected client names
				networkMutex.Lock()
				For Client:TServerClient = EachIn server.m_clients
					cilentNames:+Client.name + " "
				Next
				TPrint "[INFO] " + server.m_clients.Count() + " Clients Connected: " + cilentNames
				networkMutex.Unlock()
				
			Case "alist" ' account list
				networkMutex.Lock()
				For Local acc:Account = EachIn Account.accountList
					cilentNames:+acc.name + " "
				Next
				TPrint "[INFO] #" + Account.accountList.Count() + " Accounts"
				Print cilentNames
				networkMutex.Unlock()
				
			Case "vlist" ' verbose list of currently connected client names
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