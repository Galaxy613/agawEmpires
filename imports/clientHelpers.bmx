Type TerritorySquare
	Global tgList:TList = CreateList(), gridDistance = 10
	Global borderMesh:TList = CreateList(), tx:Int, ty:Int, tl:Int
	Field x:Int, y:Int, rgb:String = "0,0,0", power:Float, distance:Float, edges:String = ""
	
	Function CreateGrid(diameter:Int = 6, distance:Int = 10)
		gridDistance = distance
		For Local xx = 0 To diameter * 2
			For Local yy = 0 To diameter * 2
				New TerritorySquare.Create((xx - diameter) * distance, (yy - diameter) * distance, distance)
			Next
		Next
	End Function
	
	Method Create:TerritorySquare(xx:Int, yy:Int, ddistance:Int)
		distance = ddistance
		'	distance:+2
		x = xx
		y = yy
		ListAddLast tgList, Self
	End Method
	
	Function UpdateAll()
		For Local ttg:TerritorySquare = EachIn tgList
			ttg.Update()
		Next
		For Local ttg:TerritorySquare = EachIn tgList
			ttg.UpdateEdges()
		Next
	End Function
	
	Function DrawAll()
		For Local ttg:TerritorySquare = EachIn tgList
			ttg.Draw()
		Next
	End Function
	
	Method Update()
		Local closestDist:Float = distance * 2.0
		Local closestRGB:String = "0,0,0"
	
		For Local tSys:TSystem = EachIn curGame.systems
			Local tDist:Float = tb.Math.GetDistance(x, y, tsys.x, tsys.y)
			If tDist < closestDist Then
				If curGame.FindPlayerID(tSys.owner) <> Null Then
					closestRGB = curGame.FindPlayerID(tSys.owner).rgb.Replace(" ", "").Replace("~t", "")
					closestDist = tDist
				End If
			End If
		Next
		
		rgb = closestRGB
		power = 1.0 - (closestDist / (distance * 4.0))
	End Method
	
	Method UpdateEdges()
		edges = ""
		If rgb="0,0,0" Then Return
		
		For Local ttg:TerritorySquare = EachIn tgList
			If ttg.x > x + (gridDistance * 2) Then Continue
			If ttg.x < x - (gridDistance * 2) Then Continue
			If ttg.y > y + (gridDistance * 2) Then Continue
			If ttg.y < y - (gridDistance * 2) Then Continue
		'	If ttg.rgb = "0,0,0" Then Continue
			If ttg.rgb = rgb Then Continue
			
		'	RuntimeError "Grid " + x + "|" + y + "rgb" + rgb + " verses " + ttg.x + "|" + ttg.y + "rgb" + ttg.rgb
			If ttg.x = x + gridDistance And ttg.y = y Then
				edges:+"0" ' right
				Continue
			End If
			If ttg.x = x And ttg.y = y + gridDistance Then
				edges:+"1" ' down
				Continue
			End If
			If ttg.x = x - gridDistance And ttg.y = y Then
				edges:+"2" ' left
				Continue
			End If
			If ttg.x = x And ttg.y = y - gridDistance Then
				edges:+"3" ' up
				Continue
			End If
		Next
		
	'	If edges <> "" Then RuntimeError "waht"
	End Method
	
	Method Draw()
		If rgb = "0,0,0" Then Return
		tb.Draw.SetRGB(rgb)
		SetAlpha 0.1'(power * 0.1) + 0.05
		'tb.Draw.FilledCircle(x * MAP_SCALE, y * MAP_SCALE, distance * 0.5 * MAP_SCALE)
		tx = Int(x - distance / 2) * MAP_SCALE
		ty = Int(y - distance / 2) * MAP_SCALE
		tl = distance * MAP_SCALE
		DrawRect tx, ty, tl, tl
		
		SetAlpha 0.25
		If edges.Contains("0") Then DrawLine(tx + tl - (MAP_SCALE / 16.0), ty, tx + (tl) - (MAP_SCALE / 16.0), ty + (tl))
		If edges.Contains("1") Then DrawLine(tx, ty + tl - (MAP_SCALE / 16.0), tx + (tl), ty + (tl) - (MAP_SCALE / 16.0))
		If edges.Contains("2") Then DrawLine(tx + (MAP_SCALE / 16.0), ty, tx + (MAP_SCALE / 16.0), ty + (tl))
		If edges.Contains("3") Then DrawLine(tx, ty + (MAP_SCALE / 16.0), tx + (tl), ty + (MAP_SCALE / 16.0))
		SetAlpha 0.1
		'	tb.Draw.Circle(x * MAP_SCALE, y * MAP_SCALE, distance * 2 * MAP_SCALE)
		SetScale MAP_SCALE / 64.0, MAP_SCALE / 64.0
		DrawText(x + "," + y, tx, ty)
		SetScale 1.0, 1.0
		SetAlpha 1.0
		SetColor 255, 255, 255
	End Method

End Type

Type TerritoryMesh
	Global TMList:TList = CreateList()
	Field mesh:Float[]
	Field hull:TList = Null, midPoint:Point = Point.Create(0, 0)
	Field adjustedMesh:Float[], lastMapScale:Int = 2
	Field rgb:String = "0,0,0", playerID:Int
	
	Function Create:TerritoryMesh(pID:Int, pRGB:String)
	'	If FindPlayerID(pID) <> Null Then Return FindPlayerID(pID)
		Local tmpMesh:TerritoryMesh = New TerritoryMesh
		tmpMesh.rgb = pRGB
		tmpMesh.playerID = pID
		Return tmpMesh
	End Function
	
	Function FindPlayerID:TerritoryMesh(pID:Int)
		For Local tmpMesh:TerritoryMesh = EachIn TMList
			If tmpMesh.playerID = pID Return tmpMesh
		Next
		Return Null
	End Function
	
	Function UpdateAll()
		For Local tPly:TPlayer = EachIn curGame.players
			Local tmpMesh:TerritoryMesh = FindPlayerID(tply.netID)
			If Not tmpMesh Then tmpMesh = Create(tPly.netID, tPly.rgb)
			tmpMesh.UpdateMesh()
		Next
	End Function
	
	Function DrawAll()
		For Local tPly:TPlayer = EachIn curGame.players
			Local tmpMesh:TerritoryMesh = FindPlayerID(tply.netID)
			If Not tmpMesh Then tmpMesh = Create(tPly.netID, tPly.rgb) ;tmpMesh.UpdateMesh
			tmpMesh.Draw()
		Next
	End Function
	
	Method UpdateMesh()
		Local PointsList:TList = CreateList()
		Const borderDist:Float = 2.0
		
		For Local ttg:TerritorySquare = EachIn TerritorySquare.tgList
			If ttg.rgb <> rgb Then Continue
			PointsList.AddLast(Point.Create(ttg.x - borderDist, ttg.y - borderDist))
			PointsList.AddLast(Point.Create(ttg.x + borderDist, ttg.y + borderDist))
			PointsList.AddLast(Point.Create(ttg.x - borderDist, ttg.y + borderDist))
			PointsList.AddLast(Point.Create(ttg.x + borderDist, ttg.y - borderDist))
			
			PointsList.AddLast(Point.Create(ttg.x, ttg.y - borderDist * 1.35))
			PointsList.AddLast(Point.Create(ttg.x, ttg.y + borderDist * 1.35))
			PointsList.AddLast(Point.Create(ttg.x - borderDist * 1.35, ttg.y))
			PointsList.AddLast(Point.Create(ttg.x + borderDist * 1.35, ttg.y))
		Next
		
		hull = tbHull.QuickHull(PointsList)
		mesh = tbHull.ConvertHullToPolygon(hull)
		UpdateAdjustedMesh()
	End Method
	
	Method UpdateAdjustedMesh()
		adjustedMesh = mesh
		lastMapScale = MAP_SCALE
		For Local ii:Int = 0 Until (mesh.Length) Step 2
			adjustedMesh[ii]:*MAP_SCALE
			adjustedMesh[ii + 1]:*MAP_SCALE
			midPoint.x:+adjustedMesh[ii]
			midPoint.y:+adjustedMesh[ii + 1]
		Next
		midPoint.x:/mesh.Length / 2
		midPoint.y:/mesh.Length / 2
	End Method
	
	Method Draw()
		If Not hull Then Return
		If lastMapScale <> MAP_SCALE Then UpdateAdjustedMesh()
		tb.Draw.SetRGB(rgb)
		SetAlpha 0.2
		If MAP_SCALE < 3
			SetAlpha 0.6
			SetImageFont medFont
			tb.Draw.CenteredText(curGame.FindPlayerID(playerID).empireName, midPoint.x, midPoint.y)
			SetImageFont stdFont
		ElseIf MAP_SCALE < 5
			SetAlpha 0.5
			SetImageFont medFont
			tb.Draw.CenteredText(curGame.FindPlayerID(playerID).empireName, midPoint.x, midPoint.y)
			SetImageFont stdFont
		ElseIf MAP_SCALE < 9
			SetAlpha 0.25
			SetImageFont lrgFont
			tb.Draw.CenteredText(curGame.FindPlayerID(playerID).empireName, midPoint.x, midPoint.y)
			SetImageFont stdFont
		Else
			SetAlpha 0.1
			SetImageFont lrgFont
			tb.Draw.CenteredText(curGame.FindPlayerID(playerID).empireName, midPoint.x, midPoint.y)
			SetImageFont stdFont
		End If
		SetAlpha 1.0
		tb.Draw.SetGrey 255
	End Method
End Type
