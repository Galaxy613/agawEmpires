Rem
TOOL BOX DE KARLOS CON UNA K
End Rem

'Import "Globals.bmx"
'Import "LuaConsole.bmx"
const _debug = False
'''
Global scnx = 1280
Global scny = 720
Global fullscreen = 0

'''

Global msx, msy, msh[4], msd[4]
Global currentXPan:Float = 0, currentYPan:Float = 0

'''
Global MouseImg:TImage
Global sfont:TImageFont
Global mfont:TImageFont
Global lfont:TImageFont

'''
Global gx# = 0.0 , gy# = 0.0
Global dTime# = 0.0, tTime% = MilliSecs()

'''
'Global currentScreen$ = "main"

Function PrintConsole(str:String) '' Replacing the LuaConsole's one.
	Print str
End Function

Function UpdateInput()
	msx = MouseX()
	msy = MouseY()
	For Local ii = 0 To 3
		msh[ii] = MouseHit(ii)
		msd[ii] = MouseDown(ii)
	Next
End Function

Function TPrint(str:String)
	Print "[" + CurrentDate() + " " + CurrentTime() + "] " + str
End Function

Type tb {expose static}
	Global Token:tbToken
	Global Draw:tbDraw
	Global list:tbList
	Global Math:tbMath
	Global PointIn:tbPointIn
	Global Text:tbText
	Global this:tb
	
	Function KeysDown(key1, key2)
		If KeyDown(key1) Then Return True
		If KeyDown(key2) Then Return True
		Return False
	End Function
	
	Function KeysHit(key1, key2)
		If KeyHit(key1) Then Return True
		If KeyHit(key2) Then Return True
		Return False
	End Function

	Function Init()
		Token:tbToken = New tbToken
		Draw:tbDraw = New tbDraw
		list:tbList = New tbList
		Math:tbMath = New tbMath
		PointIn:tbPointIn = New tbPointIn
		Text:tbText = New tbText
		this:tb = New tb
	End Function
	
	Method FPS%()
		Global Counter, Time, TFPS
		Counter:+1
		If Time < MilliSecs()
			TFPS = Counter' <- Frames/Sec
			Time = MilliSecs() + 1000 ' Update
			Counter = 0
		EndIf
		Return TFPS
	End Method
	
	Method AverageMemoryUsage%()
		Global Counter, Amount%, Time, AvgMemUsuage
		Counter:+ 1
		Amount:+ GCMemAlloced()
		If Time < MilliSecs()
			AvgMemUsuage= Amount/Counter
			Time = MilliSecs() + 1000 ' Update
			Counter = 0
			Amount = 0
		EndIf
		Return AvgMemUsuage
	EndMethod
	
	Function FlushKeyHits()
		For Local I:Int = 0 Until 256
			KeyHit(I)
		Next
	End Function

	Method RunErr(txt$="There's an error up in this foo'!")
		RuntimeError txt$
	End Method
End Type

'''''''''''''''''''''''''''
'#Region Tokenizer Methods
Type tbToken {expose static}
Method RandomParameter:String(txt:String, seperator:String = ",")
	Local tmp = Rand(1, CountParameters(txt$, seperator$) ) 
	Return GetParameter$(txt$,tmp,seperator$)
End Method

Method CountParameters(txt$,seperator$=",")
	Local i = 1, tI = 1, txtLen = Len Txt$
	
	If txt$ = "" Then Return 0
	
	While tI =< txtLen
		If Mid(txt$,tI,1) = seperator$ Then i:+1
		
		tI:+1
	Wend
	
	Return i
End Method

'I don't suggest you use this when you want speed... I doubt this is very speedy.
Method GetParameter$(txt$,num,seperator$=",")
	Local i=1,tI=1,txtLen=Len Txt$,lastPos=0,curPos=0,tmp$,position,size
	
	While tI =< txtLen
		If Mid(txt$,tI,1) = seperator$ Then
			i:+1
			lastPos=curPos
			curPos=tI
		EndIf
		
		If i = (num+1)
			position	=	lastPos+1
			size		=	(curPos)-(lastPos+1)
			tmp$=Mid(txt$,position,size)
			
		'	PrintConsole "GetParameter$('"+txt$+"',"+num+") = "+tmp$
			Return tmp$
		EndIf
		
		tI:+1
	Wend
	If i=1 Then Return txt$
	If (i+1) = (num+1)
		lastPos=curPos
		curPos=tI+1
		position	=	lastPos+1
		size		=	(curPos)-(lastPos+1)
		tmp$=Mid(txt$,position,size)
		
		'PrintConsole "GetParameter$('"+txt$+"',"+num+") = "+tmp$
		Return tmp$
	EndIf
	
	'PrintConsole "GetParameter$('"+txt$+"',"+num+") : Couldn't find parameter "+num+" in '"+txt$+"'!"
	Return ""
End Method

Method FindParameter$(txt$,find$,seperator$=",")
	Local i
	
	For i = 1 To CountParameters(txt$)
		If GetParameter(txt$,i) = find$ Then Return GetParameter(txt$,i,seperator$)
	Next
	
	Return ""
End Method
End Type
'#End Region
'''''''''''''''''''''''''''

'''''''''''''''''''''''''''
'#Region Point in Rect/Text
Type tbPointIn {expose static}
'' Simple rect check.
Method PointInRect%(x,y,rx,ry,rw,rh)
	If x => rx And y => ry
		If x =< (rx+rw) And y =< (ry+rh)
			Return 1
		EndIf
	EndIf
	Return 0
End Method

'' Simple rect check, assuming msx and msy were declared elsewhere and are constantly updated.
'' msx = MouseX();msy = MouseY()
Method MouseInRect%(rx,ry,rw,rh)
	If msx => rx And msy => ry
		If msx =< (rx+rw) And msy =< (ry+rh)
			Return 1
		EndIf
	EndIf
	Return 0
End Method

Method MouseInImage(img:TImage, x, y, centered = False)
	Local tX, tY
	If centered Then
		tX = x + (ImageWidth(img) / 2)
		ty = y + (ImageHeight(img) / 2)
	Else
		tX = x
		tY = y
	EndIf
	
	If MouseInRect(tX, tY, ImageWidth(img), ImageHeight(img)) Then
		Return 1
	EndIf
	
	Return 0
End Method

'' msx = MouseX();msy = MouseY()
Method MouseInText(txt$,tx,ty,centered=False)
	Local txtwidth = TextWidth(txt$)'(Len txt$) * 8
	
	If centered = True Then Return MouseInRect(tx-(txtwidth / 2),ty,txtwidth,TextHeight(txt$))
	
	If centered = False Then Return MouseInRect(tx,ty,txtwidth,TextHeight(txt$))
End Method

Method PointInText(px,py,tx,ty,txt$,centered=False)
	Local txtwidth = TextWidth(txt$)'(Len txt$) * 8
	
	If centered = True Then Return PointInRect(px, py, tx - (txtwidth / 2), ty, txtwidth, TextHeight(txt:String))
	
	If centered = False Then Return PointInRect(px,py,tx,ty,txtwidth,TextHeight(txt$))
End Method

Method CheckFuzz(x:Float, y:Float, z:Float) ' (x > y - z) And (x < y + z)
	' Check fuzzly, instead of a streight (x = y) this allows for some flexiblity.
	If x > y - z And x < y + z Then Return True
	Return False
End Method
End Type
'#End Region
'''''''''''''''''''''''''''

'''''''''''''''''''''''''''
'#Region Text Modifing Methods
Type tbText {expose static}
	
	Method StrToIntBool%(boolText$) {bool}
		boolText = Lower(boolText)
	'	PrintConsole boolText 
		If boolText = "true" Or boolText = "t" Or boolText = "yes"  Or boolText = "y" Then Return 1
		If boolText = "false" Or boolText = "f" Or boolText = "no"  Or boolText = "n" Then Return 0
		If Int(boolText) > 0 Then Return True
		Return False
	End Method
	
	Method IntToStrBool$(boolInt%,trueORyes=True)
		If boolInt Then
			If trueORyes
				Return "true"
			Else
				Return "yes"
			End If
		Else
			If trueORyes
				Return "false"
			Else
				Return "no"
			End If
		End If
		Return "false"
	End Method
	
	Method DirectFileParagraph(file:TStream,x,y,displace=0,maxLines=-1,comments=False)
		Local i,cnt,dmL=(displace+maxLines),currentLine$
		
		While Not Eof(file)
			currentLine$=ReadLine$(file)
			If Left(currentLine$,1) = "*" Then Continue
			
			If comments = False Or (comments = True And Left(currentline$,2) <> "//")
				If cnt => displace Then
					If maxLines > 0 Then
						If cnt < dmL Then
							DrawText currentLine$,x,y+(i*16)
							i:+1
						EndIf
					Else
						DrawText currentLine$,x,y+(i*16)
						i:+1
					EndIf
				EndIf
				cnt:+1
			EndIf
		Wend
		
		SeekStream file,0
	End Method

Method WriteAutoMultiText(t:String, file:TStream, maxCharWidth:Int=40, prefix$="")
	If t.Length =< maxCharWidth Then WriteLine file, prefix+t
	If t = "" Then Return 0
	
	Local words:String[]=t.split(" ")
	
	Local tmpStr$, lastStr$
	Local wordItr = 0
	
	While True
		lastStr = tmpStr
		tmpStr :+ words[wordItr]
		
		If tmpStr.Length < maxCharWidth Then
			wordItr:+ 1 
			tmpStr:+" "
		Else
			WriteLine file, prefix+lastStr
			tmpStr=""
		EndIf
		
		If wordItr => words.length Then '' If we are have finished...
			If tmpStr <> "" Then WriteLine file, prefix+tmpStr
			Exit
		EndIf
	Wend
EndMethod

Method DrawAutoMultiText:Int(t:String, x:Float, y:Float, maxCharWidth:Int=40, startLine:Int = 1, endLine:Int=99999)
	If t.length =< maxCharWidth Then DrawText t,x,y
	If t = "" Then Return 0
	
	Local words:String[]=t.split(" ")
	Local lineheight:Int=TextHeight(" ")
	
	Local numberOfLines = 1
	
	Local dy:Float=y
	Local tmpStr$, lastStr$
	Local wordItr = 0
	
	While True
		lastStr = tmpStr
		tmpStr :+ words[wordItr]
		
		If tmpStr.length < maxCharWidth Then '' Check if the line has exceeded the max width
			'' It hasn't, so add a space and go to the next word
			wordItr:+ 1 
			tmpStr:+" "
		Else
			'' It HAS exceeded the max line, so draw lastStr and DO NOT add to wordItr
			If numberOfLines => startLine And numberOfLines < endLine
				DrawText lastStr , x, dy 
				dy:+lineheight
			EndIf
			
			tmpStr="" '' Reset tmpStr for a new line			
			numberOfLines:+1
		EndIf
		
		If wordItr => words.length Then '' If we are have finished...
			If tmpStr <> "" And numberOfLines < endLine Then DrawText tmpStr, x, dy '' PrintConsole any outstanding words.
			Exit
		EndIf
	Wend
	
	Return numberOfLines '' Return the number of lines drawn
EndMethod

Method FileGetLine$(filename$,line)
	Local cnt, currentLine:String, file:TStream = OpenFile(filename:String, True, False)
	If Not file Then TPrint "[ERROR] Could not open '" + filename:String + "' !" ; Return ""
	
	While Not Eof(file)
		currentLine$=ReadLine$(file)
		If Left(currentLine$,1) = "*" Then Continue
		
		cnt:+ 1
		If cnt = line Then Exit
	Wend
	
	SeekStream file, 0
	file.Close()
	Return currentLine
End Method

Method FileWriteLine(filename:String, line:String)
	Local file:TStream = WriteFile(filename)
	If Not file Then TPrint "[ERROR] Could not open '" + filename:String + "' !" ; Return False
	file.WriteLine(line)
	file.Close()
	Return True
End Method

Method Paragraph(txt$,x,y,displace=0,maxLines=-1,maxChar=100)
	Local cLen=(Len txt$),tmpLine$=txt$,i,ti,di=1,cnt
	Local tmpChar
	
	While cLen > maxChar
		tmpLine$ = Left(txt$,maxChar)
		
		tmpChar = maxChar
			
		If Right(tmpLine$,1) <> " " Then
			ti=1
			
			While Mid(tmpLine$,((Len tmpLine$)-ti),1) <> " "
				ti:+1
			Wend
			
			tmpChar = maxChar-ti
			tmpLine$ = Left(txt$,tmpChar)
		EndIf
				
		If Left(tmpLine$,1) = " " Then tmpLine$ = Right(tmpLine$,(Len tmpLine$)-1)
		If Right(tmpLine$,1) = " " Then tmpLine$ = Left(tmpLine$,(Len tmpLine$)-1)
		
		txt$ = Right(txt$,cLen-(tmpChar-1)) 
		
		
		If cnt => displace Then
			If maxLines > 0 Then
				If cnt < (displace+maxLines) Then
					DrawText tmpLine$,x,y+(i*16)
					i:+1
				EndIf
			Else
				DrawText tmpLine$,x,y+(i*16)
				i:+1
			EndIf
		EndIf
		
		cLen=(Len txt$)
		cnt:+1
	Wend
	
	If cnt => displace Then
		If maxLines > 0 Then
			If cnt < (displace+maxLines) Then
				DrawText txt$,x,y+(i*16)
			EndIf
		Else
			DrawText txt$,x,y+(i*16)
		EndIf
	EndIf
	
	'Warning :+ "PH"+cnt
	Return cnt
End Method

Method SPrintConsoleF:String(txt:String, a:String, b:String = "", c:String = "", d:String = "", e:String = "", f:String = "", g:String = "")
	If a$ Then txt$ = Replace(txt$,"$1",a$)
	If b$ Then txt$ = Replace(txt$,"$2",b$)
	If c$ Then txt$ = Replace(txt$,"$3",c$)
	If d$ Then txt$ = Replace(txt$,"$4",d$)
	If e$ Then txt$ = Replace(txt$,"$5",e$)
	If f$ Then txt$ = Replace(txt$,"$6",f$)
	If g$ Then txt$ = Replace(txt$,"$7",g$)
	
	Return txt$
End Method

Method StripUpTo$(txt$, upto$) 
	Local pos = Instr(txt$, upto$) + (Len upto$)
	If Not Instr(txt$, upto$) Then Return txt$
	Return Right(txt$,(Len txt$)-pos)
End Method
End Type
'#End Region
'''''''''''''''''''''''''''

'''''''''''''''''''''''''''
'#Region Drawing Methods
Type tbDraw {expose static}
Global TK_AllowAlphaChange = True
Global TK_AllowColorChange = True

Method ResetTransforms()
	SetScale 1,1
	SetAlpha 1.0
	SetColor 255,255,255
	SetRotation 0
End Method

Method ClickableText(txt:String, x, y, disabled = False, centered = False, blackoval = False, highlight = False)
	Local tmpColor:String = getRGB()
	If blackoval Then
		If TK_AllowColorChange Then SetColor 0, 0, 0
		If TK_AllowAlphaChange Then SetAlpha 0.6
		Local centeredWidth:Int = 0
		If centered Then centeredWidth = TextWidth(txt:String) / 2
		'DrawOval x-4, y, TextWidth(txt$)+8, TextHeight(txt$)+1
		DrawOval x - 4 - centeredWidth, y - 2, 8, TextHeight(txt:String) + 5
		DrawOval x + TextWidth(txt:String) - 4 - centeredWidth, y - 2, 8, TextHeight(txt:String) + 5
		DrawRect x - centeredWidth, y - 2, TextWidth(txt:String), TextHeight(txt:String) + 5
		
		If TK_AllowColorChange Then SetRGB tmpColor 'SetColor 255, 255, 255
		If TK_AllowAlphaChange Then SetAlpha 1
	EndIf
	If tb.PointIn.MouseInText(txt$, x, y, centered) Then
		If TK_AllowAlphaChange Then SetAlpha 1.0
		If msh[1] And Not disabled = 1 Then
		'	If MenuEffects Then PlaySound menuEffectSound
			msh[1]=0
			Return 1
		EndIf
		If msh[2] And Not disabled = 1 Then
		'	If MenuEffects Then PlaySound menuEffectSound
			msh[2]=0
			Return 2
		EndIf
	Else
		If TK_AllowAlphaChange Then SetAlpha 0.8
		If highlight = 1 Then SetAlpha 0.95
	EndIf
	If disabled = 1 Then If TK_AllowAlphaChange Then SetAlpha 0.6
	If Not centered Then
		DrawText txt$, x, y
	Else
		CenteredText(txt, x, y, False, tmpColor)
	EndIf
	If TK_AllowAlphaChange Then SetAlpha 1.0
	Return 0
End Method

Method ImageProgress(aIMG:TImage, x, y, progress:Float = 1.0, direction = 0)
	If direction = 0 Then
		DrawImageRect(aimg, x, y, aimg.width * progress, aIMG.Height)
	Else
		DrawImageRect(aIMG, x, y, aIMG.width, aIMG.Height * progress)
	End If
End Method

Method ClickableImage(IMG:TImage, x, y, Frame = 0, centered = False)
	Local result:Int = 0
	If centered Then
		result = tb.PointIn.MouseInRect(x - (ImageWidth(IMG) / 2), y - (ImageHeight(IMG) / 2), ImageWidth(IMG), ImageHeight(IMG))
	Else
		result = tb.PointIn.MouseInRect(x, y, ImageWidth(IMG), ImageHeight(IMG))
	EndIf
	If result Then
		If TK_AllowAlphaChange Then SetAlpha 1.0
		If msh[1] 'And Not disabled = 1 Then
		'	If MenuEffects Then PlaySound menuEffectSound
			msh[1]=0
			Return 1
		EndIf
	Else
		If TK_AllowAlphaChange Then SetAlpha 0.8
	EndIf
	'If disabled = 1 Then SetAlpha 0.6
	DrawImage img,x,y,frame
	If TK_AllowAlphaChange Then SetAlpha 1.0
	Return 0
End Method

Method Circle(x, y, dia#, points% = 16) 
	Local pAngle# = 360.0 / points, i%
	Local x1#, y1#, x2#, y2#
	
	For i = 1 To points
		x1 = x + (Cos((i-1)*pAngle)*dia)
		y1 = y + (Sin((i-1)*pAngle)*dia)
		x2 = x + (Cos(i*pAngle)*dia)
		y2 = y + (Sin(i*pAngle)*dia)
		DrawLine x1,y1,x2,y2
	Next
End Method

Method FilledCircle(x, y, dia:Float)
	DrawOval x - Int(dia), y - Int(dia), Int(dia * 2), Int(dia * 2)
End Method

Method DottedCircle(x, y, dia:Float, points = 16, percent:Float = 0.5)
	Local pAngle# = 360.0 / points, i%
	Local tAngle:Float = pAngle * percent
	Local x1#, y1#, x2#, y2#
	
	For i = 1 To points
		x1 = x + (Cos((i-1)*pAngle)*dia)
		y1 = y + (Sin((i-1)*pAngle)*dia)
		x2 = x + (Cos((i*pAngle) - tAngle)*dia)
		y2 = y + (Sin((i*pAngle) - tAngle)*dia)
		DrawLine x1,y1,x2,y2
	Next
End Method

Method CircleAtAngle(x, y, dia:Float, sAngle:Float, points = 16)
	Local pAngle:Float = 360.0 / points, I:Int
	Local x1:Float, x2:Float, y1:Float, y2:Float
	
	For I = 1 To points
		x1 = x + (Cos((I - 1) * pAngle + sAngle) * dia)
		y1 = y + (Sin((I - 1) * pAngle + sAngle) * dia)
		x2 = x + (Cos(I * pAngle + sAngle) * dia)
		y2 = y + (Sin(I * pAngle + sAngle) * dia)
		DrawLine x1, y1, x2, y2
	'	DrawLine x+(Cos((i-1)*pAngle#)*dia#),y+(Sin((i-1)*pAngle#)*dia#),x+(Cos(i*pAngle#)*dia#),y+(Sin(i*pAngle#)*dia#)
	Next
End Method

Global TK_CrossAngle:Float

Method Cross(x, y, Rotate:Int = 1, extra:Float = 0.0)
	'DrawRect x-5,y-1,11,3
	'DrawRect x-1,y-5,3,11
	TK_CrossAngle:+(0.5 + extra:Float) * rotate
	
	SetRotation TK_CrossAngle:Float
	SetLineWidth 3
	
	'DrawLine x-6,y,x+5,y
	'DrawLine x,y-6,x,y+5
	DrawLine x,y,x+5,y
	DrawLine x,y,x,y+5
	DrawLine x,y,x-5,y
	DrawLine x,y,x,y-5
	
	SetLineWidth 1
	SetRotation 0
End Method

Rem
Method SystemMapCross(xx#,yy#,sSize#)
	DrawLine 	scnx/2 + ( (xx)*sysMapScale ),		scny/2 + ( (yy-sSize)*sysMapScale ),		..
				scnx/2 + ( (xx)*sysMapScale ),		scny/2 + ( (yy+sSize)*sysMapScale )
	DrawLine 	scnx/2 + ( (xx-sSize)*sysMapScale ),	scny/2 + ( (yy)*sysMapScale ),		..
				scnx/2 + ( (xx+sSize)*sysMapScale ),	scny/2 + ( (yy)*sysMapScale )	
End Method
EndRem

Method LineRect(x,y,wid,hig,Cross=0,highlight=0)
	If TK_AllowAlphaChange Then If highlight Then SetAlpha 0.9
	
	DrawLine x, y, x + wid, y
	DrawLine x, y, x, y + hig
	
	If TK_AllowAlphaChange Then If highlight Then SetAlpha 0.4
	
	DrawLine x+wid,	y,		x+wid,	y+hig
	DrawLine x, y + hig, x + wid, y + hig
	
	If TK_AllowAlphaChange Then If highlight Then SetAlpha 1
	
	If cross
	DrawLine x,		y,		x+wid,	y+hig
	DrawLine x+wid,	y,		x,		y+hig	
	EndIf
End Method

Method LineRectNoOverlap(x,y,wid,hig)	
	DrawLine x, y, x + wid-1, y
	DrawLine x, y+1, x, y + hig-1
	
	DrawLine x+wid,	y,			x+wid,	y+hig
	DrawLine x, 		y+hig, 	x+wid-1, 	y+hig
End Method

Method RotatedLineSq(x,y,wid,angle#=0)
	SetAlpha 1
'	Local xc = Cos(angle)*wid
'	Local yc = Sin(angle)*wid
	
	DrawLine x+Cos(angle-45)*wid,	y+Sin(angle-45)*wid,	x+Cos(angle+45)*wid,	y+Sin(angle+45)*wid
	DrawLine x+Cos(angle+45)*wid,	y+Sin(angle+45)*wid,	x+Cos(angle+135)*wid,	y+Sin(angle+135)*wid
	DrawLine x+Cos(angle+135)*wid,y+Sin(angle+135)*wid,	x+Cos(angle-135)*wid,	y+Sin(angle-135)*wid	
	DrawLine x+Cos(angle-135)*wid,y+Sin(angle-135)*wid,	x+Cos(angle-45)*wid,	y+Sin(angle-45)*wid	
End Method

Method TextOutline(t:String, x:Float, y:Float, centered = False, orgb:String = "0,0,0", rgb:String = "255,255,255", weight:Float = 1.0)
	'If TK_AllowColorChange Then SetColor 0, 0, 0
	'SetAlpha 1	
	'SetScale 1,1
	Local txtWidth:Int = 0'TextWidth(t)
	
	If centered <> 0 Then
		txtWidth = TextWidth(t) / 2
	End If
	
	SetRGB orgb
	
	DrawText t, x - txtWidth + weight, y
	DrawText t, x - txtWidth - weight, y
	DrawText t, x - txtWidth, y + weight
	DrawText t, x - txtWidth, y - weight
	
	SetRGB rgb
	
	DrawText t, x - txtWidth, y
End Method

Method LeftAlignedText(t$, x%, y%)
	Local txtWidth = TextWidth(t)
	
	DrawText t, x - txtWidth, y
End Method

Method AlignedText(t$, x%, y%, a%)
	Select a
		Case -1
			LeftAlignedText(t$, x, y)
		Case 0
			CenteredText(t, x, y)
		Case 1
			DrawText t, x, y
	End Select
End Method

Method CenteredText(t:String, x, y, outline = False, rgb:String = "255,255,255", orgb:String = "0,0,0")
	If outline Then
		TextOutline t, x, y, False, orgb, rgb
	Else
		Local txtwidth:Int = TextWidth(t) / 2
		DrawText t:String, x - txtwidth, y
	EndIf
End Method

Method SetRGB(RGB:String)
	' Format MUST be ###,###,###
'	SetColor Int(tb.Token.GetParameter(RGB, 1)), Int(tb.Token.GetParameter(RGB, 2)), Int(tb.Token.GetParameter(RGB, 3))
	Select RGB.ToLower()
		Case "red"
			RGB = "255,64,64"
		Case "green"
			RGB = "64,255,64"
		Case "blue"
			RGB = "64,64,255"
		Case "yellow"
			RGB = "255,255,64"
		Case "cyan"
			RGB = "64,255,255"
	End Select
	SetColor Int(RGB.Split(",")[0]), Int(RGB.Split(",")[1]), Int(RGB.Split(",")[2])
End Method

Method SetGrey(amt:Int)
	SetColor amt,amt,amt
End Method

Method TakeScreenshot(numPaddingStart:Int = 0)
	Local dir:String="screenshots\"
	Local filename:String, padded:String
	Local num:Int = numPaddingStart

	padded = num
	While padded.length < 3 
		padded = "0"+padded
	Wend
	filename = dir + "screen"+padded+".png"
	
	PrintConsole "Screenshot Filename: " + filename
	PrintConsole FileSize(filename)
	
	While FileSize(filename) > 0
		num:+1

		padded = num
		While padded.length < 3 
			padded = "0"+padded
		Wend
		filename = dir + "screen"+padded+".png"
	Wend

	Local img:TPixmap = GrabPixmap(0,0,GraphicsWidth(),GraphicsHeight())

	SavePixmapPNG(img, filename)
	
	PrintConsole "Screenshot saved as " + filename + " into the 'Screenshots' folder"

EndMethod

Method GetRGB:String()
	Local tmpR:Int, tmpG:Int, tmpB:Int
	GetColor(tmpR, tmpG, tmpB)
	Return tmpr + "," + tmpG + "," + tmpB
End Method

Method GetRGBBasedOnNumber:String(clr:Int)
	Global cmax:Int = 255, cmin:Int = 64
	Select clr
		Case 1
			Return cmax + "," + cmin + "," + cmin '' Red
		Case 2
			Return cmin + "," + cmax + "," + cmin  '' Green
		Case 3
			Return cmin + "," + cmin + "," + cmax  '' Blue
		Case 4
			Return cmax + "," + cmax + "," + cmin  '' Yellow
		Case 5
			Return cmax + "," + cmin + "," + cmax  '' Purple
		Case 6
			Return cmin + "," + cmax + "," + cmax  '' Cyan
		Case 7
			Return Int(cmax * 0.6) + "," + Int(cmax * 0.6) + "," + Int(cmax * 0.8)
		Case 8
			Return cmax + "," + (cmax * 0.7) + "," + cmin '' Red
		Case 9
			Return Int(cmax * 0.7) + "," + cmax + "," + cmin  '' Green
		Case 10
			Return cmin + "," + Int(cmax * 0.7) + "," + cmax  '' Blue
		Case 11
			Return cmax + "," + cmax + "," + Int(cmax * 0.7)  '' Yellow
		Case 12
			Return cmax + "," + Int(cmax * 0.7) + "," + cmax  '' Purple
		Case 13
			Return Int(cmax * 0.7) + "," + cmax + "," + cmax  '' Cyan
		Default'Case 0
			Return cmax + "," + cmax + "," + cmax
	End Select
End Method
End Type
'#End Region
'''''''''''''''''''''''''''

'''''''''''''''''''''''''''
'#Region Extra List Methods
Type tbList {expose static}
Method GetIndexInList(list:TList, objt:Object)
	Return FindIndexInList(list, objt)
EndMethod

Method FindIndexInList(list:TList, objt:Object)
	Local count%,tmp:Object
	
	For tmp:Object = EachIn list
		count%:+1
		If tmp = objt Then Return count
	Next
	
	Return - 1
End Method

Method GetObjectAtIndex:Object(list:TList, index:Int)
	Local count%,tmp:Object
	
	For tmp:Object = EachIn list
		count%:+1
		If Count = index Then Return tmp
	Next
	
	Return Null
End Method

Method GetRandomFromList:Object(list:TList)
	Local count:Int = CountList(list), tmp:Object
	Local random = Rand(1,count)
	count=0
	
	For tmp:Object = EachIn list
		count%:+1
		If count = random Then Return tmp
	Next
End Method
End Type
'#End Region
'''''''''''''''''''''''''''

'''''''''''''''''''''''''''
'#Region Maths
Type tbMath {expose static}
	
Method SlowRotation:Float(speed:Float = 0.01)
	Return (MilliSecs() * speed) Mod 360.0
End Method

Method eInt(num#)
	Local tn% = Int(Num#)
	
	If num > 0
		If (num - tn) > 0.5 Then Return tn+1
		If (num - tn) =< 0.5 Then Return tn'-1
	ElseIf num < 0
		If (num - tn) > -0.5 Then Return tn
		If (num - tn) =< -0.5 Then Return tn-1		
	Else
		Return 0
	EndIf
End Method

Method Snap:Int(number:Float, limiter:Int, offset:Int)
	Return Int(Float(number+offset) / Float(limiter)) * limiter
End Method

Method GetPercent#(number#,maximum#)
	Return number#/maximum#
End Method

Method Limit360#(angle#)
	If angle# > 360 Then angle#:-360
	If angle# < 0 Then angle#:+360
	Return Angle#
End Method

Method Within(this#,within#,edge#) {bool}
	If this# =< within# + edge
		If this# => within# - edge
			Return True
		EndIf
	EndIf
	
	Return False
End Method

Method GetDistance#(x1#,y1#,x2#,y2#)
	Return Sqr( ((x2 - x1)^2) + ((y2 - y1)^2) )
End Method

Method GetAngle#(x1#,y1#,x2#,y2#)
	Return ATan2((y2# - y1#), (x2# - x1#))
End Method

Method GetAngleVector#(currentAngle#,targetAngle#)
	If currentAngle# => 0 And currentAngle# =< 180 Then
		If TargetAngle# > 180 And TargetAngle# =< 360 Then
			Return 1
		ElseIf TargetAngle# => 0 And TargetAngle# =< 180 Then
			If currentAngle# > TargetAngle#
				Return -1
			Else
				Return 1
			EndIf
		EndIf
	ElseIf currentAngle# > 180 And currentAngle# =< 360 Then
		If TargetAngle# => 0 And TargetAngle# =< 180 Then
			Return 1
		ElseIf TargetAngle# > 180 And TargetAngle# =< 360 Then
			If currentAngle# > TargetAngle#
				Return -1
			Else
				Return 1
			EndIf
		EndIf
	EndIf
End Method

Method GetAngleVectorP#(currentAngle#,targetAngle#)
	If currentAngle# => 0 And currentAngle# =< 90 Then
		If TargetAngle# > 180 And TargetAngle# =< 360 Then
			Return 1
		ElseIf TargetAngle# => 0 And TargetAngle# =< 180 Then
			If currentAngle# > TargetAngle#
				Return -1
			Else
				Return 1
			EndIf
		EndIf
	ElseIf currentAngle# > 90 And currentAngle# =< 180 Then
		If TargetAngle# > 180 And TargetAngle# =< 360 Then
			Return 1
		ElseIf TargetAngle# => 0 And TargetAngle# =< 180 Then
			If currentAngle# > TargetAngle#
				Return -1
			Else
				Return 1
			EndIf
		EndIf
	ElseIf currentAngle# > 180 And currentAngle# =< 270 Then
		If TargetAngle# => 0 And TargetAngle# =< 180 Then
			Return 1
		ElseIf TargetAngle# > 180 And TargetAngle# =< 360 Then
			If currentAngle# > TargetAngle#
				Return -1
			Else
				Return 1
			EndIf
		EndIf
	ElseIf currentAngle# > 270 And currentAngle# =< 360 Then
		If TargetAngle# => 0 And TargetAngle# =< 180 Then
			Return 1
		ElseIf TargetAngle# > 180 And TargetAngle# =< 360 Then
			If currentAngle# > TargetAngle#
				Return -1
			Else
				Return 1
			EndIf
		EndIf
	EndIf
End Method

Method LimitDecimal$(tmpfloat#,positions = 1) 
	Return Left(String(tmpFloat#), Instr(tmpFloat#,".")+positions)
End Method

Method LimitDenom:String(amount:Float, cred:String = "m", thou:String = "b", mill:String = "t")'cred:String = "c", thou:String = "k", mill:String = "m")
'	amount = Abs(amount)
	If Abs(amount) > 999 Then Return LimitDecimal(amount * 0.001) + thou
	'If amount > 9999 Then Return LimitDecimal(amount#*0.001)+"k"
	If Abs(amount) > 999999 Then Return LimitDecimal(amount * 0.000001) + mill
	If Abs(amount) > 999999999 Then Return LimitDecimal(amount * 0.000000001) + mill + mill
	Return Int(amount) + cred
End Method

Method LimitTime:String(amount:Float, ms:String = "ms", sec:String = "sec", amin:String = "min", hour:String = "hr")
'	amount = Abs(amount)
	If Abs(amount) < 1.0 Then Return Int(amount * 1000) + ms
	If Abs(amount) > 60 Then Return Int(amount / 60) + amin
	'If amount > 9999 Then Return LimitDecimal(amount#*0.001)+"k"
	If Abs(amount) > 3600 Then Return Int(amount / 3600) + hour
	Return Int(amount) + sec
End Method
End Type
'#End Region
'''''''''''''''''''''''''''

Type Point
	Field x#,y#
	
	Function Create:Point(x:Float, y:Float)
		Local P:Point = New Point
		p.x=x
		p.y=y
		Return p
	End Function
End Type

Type Vector2D {expose}
	Field x:Double, y:Double
	Field Length:Double
	
	''''''''''''''''''''''''''''''''''''''''
	'#Region Methods
	
	Method debug_toString:String(limit = -1)
		If limit > - 1 Then
			Return "( " + tb.Math.LimitDecimal(x, limit) + " , " + tb.Math.LimitDecimal(y, limit) + " )"
		Else
			Return "( " + x + " , " + y + " )"
		EndIf
	End Method
	
	Method Avg:Double()
		Return (x + y) / 2.0
	End Method
	
	Method GetAngle:Double(vec:Vector2D) 
		Return tb.Math.GetAngle(x, y, vec.x, vec.y) 
	End Method
	
	Method Angle:Double() 
		Return tb.Math.GetAngle(0, 0, x, y) 
	End Method
	
	Method Magitude:Double() 
		Return (x + y) / 2
	End Method
	
	Method Set(_x:Double, _y:Double)
		x = _x
		y = _y
		Length = Sqr((x^2)+(y^2))
	End Method
	
	Method roundTo(r:Double)
		'Int(Float(number + offset) / Float(limiter)) * limiter
		x = Int(x / r) * r
		y = Int(y / r) * r
	End Method
	
	Method Sync(vec:Vector2D)
		x = vec.x
		y = vec.y
		length = vec.Length
	End Method
	
	Method translateTo(vec:Vector2D, theshold:Double = 1.0)
		If x > vec.x + theshold Then
			x:-theshold
		ElseIf x < vec.x - theshold Then
			x:+theshold
		EndIf
		
		If y > vec.y + theshold Then
			y:-theshold
		ElseIf y < vec.y - theshold Then
			y:+theshold
		End If
	End Method
	
	Method slideTo(vec:Vector2D, theshold:Double = 1.0)
		Local tmp:Vector2D = New Vector2D.Sub(Self, vec)
		If _debug = 2 Then PrintConsole tmp.x + " | " + tmp.y + " || " + tmp.Length
		tmp.Normalize
		If _debug = 2 Then PrintConsole tmp.x + " | " + tmp.y + " || " + tmp.Length
		
		x:+tmp.x * -theshold
		y:+tmp.y * -theshold
	End Method
	
	Method FuzzyEquals(vec:Vector2D, thershold:Double = 0.5)
		If tb.PointIn.CheckFuzz(x, vec.x, thershold) And tb.PointIn.CheckFuzz(y, vec.y, thershold)
			Return True
		EndIf
		Return False
	End Method
	
	Method Equals(vec:Vector2D)
		If x = vec.x And y = vec.y Then
			Return True
		End If
		Return False
	End Method
	
	Method Absol()
		x = Abs(x)
		y = Abs(y)
		Length = Sqr((x^2)+(y^2))
	End Method
	
	Method Normalize()
	'	x = Double(Float(length) / Float(x))
	'	y = Double(Float(length) / Float(y))
		x = Double(Float(x) / Float(length))
		y = Double(Float(y) / Float(length))
	'	x = x / length
	'	y = y / length
	End Method
	
	Method Distance:Double(vec:Vector2D)
		Return Sqr(((vec.x - x) ^ 2) + ((vec.y - y) ^ 2))
	End Method
	
	Method SetScaleTo()
		SetScale x,y
	End Method
	
	Method MidPoint:Vector2D(o:Vector2D)
		Return New Vector2D.Create((x+o.x)/2,(y+o.y)/2)
	End Method
	
	Method Point:Vector2D(o:Vector2D,divisor:Double)
		Return New Vector2D.Create((x+o.x)/divisor,(y+o.y)/divisor)
	End Method
	
	Method DrawAt(i:TImage, f% = 0)
		DrawImage i, x, y, f
	End Method
	
	Method DrawAt_WithScale(i:TImage, s:Vector2D, f% = 0)
		Local fx#,fy#
		GetScale(fx,fy)
		SetScale s.x, s.y
		DrawImage(i, x, y, f)
		SetScale fx,fy
	End Method
	
'	Method Distance:Double(vec:Vector2D)
'		Local dist:Double = Sqr(((vec.x - x) ^ 2) + ((vec.y - y) ^ 2))
'		PrintConsole "Self: " + Self.debug_toString() + " Other: " + vec.debug_toString() + " Distance Calc: " + dist
'		Return dist
'	End Method
	'#End Region
	''''''''''''''''''''''''''''''''''''''''
	'#Region Methods
	
	Method GetMidPoint:Vector2D(v1:Vector2D, v2:Vector2D)
		Return v1.MidPoint(v2)
	End Method
	
	Method GetPoint:Vector2D(v1:Vector2D, v2:Vector2D, div:Double)
		Return v1.Point(v2,div)
	End Method
	
	Method Add:Vector2D(vec1:Vector2D, vec2:Vector2D)
		Local tVec:Vector2D = New Vector2D
		
		tVec.Set vec1.x+vec2.x,vec1.y+vec2.y
		
		Return tVec
	End Method
	
	Method Sub:Vector2D(vec1:Vector2D, vec2:Vector2D)
		Local tVec:Vector2D = New Vector2D
		
		tVec.Set vec1.x-vec2.x,vec1.y-vec2.y
		
		Return tVec
	End Method
	
	Method Mul:Vector2D(vec1:Vector2D, vec2:Vector2D)
		Local tVec:Vector2D = New Vector2D
		
		tVec.Set vec1.x*vec2.x,vec1.y*vec2.y
		
		Return tVec
	End Method
	
	Method Div:Vector2D(vec1:Vector2D, vec2:Vector2D)
		Local tVec:Vector2D = New Vector2D
		
		tVec.Set vec1.x/vec2.x,vec1.y/vec2.y
		
		Return tVec
	End Method
	
	Function Create:Vector2D(x:Double, y:Double)
		Local tVec:Vector2D = New Vector2D
		
		tVec.Set x,y
		
		Return tVec
	End Function
	
	Method Clone:Vector2D()'(avec:Vector2D)
		Local tVec:Vector2D = New Vector2D
		
		tVec.Sync Self
		
		Return tVec
	End Method
	
	Rem
	bbdoc:Draws an Image[i] at the x And y coords.[v] with frame number[f]
	End Rem 
	Method DrawImageAt(i:TImage, v:Vector2D, f:Int = 0)
		v.DrawAt i, f
	End Method
	
	Rem
	bbdoc:Draws an Image[i] at the x And y coords.[v] with frame number[f]
	end rem 
	Method DrawImageAt_WithScale(i:TImage, v:Vector2D, s:Vector2D, f:Int = 0)
		v.DrawAt_WithScale i, s, f
	End Method
	
	'#End Region
End Type
'''''''''''''''''''''''''''

Type tbHull
 'returns True if p1 and p2 are on the same side of the line a->b
Function SameSide(p1x:Float, p1y:Float, p2x:Float, p2y:Float, ax:Float, ay:Float, bx:Float, by:Float)
	If ((bx-ax)*(p1y-ay)-(p1x-ax)*(by-ay))*((bx-ax)*(p2y-ay)-(p2x-ax)*(by-ay)) >= 0 Then Return True
End Function	
	
'Clever little trick for telling if a point is inside a given triangle
'If for each pair of points AB in the triangle, P is on the same side of AB as 
'the other point in the triangle, then P is in the triangle. 
Function PointInTriangle(px:Float, py:Float, ax:Float, ay:Float, bx:Float, by:Float, cx:Float, cy:Float)
	If sameside(px,py,ax,ay,bx,by,cx,cy) And sameside(px,py,bx,by,ax,ay,cx,cy) And sameside(px,py,cx,cy,ax,ay,bx,by)
		Return True
	Else
		Return False
	EndIf
End Function

Function ConvertHullToPolygon:Float[] (hull:TList)
	Local tmpMesh:Float[] = New Float[hull.Count() * 2]
	Local ii% = 0
	
	For Local pp:Point = EachIn hull
		tmpMesh[ii * 2] = pp.x' * MAP_SCALE
		tmpMesh[(ii * 2) + 1] = pp.y' * MAP_SCALE
		ii:+1
	Next
	
	Return tmpMesh
End Function

'Quickhull function - call this one with a set of points.
Function QuickHull:TList(s:TList)
	If s.count()<=3 Return s
	Local l:point=Null
	Local r:point = Null
	Local P:point = Null
	For P = EachIn s
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
	For P = EachIn s
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
	Local o:Object = Null
	out.addlast l
	If out1
		For o = EachIn out1
			out.addlast o
		Next
	EndIf
	out.addlast r
	If out2
		For o = EachIn out2
			out.addlast o
		Next
	EndIf
	
	Return out
End Function

'Findhull helper function - you never need to call this
Function FindHull:TList(sk:TList, P:point, q:point)
	If Not sk.count() Return Null
	Local c:point = Null
	Local tp:point = Null
	Local o:Object = Null
	Local out:TList=New TList
	Local maxdist#=-1
	Local an#=ATan2(q.y-p.y,q.x-p.x)
	Local rx#=Cos(an)
	Local ry#=Sin(an)
	Local sx#=-ry
	Local sy:Float = rx
	Local mu:Float = 0.0
	For tp = EachIn sk
		If tp<>p And tp<>q
			mu = (P.y - tp.y + (ry / rx) * (tp.x - P.x)) / (sy - sx * ry / rx)
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
	For tp = EachIn sk
		If tp<>c
			If Not pointintriangle(tp.x,tp.y,p.x,p.y,q.x,q.y,c.x,c.y)
				mu = (P.y - tp.y + (ry / rx) * (tp.x - P.x)) / (sy - sx * ry / rx)
				If mu<0 s1.addlast tp ElseIf mu>0 s2.addlast tp
			EndIf
		EndIf
	Next
	Local out1:TList=findhull(s1,p,c)
	Local out2:TList=findhull(s2,c,q)
	If out1
		For o = EachIn out1
			out.addlast o
		Next
	EndIf
	out.addlast c
	If out2
		For o = EachIn out2
			out.addlast o
		Next
	EndIf
	Return out
End Function
End Type