Global curGame:TGame = New TGame 'Null

Type TGame
	Field systems:TList = CreateList()
	Field gID:Int = 0 'MilliSecs() / 5000 '
	Field lastUpdate:Int = MilliSecs()
	Field players:TList = CreateList()
	Field fleets:TList = CreateList()
	Field CurrentTurn:Int = 0
	
	Field GNNTicker:TList = CreateList()
	
	Field ddebugStr:String = ""
	
	Method GetYear:String()
		Return tb.Math.LimitDecimal(3500.0 + (CurrentTurn * 0.05))
	End Method
	
	Field attackersModifer:Float = 0.0025 ' Orig 0.025
	Field defendersModifer:Float = 0.003 ' Orig 0.03
	Field movementTimeScale:Float = 0.04
	
	Method SendGNNUpdate(msgStr:String)
		For Local ply:TPlayer = EachIn players
			ply.messages.AddLast("[GNN] " + msgStr + "`3")
		Next
		If server Then server.SendBroadcast("[GNN] " + msgStr)
		GNNTicker.AddFirst(msgStr)
		If GNNTicker.Count() > 10 Then GNNTicker.RemoveLast()
	End Method
	
	Method UpdateGame()
		lastUpdate = MilliSecs()
		TPrint "[INFO] Game tick! " + CurrentTurn
		
		For Local ply:TPlayer = EachIn players
			ply.UpdateResearch()
		Next
		
		For Local sys:TSystem = EachIn systems
			sys.Update()
			If sys.owner > 0 Then '' Calculate new credits/research points this turn.
				If sys.quality = 10 Then
					FindPlayerID(sys.owner).newCreditsThisTurn:+sys.quality * FindPlayerID(sys.owner).researchTopics[TPlayer.RES_RESEARCH]
				Else
					If Not sys.isBuilding Then
						FindPlayerID(sys.owner).newCreditsThisTurn:+sys.quality * FindPlayerID(sys.owner).researchTopics[TPlayer.RES_RESEARCH]
					Else
						FindPlayerID(sys.owner).newCreditsThisTurn:+sys.quality * FindPlayerID(sys.owner).researchTopics[TPlayer.RES_RESEARCH] * 0.1
					EndIf
				EndIf
			End If
			
			''' Shoot dem fleets
			For Local flt:TFleet = EachIn fleets
				If flt.owner = sys.owner Then Continue
				If tb.Math.GetDistance(sys.x, sys.y, flt.x, flt.y) < movementTimeScale * 1.5 * curGame.FindPlayerID(flt.owner).researchTopics[TPlayer.RES_PLANETARYDEFENSE] Then
					If curGame.FindPlayerID(sys.owner) Then
						flt.damageTaken:+sys.ships * (curGame.FindPlayerID(Sys.owner).researchTopics[TPlayer.RES_PLANETARYDEFENSE] * defendersModifer) * (1 + (curGame.FindPlayerID(Sys.owner).homeSystemID = sys.netID))
					Else
						flt.damageTaken:+sys.ships * defendersModifer
					End If
						
					If flt.strength < 1 Then
						flt.strength = -1
						flt.NeedsToSync()
						fleets.remove(flt)
						FindPlayerID(flt.owner).messages.AddLast("[Admiral] Your fleet #" + flt.netID + " at System #" + sys.netID + " was destroyed.`1")
						
						If FindPlayerID(Sys.owner) Then
							FindPlayerID(sys.owner).messages.AddLast("[Admiral] Your garrison at System #" + sys.netID + " has destroyed " + FindPlayerID(sys.owner).empireName + "'s fleet of " + flt.originalStrength + " ships.`1")
							SendGNNUpdate("The " + curGame.FindPlayerID(flt.owner).empireName + " failed to take over the " + FindPlayerID(sys.owner).empireName + " System #" + sys.netID + " using around " + (((Rand(flt.originalStrength / 2, flt.originalStrength) / 10) + 1) * 10) + " ships!")
						Else
							SendGNNUpdate("The " + curGame.FindPlayerID(flt.owner).empireName + " failed to take over System #" + sys.netID + " with around " + (((Rand(flt.originalStrength / 2, flt.originalStrength) / 10) + 1) * 10) + " ships!")
						End If
					Else
						If Int(flt.damageTaken) > 0 Then
							flt.strength:-Int(flt.damageTaken)
							FindPlayerID(flt.owner).messages.AddLast("[Admiral] Fleet #" + flt.netID + " of " + flt.originalStrength + " ships at System #" + sys.netID + " has lost " + Int(flt.damageTaken) + " ships.`1")
							If sys.owner > (-1) Then FindPlayerID(sys.owner).messages.AddLast("[Admiral] Enemy Fleet #" + flt.netID + " of " + flt.originalStrength + " ships at System #" + sys.netID + " has lost " + Int(flt.damageTaken) + " ships to our garrison!`2")
							flt.damageTaken:-Int(flt.damageTaken)
						EndIf
					End If
				EndIf
			Next
		Next
		
		For Local ply:TPlayer = EachIn players
			ply.credits:+Int(ply.newCreditsThisTurn)
			ply.newCreditsThisTurn = 0.0
			ply.NeedsToSync()
		Next
		
		For Local flt:TFleet = EachIn fleets
			If tb.Math.GetDistance(flt.destSys.x, flt.destsys.y, flt.x, flt.y) < movementTimeScale * 1.5 * curGame.FindPlayerID(flt.owner).researchTopics[TPlayer.RES_FLEETSPEED] Then
				If flt.destSys.owner = flt.owner Then ''' If we already own it then...
					flt.destSys.owner = flt.owner
					flt.destSys.ships:+flt.strength
					fleets.remove(flt)
					flt.strength = -1
					flt.NeedsToSync()
				Else '' Otherwise..
					If flt.destSys.ships > 0 Then
						flt.damageOutput:+flt.strength * (curGame.FindPlayerID(flt.owner).researchTopics[TPlayer.RES_FLEETWEAPONS] * attackersModifer)
						If Int(flt.damageOutput) > 0 Then
							flt.destSys.ships:-Int(flt.damageOutput)
							FindPlayerID(flt.owner).messages.AddLast("[Admiral] Fleet #" + flt.netID + " of " + flt.originalStrength + " ships at System #" + flt.destID + " has destroyed " + Int(flt.damageOutput) + " ships!`2")
							If flt.destSys.owner > - 1 Then FindPlayerID(flt.destSys.owner).messages.AddLast("[Admiral] Enemy Fleet #" + flt.netID + " of " + flt.originalStrength + " ships at System #" + flt.destID + " has destroyed " + Int(flt.damageOutput) + " ships in our garrison.`1")
							flt.damageOutput:-Int(flt.damageOutput)
						End If
						flt.NeedsToSync()
					Else
						If flt.destSys.owner > 0 Then
							SendGNNUpdate("The " + FindPlayerID(flt.owner).empireName + " took over System #" + flt.destID + " from the " + FindPlayerID(flt.destSys.owner).empireName + " using around " + Rand(flt.originalStrength / 2, flt.originalStrength) + " ships!")
'							Local tmpPly:TPlayer = FindPlayerID(flt.owner)
'							Local tmpOPly:TPlayer = FindPlayerID(flt.destSys.owner)
'							Local rando:Int = Rand(0, 100)
'							If rando < 35 Then
'								Local tmpCash = Rand(1, tmpOPly.credits / 10)
'								tmpPly.credits:+tmpCash
'								tmpOPly.credits:-tmpCash
'								If tmpCash > 1000 Then SendGNNUpdate("A credit heist happened in #" + flt.destID + " system where the " + tmpPly.empireName + " stole " + tb.Math.LimitDenom(tmpCash) + " from the " + tmpOPly.empireName + "!")
'								tmpPly.messages.AddLast("[Attache] In System #" + flt.destID + " we stole " + tb.Math.LimitDenom(tmpCash) + " from the " + tmpOPly.empireName + "!`2")
'								tmpOPly.messages.AddLast("[Attache] The " + tmpPly.empireName + " stole " + tb.Math.LimitDenom(tmpCash) + " from us in the #" + flt.destID + " System!`1")
'							ElseIf rando < 45
'								Local tmpTech:Float = Rnd(0.1, 0.5)
'								Local tmpTopic:Int = Rand(0, 6)
'								tmpPly.researchTopics[tmpTopic]:+tmpTech
'								tmpOPly.researchTopics[tmpTopic]:-tmpTech
'								If tmpTech > 0.3 Then SendGNNUpdate("A research heist happened in #" + flt.destID + " system where the " + tmpPly.empireName + " stole " + tb.Math.LimitDecimal(tmpTech) + " of " + tmpOPly.GetResearchTopicName(tmpTopic, False) + " research from the " + tmpOPly.empireName + "!")
'								tmpPly.messages.AddLast("[Attache] In System #" + flt.destID + " we stole " + tb.Math.LimitDecimal(tmpTech) + " of " + tmpOPly.GetResearchTopicName(tmpTopic, False) + " research from the " + tmpOPly.empireName + "!`2")
'								tmpOPly.messages.AddLast("[Attache] The " + tmpPly.empireName + " stole " + tb.Math.LimitDecimal(tmpTech) + " of " + tmpOPly.GetResearchTopicName(tmpTopic, False) + " research from us in the #" + flt.destID + " System!`1")
'							ElseIf rando < 50 Then
'								Local tmpCash = Rand(tmpOPly.credits / 10, tmpOPly.credits / 2)
'								tmpPly.credits:+tmpCash
'								tmpOPly.credits:-tmpCash
'								If tmpCash > 1000 Then SendGNNUpdate("A major credit heist happened in #" + flt.destID + " system where the " + tmpPly.empireName + " stole " + tb.Math.LimitDenom(tmpCash) + " from the " + tmpOPly.empireName + "!")
'								tmpPly.messages.AddLast("[Attache] In System #" + flt.destID + " we stole " + tb.Math.LimitDenom(tmpCash) + " from the " + tmpOPly.empireName + "!`2")
'								tmpOPly.messages.AddLast("[Attache] The " + tmpPly.empireName + " stole " + tb.Math.LimitDenom(tmpCash) + " from us in the #" + flt.destID + " System!`1")
'							End If
						Else
							SendGNNUpdate("The " + FindPlayerID(flt.owner).empireName + " took over System #" + flt.destID + " using around " + (((Rand(flt.originalStrength / 2, flt.originalStrength) / 10) + 1) * 10) + " ships!")
						End If
						flt.destSys.owner = flt.owner
						If flt.destSys.ships < 0 Then flt.destSys.ships = 0
						flt.destSys.ships:+flt.strength
						flt.destSys.isBuilding = True
						fleets.remove(flt)
						flt.destSys.NeedsToSync()
						flt.NeedsToSync()
					End If
				End If
			Else
				Local fvfCombat:Int = False
				For Local oflt:TFleet = EachIn fleets
					If oflt <> flt Then If oflt.owner <> flt.owner Then
							If tb.Math.GetDistance(oflt.x, oflt.y, flt.x, flt.y) < 0.2 Then
								fvfCombat = True
								oflt.damageTaken:+flt.strength * (curGame.FindPlayerID(flt.owner).researchTopics[TPlayer.RES_FLEETWEAPONS] * attackersModifer)
							
								If flt.strength < 1 Then
									flt.strength = -1
									flt.NeedsToSync()
									fleets.remove(flt)
									FindPlayerID(flt.owner).messages.AddLast("[Admiral] Your Fleet #" + flt.netID + " of " + flt.originalStrength + " ships was destroyed by " + FindPlayerID(oflt.owner).empireName + "'s Fleet #" + oflt.netID + " of " + oflt.originalStrength + " ships`1")
									FindPlayerID(oflt.owner).messages.AddLast("[Admiral] Your Fleet #" + oflt.netID + " of " + oflt.originalStrength + " ships destroyed " + FindPlayerID(flt.owner).empireName + "'s Fleet #" + flt.netID + " of " + flt.originalStrength + " ships!`2")
								'	SendGNNUpdate(FindPlayerID(flt.owner).empireName + "'s Fleet #" + flt.netID + " of about " + (((Rand(flt.originalStrength / 2, flt.originalStrength) / 10) + 1) * 10) + " ships was destroyed by " + FindPlayerID(oflt.owner).empireName + "'s fleet of about " + Int(oflt.originalStrength * 0.75) + " ships between the " + flt.destID + " and " + flt.homeID + " systems.")
									SendGNNUpdate("A fleet of over " + (((Rand(flt.originalStrength / 2, flt.originalStrength - 10) / 10) + 1) * 10) + " " + FindPlayerID(flt.owner).empireName + " ships by a " + FindPlayerID(oflt.owner).empireName + " fleet between the " + flt.destID + " and " + flt.homeID + " systems.")
								Else
									If Int(flt.damageTaken) > 0 Then
										flt.strength:-Int(flt.damageTaken)
										FindPlayerID(flt.owner).messages.AddLast("[Admiral] Fleet #" + flt.netID + " of " + flt.originalStrength + " ships has lost " + Int(flt.damageTaken) + " ships to " + oflt.owner + "'s Fleet #" + oflt.netID + "`1")
										FindPlayerID(oflt.owner).messages.AddLast("[Admiral] Fleet #" + oflt.netID + " of " + oflt.originalStrength + " ships has destroyed " + Int(flt.damageTaken) + " ships of " + flt.owner + "'s Fleet #" + flt.netID + "!`2")
										flt.damageTaken:-Int(flt.damageTaken)
									EndIf
								End If
							EndIf
						End If
				Next
				
				If Not fvfCombat Then flt.Update(movementTimeScale) ; flt.NeedsToSync()
			EndIf
		Next
		CurrentTurn:+1
	End Method
	
	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	''' Find crap
	Method FindSystemID:TSystem(netID:Int)
		For Local sys:TSystem = EachIn systems
			If sys.netID = netID Then Return sys
		Next
		Return Null
	End Method
	
	Method CountOwnedSystems:Int(owner:Int)
		Local Count:Int = 0
		For Local sys:TSystem = EachIn systems
			If sys.owner = owner Then Count:+1
		Next
		Return Count
	End Method
	
	Method FindPlayerID:TPlayer(pID:Int)
		For Local ply:TPlayer = EachIn players
			If ply.netID = pID Then Return ply
		Next
		Return Null
	End Method
	
	Method FindPlayerObj:TPlayer(name:String)
		name = name.ToLower()
		For Local ply:TPlayer = EachIn players
			If ply.empireName.ToLower() = name Then Return ply
			If ply.username.ToLower() = name Then Return ply
		Next
		Return Null
	End Method
	
	Method FindFleetID:TFleet(netID:Int)
		For Local flt:TFleet = EachIn fleets
			If flt.netID = netID Then Return flt
		Next
		Return Null
	End Method
	
	Method CountOwnedFleets:Int(owner:Int)
		Local Count:Int = 0
		For Local flt:TFleet = EachIn fleets
			If flt.owner = owner Then Count:+1
		Next
		Return Count
	End Method
	
	Method GetOpenFleetID:Int()
		For Local ii:Int = 0 To fleets.Count()
			If Not FindFleetID(ii) Then Return ii
		Next
		Return fleets.Count() + 1
	End Method
	
	Method FindJoinableSystem:TSystem(minDist:Float = 22, maxtimeout:Int = 150)
		Local sys:TSystem = Null
		Local curTimeout:Int, systemsNearby:Int = 0, nearbyDist:Float = minDist / 2, adjcentDist:Float = minDist / 3
		While sys = Null
			sys = FindSystemID(Rand(0, systems.Count()))
			If sys = Null Then Continue
			If sys.owner = -1 Then
				systemsNearby = 0
				If sys Then
					For Local osys:TSystem = EachIn systems
						If osys = sys Then Continue
						If osys.owner = -1 Then
							If systemsNearby < 3 Then
								If tb.Math.GetDistance(sys.x, sys.y, osys.x, osys.y) < adjcentDist Then systemsNearby:+1
							Else
								If tb.Math.GetDistance(sys.x, sys.y, osys.x, osys.y) < nearbyDist Then systemsNearby:+1
							EndIf
						Else
							If tb.Math.GetDistance(sys.x, sys.y, osys.x, osys.y) < minDist Then
								sys = Null
								Exit
							EndIf
						EndIf
					Next
				EndIf
			EndIf
			If systemsNearby < 5 Then sys = Null
			If curTimeout > maxtimeout Then Exit
			curTimeout:+1
		Wend
		Return sys
	End Method
	
	Method GetShortestDistFromPlayersSystems:Float(x:Float, y:Float, ply:TPlayer)
		Local minDist:Float = 10000, dist:Float
		For Local sys:TSystem = EachIn systems
			If sys.owner = ply.netID Then
				dist = tb.Math.GetDistance(x, y, sys.x, sys.y)
				If dist < minDist Then minDist = dist
			EndIf
		Next
		Return minDist
	End Method
	
	Method GetShortestDistFromPlayersFleets:Float(x:Float, y:Float, ply:TPlayer)
		Local minDist:Float = 10000, dist:Float
		For Local flt:TFleet = EachIn fleets
			If flt.owner = ply.netID Then
				dist = tb.Math.GetDistance(x, y, flt.x, flt.y)
				If dist < minDist Then minDist = dist
			EndIf
		Next
		Return minDist
	End Method
	
	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	''' Unpack crap	
	Method UnPackPlayer(packetArray:String[])
		Local ply:TPlayer = FindPlayerID(Int(packetArray[0]))
		If Not ply Then '' If doesn't exist, make it!
			ply = TPlayer.CreateClient(Combine(packetArray))
		Else '' Otherwise, just update it
			ply.UnPack(packetArray)
		End If
	End Method
	
	Method UnPackSystem(packetArray:String[])
		Local tSys:TSystem = FindSystemID(Int(packetArray[0]))
		If Not tSys Then '' If doesn't exist, make it!
			tSys = TSystem.Create(Combine(packetArray))
		Else '' Otherwise, just update it
			tSys.UnPack(packetArray)
		End If
	End Method
	
	Method UnPackFleet(packetArray:String[])
		Local flt:TFleet = FindFleetID(Int(packetArray[0]))
		If Not flt Then '' If doesn't exist, make it!
			flt = TFleet.Create(Combine(packetArray))
		Else '' Otherwise, just update it
			flt.UnPack(packetArray)
		End If
		If flt.strength < 1 Then fleets.remove(flt)
	End Method
	
	Method ResetFleetSync()
		For Local flt:TFleet = EachIn fleets
			flt.Sync = False
		Next
	End Method
	
	Method RemoveUnsyncedFleets()
		For Local flt:TFleet = EachIn fleets
			If flt.Sync = False Then
				fleets.remove(flt)
			ElseIf flt.strength < 1 Then
				fleets.remove(flt)
			EndIf
		Next
	End Method
	
	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	''' New crap
	Method PlayerJoin:Int(playerName:String, preferedTopic:Int = -1)
		TPrint "[INFO] Seeing if " + playerName + " is already joined..."
		If FindPlayerObj(playerName) Then TPrint "[Game] Player has already joined!" ; Return 0
		TPrint "[INFO] Player is new, finding a system..."
		Local homeSystem:TSystem = FindJoinableSystem()
		If Not homeSystem Then TPrint "[Game] Can not find system for player!" ; Return(-1)
		TPrint "[INFO] Found system ID: " + homeSystem.netID + "! :D"
		Local ply:TPlayer = TPlayer.Create(playerName)
		
		ply.SetHomeSystem(homeSystem)
		homeSystem.ships = 50 + (CurrentTurn / 20)
		homeSystem.quality = 10
		homeSystem.isBuilding = True
?not console
		ply.rgb = tb.Draw.GetRGBBasedOnNumber(players.Count())
?
		
		If preferedTopic = -1 Then preferedTopic = Rand(0, ply.researchTopics.Length - 2)
		ply.preferedResearchAspect = preferedTopic
		ply.SetResearchTopic(ply.preferedResearchAspect)
		
		Local empirePrefix:String = "unknown"
		Select preferedTopic
			Case TPlayer.RES_RESEARCH
				empirePrefix = "scientific prodigy"
			Case TPlayer.RES_SHIPBUILDING
				empirePrefix = "master ship-builder"
			Case TPlayer.RES_FLEETWEAPONS
				empirePrefix = "legendary weaponsmith"
			Case TPlayer.RES_FUELRANGE
				empirePrefix = "amazing fuel tank designer"
			Case TPlayer.RES_RADARRANGE
				empirePrefix = "long-range sensor prodigy"
			Case TPlayer.RES_FLEETSPEED
				empirePrefix = "speed demon"
			Case TPlayer.RES_PLANETARYDEFENSE
				empirePrefix = "defense guru"
		End Select
		ply.researchTopics[preferedTopic]:+ply.GetResearchAdvanceAmount(preferedTopic) * (10 + (CurrentTurn / 50.0))
		ply.nextResearchTopic = preferedTopic
		
		SendGNNUpdate("The " + empirePrefix + " " + ply.username + " has joined the game at system " + homeSystem.netID + "!")
		
		ply.NeedsToSync()
		homeSystem.NeedsToSync()
		
		Return 1
	End Method
	
	Method CreateStarfield(xx%, yy%, numOfStars:Int, maxDist:Float, minDist:Float = 5)
		Local tmpAngle:Float
		Local tmpDist:Float
		Local tmp:TSystem
		For Local ii:Int = 0 To numOfStars
			tmpAngle = Rnd(0.0, 360.0)
			tmpDist = Rnd(minDist, maxDist)
			tmp = TSystem.Create("-1`" + (xx + Int(Cos(tmpAngle) * tmpDist)) + "`" + (yy + Int(Sin(tmpAngle) * tmpDist)))
			If tmp Then
				tmp.NeedsToSync()
				tmp.ships = Rand(-5, 15) * (1 + (4 * (Rand(100) > 85)))
				If tmp.ships < 0 Then tmp.ships = 0
				tmp.quality = Rand(1, 99)
				tmp.quality = Int(((tmp.quality * tmp.quality) / 1100.0) + 1)
				TPrint "System Created at " + tmp.x + " " + tmp.y + " with ID " + tmp.netID + " and Quailty of " + tmp.quality
			EndIf
		Next
	End Method
	
	Method CreateGalaxy(tType:Int, xx:Int = 0, yy:Int = 0, angleOffset:Int = 0)
		Local numOfSystems:Int = 13, angleCurve:Float = 13.5, spread:Float = 3.0, startDistance:Int = 4
		Select tType
			Case 1 '' 
				numOfSystems = 13; angleCurve = 13.0; spread = 3.0; startDistance = 4
				CreateSpiralArm(angleOffset + 0, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + 90, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + 180, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + -90, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				
				numOfSystems = 35; angleCurve = 10.0; spread = 1.5; startDistance = 20
				CreateSpiralArm(angleOffset + 0 + 45, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + 180 + 45, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + 90 + 45, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + 180 + 90 + 45, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				
				numOfSystems = 72; angleCurve = 5.0; spread = 0.15; startDistance = 70
				CreateSpiralArm(angleOffset + 45, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				
			Case 2
				numOfSystems = 10; angleCurve = 20.0; spread = 2; startDistance = 2
				CreateSpiralArm(angleOffset + 0, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + 180, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				spread = 3; startDistance = 4
				CreateSpiralArm(angleOffset + 90, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + -90, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				
			Case 3
				numOfSystems = 30; angleCurve = 20.0; spread = 2; startDistance = 2
				CreateSpiralArm(angleOffset + 0, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + 180, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				spread = 3; startDistance = 4
				CreateSpiralArm(angleOffset + 90, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + -90, numOfSystems, angleCurve, spread, startDistance, xx, yy)
			
			Default
				numOfSystems = 8; angleCurve = 15.0; spread = 3.0; startDistance = 7
				CreateSpiralArm(angleOffset + 0, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + 90, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + 180, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + -90, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				
				numOfSystems = 11; angleCurve = 15.0; spread = 3.0; startDistance = 7
				CreateSpiralArm(angleOffset + 0 + 45, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + 90 + 45, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + 180 + 45, numOfSystems, angleCurve, spread, startDistance, xx, yy)
				CreateSpiralArm(angleOffset + (-90) + 45, numOfSystems, angleCurve, spread, startDistance, xx, yy)
		End Select
	End Method
	
	Method CreateSpiralArm(startangle:Float = 0, numSystems:Int = 5, curve:Float = 13.0, spread:Float = 3, startDistance:Float = 4, xx:Int = 0, yy:Int = 0)
		For Local xAngle:Int = 0 To numSystems
			Local angle:Float = startangle
			angle:+xAngle * curve
			Local dist:Float = startDistance + xangle * spread
			Local tmp:TSystem = TSystem.Create("-1`" + (xx + Int(Cos(angle) * dist)) + "`" + (yy + Int(Sin(angle) * dist)))
			If tmp Then
				tmp.ships = Rand(-1, 7) * 3
				tmp.quality = Rand(0, 9)
			EndIf
		Next
	End Method
	
	Method SendFleet:TFleet(fromSys:TSystem, toSys:TSystem, ships:Int, player:TPlayer)
		If tb.Math.GetDistance(fromSys.x, fromSys.y, toSys.x, toSys.y) > FindPlayerID(fromSys.owner).researchTopics[TPlayer.RES_FUELRANGE] Then
			player.messages.AddLast("[Admiral] That system is too far from your systems.`1")
			Return Null '' Outside of range
		EndIf
		If fromSys.ships - 1 < ships Then
			player.messages.AddLast("[Admiral] You can not send all of your ships! At least one must stay behind.`1")
			Return Null '' Cannot send everyone you dummy
		EndIf
		'netID + "`" + x + "`" + y + "`" + angle + "`" + speed + "`" + owner + "`" + strength + "`" + destID + "`" + homeID
		Local tmp:TFleet = TFleet.Create("-1`" + fromSys.x + "`" + fromSys.y + "`" + tb.Math.GetAngle(fromSys.x, fromSys.y, toSys.x, toSys.y))
		tmp.speed = player.researchTopics[TPlayer.RES_FLEETSPEED]
		tmp.owner = fromSys.owner
		tmp.strength = ships
		tmp.originalStrength = ships
		fromSys.ships:-ships
		tmp.destSys = toSys
		tmp.homeSys = fromSys
		tmp.destID = toSys.netID
		tmp.homeID = fromSys.netID
		tmp.NeedsToSync()
		fromSys.NeedsToSync()
		'	Print "[INFO] " + fromSys.owner + " sent a fleet of " + tmp.strength + " from " + tmp.homeID + " to " + tmp.destID
		Return tmp
	End Method
	
	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	''' File crap
	Method SaveToFile(filename:String = "game*.txt")
		filename = filename.Replace("*", gID)
		TPrint "[INFO] Saving galaxy to: " + filename
		Local Handle:TStream = WriteFile(filename)
		If Handle <> Null
			Handle.WriteLine(CurrentTurn)
			TNetObject.WriteTo(players, Handle)
			TNetObject.WriteTo(systems, Handle)
			TNetObject.WriteTo(fleets, Handle)
			'TNetObject.WriteTo(designs, Handle)
		EndIf
		Handle.Close()
	End Method
	
	Method LoadFromFile:Int(filename:String = "game*.txt")
		filename = filename.Replace("*", gID)
		TPrint "[INFO] Loading galaxy from: " + filename
		If FileSize(filename) = -1 Then Return False
		Print "File: '" + filename + "' Size is: " + FileSize(filename)
		Local Handle:TStream = ReadFile(filename)
		If Handle <> Null
			CurrentTurn = Int(Handle.ReadLine())
			Local Count:Int = Int(Handle.ReadLine())
			Local ii%
			For ii = 0 Until Count
				If Handle.Eof() Then Print "[ERROR] Unexpected EOF Loading " + filename + "! In Players" ; Return False
				UnPackPlayer(Handle.ReadLine().Split("`"))
			Next
			Print "[GAME] Loaded " + Count + " Players"
			
			If Handle.Eof() Then Print "[ERROR] Unexpected EOF Loading " + filename + "! Before Systems" ; Return False
			Count = Int(Handle.ReadLine())
			For ii = 0 Until Count
				If Handle.Eof() Then Print "[ERROR] Unexpected EOF Loading " + filename + "! In Systems" ; Return False
				UnPackSystem(Handle.ReadLine().Split("`"))
			Next
			Print "[GAME] Loaded " + Count + " Systems"
			
			If Handle.Eof() Then Print "[ERROR] Unexpected EOF Loading " + filename + "! Before Fleets" ; Return False
			Count = Int(Handle.ReadLine())
			For ii = 0 Until Count
				If Handle.Eof() Then Print "[ERROR] Unexpected EOF Loading " + filename + "! In Fleets" ; Return False
				UnPackFleet(Handle.ReadLine().Split("`"))
			Next
			Print "[GAME] Loaded " + Count + " Fleets"
		EndIf
		Handle.Close()
		Return True
	End Method
End Type

Type TNetObject Abstract
	Const ID_SYSTEM:Int = 1
	Const ID_PLAYER:Int = 2
	Const ID_FLEET:Int = 3
	
	Field netID:Int = -1
	Field netTypeID:Int = -1
	
	Global RecentlyUpdated:TList = CreateList()
	
	Method Packetize:String(requestType:Int) Abstract
	Method UnPack:Int(packet:String[]) Abstract
	
	Function WriteTo(list:TList, Handle:TStream)
		'Handle.WriteInt(list.Count())
		Handle.WriteLine(list.Count())
		For Local netO:TNetObject = EachIn list
			Handle.WriteLine(netO.Packetize(-1))
		Next
	End Function
	
	Method NeedsToSync()
		If Not RecentlyUpdated.Contains(Self) Then RecentlyUpdated.AddLast(Self)
	End Method
End Type

Global MAP_SCALE:Int = 16

Type TPlayer Extends TNetObject
	Field netID:Int = -1, username:String, empireName:String = "", homeSystemID:Int = -1, homeSystem:TSystem
	Field messages:TList = CreateList()
	Field rgb:String = "255,255,255"
	Field nameChanges:Int = 2
	
	Const RES_RESEARCH:Int = 0
	Const RES_SHIPBUILDING:Int = 1
	Const RES_FLEETWEAPONS:Int = 2
	Const RES_FUELRANGE:Int = 3
	Const RES_RADARRANGE:Int = 4
	Const RES_FLEETSPEED:Int = 5
	Const RES_PLANETARYDEFENSE:Int = 6
	Const RES_OTHER:Int = 7
	
	Field newCreditsThisTurn:Float = 0.0, syncNeow:Int = False
	Field credits:Int = 250, researchTopics:Float[8] 'shipBuilding:Float = 1.0, Research:Float = 1.0
	'	Field fuelRange:Float = 8.5, radarRange:Float = 12.5, fleetSpeed:Float = 1.5, planetaryDefense:Float = 1.0, fleetWeapons:Float = 1.0
	Field preferedResearchAspect:Int = 0, researchAspect:Int = -1, untilNextDecimal:Int, currentResearchTurn:Int, nextResearchTopic:Int = -1
	
	Function Create:TPlayer(name:String, initPacket:String = "")
		Local tmp:TPlayer = New TPlayer
		tmp.username = name
		tmp.empireName = name + "ian Empire"
		If initPacket <> "" Then tmp.UnPack(initPacket.Split("`"))
		If tmp.netID = -1 Then If curGame Then tmp.netID = curGame.players.Count() + 1
		If curGame Then curGame.players.AddLast(tmp)
		Return tmp
	End Function
	
	Function CreateClient:TPlayer(initPacket:String = "")
		Local tmp:TPlayer = New TPlayer
		If initPacket <> "" Then tmp.UnPack(initPacket.Split("`"))
		If curGame Then curGame.players.AddLast(tmp)
		Return tmp
	End Function
	
	Method New()
		netTypeID = ID_PLAYER
		researchTopics[RES_RESEARCH] = 1.0
		researchTopics[RES_SHIPBUILDING] = 1.0
		researchTopics[RES_FLEETWEAPONS] = 1.0
		researchTopics[RES_FUELRANGE] = 8.0
		researchTopics[RES_RADARRANGE] = 12.0
		researchTopics[RES_FLEETSPEED] = 1.5
		researchTopics[RES_PLANETARYDEFENSE] = 1.0
		researchTopics[RES_OTHER] = 1.0
	End Method
	
	Method GetResearchTopicName:String(topicID:Int, useSpecialMark:Int = True)
		Local specialMark:String = ""
		useSpecialMark = False '' too lazy to do it offically..
		If useSpecialMark And topicID = preferedResearchAspect Then specialMark = " (Prefered)"
		Select topicID
			Case RES_RESEARCH
				Return "Research" + specialMark
			Case RES_SHIPBUILDING
				Return "Ship Building" + specialMark
			Case RES_FLEETWEAPONS
				Return "Fleet Weapons" + specialMark
			Case RES_FUELRANGE
				Return "Fuel Range" + specialMark
			Case RES_RADARRANGE
				Return "Radar Range" + specialMark
			Case RES_FLEETSPEED
				Return "Fleet Speed" + specialMark
			Case RES_PLANETARYDEFENSE
				Return "Planetary Defense" + specialMark
			Case RES_OTHER
				Return "Other" + specialMark
		End Select
		Return "n/a"
	End Method
	
	Method UpdateResearch()
		If researchAspect >= 0 Then
			currentResearchTurn:+1
			If currentResearchTurn >= untilNextDecimal Then
				AdvanceResearch
			EndIf
		End If
	End Method
	
	Method PayForResearch:Int(resTopic:Int)
		If credits < 0 Then Return (-1) ' Can't when you have no positive credits
		If researchAspect < 0 Then Return (-2)
		
		AdvanceResearch(resTopic = researchAspect)
		
		Local researchCost:Int = GetResearchCost(resTopic)
		credits:-researchCost
		If credits > 0 Then
			messages.AddLast("[Attache] We paid " + tb.Math.LimitDenom(researchCost) + " Credits to advance " + ..
				GetResearchTopicName(researchAspect, False) + "!`2")
		Else
			messages.AddLast("[Attache] We paid " + tb.Math.LimitDenom(researchCost) + " Credits to advance " + ..
				GetResearchTopicName(researchAspect, False) + " and has put us " + tb.Math.LimitDenom(credits) + " in debt.`1")
		End If
		
		Return 0
	End Method
	
	Method GetResearchCost:Int(resTopic:Int)
		Local researchCost:Int = -1
		If resTopic = researchAspect Then
			researchCost = (untilNextDecimal - currentResearchTurn) * 625
		Else
			researchCost = GetResearchLength(resTopic) * 625
		End If
		If resTopic = preferedResearchAspect Then researchCost = Int(researchCost * (4 / 5.0))
		Return researchCost
	End Method
	
	Method AdvanceResearch(setResTopic:Int = True)
		Local amount:Float = GetResearchAdvanceAmount(researchAspect)
		If Rand(0, 100) < 5 'researchTopics[researchAspect] = Int(researchTopics[researchAspect]) Then
			curGame.SendGNNUpdate("Sources say the " + empireName + " have made a breakthrough in " + GetResearchTopicName(researchAspect, False) + "!")
			amount:*Rand(3, 5)
			messages.AddLast("[Attache] We've made a breakthrough and have gained an extraordinary amount of " + amount + " research points in " + GetResearchTopicName(researchAspect, False) + "!")
		End If
		
		researchTopics[researchAspect]:+amount
		If setResTopic Then
			If Not IsResearchTopicAvailable(researchAspect) Then nextResearchTopic = -1
			If nextResearchTopic = -1 Then ''' Goto the next research topic
				Local tmpResTopic:Int = researchAspect + 1, timesTried:Int = 0
				While Not IsResearchTopicAvailable(tmpResTopic)
					tmpResTopic:+1
					If tmpResTopic > researchTopics.Length - 2 Then tmpResTopic = 0
					timesTried:+1
					If timesTried > researchTopics.Length Then
						nextResearchTopic = -2
						Exit
					EndIf
				Wend
				researchAspect = tmpResTopic
			End If
			If nextResearchTopic < - 1 Then
				Local tmpResTopic:Int = -1, timesTried:Int = 0
				researchAspect = -1
				While timesTried < 10
					tmpResTopic = Rand(0, researchTopics.Length - 2)
					If IsResearchTopicAvailable(tmpResTopic) Then researchAspect = tmpResTopic;Exit
					timesTried:+1
				Wend
			End If
			SetResearchTopic(researchAspect)
		EndIf
		
		NeedsToSync()
	End Method
	
	Method IsResearchTopicAvailable:Int(curResearchAspect:Int)
		Select curResearchAspect
			Case RES_RESEARCH
				If researchTopics[curResearchAspect] >= 10.0 Then Return False
			Case RES_FUELRANGE
				If researchTopics[curResearchAspect] >= 50.0 Then Return False
			Case RES_RADARRANGE
				If researchTopics[curResearchAspect] >= 50.0 Then Return False
			Case RES_FLEETSPEED
				If researchTopics[curResearchAspect] >= 10.0 Then Return False
			Case RES_SHIPBUILDING
				If researchTopics[curResearchAspect] >= 10.0 Then Return False
			Case RES_FLEETWEAPONS
				If researchTopics[curResearchAspect] >= 10.0 Then Return False
			Case RES_PLANETARYDEFENSE
				If researchTopics[curResearchAspect] >= 10.0 Then Return False
			Default
				Return False
		End Select
		Return True
	End Method
	
	Method GetResearchAdvanceAmount:Float(curResearchAspect:Int)
		Local amount:Float = 0.1
		If curResearchAspect = RES_FUELRANGE Then amount:*2
		If curResearchAspect = RES_RADARRANGE Then amount:*2
		Return amount
	End Method
	
	Method SetResearchTopic(topicID:Int)
		If Not IsResearchTopicAvailable(topicID) Then topicID = preferedResearchAspect
		If Not IsResearchTopicAvailable(topicID) Then topicID = -1
		
		researchAspect = topicID
		currentResearchTurn = 0
		
		If researchAspect < 0 Then
			untilNextDecimal = 1
			Return
		EndIf
		untilNextDecimal = GetResearchLength(researchAspect)
		
		NeedsToSync()
	End Method
	
	Method GetResearchLength:Int(resTopic:Int)
		If resTopic < 0 or resTopic > 6 Then Return -1
		Local tmpResLength:Float = researchTopics[resTopic] * 20
		Select resTopic
			Case RES_RESEARCH
				tmpResLength:+Int(researchTopics[resTopic] - 1) * 10
			Case RES_FUELRANGE
				tmpResLength:*(1 / 3.0)
			Case RES_RADARRANGE
				tmpResLength:*(1 / 3.0)
			Case RES_FLEETSPEED
				tmpResLength:*(1 / 2.0)
			Case RES_SHIPBUILDING
			'	tmpResLength:*(1 / 3.0)
			Case RES_FLEETWEAPONS
				tmpResLength:+Int(researchTopics[resTopic] - 1) * 5
			Case RES_PLANETARYDEFENSE
				tmpResLength:+Int(researchTopics[resTopic] - 1) * 5
		End Select
		If resTopic = preferedResearchAspect Then tmpResLength:*0.9
		tmpResLength:-researchTopics[RES_RESEARCH] * 0.25
		Return Int(tmpResLength)
	End Method
	
	Method SetHomeSystem(sys:TSystem)
		homeSystem = sys
		homeSystemID = sys.netID
		homeSystem.owner = netID
	End Method
	
	Method Packetize:String(levelOfKnowledge:Int = 0)
		Select levelOfKnowledge
			Case 0
				Return netID + "`" + empireName + "`" + rgb
				
			Case 1
				Return netID + "`" + empireName + "`" + rgb + "`" + homeSystemID
				
			Case 5
				Return netID + "`" + empireName + "`" + rgb + "`" + homeSystemID + "`" + credits + "`" + PacketizeResearch() + "`" + ..
					preferedResearchAspect + "," + researchAspect + "," + untilNextDecimal + "," + nextResearchTopic + "," + currentResearchTurn + ..
					"`" + username
				
			Default
				Return netID + "`" + empireName + "`" + rgb + "`" + homeSystemID + "`" + credits + "`" + PacketizeResearch() + "`" + ..
					preferedResearchAspect + "," + researchAspect + "," + untilNextDecimal + "," + nextResearchTopic + "," + currentResearchTurn + ..
					"`" + username + "`" + PacketizeMessages()
		End Select
	End Method
	
	Method UnPack:Int(packet:String[])
		Local ix:Int = 0
		
		If Packet[ix] <> "" Then netID = Int(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then empireName = (Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then rgb = (Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then homeSystemID = Int(Packet[ix])
		If Not homeSystem Then homeSystem = curGame.FindSystemID(homeSystemID)
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then credits = Int(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then UnpackResearch(Packet[ix].Split(","))
		ix:+1 ; If Packet.Length = ix Then Return ix
		'preferedResearchAspect:Int = 0, researchAspect = -1, untilNextDecimal:Int, currentResearchTurn:Int
		
		If packet[ix] <> "" Then
			Local tmpSA:String[] = packet[ix].Split(",")
			preferedResearchAspect = Int(tmpSA[0])
			researchAspect = Int(tmpSA[1])
			untilNextDecimal = Int(tmpSA[2])
			nextResearchTopic = Int(tmpSA[3])
			currentResearchTurn = Int(tmpSA[4])
		EndIf
		ix:+1 ; If packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then username = (Packet[ix])
		ix:+1 ; If packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then UnPackMessages(Packet[ix].Split("~~"))
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		'	If packet[ix] <> "" Then UnPackMessages(packet[ix].Split(","))
		'	ix:+1 ; If packet.Length = ix Then Return ix
		
		Return -1
	End Method
	
	Method PacketizeMessages:String()
		Local result:String = ""
		For Local tmp:String = EachIn messages
			If result <> "" Then result:+"~~"
			result:+tmp.Replace("|", "\").Replace("~~", "").Replace("`", "|")
		Next
		Return result
	End Method
	
	Method UnPackMessages:Int(packet:String[])
		Local numMessage:Int = packet.Length, ii:Int = 0
		messages.Clear()
		For ii = 0 Until numMessage
			If Packet.Length = ii Then TPrint "[ERROR] Unpack Messages was given too sort of a packet!";Exit
			messages.AddLast(packet[ii].Replace("|", "`"))
		Next
		Return ii
	End Method
	
	Method PacketizeResearch:String()
		Local tmp:String = "", ii:Int = 0
		For ii = 0 Until Int(researchTopics.Length)
			If tmp <> "" Then tmp:+","
			tmp:+tb.Math.LimitDecimal(researchTopics[ii], 2)
		Next
		Return tmp
	End Method
	
	Method UnpackResearch(resPacket:String[])
		If resPacket.Length > researchTopics.Length Then TPrint "[ERROR] Tried to Unpack Research into a differently sized array!"
		For Local ii:Int = 0 Until researchTopics.Length
			researchTopics[ii] = Float(resPacket[ii])
		Next
	End Method
End Type

Type TSystem Extends TNetObject
	Field x:Int, y:Int
	Field netID:Int
	Field ships:Int = 0
	Field owner:Int = -1
	Field quality:Int = -1
	Field lastBuild:Int = 0, isBuilding:Int = -1
	
	Method New()
		netTypeID = ID_SYSTEM
	End Method
	
	Function Create:TSystem(initPacket:String = "")
		Local tmp:TSystem = New TSystem
		If initPacket <> "" Then tmp.UnPack(initPacket.Split("`"))
		If tmp.netID = -1 Then If curGame Then tmp.netID = curGame.systems.Count()
		For Local tsys:TSystem = EachIn curGame.systems
			If tsys.x = tmp.x And tsys.y = tmp.y Then
				TPrint "[ERROR] Tried to create a system at " + tmp.x + ", " + tmp.y + " but one already exists there!"
				Return Null
			EndIf
		Next
		If curGame Then curGame.systems.AddLast(tmp)
		Return tmp
	End Function
	
	Method Packetize:String(levelOfKnowledge:Int = 0)
		Select levelOfKnowledge
			Case 0
				Local xx:int = Int(Rnd(-10,10) + x)
				Local yy:int = Int(Rnd(-10,10) + y)
				Return netID + "`" + xx + "`" + yy + "`-1`-1`-1"
				
			Case 1
				Return netID + "`" + x + "`" + y + "`" + owner + "`-1`-1"
			
			Case 2
				Return netID + "`" + x + "`" + y + "`" + owner + "`" + quality + "`" + ships
				
			Default
				Return netID + "`" + x + "`" + y + "`" + owner + "`" + quality + "`" + ships + "`" + lastBuild + "`" + isBuilding
		End Select
	End Method
	
	Method UnPack:Int(packet:String[])
		Local ix:Int = 0
		If Packet[ix] <> "" Then netID = Int(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then x = Int(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then y = Int(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then owner = Int(Packet[ix])
		ix:+1 ; If packet.Length = ix Then Return ix
		
		quality = -1;If packet[ix] <> "" Then quality = Int(packet[ix])
		ix:+1 ; If packet.Length = ix Then Return ix
		
		ships = -1;If Packet[ix] <> "" Then ships = Int(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then lastBuild = Int(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then isBuilding = Int(Packet[ix])
		
		Return - 1
	End Method
	
	Method CalculateNewShipTime:Int()
		Local ply:TPlayer = curGame.FindPlayerID(owner), minBuild:Int = 30
		If quality < 1 Then Return - 1
		
		minBuild:-quality
		
		If ply Then
			If (ply.researchTopics[TPlayer.RES_SHIPBUILDING]) < 1 Then Return - 1
			minBuild:-(ply.researchTopics[TPlayer.RES_SHIPBUILDING])
		Else
			If ships = 0 Then Return - 1
			minBuild:*2
		EndIf
		
		If minBuild < 3 Then
			minBuild = 3
		EndIf
		
		Return minBuild
	End Method
	
	Method Update()
		If ships < 0 Then ships = 0
		Local ply:TPlayer = curGame.FindPlayerID(owner), minBuild:Int = CalculateNewShipTime()
		
		If minBuild < 0 Then Return
		If Not isBuilding Then Return
		
		lastBuild:+1
		
		If lastBuild > minBuild - 1 Then
			ships:+1
			lastBuild = 0
		End If
		
	End Method
	
	Method GetX:Int()
		Return (x * MAP_SCALE) - (MAP_SCALE) + (scnx / 2) - currentXPan
	End Method
	
	Method GetY:Int()
		Return (y * MAP_SCALE) - (MAP_SCALE) + (scny / 2) - currentYPan
	End Method
	
?not console
	Method IsMouseOver:Int()
		Return tb.PointIn.MouseInRect((x * MAP_SCALE) - (MAP_SCALE) + (scnx / 2) - currentXPan,  ..
			(y * MAP_SCALE) - (MAP_SCALE) + (scny / 2) - currentYPan,  ..
			(MAP_SCALE * 2), (MAP_SCALE * 2))
	End Method
	
	Method Draw(drawMouseOver:Int = False)
		Local isPlayers:Int = False
		SetColor 255, 255, 255
		Local tmpPlayer:TPlayer = curgame.FindPlayerID(owner)
		
		If client And tmpPlayer And client.ply And tmpPlayer.netID = client.ply.netID Then isPlayers = True
		
		If tmpPlayer Then
			tb.Draw.SetRGB(tmpPlayer.rgb)
		ElseIf ships <= 0 Then
			SetAlpha( 0.5 )
		EndIf
		
		'' Draw 'Star'
		If tmpPlayer Then If tmpPlayer.homeSystemID = netID Then
				DrawLine (x * MAP_SCALE), (y * MAP_SCALE),  ..
					(x * MAP_SCALE), (y * MAP_SCALE) - (MAP_SCALE / 2)
				SetLineWidth 5
				DrawLine (x * MAP_SCALE), (y * MAP_SCALE) - (MAP_SCALE / 2), (x * MAP_SCALE) + 8, (y * MAP_SCALE) - (MAP_SCALE / 2)
				SetLineWidth 1
			EndIf
		DrawOval (x * MAP_SCALE) - (MAP_SCALE / 4), (y * MAP_SCALE) - (MAP_SCALE / 4), (MAP_SCALE / 2), (MAP_SCALE / 2)
		
		If MAP_SCALE < 3 Then Return
		
		'' Draw text labels
		If MAP_SCALE < 5
			SetAlpha 0.25
		ElseIf MAP_SCALE < 9
			SetAlpha 0.5
		Else
			SetAlpha 0.85
		End If
		If ships > 0
			DrawText ships, Int((x * MAP_SCALE) + (MAP_SCALE / 3)), Int((y * MAP_SCALE) - (MAP_SCALE / 4) - (TextHeight("?") / 2))
		'	If isPlayers And isBuilding < 0 Then DrawText "X", Int((x * MAP_SCALE) - 8 - (MAP_SCALE / 3)), Int((y * MAP_SCALE))
		ElseIf ships = 0
			SetAlpha 0.3
			DrawText "0", Int((x * MAP_SCALE) + (MAP_SCALE / 3)), Int((y * MAP_SCALE) - (MAP_SCALE / 4) - (TextHeight("?") / 2))
		ElseIf ships < 0 And MAP_SCALE > 9
			SetAlpha 0.3
			DrawText "?", Int((x * MAP_SCALE) + (MAP_SCALE / 3)), Int((y * MAP_SCALE) - (MAP_SCALE / 4) - (TextHeight("?") / 2))
		EndIf
		
		'if netID = curGame.FindPlayerID(owner).homeSystemID Then 
		'	DrawText owner, (x * MAP_SCALE) - (TextWidth(owner) / 2), (y * MAP_SCALE) + (MAP_SCALE / 4)
		If Not drawMouseOver Then
			drawMouseOver = IsMouseOver() * 2
		EndIf
		If drawMouseOver
			If owner <> ""
				tb.Draw.CenteredText "#" + netID, (x * MAP_SCALE), (y * MAP_SCALE) + (MAP_SCALE / 2)
			Else
				tb.Draw.CenteredText "#" + netID, (x * MAP_SCALE), (y * MAP_SCALE) + (MAP_SCALE / 2)
			EndIf
			If quality > 0 Then
				tb.Draw.CenteredText "*" + quality, (x * MAP_SCALE), (y * MAP_SCALE) + (MAP_SCALE / 2) + 16
			End If
			
			If isPlayers = True Then
				'	If isBuilding > 0
				'		tb.Draw.CenteredText "Building ON", (x * MAP_SCALE), (y * MAP_SCALE) + (MAP_SCALE / 2) + 16
				'	Else
				'		tb.Draw.CenteredText "Building OFF", (x * MAP_SCALE), (y * MAP_SCALE) + (MAP_SCALE / 2) + 16
				'	EndIf
			
				SetAlpha 0.35
				SetLineWidth MAP_SCALE * 0.4 * drawMouseOver
				tb.Draw.CircleAtAngle((x * MAP_SCALE), (y * MAP_SCALE), MAP_SCALE * client.ply.researchTopics[TPlayer.RES_FUELRANGE], tb.Math.SlowRotation(), 32)
				SetLineWidth drawMouseOver
				
				tb.Draw.DottedCircle((x * MAP_SCALE), (y * MAP_SCALE), MAP_SCALE * client.ply.researchTopics[TPlayer.RES_RADARRANGE], 24)
				tb.Draw.DottedCircle((x * MAP_SCALE), (y * MAP_SCALE), MAP_SCALE * client.ply.researchTopics[TPlayer.RES_RADARRANGE] * 3, 48)
				SetLineWidth 1
			EndIf
			SetAlpha 1.0
		EndIf
		SetAlpha 1.0
		SetColor 255, 255, 255
	End Method
?
End Type

Type TFleet Extends TNetObject
	Field netID:Int = -1, owner:Int = -1, strength:Int = -1, originalStrength:Int = -1, speed:Float = -1.0
	Field x:Float, y:Float, angle:Float, damageOutput:Float = 0.0, damageTaken:Float = 0.0
	Field isInCombat:Int = False
	
	Field destID:Int = -1, homeID:Int = -1
	Field destSys:TSystem, homeSys:TSystem
	
	Field Sync:Int = False
	
	Method New()
		netTypeID = ID_FLEET
	End Method
	
	Function Create:TFleet(initPacket:String = "")
		Local tmp:TFleet = New TFleet
		If initPacket <> "" Then tmp.UnPack(initPacket.Split("`"))
		If tmp.netID = -1 Then If curGame Then tmp.netID = curGame.GetOpenFleetID()
		If curGame Then curGame.fleets.AddLast(tmp)
		Return tmp
	End Function
	
	Method Packetize:String(levelOfKnowledge:Int = 0)
		Select levelOfKnowledge
			Case 0 '' Galaxy level?
				Return netID + "`" + x + "`" + y + "`" + angle
				
			Case 1 '' Long range sensors
				Local notStrength:Int = 0
				If strength > 250 Then notStrength = 250
				If strength > 1000 Then notStrength = 1000
				Return netID + "`" + x + "`" + y + "`" + angle + "`" + speed + "`" + owner + "`" + notStrength + "`" + isInCombat
				
			Case 2 '' Nearby
				Return netID + "`" + x + "`" + y + "`" + angle + "`" + speed + "`" + owner + "`" + strength + "`" + isInCombat + "`" + destID
				
			Default '' Save/Owner
				Return netID + "`" + x + "`" + y + "`" + angle + "`" + speed + "`" + owner + "`" + strength + "`" + isInCombat + "`" + destID + "`" + homeID + "`" + damageOutput + "`" + damageTaken + "`" + originalStrength
		End Select
		'damageOutput:Float = 0.0, damageTaken:Float = 0.0
	End Method
	
	Method UnPack:Int(packet:String[])
		Local ix:Int = 0
		Sync = True
		
		If Packet[ix] <> "" Then netID = Int(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then x = Float(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then y = Float(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then angle = Float(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then speed = Float(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then owner = Int(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then strength = Float(Packet[ix])
		ix:+1 ; If packet.Length = ix Then Return ix
		
		If packet[ix] <> "" Then isInCombat = Int(packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then destID = Int(Packet[ix])
		destSys = curGame.FindSystemID(destID)
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then homeID = Int(Packet[ix])
		homeSys = curGame.FindSystemID(homeID)
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then damageOutput = Float(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If Packet[ix] <> "" Then damageTaken = Float(Packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		If packet[ix] <> "" Then originalStrength = Int(packet[ix])
		ix:+1 ; If Packet.Length = ix Then Return ix
		
		Return - 1
	End Method
	
	Method Update(timeScale:Float)
		x:+Cos(angle) * (speed * timeScale)
		y:+Sin(angle) * (speed * timeScale)
		angle = tb.Math.GetAngle(x, y, destSys.x, destSys.y)
	End Method
	
	Method GetX:Int()
		Return (x * MAP_SCALE) - (MAP_SCALE) + (scnx / 2) - currentXPan
	End Method
	
	Method GetY:Int()
		Return (y * MAP_SCALE) - (MAP_SCALE) + (scny / 2) - currentYPan
	End Method
	
?not console
	Method IsMouseOver:Int()
		Return tb.PointIn.MouseInRect((x * MAP_SCALE) - (MAP_SCALE) + (scnx / 2) - currentXPan,  ..
			(y * MAP_SCALE) - (MAP_SCALE) + (scny / 2) - currentYPan,  ..
			(MAP_SCALE * 2), (MAP_SCALE * 2))
	End Method
	
	Method Draw(drawMouseOver:Int = False)
		If MAP_SCALE < 5 Then Return
		'curGame.IsFriendly(owner)
		SetColor 255, 255, 255
		Local radarRange:Int = 0
		If curGame.FindPlayerID(owner) Then
			tb.Draw.SetRGB(curGame.FindPlayerID(owner).rgb)
			If client Then If client.ply Then If client.ply.netID = owner Then radarRange = curGame.FindPlayerID(owner).researchTopics[TPlayer.RES_RADARRANGE] / 4
		EndIf
		
		'' Draw 'Fleet'
		Local sides:Int = 1
		If strength >= 250 Then sides:+1
		'	If strength >= 500 Then sides:+1
		If strength >= 1000 Then sides:+1
		
		'tb.Draw.CircleAtAngle(x * MAP_SCALE, y * MAP_SCALE, (MAP_SCALE / 3), angle, 3)
		tb.Draw.CircleAtAngle(x * MAP_SCALE, y * MAP_SCALE, (MAP_SCALE / 3), angle, 1 + (2 * sides))
		
		SetAlpha 0.5
		If client And client.ply And owner = client.ply.netID Then
			If destSys Then DrawLine x * MAP_SCALE, y * MAP_SCALE, destSys.x * MAP_SCALE, destSys.y * MAP_SCALE
			SetAlpha 0.15
			If homeSys Then DrawLine x * MAP_SCALE, y * MAP_SCALE, homeSys.x * MAP_SCALE, homeSys.y * MAP_SCALE
		EndIf
		
		'' Draw text labels
		If MAP_SCALE < 9
			SetAlpha 0.25
		ElseIf MAP_SCALE < 17
			SetAlpha 0.6
		Else
			SetAlpha 0.85
		End If
		If strength > 0
			DrawText strength, Int((x * MAP_SCALE) + (MAP_SCALE / 3)), Int((y * MAP_SCALE) - (MAP_SCALE / 4) - (TextHeight("?") / 2))
		ElseIf strength = -1
			SetAlpha 0.6
			DrawText "?", (x * MAP_SCALE) + (MAP_SCALE / 3), (y * MAP_SCALE) - (MAP_SCALE / 4) - (TextHeight("?") / 2)
		EndIf
		If speed < 0.2 Then ..
			DrawText "X", Int((x * MAP_SCALE) - 8 - (MAP_SCALE / 3)), Int((y * MAP_SCALE))
		
			If Not drawMouseOver Then
				drawMouseOver = IsMouseOver() * 2
			EndIf
			If drawMouseOver > 0
				'	If owner <> ""
				'		tb.Draw.CenteredText "#" + netID + " " + angle, (x * MAP_SCALE), (y * MAP_SCALE) + (MAP_SCALE / 2)
				'	Else
				tb.Draw.CenteredText "#" + netID, (x * MAP_SCALE), (y * MAP_SCALE) + (MAP_SCALE / 2)
				'	EndIf
				If radarRange Then
					SetLineWidth drawMouseOver
					tb.Draw.DottedCircle(x * MAP_SCALE, y * MAP_SCALE, radarRange * MAP_SCALE, 12)
					SetLineWidth 1
				EndIf
			EndIf
		
			SetAlpha 1.0
			SetColor 255, 255, 255
		End Method
	?
	End Type