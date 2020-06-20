Rem

''''''''''''''' STRAIGHT FORWARD TCP NETWORKING
-----	Parts based on EdzUp Network system by Ed 'EdzUp' Upton which 
-----  was released under public domain license on BlitzMax.com Code
-----  Archives. http://blitzbasic.com/codearcs/codearcs.php?code=2781
-----  Inspriation also from rich41x and his simple TCP code at:
-----  http://blitzbasic.com/codearcs/codearcs.php?code=1974
-----  and even http://blitzbasic.com/codearcs/codearcs.php?code=2732

-----  This is designed to be a less confusing version of it.

endrem

Strict
Import brl.LinkedList
Import brl.System
Import brl.Socket
Import brl.SocketStream
Import brl.Retro
Import brl.EventQueue
Import brl.PNGLoader
Import "Toolbox.bmx"
Include "networkHelpers.bmx"
Include "GameObjects.bmx"

tb.Init()
const _debug = False
Global DEFAULTPORT:Int = 25567
Global SFTCP_VERSION:Int = 0001
Global GAME_TICK_TIME:Int = 1000 * 2 '* 30 * 2 '' TODO #16 make this configurable by the server

Type Packet
	Const ID_PING:Int = 1
	Const ID_PONG:Int = 2
	
	Const ID_MESSAGE:Int = 10
	Const ID_MESSAGESELF:Int = 11
	Const ID_PRIVATEMESSAGE:Int = 12
	Const ID_MESSAGEATTACHE:Int = 13
	
	Const ID_LOGIN:Int = 20
	Const ID_USERLIST:Int = 21
	
	Const ID_JOINREQUEST:Int = 30
	Const ID_UPDATEOBJ:Int = 35
	Const ID_UPDATEALL:Int = 36
	'	Const ID_REMOVEOBJ:Int = 37
	
	Const ID_CMDSENDFLEET:Int = 40
	Const ID_CMDBUILDSHIP:Int = 41
	Const ID_CMDRETREATFLEET:Int = 42
	Const ID_CMDSTOPFLEET:Int = 43
	Const ID_CMDSTARTFLEET:Int = 44
	
	Const ID_RESEARCHSTART:Int = 50
	Const ID_RESEARCHSTOP:Int = 51
	Const ID_RESEARCHPAY:Int = 52
	Const ID_SETEMPIRENAME:Int = 53
End Type

'' Because I'm HORRIBLE and use singletons
Global client:TMasterClient = Null
Global server:TServer = Null

Function SendPacketToStreamThread:Object(data:Object)
	Local packetData:PPacket = PPacket(data)
	'' add stream/packetData protection if this works
	Try
		packetData.stream.WriteInt(packetData.netID)
		packetData.stream.WriteInt(packetData.data.Length)
		packetData.stream.WriteLine(packetData.data)
	Catch e:Object
		'TPrint("[ERROR] Packet Sending Failure:" + e.ToString() + "`1")
		Return e
	End Try
	
	Return Null
End Function

Type PPacket
	Field stream:TStream, netID:Int, data:String
	
	Method Create:PPacket(sstream:TStream, iid:Int, ddata:String)
		stream = sstream
		netID = iid
		data = ddata
		Return Self
	End Method
EndType

Type TBaseClient Extends TStream Abstract
	
	Field m_socket:TSocket, m_sip:Int
	Field lastPingRecv:Int = MilliSecs(), lastPingSent:Int = MilliSecs(), pingDelta:Int = 0
	Field lastSync:Int = MilliSecs()
	Field recievedMessages:TList = CreateList(), ply:TPlayer = Null
	
	Field name:String, pass:String, auth:Int = False, stat:Int
	Field IsSyncingTGame = False
	
	Method Init(Socket:TSocket)
		m_socket = Socket
		If m_socket
			m_sip = m_socket.RemoteIp()
		End If
		name = "cadet" + (GetIPAddressAsInt() Mod 999)
	End Method
	
	Method read:Int(Buf:Byte Ptr, Count:Int)
		Return m_socket.Recv(Buf, Count)
	End Method
	
	Method Write:Int(Buf:Byte Ptr, Count:Int)
		Return m_socket.Send(Buf, Count)
	End Method
	
	Method SendPacket(pid:Int, data:String)
		If Eof() Then Return False
		? Threaded
		Local packetThread:TThread = TThread.Create(SendPacketToStreamThread, New PPacket.Create(Self, pid, data))
		Local startingMS:Int = MilliSecs()
		While packetThread.Running()
			If MilliSecs() - startingMS > 100 Then packetThread.Detach() ;TPrint "Stream Time-Out for PacketID: " + pid + " Data: " + data ;Return False
		Wend
		Local e:Object = packetThread.wait()
		If e Then
			TPrint("[ERROR] Packet Sending Failure:" + e.ToString() + "`1")
			Return False
		End If
		? Not Threaded
		TPrint "Sending Unthreaded Packet.." + pid + " Data: " + data
		Try
			WriteInt(pid)
			WriteInt(data.Length)
			WriteLine(data)
		Catch e:Object
			recievedMessages.AddLast("[ERROR] Packet Sending Failure:" + e.ToString() + "`1")
			Close()
		End Try
		?
		Return True
	End Method
	
	Method SendText(aText:String, vlvl:Int = 0)
		aText = aText.Replace("`", "'")
		SendPacket(Packet.ID_MESSAGE, aText + "`" + vlvl)
	End Method
	
	Method SendPing()
		SendPacket(Packet.ID_PING, MilliSecs())
		lastPingSent = MilliSecs()
		'	TPrint "[INFO] Sending a Ping..."
	End Method
	
	Method SendPong()
		SendPacket(Packet.ID_PONG, MilliSecs())
		'	TPrint "[INFO] Sending a Pong..."
	End Method
	
	Method ReadAvail:Int()
		Return m_socket.ReadAvail()
	End Method
	
	Method Eof:Int()
		If m_socket
			If m_socket.Connected() = True
				Return False
			End If
		End If
		Close()
		Return True
	End Method
	
	Method Close()
		If m_socket
			m_socket.Close()
			m_socket = Null
		End If
	End Method
	
	Method Connect:Int(RemoteIp:Int, RemotePort:Int)
		m_sip = RemoteIp
		Return m_socket.Connect(RemoteIp, RemotePort)
	End Method
	
	Method Connected:Int()
		If m_socket
			Return m_socket.Connected()
		End If
		Return False
	End Method
	
	Method Update()
		Local msgID:Int = -1, msgTextLength:Int, msgText:String = ""
		'? Not Debug
		Try
			'?		
			If Not Eof()
				If ReadAvail() > 0
					msgID = ReadInt()
					If Eof() Then TPrint "[WARNING] Incomplete Packet Recieved! Supposed Packet ID was: " + msgID;Return False
					msgTextLength = ReadInt()
					If Eof() Then TPrint "[WARNING] Incomplete Packet Recieved! Supposed Packet ID was: " + msgID;Return False
					msgText = ReadLine()
					If msgText.Length <> msgTextLength Then
						TPrint "[WARNING] Incomplete Packet Recieved! Supposed Packet ID was: " + msgID
						Return False
					End If
				End If
			End If
			'? Not Debug
		Catch e:Object
			TPrint "[ERROR] Packet Handle Failure: " + e.ToString()
			Return False
		End Try
		'?
		If msgID > (-1) Then Return HandleMessage(msgID, msgText)
	End Method
	
	Method GetIPAddressAsInt:Int()
		Return m_sip
	End Method
	
	Method GetIPAddressAsString:String(separator:String = ".")
		Return (m_sip Shr 24) + separator + (m_sip Shr 16 & 255) + separator + (m_sip Shr 8 & 255) + separator + (m_sip & 255)
	End Method
	
	Method HandleMessage(id:Int, data:String) Abstract
	
End Type

Type TServer
	
	Field m_port:Int
	Field m_socket:TSocket
	Field m_clients:TList
	
	Field recentBroadcasts:TList = CreateList()
	Field gamePaused:Int = False
	
	Field lastGameSave:Int = MilliSecs() + 5000
	Field lastUpdate:Int = MilliSecs()
	Field hiccupChecks:Int[8]
	
	Field MOTD:String = "Welcome to AGaW:E Alpha Test! If you have an account type '/login Username Password' to get started. Type '/join' to get a homeworld and 25 ships."
	
	Field currentTNetObject:TNetObject = Null
	
	Method New()
		m_clients = New TList
	End Method
	
	Method Create:TServer(Socket:TSocket, port:Int)
		m_port = port
		m_socket = Socket
		Account.LoadFile()
		For Local ii:Int = 0 Until hiccupChecks.Length
			hiccupChecks[ii] = 0
		Next
		Return Self
	End Method
	
	Method Start:Int()
		If m_socket <> Null
			If m_socket.Bind(m_port) = True
				m_socket.Listen(0)
				Return True
			End If
		End If
		Return False
	End Method
	
	Method SendBroadcast(aText:String, fromServer = True)
		TPrint "[Broadcast] " + aText
		aText = curGame.GetYear() + " " + aText
		For Local mClient:TServerClient = EachIn m_clients
			mClient.SendText(aText, 3 * fromServer)
		Next
		recentBroadcasts.AddLast(aText + "`" + (3 * fromServer))
		If recentBroadcasts.Count() > 25 Then recentBroadcasts.RemoveFirst()
	End Method
	
	Method Kick(mClient:TServerClient, reason:String = "")
		TPrint "[Server] " + mClient.name + " was kicked. Reason: " + reason
		If reason <> "" Then
			SendBroadcast("[Server] " + mClient.name + " was kicked. Reason: " + reason)
		Else
			SendBroadcast("[Server] " + mClient.name + " was kicked.")
		EndIf
		mClient.Close()
	End Method
	
	Method Update()
		curGame.ddebugStr = "Sector a" 'hiccupChecks[0] = MilliSecs()
		Local currentTNetObject:Object = Null
		If TNetObject.RecentlyUpdated.Count()
			currentTNetObject = (TNetObject.RecentlyUpdated.RemoveFirst())
		End If
		For Local tclient:TServerClient = EachIn m_clients
			''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
			''''' HOUSE KEEPING
			curGame.ddebugStr = "Sector 1" ; tclient.hiccupChecks[0] = MilliSecs()
			If tclient.Eof() Then
				If tclient.auth Then SendBroadcast("[Server] " + tclient.name + " disconnected")
				tclient.Close()
				Continue
			End If
			If MilliSecs() - tclient.lastSpamCheck > 1000 Then If tclient.messagesRecivedRecently > 100 Then
					Kick tclient, "Spamming Packets"
					tclient.Close()
					Continue
				Else
					tclient.messagesRecivedRecently:-5
					If tclient.messagesRecivedRecently < 0 Then tclient.messagesRecivedRecently = 0
				EndIf
			If tclient.acc And tclient.acc.stat = -1 Then
				Kick tclient
				Continue
			End If
			tclient.hiccupChecks[0] = MilliSecs() - tclient.hiccupChecks[0]
			If tclient.hiccupChecks[0] > 500 Then TPrint "[WARNING] Client " + tclient.name + " lagged siginificantly during Housecleaning! " + tclient.hiccupChecks[0] + "ms"
			
			UpdateClient(tclient, currentTNetObject)
		Next
		curGame.ddebugStr = "Sector b" 'hiccupChecks[0] = MilliSecs() - hiccupChecks[0]
		If gamePaused Then
			If MilliSecs() - lastGameSave > 10 * 60 * 1000 Then curGame.SaveToFile() ;lastGameSave = MilliSecs()
		Else
			If MilliSecs() - lastUpdate > GAME_TICK_TIME Then
				'	hiccupChecks[2] = MilliSecs()
				curGame.UpdateGame()
				lastUpdate = MilliSecs()
				'	hiccupChecks[2] = MilliSecs() - hiccupChecks[2]
			EndIf
			If MilliSecs() - lastGameSave > GAME_TICK_TIME * 15 Then
				'	hiccupChecks[4] = MilliSecs()
				curGame.SaveToFile()
				lastGameSave = MilliSecs()
				'	hiccupChecks[4] = MilliSecs() - hiccupChecks[4]
			EndIf
		End If
		
		'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
		''' Accept new connections
		curGame.ddebugStr = "Sector c" ; Local Socket:TSocket = m_socket.Accept(0)
		If Socket
			AddClient(New TServerClient.Create(Socket))
		End If
	End Method
	
	Method UpdateClient(tclient:TServerClient, currentTNetObject:Object = Null)
		''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
		''' Update and deal with messages
		curGame.ddebugStr = "Sector 2" ; tclient.hiccupChecks[2] = MilliSecs()
		tclient.Update()
		If tclient.auth > 0 Then
			''' Broadcasting Messages
			If tclient.recievedMessages.Count() > 0
				Local currentMsg:String = String(tClient.recievedMessages.RemoveFirst())
				currentMsg = "<" + tclient.name + "> " + currentMsg
				'	TPrint("[INFO] " + currentMsg)
				SendBroadcast(currentMsg, False)
			EndIf
				
			If tclient.auth = 2 Then ''' Just logged in!
				SendBroadcast("[Server] " + tclient.name + " just logged in!")
				tclient.auth = 1
			EndIf
				
			'''''
			If currentTNetObject Then Select TNetObject(currentTNetObject).netTypeID
					Case TNetObject.ID_SYSTEM
						tclient.SyncSystems(TSystem(currentTNetObject))
					Case TNetObject.ID_FLEET
						tclient.SyncFleets(TFleet(currentTNetObject))
					Case TNetObject.ID_PLAYER
						tclient.SyncPlayers(TPlayer(currentTNetObject))
				End Select
		Else
			tclient.recievedMessages.Clear()
		EndIf
		tclient.hiccupChecks[2] = MilliSecs() - tclient.hiccupChecks[2]
		If tclient.hiccupChecks[2] > 500 Then TPrint "[WARNING] Client " + tclient.name + " lagged siginificantly during Updating! " + tclient.hiccupChecks[2] + "ms"
			
		'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
		''' SYNCING!
		curGame.ddebugStr = "Sector 3" ; If tclient.ply Then
			If tclient.ply.messages.Count() > 0 Then
				tclient.SendPacket(Packet.ID_MESSAGEATTACHE, curGame.GetYear() + " " + String(tclient.ply.messages.RemoveFirst()))
			EndIf
			If tclient.ply.syncNeow Then tclient.SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_PLAYER + "`" + tclient.ply.Packetize(-1)) ; tclient.ply.syncNeow = False
		EndIf
		If tclient.IsSyncingTGame Then
			'	If MilliSecs() - tClient.lastObjSync > 5 Then
			tclient.lastObjSync = MilliSecs()
			
			If tclient.CurrentTSystem >= curGame.systems.Count() Then
				If tclient.CurrentTFleet >= curGame.fleets.Count() Then
					If tclient.CurrentTPlayer >= curGame.players.Count() Then
						tclient.IsSyncingTGame = False
						tclient.SendPacket(Packet.ID_UPDATEALL, "DONE")
						tclient.lastSync = MilliSecs()
					Else
					'	TPrint "[Sync] {" + tclient.name + "} Player " + tclient.CurrentTPlayer + "/" + curGame.players.Count()
						tclient.SyncPlayers(TPlayer(curGame.players.ToArray()[tclient.CurrentTPlayer]))
					End If
				Else
				'	TPrint "[Sync] {" + tclient.name + "} Fleet " + tclient.CurrentTFleet + "/" + curGame.fleets.Count()
					tclient.SyncFleets(TFleet(curGame.fleets.ToArray()[tclient.CurrentTFleet]))
				EndIf
			Else
			'	TPrint "[Sync] {" + tclient.name + "} System " + tclient.CurrentTSystem + "/" + curGame.systems.Count()
				tclient.SyncSystems(TSystem(curGame.systems.ToArray()[tclient.CurrentTSystem]))
			End If
		EndIf
		If tclient.hiccupChecks[4] > 500 Then
			TPrint "[WARNING] Client " + tclient.name + " lagged siginificantly during Syncing! " + tclient.hiccupChecks[4] + "ms"
			TPrint "CSys: " + tclient.CurrentTSystem + " CFlt: " + tclient.CurrentTFleet + " CPlt:" + tclient.CurrentTPlayer
		EndIf
			
		'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
		''' Timed Stuffs
		curGame.ddebugStr = "Sector 4" ; tclient.hiccupChecks[6] = MilliSecs()
		If MilliSecs() - tclient.lastPingRecv > 120 * 1000 Then
			tclient.SendText("[Server] You've been dropped due to timing out (2 Minutes)", 1)
			SendBroadcast("[Server] " + tclient.name + " timed out")
			TPrint("[INFO] " + tclient.GetIPAddressAsString() + " timed out")
			tclient.Close()
		Else
			If MilliSecs() - tclient.lastPingRecv > 10 * 1000 And MilliSecs() - tclient.lastPingSent > 2 * 1000 Then tclient.SendPing()
			If MilliSecs() - tclient.lastSync > 60 * 1000 And Not tclient.IsSyncingTGame Then tclient.StartSyncing
		EndIf
		tclient.hiccupChecks[6] = MilliSecs() - tclient.hiccupChecks[6]
		If tclient.hiccupChecks[6] > 500 Then TPrint "[WARNING] Client " + tclient.name + " lagged siginificantly during Timed Stuffs! " + tclient.hiccupChecks[6] + "ms"
	End Method
	
	Method AddClient(client:TServerClient)
		client.SetLink(m_clients.AddLast(client))
		client.SendPing()
		TPrint "[INFO] Client Connected from: " + client.GetIPAddressAsString()
		client.SendText("[MOTD] " + MOTD, 5)
		If recentBroadcasts.Count() > 0 Then
			For Local str:String = EachIn recentBroadcasts
				If Instr(str, "`")
					Local txtSplit:String[] = str.Split("`")
					client.SendText(txtSplit[0], Int(txtSplit[1]))
				Else
					client.SendText(str)
				End If
			Next
		EndIf
	End Method
	
	Method Disconnect()
		For Local client:TServerClient = EachIn m_clients
			client.SendText("[Server] Shutting Down Server-side, Sorry!", 1)
			client.Close()
		Next
		If m_socket
			m_socket.Close()
		End If
	End Method
	
End Type

Type TServerClient Extends TBaseClient
	
	Field m_link:TLink
	Field messagesRecivedRecently:Int = 0, lastSpamCheck = MilliSecs(), lastObjSync:Int = MilliSecs()
	Field acc:Account = Null
	Field hiccupChecks:Int[10]
	
	'''' Syncing
	Field CurrentTSystem:Int = 0
	Field CurrentTPlayer:Int = 0
	Field CurrentTFleet:Int = 0
	
	Method Create:TServerClient(Socket:TSocket)
		Init(Socket)
		lastPingRecv = MilliSecs()
		For Local ii:Int = 0 Until hiccupChecks.Length
			hiccupChecks[ii] = 0
		Next
		Return Self
	End Method
	
	Method SetLink(link:TLink)
		m_link = link
	End Method
	
	Method RemoveLink()
		If m_link
			m_link.remove()
			m_link = Null
		End If
	End Method
	
	Method SendPacket(pid:Int, data:String)
		Local e:Object = Null
		If Eof() Then Return False
		? Threaded
		Local packetThread:TThread = TThread.Create(SendPacketToStreamThread, New PPacket.Create(Self, pid, data))
		Local startingMS:Int = MilliSecs()
		While packetThread.Running()
			If MilliSecs() - startingMS > 100 Then
				packetThread.Detach()
				TPrint "[WARNING] Client " + name + " Stream Time-Out for PacketID: " + pid + " Data: " + data
				messagesRecivedRecently:+15
				Return False
			EndIf
		Wend
		e = packetThread.wait()
		If e Then
			TPrint("[ERROR] Client " + name + " Packet Sending Failure:" + e.ToString() + "`1")
			Return False
		End If
		? Not Threaded
		'TPrint "Sending Unthreaded Packet.." + pid + " Data: " + data
		Local packetSendMS = MilliSecs()
		e = SendPacketToStreamThread(New PPacket.Create(Self, pid, data))
		If e Then
			TPrint("[ERROR] Client " + name + " Packet Sending Failure:" + e.ToString() + "`1")
			Return False
		End If
		packetSendMS = MilliSecs() - packetSendMS
		If PacketSendMS > 1000 Then
			If server Then server.Kick(Self, "Packets Took Too Long to Send")
			TPrint "[WARNING] Client " + name + " Stream Time-Out " + PacketSendMS + " For PacketID: " + pid + " Data: " + data
		EndIf
		?
		Return True
	End Method
	
	Method Close()
		Super.Close()
		RemoveLink()
		If acc Then acc.loggedIn = False ; acc.SaveToFile()
		'	TPrint("[INFO] " + GetIPAddressAsString() + "::" + name + " disconnected")
	End Method
	
	Method DealWithLogin(packetArray:String[])
		Account.LoadFile() '' Get the latest!
		Local wname:String = Account.cleanName(packetArray[0])'ReadString(ReadInt()))
		Local wpass:String = packetArray[1]
		Local wacc:Account = Account.Find(wname)
		If wacc <> Null
			If wacc.stat = -1 Then SendText("[Server] You can't log into a banned account!", 1) ;Return
			If wacc.loggedIn Then SendText("[Server] Someone else is already logged into that account!", 1) ;Return
			If wpass = wacc.pass Then
				SendPacket(Packet.ID_LOGIN, "1`" + wacc.name)
				acc = wacc
				name = acc.name
				auth = 2
				acc.loggedIn = True
				ply = curGame.FindPlayerObj(name)
				StartSyncing()
				TPrint("[INFO] " + name + " is authenticated from " + GetIPAddressAsString())
			Else
				SendPacket(Packet.ID_LOGIN, "0")
				TPrint("[INFO] " + name + " failed to match " + wname + "'s password from " + GetIPAddressAsString())
			End If
		Else
			SendPacket(Packet.ID_LOGIN, "-1")
			TPrint("[INFO] " + name + " tried to access nonexistant user " + wname + " from " + GetIPAddressAsString())
		End If
	End Method
	
	Method DealWithFleetRequest(packetArray:String[])
		''' fromnetID, tonetID, ships
		If packetArray.Length <> 3 Then SendText("[Server] Incomplete Fleet Dispatch Request Packet, Try Again", 1) ; Return False
		Local fromSys:TSystem = curGame.FindSystemID(Int(packetArray[0]))
		If fromSys.owner <> ply.netID Then
			TPrint "[WARNING!GAME] Recieved a fleet send request from " + name + " to send ships from someone else's system."
			SendText("[Server] You can not send fleet requests to other people's system!", 1)
			Return False
		EndIf
		Local toSys:TSystem = curGame.FindSystemID(Int(packetArray[1]))
		Local tmpF:TFleet = curGame.SendFleet(fromSys, toSys, Int(packetArray[2]), ply)
		
		ply.messages.AddLast("[Admiral] Mobilizing a Fleet of " + Int(packetArray[2]) + " in #" + fromSys.netID + " to move to #" + toSys.netID + ".`5")
		Return True
	End Method
	
	Method StartSyncing()
		If Not auth Then Return False
		If IsSyncingTGame = False Then
			IsSyncingTGame = True
			CurrentTSystem = 0
			CurrentTPlayer = 0
			CurrentTFleet = 0
			SendPacket(Packet.ID_UPDATEALL, curGame.gID + "`" + curGame.CurrentTurn + "`" + curGame.systems.Count() + "`" + curGame.fleets.Count() + "`" + curGame.players.Count())
			ply = curGame.FindPlayerObj(name)
			If ply Then ply.NeedsToSync()
			lastObjSync = MilliSecs()
		End If
		Return True
	End Method
	
	Method SyncSystems(tmp:TSystem)
		'If CurrentTSystem = 0 Then TPrint "[Info] Starting to Sync Systems for " + name
		curGame.ddebugStr = "Sector 3.1"
		CurrentTSystem:+1
		If Not tmp Then Return False
		
		If ply Then
			If tmp.owner = ply.netID Then
				SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_SYSTEM + "`" + tmp.Packetize(-1))
			Else
				Local tmpDist:Float = curGame.GetShortestDistFromPlayersFleets(tmp.x, tmp.y, ply)
				Local tmpDistOther:Float = curGame.GetShortestDistFromPlayersSystems(tmp.x, tmp.y, ply)
				If tmpDistOther < tmpDist Then tmpDist = tmpDistOther
				
				If ply.researchTopics[TPlayer.RES_RADARRANGE] / 4 > tmpDist Then
					SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_SYSTEM + "`" + tmp.Packetize(2))
				Else
					SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_SYSTEM + "`" + tmp.Packetize(1))
				End If
			End If
		Else
			SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_SYSTEM + "`" + tmp.Packetize(1))
		EndIf
		
		Return True
	End Method
	
	Method SyncFleets(tmp:TFleet)
		'If CurrentTFleet = 0 Then TPrint "[Info] Starting to Sync Fleets for " + name
		CurrentTFleet:+1
		If Not tmp Then Return False
		If ply Then
			'' 0Galaxy; 1LongRng; 2Nearby; 3Own
			If tmp.owner = ply.netID Then
				SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_FLEET + "`" + tmp.Packetize(-1)) '' You own it, so you know all!
			Else
				Local tmpDist:Float = curGame.GetShortestDistFromPlayersFleets(tmp.x, tmp.y, ply)
				Local tmpDistOther:Float = curGame.GetShortestDistFromPlayersSystems(tmp.x, tmp.y, ply)
				If tmpDistOther < tmpDist Then tmpDist = tmpDistOther
				If ply.researchTopics[TPlayer.RES_RADARRANGE] / 2 > tmpDist Then
					'		Print name + " [netID" + tmp.netID + "] ply.radarRange / 2 > tmpDist = " + (ply.radarRange / 2) + " > " + tmpDist
					SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_FLEET + "`" + tmp.Packetize(2)) '' Nearby!
				ElseIf ply.researchTopics[TPlayer.RES_RADARRANGE] > tmpDist Then
					'		Print name + " [netID" + tmp.netID + "] ply.radarRange > tmpDist = " + (ply.radarRange) + " > " + tmpDist
					SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_FLEET + "`" + tmp.Packetize(1)) '' Long Range Sensors
				End If
			End If
			'Else
			'	Print name + " [netID" + tmp.netID + "] Anon"
			'	SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_FLEET + "`" + tmp.Packetize(0))
		EndIf
		Return True
	End Method
	
	Method SyncPlayers(tply:TPlayer)
		'if CurrentTPlayer = 0 Then TPrint "[Info] Starting to Sync Players for " + name
		CurrentTPlayer:+1
		If Not tply Then Return False
		
		If name = tply.username Then
			SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_PLAYER + "`" + tply.Packetize(5))
		Else
			If Not tply.homeSystem Then tply.homeSystem = curGame.FindSystemID(tply.homeSystemID)
			If tply.homeSystem And ply Then
				Local tmpDist:Float = curGame.GetShortestDistFromPlayersFleets(tply.homeSystem.x, tply.homeSystem.y, ply)
				Local tmpDistOther:Float = curGame.GetShortestDistFromPlayersSystems(tply.homeSystem.x, tply.homeSystem.y, ply)
				If tmpDistOther < tmpDist Then tmpDist = tmpDistOther
				If ply.researchTopics[TPlayer.RES_RADARRANGE] / 4 > tmpDist Then
					SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_PLAYER + "`" + tply.Packetize(1))
				Else
					SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_PLAYER + "`" + tply.Packetize(0))
				End If
			Else
				SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_PLAYER + "`" + tply.Packetize(0))
			EndIf
		EndIf
		Return True
	End Method
	
	Method HandleMessage(id:Int, data:String)
		Local packetArray:String[] = data.Split("`")
		'	If id <> Packet.ID_PING And id <> Packet.ID_PONG Then TPrint "[CLIENT] Packet:'" + name + "' ID:" + id + " Data:'" + data + "' Args:" + packetArray.Length
		messagesRecivedRecently:+1
		lastPingRecv = MilliSecs() '' Ultimate timeout protector
		Select id
			Case Packet.ID_PING
				SendPong()
				
			Case Packet.ID_PONG
				pingDelta = MilliSecs() - lastPingSent
				lastPingRecv = MilliSecs()
				
			Case Packet.ID_MESSAGE
				If auth Then
					recievedMessages.AddLast(packetArray[0])'ReadString(ReadInt()))
					TPrint "[INFO] Recieved message from " + name + "!"
				Else
					SendText("[Server] You can not send messages until you login!", 1)
					TPrint "[INFO] Recieved message from " + name + ", but isn't authorized."
				EndIf
				
			Case Packet.ID_MESSAGESELF
				If auth Then
					server.SendBroadcast("/" + name + " " + packetArray[0] + "/", False)
					'recievedMessages.AddLast(packetArray[0])'ReadString(ReadInt()))
					TPrint "[INFO] Recieved message from " + name + "!"
				Else
					SendText("[Server] You can not send messages until you login!", 1)
					TPrint "[INFO] Recieved message from " + name + ", but isn't authorized."
				EndIf
				
			Case Packet.ID_LOGIN
				If packetArray.Length <> 2 Then
					TPrint("[WARNING] Packet.ID_LOGIN Packet didn't provide enough data: '" + data + "'")
					SendText("[Server] Invalid Login Data, Please Try Again", 1)
				Else
					DealWithLogin(packetArray)
				End If
			'' Send IntIntString
				
			Case Packet.ID_USERLIST
				If auth Then
					Local cilentNames:String = ""
					For Local client:TServerClient = EachIn server.m_clients
						If client.stat = 1337 Then cilentNames:+"@"
						cilentNames:+client.name + " "
					Next
					SendText("[SERVER] " + server.m_clients.Count() + " Players Online : " + cilentNames, 3)
				Else
					SendText("[Server] You can not send messages until you login!", 1)
					TPrint "[INFO] Recieved a userlist request from " + name + ", but isn't authorized."
				End If
				
			Case Packet.ID_UPDATEALL
				'If auth then
				StartSyncing
			'Endif
				
			Case Packet.ID_JOINREQUEST
				If auth Then
					Local result:Int = 0
					If packetArray.Length Then TPrint "[ServerC] " + packetArray[0] + " Int:" + Int(packetArray[0])
					If packetArray.Length <> 1 Then
						result = curGame.PlayerJoin(name)
					Else
						result = curGame.PlayerJoin(name, Int(packetArray[0]))
					End If
					If result = 0 Then
						SendText("[Server] You are already joined in this game!", 1)
					ElseIf result = -1 Then
						SendText("[Server] The map is too full!", 1)
					Else
						StartSyncing()
					EndIf
				Else
					SendText("[Server] You can not request to join until you login!", 1)
				End If
				
			Case Packet.ID_CMDSENDFLEET
				If auth Then
					If ply Then
						DealWithFleetRequest(packetArray)
					Else
						TPrint "[WARNING!GAME] Recieved a fleet send request from " + name + ", but isn't authorized."
						SendText("[Server] You can not send fleet requests without joining the game!", 1)
					End If
				Else
					SendText("[Server] You can not request to send fleets until you login!", 1)
				End If
				
			Case Packet.ID_CMDRETREATFLEET
				If auth Then
					If packetArray.Length <> 1 Then
						SendText("[Server] Malformed Retreat Request", 1)
					Else
						If ply Then
							Local tmpf:TFleet = curGame.FindFleetID(Int(packetArray[0]))
							If tmpf Then
								If tmpf.owner = ply.netID Then
									Local tmps:TSystem = tmpf.destSys
									Local tmpsID:Int = tmpf.destID
									tmpf.destSys = tmpf.homeSys
									tmpf.destID = tmpf.homeID
									tmpf.homeSys = tmps
									tmpf.homeID = tmpsID
									SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_FLEET + "`" + tmpf.Packetize(-1))
									'	SendText("[Admiral] Fleet #" + tmpf.netID + " is now headed to System #" + tmpf.destID, 5)
									ply.messages.AddLast("[Admiral] Fleet #" + tmpf.netID + " is now headed to System #" + tmpf.destID + "`5")
								Else
									TPrint "[WARNING!GAME] Recieved a fleet " + tmpf.netID + " retreat from " + name + ", but isn't authorized to move that fleet."
									SendText("[Server] You can not send fleet retreat request to someone else's fleets!", 1)
								End If
							Else
								SendText("[Server] Unable to find fleet to send retreat request to! Please try again.", 1)
							EndIf
						Else
							TPrint "[WARNING!GAME] Recieved a fleet send retreat from " + name + ", but isn't authorized."
							SendText("[Server] You can not send fleet retreat request without joining the game!", 1)
						End If
					EndIf
				Else
					SendText("[Server] You can not request to send fleets until you login!", 1)
				End If
				
			Case Packet.ID_CMDSTOPFLEET
				If auth Then
					If packetArray.Length <> 1 Then
						SendText("[Server] Malformed Retreat Request", 1)
					Else
						If ply Then
							Local tmpf:TFleet = curGame.FindFleetID(Int(packetArray[0]))
							If tmpf.owner = ply.netID Then
								tmpf.speed = 0
								SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_FLEET + "`" + tmpf.Packetize(-1))
								ply.messages.AddLast("[Admiral] Fleet #" + tmpf.netID + " has stopped`5")
							Else
								TPrint "[WARNING!GAME] Recieved a fleet " + tmpf.netID + " order from " + name + ", but isn't authorized to move that fleet."
								SendText("[Server] You can not send fleet retreat request to someone else's fleets!", 1)
							End If
						Else
							TPrint "[WARNING!GAME] Recieved a fleet send order from " + name + ", but isn't authorized."
							SendText("[Server] You can not send fleet order request without joining the game!", 1)
						End If
					EndIf
				Else
					SendText("[Server] You can not request to order fleets until you login!", 1)
				End If
				
			Case Packet.ID_CMDSTARTFLEET
				If auth Then
					If packetArray.Length <> 1 Then
						SendText("[Server] Malformed Retreat Request", 1)
					Else
						If ply Then
							Local tmpf:TFleet = curGame.FindFleetID(Int(packetArray[0]))
							If tmpf.owner = ply.netID Then
								tmpf.speed = ply.researchTopics[TPlayer.RES_FLEETSPEED]
								SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_FLEET + "`" + tmpf.Packetize(-1))
								ply.messages.AddLast("[Admiral] Fleet #" + tmpf.netID + " has started`5")
							Else
								TPrint "[WARNING!GAME] Recieved a fleet " + tmpf.netID + " order from " + name + ", but isn't authorized to move that fleet."
								SendText("[Server] You can not send fleet order request to someone else's fleets!", 1)
							End If
						Else
							TPrint "[WARNING!GAME] Recieved a fleet send order from " + name + ", but isn't authorized."
							SendText("[Server] You can not send fleet order request without joining the game!", 1)
						End If
					EndIf
				Else
					SendText("[Server] You can not request to order fleets until you login!", 1)
				End If
			
			Case Packet.ID_CMDBUILDSHIP
				If auth Then
					If packetArray.Length <> 1 Then
						SendText("[Server] Malformed Build Request", 1)
					Else
						If ply Then
							Local tmp:TSystem = curGame.FindSystemID(Int(packetArray[0]))
							If tmp Then
								If tmp.owner = ply.netID Then
									tmp.isBuilding:*- 1
									If tmp.isBuilding > 0 Then
										ply.messages.AddLast("[Attache] Construction started at #" + tmp.netID + "`5")
									Else
										ply.messages.AddLast("[Attache] Construction stopped at #" + tmp.netID + "`5")
									End If
								Else
									TPrint "[WARNING!GAME] Recieved a build request from " + name + ", but isn't authorized."
									SendText("[Server] You can not send build requests to someone else's fleets!", 1)
								End If
							Else
								SendText("[Server] Malformed Build Ship Request System ID", 1)
							EndIf
						Else
							TPrint "[WARNING!GAME] Recieved a fleet send request from " + name + ", but isn't authorized."
							SendText("[Server] You can not send fleet requests without joining the game!", 1)
						End If
					EndIf
				Else
					SendText("[Server] You can not request to send fleets until you login!", 1)
				End If
			'		SendText("[Server] Deprecated Feature!", 1)
								
			Case Packet.ID_SETEMPIRENAME
				If auth Then
					If packetArray.Length = 1 And Account.cleanName(data) <> "" Then
						If ply Then
							If ply.nameChanges > 0 Then
								data = Account.cleanName(data)
								ply.nameChanges:-1
								curGame.SendGNNUpdate("The " + ply.empireName + " shall henceforth be called the '" + data + "'!")
								SendText("[Server] You can only change your name " + ply.nameChanges + " more time(s)!", 5)
								ply.empireName = data
								ply.NeedsToSync()
							Else
								SendText("[Server] You can not change your empire name more than 2 times!", 1)
							End If
						Else
							SendText("[Server] You can not change your empire name until you join!", 1)
						End If
					End If
				Else
					SendText("[Server] You can not request to join until you login and/or Improper name given!", 1)
				End If
				
			Case Packet.ID_RESEARCHSTART
				If auth Then
					If packetArray.Length <> 1 Then
						SendText("[ServerC] Malformed Research Request", 1)
					Else
						If ply Then
							If ply.researchAspect = Int(packetArray[0]) Then
								ply.messages.AddLast("[Attache] You are already researching that!`5")
							Else
								ply.SetResearchTopic(Int(packetArray[0]))
								ply.messages.AddLast("[Attache] Research has started on " + ply.GetResearchTopicName(ply.researchAspect, False) + "!`5")
								SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_PLAYER + "`" + ply.Packetize(-1))
							EndIf
						Else
							TPrint "[WARNING!GAME] Recieved a Research request from " + name + ", but isn't authorized."
							SendText("[ServerC] You can not send Research requests without joining the game!", 1)
						End If
					EndIf
				Else
					SendText("[ServerC] You can not request to Research until you login!", 1)
				End If
				
			Case Packet.ID_RESEARCHSTOP
				If auth Then
					If ply Then
						ply.SetResearchTopic(-1)
						SendText("[Attache] Research has stopped", 5)
					Else
						TPrint "[WARNING!GAME] Recieved a Research request from " + name + ", but isn't authorized."
						SendText("[Server] You can not send Research requests without joining the game!", 1)
					End If
				Else
					SendText("[Server] You can not request to Research until you login!", 1)
				End If
				
			Case Packet.ID_RESEARCHPAY
'				If auth Then
'					If ply Then
'						Select ply.PayForResearch(ply.researchAspect)
'							Case (-1)
'								ply.messages.AddLast("[Attache] You must at least have some positive amount of credits to do that!`1")
'							Case (-2)
'								ply.messages.AddLast("[Attache] The research topic is almost done already!`1")
'						End Select
'						SendPacket(Packet.ID_UPDATEOBJ, TNetObject.ID_PLAYER + "`" + ply.Packetize(-1))
'					Else
'						TPrint "[WARNING!GAME] Recieved a Research request from " + name + ", but isn't authorized."
'						SendText("[Server] You can not send Research requests without joining the game!", 1)
'					End If
'				Else
'					SendText("[Server] You can not request to Research until you login!", 1)
'				End If
					SendText("[Server] Deprecated Feature!", 1)
				
				
				'	Case Packet.ID_UPDATEOBJ ''' Shouldn't recieve this from a player?
				
				Default
				TPrint("[WARNING] Unknown network message id: " + id)
				messagesRecivedRecently:+4
		End Select
		
		Return True
	End Method
	
End Type

Type TMasterClient Extends TBaseClient
	Field attacheUpdates:TList = CreateList(), newAttacheUpdate:Int = False, newChatUpdate:Int = False, finishedSyncingThisFrame:Int = False
	Field totalSystems:Int = -1, totalFleets:Int = -1, totalPlayers:Int = -1
	
	Method Create:TMasterClient(Socket:TSocket)
		Init(Socket)
		Return Self
	End Method
	
	Method SendLogin(name:String, pass:String)
		SendPacket(Packet.ID_LOGIN, name + "`" + MD5(pass))
	End Method
	
	Method SyncTGame()
		SendPacket(Packet.ID_UPDATEALL, "plz")
	End Method
	
	Method HandleMessage(id:Int, data:String)
		Local packetArray:String[] = data.Split("`")
		If id <> Packet.ID_PING And id <> Packet.ID_PONG Then Print "MClient Packet Recived! ID:" + id + " Data:'" + data + "' Args:" + packetArray.Length
		Select id
			Case Packet.ID_LOGIN
				If Not packetArray.Length > 0 Then
					TPrint("[WARNING] Packet.ID_LOGIN Packet didn't provide enough data: '" + data + "'")
					Return
				EndIf
				Select Int(packetArray[0])
					Case 1 ''' WOO! We're in!
						If Not packetArray.Length > 1 Then
							TPrint("[WARNING] Packet.ID_LOGIN Packet didn't provide enough data: '" + data + "'")
							Return
						EndIf
						name = packetArray[1]
						TPrint("[INFO] Logged in as: " + name)
						auth = True
					Case 0
						recievedMessages.AddLast("Password is incorrect!")
					Case (-1)
						recievedMessages.AddLast("Username does not Exist!")
				End Select
				
			Case Packet.ID_PING
				SendPong()
				
			Case Packet.ID_PONG
				pingDelta = MilliSecs() - lastPingSent
				lastPingRecv = MilliSecs()
				
			Case Packet.ID_MESSAGE
				recievedMessages.AddLast(data)
				newChatUpdate = True
				
			Case Packet.ID_MESSAGEATTACHE
				attacheUpdates.AddLast(data)
				newAttacheUpdate = True
				
			Case Packet.ID_UPDATEALL
				If data.ToLower() = "done" Then
					IsSyncingTGame = False
					finishedSyncingThisFrame = True
					lastSync = MilliSecs()
					ply = curGame.FindPlayerObj(name)
					For Local tflt:TFleet = EachIn curGame.fleets
						If Not tflt.Sync Then curGame.fleets.remove(tflt)
					Next
				Else
					If packetArray.Length = 1 Then
						curGame.gID = Int(data)
					ElseIf packetArray.Length = 2 Then
						curGame.gID = Int(packetArray[0])
						curGame.CurrentTurn = Int(packetArray[1])
					Else
						curGame.gID = Int(packetArray[0])
						curGame.CurrentTurn = Int(packetArray[1])
						totalSystems = Int(packetArray[2])
						totalFleets = Int(packetArray[3])
						totalPlayers = Int(packetArray[4])
					End If
					IsSyncingTGame = True
					curGame.ResetFleetSync()
				End If
				
			Case Packet.ID_JOINREQUEST
				SyncTGame()
				
			Case Packet.ID_UPDATEOBJ
				Select Int(packetArray[0])
					Case TNetObject.ID_SYSTEM
						curGame.UnPackSystem(packetArray[1..])
					Case TNetObject.ID_PLAYER
						curGame.UnPackPlayer(packetArray[1..])
						TPrint "Player Packet Received: '" + Combine(packetArray[1..]) + "'"
					Case TNetObject.ID_FLEET
						curGame.UnPackFleet(packetArray[1..])
						
						Default
						recievedMessages.AddLast("Unkown TNetObject ID " + Int(packetArray[0]) + "1`1")
				End Select
				
				Default
				TPrint("[WARNING] Unknown network message id: " + id)
		End Select
		
		Return True
	End Method
	
End Type