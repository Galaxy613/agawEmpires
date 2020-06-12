Strict

Import "Toolbox.bmx"
Import odd.odd2d
Import ODD.GLOdd2D
Incbin "OCRAEXT.TTF"

tb.Init()
Global MAP_SCALE = 8
'scnx:/4
'scny:/4
	
	Global ppX = 42, ppY = 0

''' Start up GFX!
SetGraphicsDriver GLOdd2DDriver()
Graphics scnx, scny
'SetVirtualResolution scnx, scny
'SetBorderMode BORDER_LETTERBOX_FILL
'SetScreenFocus scnx / 2, scny / 2
SetOrigin scnx / 2, scny / 2
SetBlend ALPHABLEND
SetImageFont LoadImageFont("incbin::OCRAEXT.TTF", 12)

Global territoryMesh:Float[], territoryHull:TList = Null

Type SPoint
	Field w:Int, x:Int, y:Int, z:Int
	Function Create:SPoint(ww:Int, xx:Int, yy:Int, zz:Int = 0)
		Local tmp:SPoint = New SPoint
		tmp.w = ww;tmp.z = zz
		tmp.x = xx;tmp.y = yy
		Return tmp
	End Function
End Type

Type GSystem Extends SPoint
	Global SList:TList = CreateList()
	Field t:Int
	
	Function Make:GSystem(xx:Int, yy:Int, TT:Int)
		Local tmp:GSystem = New GSystem
		tmp.x = xx
		tmp.y = yy
		tmp.t = tt
		SList.AddLast(tmp)
		Return tmp
	End Function
	
	Method Draw()
		If t Then SetAlpha 0.15
		DrawOval (x * MAP_SCALE) - (MAP_SCALE / 4), (y * MAP_SCALE) - (MAP_SCALE / 4), (MAP_SCALE / 2), (MAP_SCALE / 2)
		SetAlpha 1.0
	End Method
End Type

Function GenerateTerritoryMesh()
	Local PointsList:TList = CreateList()
	
	For Local gSys:GSystem = EachIn GSystem.SList
		PointsList.AddLast(point.Create(gSys.x, gSys.y-2.5))
		PointsList.AddLast(point.Create(gSys.x, gSys.y + 2.5))
		PointsList.AddLast(point.Create(gSys.x - 2.5, gSys.y))
		PointsList.AddLast(point.Create(gSys.x + 2.5, gSys.y))
		
		PointsList.AddLast(point.Create(gSys.x-2, gSys.y-2))
		PointsList.AddLast(point.Create(gSys.x+ 2, gSys.y + 2))
		PointsList.AddLast(point.Create(gSys.x - 2, gSys.y+ 2))
		PointsList.AddLast(point.Create(gSys.x + 2, gSys.y- 2))
	Next
	
	territoryHull = quickhull(PointsList) 
	territoryMesh= New Float[territoryHull .count()*2]
	
	Local ii% = 0
	
	For Local pp:Point = EachIn territoryHull 
		territoryMesh[ii*2] = pp.x*MAP_SCALE
		territoryMesh[ii*2+1] = pp.y*MAP_SCALE
		ii:+1
	Next
	
	
End Function

GSystem.Make(-3, 0, 0)
GSystem.Make(2, 0, 0)
GSystem.Make(0, -4, 0)
GSystem.Make(0, 5, 0)
'GSystem.Make(2, -1, 0)
'GSystem.Make(3, 1, 0)
'GSystem.Make(-2, 2, 0)

GenerateTerritoryMesh()

Rem
Function CreateSpiralArm(startangle:Float = 0, numSystems = 5, curve:Float = 13.0, spread:Float = 1.5, startDistance:Float = 4)
	For Local xAngle:Int = 0 To numSystems
		Local angle:Float = startangle
		angle:+xAngle * curve
		Local dist:Float = startDistance + xangle * spread
		GSystem.Make(Cos(angle) * dist, Sin(angle) * dist, 0)
	Next
End Function
CreateSpiralArm(0)
CreateSpiralArm(90)
CreateSpiralArm(180)
CreateSpiralArm(-90)
EndRem

While (Not AppTerminate()) And (Not KeyHit(Key_Escape))
	Cls
	
	SetAlpha 0.25
	DrawPoly(territoryMesh)
	Rem
	If territoryHull Then
		Local n = 0
		Local ox# = - 1
		Local oy#=-1
		For Local p:point = EachIn territoryHull 
			If ox >= 0
				DrawLine ox*MAP_SCALE , oy*MAP_SCALE , p.x*MAP_SCALE , p.y*MAP_SCALE
			EndIf
			ox = p.x
			oy = p.y
			n:+ 1
		Next
	EndRem 'If
	SetAlpha 1.0
	
	For Local gSys:GSystem = EachIn GSystem.SList
		gSys.Draw()
	Next
	
	Flip
Wend
End

Type point
	Field x#,y#
	
	Function Create:point(x#,y#)
		Local p:point=New point
		p.x=x
		p.y=y
		Return p
	End Function
End Type

'returns True if p1 and p2 are on the same side of the line a->b
Function sameside(p1x#,p1y#,p2x#,p2y#,ax#,ay#,bx#,by#)
	If ((bx-ax)*(p1y-ay)-(p1x-ax)*(by-ay))*((bx-ax)*(p2y-ay)-(p2x-ax)*(by-ay)) >= 0 Then Return True
End Function	
	
'Clever little trick for telling if a point is inside a given triangle
'If for each pair of points AB in the triangle, P is on the same side of AB as 
'the other point in the triangle, then P is in the triangle. 
Function pointintriangle(px#,py#,ax#,ay#,bx#,by#,cx#,cy#)
	If sameside(px,py,ax,ay,bx,by,cx,cy) And sameside(px,py,bx,by,ax,ay,cx,cy) And sameside(px,py,cx,cy,ax,ay,bx,by)
		Return True
	Else
		Return False
	EndIf
End Function

'Quickhull function - call this one with a set of points.
Function quickhull:TList(s:TList)
	If s.count()<=3 Return s
	Local l:point=Null
	Local r:point=Null
	For Local p:point=EachIn s
		If l=Null
			l=p
		ElseIf p.x<l.x
			l=p
		EndIf
		If r=Null
			r=p
		ElseIf p.x>r.x
			r=p
		EndIf
	Next
	
	Local an#=ATan2(r.y-l.y,r.x-l.x)
	Local rx#=Cos(an)
	Local ry#=Sin(an)
	Local sx#=Cos(an+90)
	Local sy#=Sin(an+90)
	
	Local s1:TList=New TList
	Local s2:TList=New TList
	For Local p:point=EachIn s
		If p<>l And p<>r
			Local mu#=(l.y-p.y+(ry/rx)*(p.x-l.x))/(sy-sx*ry/rx)
			If mu<0 
				s1.addlast p 
			ElseIf mu>0
				s2.addlast p
			EndIf
		EndIf
	Next
	
	Local out1:TList=findhull(s1,l,r)
	Local out2:TList=findhull(s2,r,l)
	Local out:TList = New TList
	out.addlast l
	If out1
		For Local o:Object=EachIn out1
			out.addlast o
		Next
	EndIf
	out.addlast r
	If out2
		For Local o:Object=EachIn out2
			out.addlast o
		Next
	EndIf
	
	Return out
End Function

'Findhull helper function - you never need to call this
Function findhull:TList(sk:TList,p:point,q:point)
	If Not sk.count() Return Null
	Local c:point=Null
	Local out:TList=New TList
	Local maxdist#=-1
	Local an#=ATan2(q.y-p.y,q.x-p.x)
	Local rx#=Cos(an)
	Local ry#=Sin(an)
	Local sx#=-ry
	Local sy#=rx
	For Local tp:point=EachIn sk
		If tp<>p And tp<>q
			Local mu#=(p.y-tp.y+(ry/rx)*(tp.x-p.x))/(sy-sx*ry/rx)
			If maxdist=-1 Or Abs(mu)>maxdist
				c=tp
				maxdist=Abs(mu)
			EndIf
		EndIf
	Next
	an#=ATan2(c.y-p.y,c.x-p.x)
	rx#=Cos(an)
	ry#=Sin(an)
	sx#=Cos(an+90)
	sy#=Sin(an+90)
	Local s1:TList=New TList
	Local s2:TList=New TList
	For Local tp:point=EachIn sk
		If tp<>c
			If Not pointintriangle(tp.x,tp.y,p.x,p.y,q.x,q.y,c.x,c.y)
				Local mu#=(p.y-tp.y+(ry/rx)*(tp.x-p.x))/(sy-sx*ry/rx)
				If mu<0 s1.addlast tp ElseIf mu>0 s2.addlast tp
			EndIf
		EndIf
	Next
	Local out1:TList=findhull(s1,p,c)
	Local out2:TList=findhull(s2,c,q)
	If out1
		For Local o:Object=EachIn out1
			out.addlast o
		Next
	EndIf
	out.addlast c
	If out2
		For Local o:Object=EachIn out2
			out.addlast o
		Next
	EndIf
	Return out
End Function
