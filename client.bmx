Strict

Import "imports/sfTCP.bmx"
Import "imports/clientChatDisplay.bmx"
Import "imports/RequestText.bmx"
Import "imports/INI_Interface.bmx"

Incbin "OCRAEXT.TTF"
Incbin "art/BottomLeftPanel.png"
Incbin "art/menubutton.png"
Incbin "art/menubutton_down.png"
Incbin "art/topBar.png"
Incbin "art/windowbackground.png"

Global mainChat:sChatHandler = New sChatHandler
Global attacheUpdates:sChatHandler = New sChatHandler

Global settingsIni:INI_File = OpenINI("settings.ini")

If FileType("settings.ini") = 0 Then
	Notify( "Setting resolution to 1280x720. Modify your settings by opening 'settings.ini'!" )
	
	settingsIni.set("screen_width", 1280, "graphics")
	settingsIni.set("screen_height", 720, "graphics")
	settingsIni.set("server_ip", "127.0.0.1", "network")
	settingsIni.set("server_port", DEFAULTPORT, "network")
	
	settingsIni.save("settings.ini")
EndIf

scnx = settingsIni.GetInteger( "screen_width", "graphics" )
scny = settingsIni.GetInteger( "screen_height", "graphics" )
mainChat.NewVariable("server_ip", settingsIni.GetString( "server_ip", "network" ))
mainChat.NewVariable("port", settingsIni.GetString( "server_port", "network" ))
Local screenMode:int = 0
If settingsIni.ItemExists("screen_mode", "graphics") Then
	screenMode = settingsIni.GetInteger( "screen_mode", "graphics" )
Else
	settingsIni.set("screen_mode", screenMode, "graphics")
EndIf

AppTitle = "A Galaxy At War: Empires ::: Alpha Test 2 ::: Client"

Graphics(scnx, scny, screenMode)
SetBlend ALPHABLEND
mainChat.enabled = False
Global stdFont:TImageFont = LoadImageFont("incbin::OCRAEXT.TTF", 12)
Global medFont:TImageFont = LoadImageFont("incbin::OCRAEXT.TTF", 24)
Global lrgFont:TImageFont = LoadImageFont("incbin::OCRAEXT.TTF", 32)
SetImageFont stdFont
'''' Login Stuffs
Global usernameCH:sTextBox = New sTextBox
Global passwordCH:sTextBox = New sTextBox
usernameCH.Prompttxt = "Username: "
usernameCH.currentString = ""
If settingsIni.ItemExists("user_name") Then
	usernameCH.currentString = settingsIni.GetInteger( "user_name" )
EndIf
If usernameCH.currentString Then
	passwordCH.enabled = True
Else
	usernameCH.enabled = True
End If
passwordCH.Prompttxt = "Password: "
passwordCH.isPassword = True

Global menuBars:TImage[] = [LoadImage("incbin::art/topBar.png"), LoadImage("incbin::art/menubutton.png"), LoadImage("incbin::art/menubutton_down.png"), LoadImage("incbin::art/windowbackground.png")]

Global mouseDragging = False
Global selectedSystem:TSystem = Null, targetSystem:TSystem = Null, selectedShips:Int = 0, selectedFleet:TFleet = Null, totalships = 0
Global bottomLeftWindow:Int = 0, topLeftChat:Int = 0

Global wasConnected = False, justConnected = False, justFinishedFirstSync = False, hasFinishedFirstSync = False
If Not Connect(mainChat.GetVariable("server_ip".tolower())._var, Int(mainChat.GetVariable("port")._var)) Then
	client = Null
EndIf

Global midDrag = False, dragX:Int = 0, dragY:Int = 0
Global lastConnectTry:Int = MilliSecs() ' lastConnectTry = MilliSecs()

TerritorySquare.CreateGrid(50, 4)

Global tgEnabled = True
Global currentScreen:Int = 0

DoMain

If client Then
	If client.Connected() Then client.SendPacket(Packet.ID_MESSAGESELF, "says Goodbye!")
	client.Close()
End If
settingsIni.save("settings.ini")
End '''''''''''''''''''''```````````'`'`'`'`'`''`'`''`''`'`''`'`'`''`````'`'`'`'`'`''`'`''`''`'`''`'`'`''`````'`'`'`'`'`''`'`''`''`'`''`'`'`''`

Function DoMain()
	While Not AppTerminate() And Not KeyHit(KEY_ESCAPE)
		UpdateInput()
		
		If client Then
			UpdateClient()
		Else
			If wasConnected Then
				mainChat.add("[ERROR] You have been disconnected for some reason!", 1)
				wasConnected = False
			End If
		End If
	
		Select currentScreen
			Case 0
				DoLoginScreen
				If client Then
					If client.auth Then
						If client.totalSystems = curGame.systems.Count()
							currentScreen = 1
							ProcessChatCommand("help", "")
						Else
							currentScreen = 2
							hasFinishedFirstSync = False
						End If
					EndIf
					If Not client.Connected() Then client.Close() ; client = Null ; lastConnectTry = MilliSecs()
				Else
					If lastConnectTry - MilliSecs() < - 5000 Then If Not Connect(mainChat.GetVariable("server_ip".tolower())._var,  ..
							Int(mainChat.GetVariable("port")._var)) Then
							client = Null
							lastConnectTry = MilliSecs()
						EndIf
				EndIf
		
			Case 1
				DrawGameScreen()
				UpdateGameScreen()
				If Not client Then
					currentScreen = 0
				Else
					If Not client.auth Then currentScreen = 0
					If Not client.Connected() Then
						client.Close()
						client = Null
						currentScreen = 0
						lastConnectTry = MilliSecs()
					
						selectedShips = 0
						selectedSystem = Null
						selectedFleet = Null
						'curGame = New TGame
					'	curGame.fleets = CreateList()
					'	curGame.systems = CreateList()
					EndIf
				EndIf
		
			Case 2
				DoSyncScreen()
				If Not client Then
					currentScreen = 0
				Else
					If Not client.auth Then currentScreen = 0
					If Not client.Connected() Then client.Close() ; client = Null ; currentScreen = 0;lastConnectTry = MilliSecs()
				
					If curGame.systems.Count() = client.totalSystems And curGame.fleets.Count() = client.totalFleets And curGame.players.Count() = client.totalPlayers Then
						currentScreen = 1
					Else
						If Not client.IsSyncingTGame Then
							client.SendPacket(Packet.ID_UPDATEALL, "plz")
						End If
					EndIf
				EndIf
		
		End Select
	
		''' Ping/Sync Info
		DrawImage(menuBars[(client <> Null) + 1], scnx - 80, -8)
		DrawPing(scnx - 56, 6)
		DrawSync(scnx - 56 - 16, 6)
		If tb.PointIn.MouseInRect(scnx - 80, 0, 80, 24) And client Then
			If client.IsSyncingTGame Then
				DrawText "Syncing now...", scnx - 128, 32
			Else
				DrawText "Last Sync:" + Int((MilliSecs() - client.lastSync) / 1000) + "s", scnx - 128, 32
			End If
		EndIf
		'	DrawText("MSZ: " + MouseZ() + " MSZS:" + MouseZSpeed(), scnx / 2, 4 + 16)
	
		Flip;Cls
	Wend
End Function

Function UpdateClient()
	wasConnected = True
	justFinishedFirstSync = False
	client.finishedSyncingThisFrame = False
	client.Update()
	If client.finishedSyncingThisFrame Then
		If tgEnabled Then TerritorySquare.UpdateAll() ; TerritoryMesh.UpdateAll()
		If Not hasFinishedFirstSync Then hasFinishedFirstSync = True ; justFinishedFirstSync = True ; currentScreen = 1
	End If
		
	If client.recievedMessages.Count() > 0
		Local tmpStr:String = String(client.recievedMessages.RemoveFirst())
		If tmpStr.Contains("`") Then
			mainChat.add(tmpStr.Split("`")[0], Int(tmpStr.Split("`")[1]))
		Else
			mainChat.add(tmpStr)
		EndIf
	EndIf
		
	If client.attacheUpdates.Count() > 0 Then
		Local tmpStr:String = String(client.attacheUpdates.RemoveFirst())
		If tmpStr.Contains("`") Then
			attacheUpdates.add(tmpStr.Split("`")[0], Int(tmpStr.Split("`")[1]))
		Else
			attacheUpdates.add(tmpStr)
		EndIf
	End If
		
	If MilliSecs() - client.lastPingRecv > 60 * 1000 And MilliSecs() - client.lastPingSent > 4 * 1000 Then
		mainChat.add("[ERROR] Server Timeout! Haven't heard from the server in the last 60 seconds...", 1)
		client.Close()
		client = Null
		wasConnected = False
	ElseIf MilliSecs() - client.lastPingRecv > 5 * 1000 And MilliSecs() - client.lastPingSent > 4 * 1000 Then
		client.SendPing()
	EndIf
End Function

Function DoLoginScreen()
	Local tmpX = scnx / 2 - 240
	Local tmpY = scny / 2

	usernameCH.SetPosition(tmpX + 16, tmpY + 24)
	passwordCH.SetPosition(tmpX + 16, tmpY + 64)
	
	If KeyHit(KEY_ENTER) And client Then
		If usernameCH.currentString = "" Then
			usernameCH.enabled = True
			passwordCH.enabled = False
		ElseIf passwordCH.currentString = "" Then
			passwordCH.enabled = True
			usernameCH.enabled = False
		End If
		If usernameCH.currentString <> "" And passwordCH.currentString <> "" Then
			client.SendLogin(usernameCH.currentString, passwordCH.currentString)
			settingsIni.set("user_name", usernameCH.currentString)
			passwordCH.currentString = ""
			usernameCH.enabled = False
			passwordCH.enabled = False
		End If
	End If
	
	If KeyHit(KEY_TAB)
		If usernameCH.enabled Then
			passwordCH.enabled = True
			usernameCH.enabled = False
		ElseIf passwordCH.enabled
			passwordCH.enabled = False
			usernameCH.enabled = True
		End If
	End If
	
	SetImageFont medFont
	Local usernameSelected:Int = usernameCH.CheckInput()
	Local passwordSelected:Int = passwordCH.CheckInput()
	If usernameCH.enabled = False And passwordCH.enabled = False Then GetChar()
	SetImageFont stdFont
	If usernameSelected
		usernameCH.enabled = True
		passwordCH.enabled = False
	ElseIf passwordSelected
		usernameCH.enabled = False
		passwordCH.enabled = True
	Else
		If msh[1] Then
			usernameCH.enabled = False
			passwordCH.enabled = False
		End If
	End If
	
	SetLineWidth 32
	SetAlpha 0.1
	SetColor 96, 96, 128
	tb.Draw.Circle(scnx / 2, scny / 2, scny / 3, scny / 8)
	tb.Draw.Circle(scnx / 2, scny / 2, ((Sin((MilliSecs() * 0.2)) Mod 360) * (8 * (1 + (client <> Null)))) + (scny / 3), scny / 8)
	SetColor 255, 255, 255
	SetLineWidth 1
	SetAlpha 0.05
	mainChat.DrawList(0, 0, 1)
	SetAlpha 0.9
	SetImageFont lrgFont
	tb.Draw.CenteredText("A Galaxy At War: Empires", scnx / 2, scny / 2 - 128)
	tb.Draw.CenteredText("Alpha Test", scnx / 2, scny / 2 - 128 + 32)
	
	'DrawRect tmpX, tmpY, 320, 128
	DrawImageRect(menuBars[3], tmpX - 4, tmpY - 4, 480 + 8, 128 + 8)
	SetColor 96, 96, 128
	DrawImageRect(menuBars[3], tmpX, tmpY, 480, 128)
	SetColor 255, 255, 255
	SetAlpha 1.0
		
	SetImageFont medFont
	usernameCH.Draw()
	passwordCH.Draw()
	
	SetImageFont stdFont
	If client
		SetColor 97, 255, 97
		tb.Draw.CenteredText "Connected to " + mainChat.GetVariable("server_ip".tolower())._var + ":" + Int(mainChat.GetVariable("port")._var), scnx / 2, tmpY - 32
	Else
		SetColor 255, 97, 97
		tb.Draw.CenteredText "Connecting to " + mainChat.GetVariable("server_ip".tolower())._var + ":" + Int(mainChat.GetVariable("port")._var), scnx / 2, tmpY - 32
	End If
	SetColor 255, 255, 255
End Function

Function DoSyncScreen()
	Local tmpX = scnx / 2
	Local tmpY = scny / 2
	
	SetLineWidth 32
	SetAlpha 0.1
	SetColor 96, 96, 128
	tb.Draw.Circle(tmpX, tmpY, scny / 3, scny / 8)
	tb.Draw.Circle(tmpX, tmpY, ((Sin((MilliSecs() * 0.2)) Mod 360) * (24 * (1 + (client <> Null)))) + (scny / 3), scny / 8)
	SetColor 255, 255, 255
	SetLineWidth 1
	SetAlpha 0.05
	mainChat.DrawList(0, 0, 1)
	SetAlpha 0.9
	SetImageFont lrgFont
	tb.Draw.CenteredText("A Galaxy At War: Empires", scnx / 2, scny / 2 - 128)
	tb.Draw.CenteredText("Alpha Test", scnx / 2, scny / 2 - 128 + 32)
	
	SetColor 255, 255, 255
	SetAlpha 1.0
		
	SetImageFont medFont
	tb.Draw.CenteredText("Syncing With Server...", tmpX, tmpY)
	If client Then
		If client.totalSystems > - 1 Then
			Local tmpPercent:Float = Float(curgame.systems.Count() + curGame.players.Count()) / (Float(client.totalSystems) + Float(client.totalPlayers))
			tb.Draw.CenteredText(Int(tmpPercent * 100) + "%", tmpX, tmpY + 32)
			SetImageFont stdFont
			tb.Draw.CenteredText("Systems: " + curGame.systems.Count() + " / " + client.totalSystems, tmpX, tmpY + 48 + (16 * 2))
		'	tb.Draw.CenteredText("Fleets: " + curGame.fleets.Count() + " / " + client.totalFleets, tmpX, tmpY + 48 + (16 * 2))
			tb.Draw.CenteredText("Players: " + curGame.players.Count() + " / " + client.totalPlayers, tmpX, tmpY + 48 + (16 * 3))
		End If
	End If
	
	SetImageFont stdFont
	If client
		SetColor 97, 255, 97
		tb.Draw.CenteredText "Connected to " + mainChat.GetVariable("server_ip".tolower())._var + ":" + Int(mainChat.GetVariable("port")._var), tmpX, tmpY - 32
	End If
	SetColor 255, 255, 255
End Function

Function UpdateGameScreen()

	If UpdateTopLeft()
		GetChar
		
		If KeyHit(KEY_ENTER) Then mainChat.enabled = True
		If KeyHit(KEY_SLASH) Then mainChat.enabled = True; mainChat.currentString = "/"
		
		Local tmp:Int = MouseZSpeed()
		If tmp = 0 Then tmp = KeyHit(KEY_2) - KeyHit(KEY_1)
		If tmp = 0 Then tmp = KeyHit(KEY_EQUALS) - KeyHit(KEY_MINUS)
		If tmp < 0 Then
			If Not (MAP_SCALE = 4) Then
				currentXPan:/2
				currentYPan:/2
			End If
			If MAP_SCALE = 8 Then MAP_SCALE = 4
			If MAP_SCALE = 16 Then MAP_SCALE = 8
			If MAP_SCALE = 32 Then MAP_SCALE = 16
			If MAP_SCALE = 64 Then MAP_SCALE = 32
			ElseIf tmp > 0 Then
				If Not (MAP_SCALE = 64) Then
					currentXPan:*2
					currentYPan:*2
				End If
				If MAP_SCALE = 32 Then MAP_SCALE = 64
				If MAP_SCALE = 16 Then MAP_SCALE = 32
				If MAP_SCALE = 8 Then MAP_SCALE = 16
				If MAP_SCALE = 4 Then MAP_SCALE = 8
				If MAP_SCALE = 2 Then MAP_SCALE = 4
		EndIf
		
		If KeyHit(KEY_F3) Then
			currentXPan = 0
			currentYPan = 0
			MAP_SCALE = 2
		End If
		
		'	If client Then
		currentYPan:+(KeyDown(KEY_DOWN) - KeyDown(KEY_UP)) * (MAP_SCALE / 4) * (tb.KeysDown(KEY_RSHIFT, KEY_LSHIFT) * 2 + 1)
		currentXPan:+(KeyDown(KEY_RIGHT) - KeyDown(KEY_LEFT)) * (MAP_SCALE / 4) * (tb.KeysDown(KEY_RSHIFT, KEY_LSHIFT) * 2 + 1)
		'		currentYPan:+(KeyDown(KEY_S) - KeyDown(KEY_W)) * (MAP_SCALE / 4) * (tb.KeysDown(KEY_RSHIFT, KEY_LSHIFT) * 2 + 1)
		'		currentXPan:+(KeyDown(KEY_D) - KeyDown(KEY_A)) * (MAP_SCALE / 4) * (tb.KeysDown(KEY_RSHIFT, KEY_LSHIFT) * 2 + 1)
		If KeyHit(KEY_HOME) Or KeyHit(KEY_SPACE) Then If client Then If client.ply Then
					If Not client.ply.homeSystem Then client.ply.homeSystem = curGame.FindSystemID(client.ply.homeSystemID)
					currentXPan = client.ply.homeSystem.x * MAP_SCALE
					currentYPan = client.ply.homeSystem.Y * MAP_SCALE
					'currentXPan = 0 ; currentYPan = 0
				EndIf
		If justFinishedFirstSync Then If client Then If client.ply Then
					If Not client.ply.homeSystem Then client.ply.homeSystem = curGame.FindSystemID(client.ply.homeSystemID)
					currentXPan = client.ply.homeSystem.x * MAP_SCALE
					currentYPan = client.ply.homeSystem.Y * MAP_SCALE
				EndIf
		If KeyHit(KEY_F)
			Local result:String = RequestText("Find System", "Enter System ID #")
			If result <> "" Then
				selectedSystem = curGame.FindSystemID(Int(result))
				currentXPan = selectedSystem.x * MAP_SCALE
				currentYPan = selectedSystem.Y * MAP_SCALE
				selectedFleet = Null
				targetSystem = Null
				selectedShips = 0
				bottomLeftWindow = 0
			End If
		End If
		'	EndIf
	End If
	
	'''''''''''''''''''' Update drag stuff
	If midDrag And Not msd[1] Then
		midDrag = False
		currentXPan:-(MouseX() - dragX)
		currentYPan:-(MouseY() - dragY)
	End If
	
	If msh[1] Then
		selectedShips = 0
		selectedSystem = Null
		selectedFleet = Null
		If msd[1] Then
			If Not midDrag Then
				midDrag = True
				dragX = MouseX()
				dragY = MouseY()
			End If
		End If
	EndIf
	tb.FlushKeyHits()
End Function

Function DrawGameScreen()
	Const TerritorySquareDepth:Float = 0.95
	'''''''''''''''''
	''' Draw Systems and Fleets
	If KeyHit(KEY_F5) Then TerritorySquare.UpdateAll() ; TerritoryMesh.UpdateAll() ;tgEnabled = True
	If KeyHit(KEY_F6) Then tgEnabled = False
	DrawBottomLeftWindow()
	Cls
	If Not midDrag Then
		SetOrigin Int((scnx / 2) - currentXPan), Int((scny / 2) - currentYPan)
	Else
		SetOrigin Int((scnx / 2) - currentXPan + (MouseX() - dragX)), Int((scny / 2) - currentYPan + (MouseY() - dragY))
	EndIf
	If tgEnabled Then
		SetLineWidth(3)
		TerritorySquare.DrawAll()
		TerritoryMesh.DrawAll()
		SetLineWidth(1)
	EndIf
	DrawGalaxyGrid
	totalships = 0
	DrawGalaxyMap
	SetOrigin(0, 0)
	
	'	If client Then
	If targetSystem And selectedSystem Then
		If selectedShips > 0 Then
			If tb.Draw.ClickableText("Click Here to Send (S)hips: " + selectedShips,  ..
				(targetSystem.x * MAP_SCALE) + (scnx / 2) - currentXPan,  ..
				(targetSystem.y * MAP_SCALE) - (MAP_SCALE * 2.1) + (scny / 2) - currentYPan,  ..
				False, True, True) Or KeyHit(KEY_S) Then ' And msh[1] Then
				msh[1] = 0
				client.SendPacket(Packet.ID_CMDSENDFLEET, selectedSystem.netID + "`" + targetSystem.netID + "`" + selectedShips)
				selectedShips = 0
				targetSystem = Null
			End If
		EndIf
	EndIf
	'	EndIf
	
	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	''' Draw GUI
	SetAlpha 1.0
	
	''' /System/ bars
	SetColor 192, 192, 255
	DrawImageRect(menuBars[0], 0, 0, scnx, menuBars[0].Height)
	DrawImageRect(menuBars[0], 0, scny - menuBars[0].Height, scnx, menuBars[0].Height)
	SetColor 255, 255, 255
	
	''' Time '' (2900.0 + (curGame.CurrentTurn * 0.1))
	DrawImage(menuBars[(client <> Null) + 1], scnx - 96 - 8, scny - menuBars[1].Height + 8)
	DrawText "Year: " + curGame.GetYear(), scnx - 96, scny - menuBars[1].Height + 16
	
	DrawTopLeft
		
	''' sys/flt Counts
	If Not client Then
		tb.Draw.TextOutline("System Count: " + curGame.systems.Count(), (scnx - 216), 4)
		tb.Draw.TextOutline("Fleet Count: " + curGame.fleets.Count(), (scnx - 216 - 128), 4)
	Else
		If client.ply Then
			tb.Draw.TextOutline("Systems: " + curGame.CountOwnedSystems(client.ply.netID), (scnx - 216), 4)
			tb.Draw.TextOutline("Fleets: " + curGame.CountOwnedFleets(client.ply.netID), (scnx - 216 - 100), 4)
			If totalships > 0 Then tb.Draw.TextOutline("Ships: " + totalships, (scnx - 216 - 100 * 2), 4)
			Else
				tb.Draw.TextOutline("System Count: " + curGame.systems.Count(), (scnx - 216), 4)
			tb.Draw.TextOutline("Fleet Count: " + curGame.fleets.Count(), (scnx - 216 - 128), 4)
		EndIf
	EndIf
	
	DrawBottomLeftWindow()
	
	''' Credits bar
	If client Then If client.ply Then
			'''' Research
			If client.ply.researchAspect > - 1 And client.ply.untilNextDecimal > 0 Then
				SetColor 0, 32, 0
				DrawImage menuBars[1], (scnx / 2) - (menuBars[1].width / 2), 4
				SetColor 0, 232, 0
				tb.Draw.ImageProgress menuBars[1], (scnx / 2) - (menuBars[1].width / 2), 4, (Float(client.ply.currentResearchTurn) / Float(client.ply.untilNextDecimal))
				SetColor 255, 255, 255
			EndIf
		
			SetColor 255, 255, 255
			DrawImage menuBars[1], (scnx / 2) - (menuBars[1].width / 2), -4
			SetColor 0, 0, 0
			'tb.Draw.CenteredText("Credits: " + tb.Math.LimitDenom(client.ply.credits), (scnx / 2), 0)
			'tb.Draw.CenteredText("Ship Cost:" + tb.Math.LimitDenom(10 + (5.0 * (client.ply.researchTopics[TPlayer.RES_FLEETSPEED])) + (15.0 * (client.ply.researchTopics[TPlayer.RES_FLEETWEAPONS]))), (scnx / 2), 16)
			tb.Draw.CenteredText("Ship Build Time:", (scnx / 2), 0)
			Local buildTurns:Int = Int(30.0 - (client.ply.researchTopics[TPlayer.RES_SHIPBUILDING]) - (client.ply.researchTopics[TPlayer.RES_RESEARCH] * 0.25))
			If buildTurns < 5 Then buildTurns = 5
			tb.Draw.CenteredText(tb.Math.LimitTime(buildTurns * (GAME_TICK_TIME * 0.001)) + " / " + tb.Math.LimitDecimal(buildTurns * 0.1) + " yr", (scnx / 2), 16)
			'16 - Int(ply.researchTopics[TPlayer.RES_SHIPBUILDING])
			SetColor 255, 255, 255
		
			If client.ply.researchAspect > - 1 Then tb.Draw.CenteredText(client.ply.GetResearchTopicName(client.ply.researchAspect, False) + " " + Int((Float(client.ply.currentResearchTurn) / Float(client.ply.untilNextDecimal)) * 100) + "%", (scnx / 2), menuBars[1].Height - 8)
		EndIf
End Function

Function Connect(ip:String, port:Int)
	If client Then Return False
	client = New TMasterClient.Create(TSocket.CreateTCP())
	If client.Connect(HostIp(ip), port) Then
		Print "Connected to Server!"
		'	client.SendText("Hello World!")
		client.SendPacket(Packet.ID_UPDATEALL, "plz")
		mainChat.add("[INFO] Connected to Server!", 2)
	Else
		'Notify "Failed to connect to server!"
		mainChat.add("[ERROR] Failed to Connect to Server! Trying again in 5 seconds...", 1)
		Return False
	End If
	currentXPan = 0
	currentYPan = 0
	Return True
End Function

Function ProcessChatCommand(command:String, arguments:String)
	Select command.ToLower()
		Case "login"
			If client Then
				Local tmpstr:String[] = arguments.Replace("`", " ").split(" ")
				If tmpstr.Length = 2 Then
					client.SendLogin(tmpStr[0], tmpStr[1])
				Else
					mainChat.add("[ERROR] You need to provide both a username and a password.", 1)
				End If
			Else
				mainChat.add("[ERROR] Cannot " + command + " because you aren't connected yet!", 1)
			EndIf
			
		Case "setempirename"
			If client Then
				client.SendPacket(Packet.ID_SETEMPIRENAME, arguments.Replace("`", ""))
			Else
				mainChat.add("[ERROR] Cannot " + command + " because you aren't connected yet!", 1)
			EndIf
			
		Case "sendships"
			If client Then
				Local tmpstr:String[] = arguments.Replace("`", " ").split(" ")
				If tmpStr.Length = 3 Then
					client.SendPacket(Packet.ID_CMDSENDFLEET, Combine(tmpStr))
					client.SendPacket(Packet.ID_UPDATEALL, "plz")
				Else
					mainChat.add("[ERROR] You need to provide a starting system, a destination system, and the amount of ships you want.", 1)
				End If
			Else
				mainChat.add("[ERROR] Cannot " + command + " because you aren't connected yet!", 1)
			EndIf
			
		Case "toggleshipyard"
			If client Then
				client.SendPacket(Packet.ID_CMDBUILDSHIP, arguments.Replace("`", " "))
			Else
				mainChat.add("[ERROR] Cannot " + command + " because you aren't connected yet!", 1)
			EndIf
			
		Case "join"
			If client Then
				client.SendPacket(Packet.ID_JOINREQUEST, arguments.Replace("`", " "))
			Else
				mainChat.add("[ERROR] Cannot " + command + " because you aren't connected yet!", 1)
			EndIf
			
		Case "help"
			mainChat.add("[HELP] toggleshipyard [id], setempirename [name], sendships [a] [b] [num], list")
			
		Case "exit"
			Return - 1
			
		Case "list"
			If client Then
				client.SendPacket(Packet.ID_USERLIST, "plz")
			Else
				mainChat.add("[ERROR] Cannot " + command + " because you aren't connected yet!", 1)
			EndIf
			
		Case "me"
			If client Then
				client.SendPacket(Packet.ID_MESSAGESELF, arguments.Replace("`", " "))
			Else
				mainChat.add("[ERROR] Cannot " + command + " because you aren't connected yet!", 1)
			EndIf
			
		Case "disconnect"
			If client Then
				client.SendText("Goodbye World!")
				client.Close()
				client = Null
			Else
				mainChat.add("[ERROR] Cannot " + command + " because you aren't connected yet!", 1)
			EndIf
			
		Case "connect"
			If Not client Then
				If arguments <> ""
					Local tmpstr:String[] = arguments.Replace("`", " ").split(":")
					If tmpstr.Length = 2 Then
						Connect(tmpstr[0], Int(tmpstr[1]))
					ElseIf tmpStr.Length = 1 Then
						Connect(mainChat.GetVariable(arguments.tolower())._var, Int(mainChat.GetVariable("port")._var))
					Else
						mainChat.add("[ERROR] You need to provide a IP and/or a port!", 1)
					End If
				Else
					mainChat.add("[ERROR] No IP/Port or variable name given!", 1)
				End If
			Else
				mainChat.add("[ERROR] Cannot " + command + " because you are already connected!", 1)
			EndIf
					
			Default
			mainChat.add("[ERROR] Command '" + command + "' is not recongized", 1)
	End Select
End Function

Function DrawPing(pbX = 0, pbY = 0)
	Local pingDelta = 0
	If client Then
		pingDelta = client.pingDelta
		'client.IsSyncingTGame
		SetColor 0, 255, 0
	Else
		SetColor 128, 0, 0
	EndIf
	DrawText("" + pingDelta, pbX + 18, pbY)
	SetLineWidth 3
	pbX:+4
	pbY:+1
	SetAlpha 0.25 ; If pingDelta < 200 Then SetAlpha 0.9
	DrawLine pbX, pbY, pbX, pbY + 12
	pbX:+4
	SetAlpha 0.25 ; If pingDelta < 400 Then SetAlpha 0.9
	DrawLine pbX, pbY + 3, pbX, pbY + 12
	pbX:+4
	SetAlpha 0.25 ; If pingDelta < 600 Then SetAlpha 0.9
	DrawLine pbX, pbY + 6, pbX, pbY + 12
	pbX:+4
	SetAlpha 0.25 ; If pingDelta < 800 Then SetAlpha 0.9
	DrawLine pbX, pbY + 9, pbX, pbY + 12
	SetLineWidth 1
	SetAlpha 1.0
	SetColor 255, 255, 255
End Function

Function DrawSync(xx:Int, yy:Int)
	If client Then
		SetColor 0, 255, 0
		SetAlpha 0.75
		'client.IsSyncingTGame
		If client.IsSyncingTGame = True Then
			DrawOval xx, yy, 8, 12
			DrawOval xx + 4, yy, 8, 12
		ElseIf client.IsSyncingTGame = False Then
			DrawOval xx, yy, 12, 12
		End If
	Else
		SetColor 128, 0, 0
		SetLineWidth 3
		DrawLine xx, yy, xx + 12, yy + 12
		DrawLine xx + 12, yy, xx, yy + 12
	EndIf
	SetLineWidth 1
	SetAlpha 1.0
	SetColor 255, 255, 255
End Function

Function DrawBottomLeftWindow()
	Local tmpX:Int = 16, tmpY = scny
	Select bottomLeftWindow
		Case 0
			tmpX = 232 '209 '440 
			If selectedSystem Then '''''''''''''''''''''''''''''''''' SYSTEM
				tmpY = 96 + 64 + 64'16
				SetColor 255, 255, 255
				DrawImageRect(menuBars[3], 0, scny - tmpY - 3, tmpX + 3, tmpY + 3)
				SetColor 96, 96, 128
				DrawImageRect(menuBars[3], 0, scny - tmpY, tmpX, tmpY + 32)
				SetColor 255, 255, 255
				tmpY = (tmpY - 12)
				tb.Draw.TextOutline("Selected System ID:" + selectedSystem.netID, 16, scny - tmpY)
				If curGame.FindPlayerID(selectedSystem.owner) Then
					tb.Draw.TextOutline("Owner: " + curGame.FindPlayerID(selectedSystem.owner).empireName, 16, scny - tmpY + (16 * 1))
				Else
					tb.Draw.TextOutline("Owner: None", 16, scny - tmpY + (16 * 1))
				End If
				tb.Draw.TextOutline("Position:  x[" + selectedSystem.x + "]  y[" + selectedSystem.y + "]", 16, scny - tmpY + (16 * 2))
				tb.Draw.TextOutline("Ships In Orbit: " + selectedSystem.ships, 16, scny - tmpY + (16 * 3))
				
				tb.Draw.TextOutline("New Ship In: " + tb.Math.LimitDecimal((selectedSystem.CalculateNewShipTime() - selectedSystem.lastBuild) * 0.1) + " years", 16, scny - tmpY + (16 * 5))
				If selectedSystem.isBuilding > 0 Then
					If tb.Draw.ClickableText("(B)uilding/Researching: Building", 16, scny - tmpY + (16 * 6) + 4, False, False, True) Or KeyHit(KEY_B) Then
						client.SendPacket(Packet.ID_CMDBUILDSHIP, selectedSystem.netID)
						selectedSystem.isBuilding:*- 1
						msh[1] = False
					EndIf
				ElseIf selectedSystem.isBuilding < 0 Then
					If tb.Draw.ClickableText("(B)uilding/Researching: Researching", 16, scny - tmpY + (16 * 6) + 4, False, False, True) Or KeyHit(KEY_B) Then
						client.SendPacket(Packet.ID_CMDBUILDSHIP, selectedSystem.netID)
						selectedSystem.isBuilding:*- 1
						msh[1] = False
					EndIf
				Else
					tb.Draw.TextOutline("Building/Researching: n/a", 16, scny - tmpY + (16 * 6) + 4)
				EndIf
				tb.Draw.TextOutline("Planet Quailty: " + selectedSystem.quality, 16, scny - tmpY + (16 * 8))
			ElseIf selectedFleet'''''''''''''''''''''''''''''''''' FLEET 
				tmpx:+16
				tmpY = 96 + 32
				If selectedFleet.homeID > - 1 And selectedFleet.destID > - 1 Then tmpY:+64'96
				If client Then If client.ply Then If selectedFleet.owner = client.ply.netID Then tmpY:+32
				SetColor 255, 255, 255
				DrawImageRect(menuBars[3], 0, scny - tmpY - 3, tmpX + 3, tmpY + 3)
				SetColor 96, 96, 128
				DrawImageRect(menuBars[3], 0, scny - tmpY, tmpX, tmpY + 32)
				SetColor 255, 255, 255
				tmpY = (tmpY - 12)
				'	tb.Draw.TextOutline("x[" + selectedFleet.damageOutput + "]  y[" + selectedFleet.damageTaken + "]", 16, scny - tmpY - (16 * 4))
				tb.Draw.TextOutline("Selected Fleet ID:" + selectedFleet.netID, 16, scny - tmpY)
				If selectedFleet.owner > 0 Then
					tb.Draw.TextOutline("Owner: " + curGame.FindPlayerID(selectedFleet.owner).empireName, 16, scny - tmpY + (16 * 1))
				Else
					tb.Draw.TextOutline("Owner: None", 16 + 225, scny - tmpY + (16 * 1))
				End If
				tb.Draw.TextOutline("Position:  x[" + tb.Math.LimitDecimal(selectedFleet.x) + "]  y[" + tb.Math.LimitDecimal(selectedFleet.y) + "]",  ..
					16, scny - tmpY + (16 * 2))
				tb.Draw.TextOutline("Ships In Fleet: " + selectedFleet.strength, 16, scny - tmpY + (16 * 3))
				
				If selectedFleet.homeID > - 1 And selectedFleet.destID > - 1 Then
					If Not selectedFleet.destSys Then selectedFleet.destSys = curGame.FindSystemID(selectedFleet.destID)
					If Not selectedFleet.destSys Then
						tb.Draw.TextOutline("Distance: ???", 16, scny - tmpY + (16 * 4))
					Else
						Local etaCalc:Float = tb.Math.GetDistance(selectedFleet.x, selectedFleet.y, selectedFleet.destSys.x, selectedFleet.destSys.y)
						tb.Draw.TextOutline("Distance: " + tb.Math.LimitDecimal(etaCalc, 2) + "u", 16, scny - tmpY + (16 * 5))
						If selectedFleet.destID > - 1 And selectedFleet.speed > 0.0
							etaCalc:/(selectedFleet.speed * curGame.movementTimeScale)
							tb.Draw.TextOutline("ETA: " + Int(etaCalc + 1.0) + " turns / " + tb.Math.LimitTime(etaCalc * (GAME_TICK_TIME * 0.001)), 16, scny - tmpY + (16 * 6))
						End If
					End If
				
					tb.Draw.TextOutline("From ID:[" + selectedFleet.homeID + "]  Dest ID:[" + selectedFleet.destID + "]", 16, scny - tmpY + (16 * 7))
					If client Then If client.ply Then If selectedFleet.owner = client.ply.netID Then
						If tb.Draw.ClickableText("(T)urn Fleet Around", 16, scny - tmpY + (16 * 8) + 4, False, False, True) Or KeyHit(KEY_T) Then
							client.SendPacket(Packet.ID_CMDRETREATFLEET, selectedFleet.netID)
							Local tsys:TSystem = selectedFleet.homeSys, tnetID:Int = selectedFleet.homeID
							selectedFleet.homeSys = selectedFleet.destSys
							selectedFleet.homeID = selectedFleet.destID
							selectedFleet.destSys = tsys
							selectedFleet.destID = tnetID
							msh[1] = False
						End If
				
						If selectedFleet.speed <= 0.5 Then
							If tb.Draw.ClickableText("(C)ontinue", 16, scny - tmpY + (16 * 9) + 8, False, False, True) Or KeyHit(KEY_C) Then ..
								client.SendPacket(Packet.ID_CMDSTARTFLEET, selectedFleet.netID)
						Else
							If tb.Draw.ClickableText("(S)top Fleet", 16, scny - tmpY + (16 * 9) + 8, False, False, True) Or KeyHit(KEY_S) Then ..
								client.SendPacket(Packet.ID_CMDSTOPFLEET, selectedFleet.netID)
						End If
					End If
				EndIf
			End If
		Case 1 '''''''''''''''''''''''''''''''''' RESEACH
			SetColor 255, 255, 255
			DrawImageRect(menuBars[3], 0, scny - 96 - 96 - 3, 440 + 3, 96 + 96 + 3)
			SetColor 96, 96, 128
			DrawImageRect(menuBars[3], 0, scny - 96 - 96, 440, 96 + 96 + 32)
			SetColor 255, 255, 255
			If client Then If client.ply Then
				tb.Draw.TextOutline("Current Research Progress:", 16, scny - 84 - 96)
				'if client.ply.prefered then drawtext
				For Local ii:Int = 0 Until client.ply.researchTopics.Length - 1
					If tb.Draw.ClickableText(client.ply.GetResearchTopicName(ii) + "", 16, scny - 84 - 96 + 24 + (16 * ii), False, False, True) Then
						client.SendPacket(Packet.ID_RESEARCHSTART, ii)
						client.ply.researchAspect = ii
						client.ply.currentResearchTurn = 0
						client.ply.untilNextDecimal = client.ply.researchTopics[client.ply.researchAspect] * (GAME_TICK_TIME * 0.001)
						If client.ply.researchAspect = TPlayer.RES_FUELRANGE Then client.ply.untilNextDecimal:*(1 / 5.0)
						If client.ply.researchAspect = TPlayer.RES_RADARRANGE Then client.ply.untilNextDecimal:*(1 / 5.0)
						If client.ply.researchAspect = TPlayer.RES_FLEETSPEED Then client.ply.untilNextDecimal:*(1 / 2.0)
						If client.ply.researchAspect = client.ply.preferedResearchAspect Then client.ply.untilNextDecimal:*(9 / 10.0)
					EndIf
		
					If ii = client.ply.researchAspect Then tb.Draw.TextOutline(">", 16 + 8 + 176, scny - 84 - 96 + 24 + (16 * ii))
					tb.Draw.TextOutline(tb.Math.LimitDecimal(client.ply.researchTopics[ii]), 16 + 176 + 32, scny - 84 - 96 + 24 + (16 * ii))
		
					If ii = client.ply.researchAspect And client.ply.untilNextDecimal > 0 Then
						Local tmp:Int = (client.ply.untilNextDecimal - client.ply.currentResearchTurn)
		'	tb.Draw.CenteredText(tb.Math.LimitTime(buildTurns * (GAME_TICK_TIME * 0.001)) + " / " + tb.Math.LimitDecimal(buildTurns * 0.1) + " yr", (scnx / 2), 16)
						
						tb.Draw.TextOutline(Int((Float(client.ply.currentResearchTurn) / Float(client.ply.untilNextDecimal)) * 100) + "% (Time Left: " + ..
							tb.Math.LimitTime((GAME_TICK_TIME * 0.001) * tmp) + " / " + tb.Math.LimitDecimal(tmp * 0.1) + " yrs)", 16 + 225 + 32, scny - 84 - 96 + 24 + (16 * ii))
			
						Local researchCost = (client.ply.untilNextDecimal - client.ply.currentResearchTurn) * 625
						If client.ply.researchAspect = client.ply.preferedResearchAspect Then researchCost = Int(researchCost * (4 / 5.0))
						If researchCost > client.ply.credits Then tb.Draw.SetRGB("red")
'						If tb.Draw.ClickableText("Pay " + tb.Math.LimitDenom(researchCost) + " to Advance Right Away", 16 + 225 - 32, scny - 84 - 96, 0, 0, 1) Then ..
'							client.SendPacket(Packet.ID_RESEARCHPAY, "plz")
						tb.Draw.SetGrey(255)
						DrawText ("Research Points: " + client.ply.credits, 16 + 225 - 32, scny - 84 - 96)
					EndIf
				Next
			EndIf
		Case 2''''''''''''''''''''''''''''''''''''''''''''''''' EMPIRES
			tmpX = 340'440
			tmpY = (curGame.players.Count() * 16) + 64
			SetColor 255, 255, 255
			DrawImageRect(menuBars[3], 0, scny - tmpY - 3, tmpX + 3, tmpY + 3)
			SetColor 96, 96, 128
			DrawImageRect(menuBars[3], 0, scny - tmpY, tmpX, tmpY + 32)
			SetColor 255, 255, 255
			tmpY = (tmpY - 12)
			tb.Draw.TextOutline("Active Empires:", 16 + (56 * 0), scny - tmpY + (16 * 0))
			tb.Draw.TextOutline("Systems:", 16 + 225, scny - tmpY + (16 * 0))
			Local ii:Int = 0

			''''
			Local tmpPlayers:TList = curGame.players.copy()
			Local tmpSorted:TList = CreateList()

			While tmpPlayers.Count() > 0
				Local highestTerritories = 0, highestplyr:TPlayer = TPlayer(tmpPlayers.First())

				For Local tply:TPlayer = EachIn tmpPlayers
					Local terrCount = curgame.CountOwnedSystems(tply.netID)
					If terrcount > highestTerritories Then highestTerritories = terrcount; highestplyr = tply
				Next

				If highestplyr
					tmpSorted.AddLast(highestplyr)
					tmpPlayers.remove(highestplyr)
				Else
					Exit
				EndIf
			Wend

			For Local tply:TPlayer = EachIn tmpSorted
				ii:+1
				If curGame.CountOwnedSystems(tply.netID) > 0 Then
					SetAlpha 1.0
				Else
					SetAlpha 0.5
				EndIf
				tb.Draw.TextOutline(tply.empireName, 16 + (56 * 0), scny - tmpY + (16 * ii), False, "0,0,0", tply.rgb)
				SetColor 255, 255, 255
				tb.Draw.TextOutline(curGame.CountOwnedSystems(tply.netID), 16 + 225, scny - tmpY + (16 * ii))
				tb.Draw.TextOutline(Int((Float(curGame.CountOwnedSystems(tply.netID)) / Float(curGame.systems.Count())) * 100) + "%", 16 + (56 * 4) + 40, scny - tmpY + (16 * ii))
				SetAlpha 1.0
				SetColor 255, 255, 255
			Next
		Default
			'
	End Select

	If bottomLeftWindow = 0 Then
		DrawImage(menuBars[1], -16, scny - menuBars[1].Height + 8)
		tb.Draw.TextOutline("Selection", 16, scny - menuBars[1].Height + 16)', False, "0,0,0", "192,192,255")
	Else
		If tb.Draw.ClickableImage(menuBars[2], -16, scny - menuBars[1].Height + 8) Then bottomLeftWindow = 0
		'	DrawImage()
		SetColor 0, 0, 0
		DrawText "Selection", 16, scny - menuBars[1].Height + 16
		SetColor 255, 255, 255
	End If

	If bottomLeftWindow = 1 Then
		DrawImage(menuBars[1], (menuBars[1].width * 1) - 16, scny - menuBars[1].Height + 8)
		tb.Draw.TextOutline("Research", (menuBars[1].width * 1) + 16, scny - menuBars[1].Height + 16)', False, "0,0,0", "192,192,255")
	Else
		If tb.Draw.ClickableImage(menuBars[2], (menuBars[1].width * 1) - 16, scny - menuBars[1].Height + 8) Then bottomLeftWindow = 1
		'	DrawImage(menuBars[2], (menuBars[1].width * 1) - 16, scny - menuBars[1].Height + 8)
		SetColor 0, 0, 0
		DrawText "Research", (menuBars[1].width * 1) + 16, scny - menuBars[1].Height + 16
		SetColor 255, 255, 255
	End If

	If bottomLeftWindow = 2 Then
		DrawImage(menuBars[1], (menuBars[1].width * 2) - 16, scny - menuBars[1].Height + 8)
		tb.Draw.TextOutline("Empires", (menuBars[1].width * 2) + 16, scny - menuBars[1].Height + 16)', False, "0,0,0", "192,192,255")
	Else
		If tb.Draw.ClickableImage(menuBars[2], (menuBars[1].width * 2) - 16, scny - menuBars[1].Height + 8) Then bottomLeftWindow = 2
		'	DrawImage(menuBars[2], (menuBars[1].width * 1) - 16, scny - menuBars[1].Height + 8)
		SetColor 0, 0, 0
		DrawText "Empires", (menuBars[1].width * 2) + 16, scny - menuBars[1].Height + 16
		SetColor 255, 255, 255
	End If
End Function

Function DrawGalaxyGrid()
	SetAlpha 0.2
	DrawLine - 300 * MAP_SCALE, 0, 300 * MAP_SCALE, 0
	DrawLine 0, -300 * MAP_SCALE, 0, 300 * MAP_SCALE
	DrawText "25u", 25 * MAP_SCALE, 0
	DrawText "50u", 50 * MAP_SCALE, 0
	DrawText "75u", 75 * MAP_SCALE, 0
	DrawText "100u", 100 * MAP_SCALE, 0
	DrawText "150u", 150 * MAP_SCALE, 0
	DrawText "200u", 200 * MAP_SCALE, 0
	SetAlpha 0.1
	tb.Draw.Circle(0, 0, 25 * MAP_SCALE, 32)
	tb.Draw.Circle(0, 0, 50 * MAP_SCALE, 48)
	tb.Draw.Circle(0, 0, 75 * MAP_SCALE, 64)
	tb.Draw.Circle(0, 0, 100 * MAP_SCALE, 84)
	tb.Draw.Circle(0, 0, 150 * MAP_SCALE, 84)
	tb.Draw.Circle(0, 0, 200 * MAP_SCALE, 84)
	'	DrawLine - 300 * MAP_SCALE, 15 * MAP_SCALE, 300 * MAP_SCALE, 15 * MAP_SCALE
	'	DrawLine - 300 * MAP_SCALE, -15 * MAP_SCALE, 300 * MAP_SCALE, -15 * MAP_SCALE
	'	DrawLine 15 * MAP_SCALE, -300 * MAP_SCALE, 15 * MAP_SCALE, 300 * MAP_SCALE
	'	DrawLine - 15 * MAP_SCALE, -300 * MAP_SCALE, -15 * MAP_SCALE, 300 * MAP_SCALE
	SetAlpha 1.0
End Function

Function DrawGalaxyMap()
	Local isMouseHit = msh[1], distFromCursor:Float = 2048, tmpDist:Float = 0.0
	For Local tsys:TSystem = EachIn curGame.systems
		If client Then If client.ply Then If tsys.owner = client.ply.netID Then totalships:+tsys.ships
		If tsys.IsMouseOver() Then
			tmpDist = tb.Math.GetDistance(msx, msy, tsys.GetX(), tsys.GetY())
			If msh[1] And tmpDist < distFromCursor Then
				selectedFleet = Null
				selectedSystem = tsys
				targetSystem = Null
				selectedShips = 0
				bottomLeftWindow = 0
				isMouseHit = -1
				distFromCursor = tmpdist
			EndIf
			If msh[2] Then
				If selectedSystem = tsys Then
					selectedShips:-1 + (tb.KeysDown(KEY_RSHIFT, KEY_LSHIFT) * 4) + (tb.KeysDown(KEY_RCONTROL, KEY_LCONTROL) * 99)
					If selectedShips < 0 Then selectedShips = 0
				ElseIf client Then
					If client.ply Then If selectedSystem Then If tb.Math.GetDistance(selectedSystem.x, selectedSystem.y, tsys.x, tsys.y) <= client.ply.researchTopics[TPlayer.RES_FUELRANGE]
						If tb.KeysDown(KEY_RALT, KEY_LALT) Then
							selectedShips = selectedSystem.ships - 1
						Else
							selectedShips:+1 + (tb.KeysDown(KEY_RSHIFT, KEY_LSHIFT) * 4) + (tb.KeysDown(KEY_RCONTROL, KEY_LCONTROL) * 99)
						EndIf
						targetSystem = tsys
					End If
				End If
			End If
			If msh[3] Then
				If client.ply Then If selectedSystem Then If tb.Math.GetDistance(selectedSystem.x, selectedSystem.y, tsys.x, tsys.y) <= client.ply.researchTopics[TPlayer.RES_FUELRANGE]
				'	Local reqstr:String = RequestText("Fleet Composition Creation", "How many ships do you want to put into this fleet?", selectedSystem.ships - 1)
				'	If Int(reqstr) > 0
						selectedShips = selectedSystem.ships - 1'Int(reqstr)
						targetSystem = tsys
				'	End If
				EndIf
			End If
		End If
		tsys.Draw(selectedSystem = tsys)
	Next
	If selectedSystem And targetSystem Then
		SetAlpha 0.25
		DrawLine selectedSystem.x * MAP_SCALE, selectedSystem.y * MAP_SCALE, targetSystem.x * MAP_SCALE, targetSystem.y * MAP_SCALE
		SetAlpha 1.0
	End If
	For Local tflt:TFleet = EachIn curGame.fleets
		tflt.Draw(selectedFleet = tflt)
		If client Then If client.ply Then If tflt.owner = client.ply.netID Then totalships:+tflt.strength
		If tflt.IsMouseOver() Then
			tmpDist = tb.Math.GetDistance(msx, msy, tflt.GetX(), tflt.GetY())
			If msh[1] And tmpDist < distFromCursor Then
				selectedFleet = tflt
				selectedSystem = Null
				targetSystem = Null
				selectedShips = 0
				bottomLeftWindow = 0
				'msh[1] = False
				isMouseHit = -1
			EndIf
		EndIf
	Next
	If isMouseHit < 0 Then msh[1] = False
End Function

Function UpdateTopLeft()
		
	If tb.PointIn.MouseInImage(menuBars[1], -16, -8) And msh[1] Then
		msh[1] = False
		topLeftChat = 0
		If mainChat.enabled Then
			mainChat.enabled = False
			attacheUpdates.enabled = False
		Else
			mainChat.enabled = True
			attacheUpdates.enabled = False
		EndIf
	ElseIf tb.PointIn.MouseInImage(menuBars[1], menuBars[1].width - 16, -8) And msh[1] Then
		msh[1] = False
		topLeftChat = 1
		If attacheUpdates.enabled Then
			attacheUpdates.enabled = False
			mainChat.enabled = False
		Else
			attacheUpdates.enabled = False
			mainChat.enabled = False
		EndIf
	ElseIf tb.PointIn.MouseInImage(menuBars[1], menuBars[1].width * 2 - 16, -8) And msh[1] Then
		msh[1] = False
		topLeftChat = 2
		If attacheUpdates.enabled Then
			attacheUpdates.enabled = False
			mainChat.enabled = False
		Else
			attacheUpdates.enabled = True
			mainChat.enabled = False
		EndIf
	EndIf
	
	If mainChat.enabled = True Then
		topLeftChat = 0
		mainChat.CheckInput()
		If mainChat.typ Then
			mainChat.enabled = False
			FlushKeys
			If mainChat.typ = 1 Then
				If mainChat.cmd <> "" Then If client Then client.SendText(mainChat.cmd)
					ElseIf mainChat.typ = 2
						ProcessChatCommand(mainChat.cmd, mainChat.arg)
			End If
		EndIf
	Else
		Return True
	EndIf
	Return False
End Function

Function DrawTopLeft()
	DrawImage(menuBars[mainChat.enabled + 1], -16, -8)
	If mainChat.enabled
		If client Then client.newChatUpdate = False
		tb.Draw.TextOutline("Player Chat", 16, 6)', False, "0,0,0", "192,192,255")
	Else
		SetColor 0, 0, 0
		If client Then If client.newChatUpdate Then SetColor 0, 250, 0
		DrawText "Player Chat", 16, 6
		SetColor 255, 255, 255
	End If
	
	'''Empire Chat
	'DrawImage(menuBars[attacheUpdates.enabled + 1], menuBars[1].width - 16, -8)
	SetColor 192, 192, 192
'	DrawImage(menuBars[1], menuBars[2].width - 16, -8)
'	'If attacheUpdates.enabled
'		'If client Then client.newAttacheUpdate = False
'		'tb.Draw.TextOutline("Empire Chat", menuBars[1].width + 16, 6)', False, "0,0,0", "192,192,255")
'	'Else
'		SetColor 0, 0, 0
'		'If client Then If client.newAttacheUpdate Then SetColor 0, 250, 0
'		DrawText "Empire Chat", menuBars[1].width + 16, 6
		SetColor 255, 255, 255
	'End If
	
	'''Empire news
	DrawImage(menuBars[attacheUpdates.enabled + 1], menuBars[1].width * 2 - 16, -8)
	If attacheUpdates.enabled
		If client Then client.newAttacheUpdate = False
		tb.Draw.TextOutline("Empire News", menuBars[1].width * 2 + 16, 6)', False, "0,0,0", "192,192,255")
	Else
		SetColor 0, 0, 0
		If client Then If client.newAttacheUpdate Then SetColor 0, 250, 0
		DrawText "Empire News", menuBars[1].width * 2 + 16, 6
		SetColor 255, 255, 255
	End If
	
	'''''''''''''''''''''''''''''
	''' Draw Chat Area
	Select topLeftChat
		Case 0
			mainChat.drawChat(8, 32)
			mainChat.DrawList(8, 48, 1, 10 + (25 * mainChat.enabled))
		Case 2
			attacheUpdates.DrawList(8, 32, 1, 20 + (25 * attacheUpdates.enabled))
	End Select
End Function

Include "imports/clientHelpers.bmx"