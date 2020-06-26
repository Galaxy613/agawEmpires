Rem

This is just a fancy way to display messages to the client user.

end rem

Import "Toolbox.bmx"

Type _Msg
	Field txt:String = "", clr = 0, ms:Int
	Global cmax:Int = 255, cmin:Int = 96
	
	Method s:_Msg(_txt$,_clr=0)
		txt = _txt
		clr = _clr
		ms = MilliSecs()
		Return Self
	End Method
	
	Method _setColor() ' setColor
		Select clr
			Case 1
				SetColor cmax, cmin, cmin '' Red
			Case 2
				SetColor cmin / 2, cmax / 2, cmin / 2  '' Green
			Case 3
				SetColor cmin, cmax, cmin  '' Green
				'SetColor cmin, cmin, cmax  '' Blue
			Case 4
				SetColor cmax, cmax, cmin  '' Yellow
			Case 5
				SetColor cmax, cmin, cmax  '' Purple
			Case 6
				SetColor cmin, cmax, cmax  '' Cyan
			Case 7
				SetColor cmax * 0.7, cmax * 0.7, cmax * 0.7
			Case 8
				SetColor cmax, cmax * 0.7, cmin '' Red
			Case 9
				SetColor cmax * 0.7, cmax, cmin  '' Green
			Case 10
				SetColor cmin, cmax * 0.7, cmax  '' Blue
			Case 11
				SetColor cmax, cmax, cmax * 0.7  '' Yellow
			Case 12
				SetColor cmax, cmax * 0.7, cmax  '' Purple
			Case 13
				SetColor cmax * 0.7, cmax, cmax  '' Cyan
			Default'Case 0
				SetColor cmax,cmax,cmax
		End Select
	End Method
End Type

Type sVar
	Field _nme$,_var$
	Method S:sVar(nme$,tvar$)
		_nme = nme
		_var = tvar
		Return Self
	End Method
	Method ToString:String()
		Return _nme+" = "+_var
	End Method
End Type

Type sChatHandler
	Field enabled = False, show = False
	Field drawWhenEmpty = True
	Field currentString:String
	Field cmd:String, arg:String, typ:Int
	Field verboseLevel:Int = 7
	
	Field MessageList:TList = CreateList()
	Global VarList:TList = CreateList()
	
	Method add(str:String, clr = 0)
		ListAddLast MessageList, New _Msg.s(str, clr)
		Print clr+"] "+CurrentTime()+" :: "+str
	End Method
	
	Method NewVariable(nme:String, tvar:String = "")
		nme = nme.ToLower()
		add("New Var '" + nme + "' Set to '" + tvar + "'")
		ListAddLast VarList,New sVar.s(nme,tvar)
	End Method
	
	Method AddVariable(aVar:sVar)
		ListAddLast VarList,aVar
	End Method
	
	Method RemoveVariable(nme:String)
		nme = nme.ToLower()
		For Local tVar:sVar = EachIn varlist
			If tvar._nme = nme Then
				ListRemove varList,tVar
				Return True
			End If
		Next
		DebugLog "Wasn't able to find var.nme = '"+nme+"' !"
		Return False
	End Method
	
	Method SetVariable(nme:String, tmvar:String = "")
		nme = nme.ToLower()
		For Local tVar:sVar = EachIn varlist
			If tvar._nme = nme Then
				tVar._var = tmvar
				Add("Set: $"+tvar.ToString(),6)
				Return True
			End If
		Next
		DebugLog "Wasn't able to find var.nme = '"+nme+"' !"
		Return False	
	End Method
	
	Method GetVariable:sVar(nme:String)
		nme = nme.ToLower()
		For Local tVar:sVar = EachIn varlist
			If tvar._nme = nme Then
				Return tVar
			End If
		Next
		DebugLog "Wasn't able to find var.nme = '"+nme+"' !"
		Return Null	
	End Method
	
	Method DrawList(x:Int, y:Int, direction:Int = 1, fadeout:Int = 20)
		If enabled = False Then SetAlpha 0.5
		Local sm:_Msg, i%, ttl% = CountList(MessageList)-1
		For sm = EachIn MessageList
			If sm.clr > verboseLevel Then i:+1; Continue	
			If (ttl - i) => fadeout Then
				If MilliSecs() > sm.ms+8000 Then
					i:+1; Continue
				ElseIf MilliSecs() > sm.ms+7000 Then
					SetAlpha 1-(MilliSecs() - (sm.ms+7000))
				End If
			End If
			
			sm._setColor
			
			DrawText sm.txt,x,y+(direction*((ttl - i)*16))	
			'DrawText sm.txt.ToUpper(),x,y+(direction*((ttl - i)*16))			
			i:+1
		Next
		SetAlpha 1
		SetColor 255,255,255
	End Method
	
	Method drawChat(x:Int, y:Int, prompttxt:String = ">")
		If enabled = False And Not show Then Return
		Global pulse = -1
		If Not drawWhenEmpty And currentString = "" Then Return
		If enabled Then SetColor 200, 255, 200
		DrawText String(prompttxt + currentString), x, y
		If enabled Then
			pulse:-1
			If pulse > 0 Then
				DrawRect x + TextWidth(prompttxt + currentString), y, 8, 16
				'DrawRect x+TextWidth(String(">"+currentString).ToUpper()),y,8,16
			ElseIf pulse < -20
				pulse = 20
			End If
		EndIf
		SetColor 255,255,255
	End Method
	
	Method CheckInput:String()
		If enabled = False Then Return
		Local c = GetChar()
		typ = 0
		Local I:Int
		Select c
			Case 8 ' BackSpace
				currentString = currentString[..currentString.length-1]
				
			Case 13 ' Enter
				arg = ""
				cmd = ""
				typ = 1
				If currentString[..2] = "/="	'VARIABLE CHANGE
					cmd = currentString[2..]
					I:Int = cmd.Find(" ")	',arg$
					
					Local tVar:sVar
					If i<>-1
						arg=cmd[i+1..]
						cmd=cmd[..i]
						setvariable(cmd, arg)
						tVar = GetVariable(cmd)
						If tVar
						'	Add("Set: $"+tvar.ToString(),6)
							Select cmd
							'	Case "port"
							'		GAMEPORT = Int(arg)
								Case "vlevel"
									verboseLevel = Int(arg)
							End Select
						Else
							Add("No such variable as '"+cmd+"'!",1)
						End If
					Else
						tVar = GetVariable(cmd)
						If tVar
							Add("$"+tvar.ToString(),6)
						Else
							add("No such variable as '" + cmd + "'!", 1)
						End If						
					EndIf
					
					typ = 0
					arg = ""
					cmd = ""
					currentString = ""
				ElseIf currentString[..2] = "/+"	'VARIABLE CREATION
					cmd = currentString[2..]
					I:Int = cmd.Find(" ")	',arg$
					
					If i<>-1
						arg=cmd[i+1..]
						cmd = cmd[..I]
						NewVariable(cmd, arg)
						add("$ " + cmd + "=" + arg, 2)
					Else
						add("When creating a variable you must provide non-zero data", 1)
					EndIf
					
					typ = 0
					arg = ""
					cmd = ""
					currentString = ""
				ElseIf currentString[..1] = "/"	'COMMAND
					'Local 
					cmd=currentString[1..]
					I:Int = cmd.Find(" ")',arg$
					
					If i<>-1
						arg=cmd[i+1..]
						cmd=cmd[..i]
					EndIf
					
					typ = 2
					currentString=""
					Return cmd.ToLower()
				Else
					cmd = currentString
					currentString = ""
					Return cmd
				EndIf
				
				currentString=""
			Default ' If an actual character...
				If c>31 And c<127 Then currentString:+Chr(c)
		End Select
	End Method
End Type

Type sTextBox
	Field enabled = False, show = True
	Field drawWhenEmpty = True
	Field Prompttxt$="Text Here: ",currentString:String, isPassword:Int = False
	Field cmd:String, arg:String, typ:Int
	Field x:Int, y:Int
	
	Method SetPosition(xx:Int, yy:Int)
		x = xx ; y = yy
	End Method
	
	Method Draw()
		If enabled = False And Not show Then Return
		Global pulse = -1
		If Not drawWhenEmpty And currentString = "" Then Return
		If enabled Then SetColor 200, 255, 200
		If isPassword Then
			Local padded:String = ""
			While padded.Length < currentString.Length
				padded = "*" + padded
			Wend
			DrawText String(Prompttxt + padded), x, y
		Else
			DrawText String(prompttxt + currentString), x, y
		EndIf
		If enabled Then
			pulse:-1
			If pulse > 0 Then
				DrawRect x + TextWidth(prompttxt + currentString), y, TextWidth("k"), TextHeight("k")
				'DrawRect x+TextWidth(String(">"+currentString).ToUpper()),y,8,16
			ElseIf pulse < -20
				pulse = 20
			End If
		EndIf
		SetColor 255, 255, 255
	End Method
	
	Method CheckInput()
		If enabled Then
		Local c = GetChar()
		typ = 0
	'	Local I:Int
		Select c
			Case 8 ' BackSpace
				currentString = currentString[..currentString.length-1]
			
				Rem Apparently I didn't want the rest of this functionality? KWN 6/2020
			Case 13 ' Enter
				arg = ""
				cmd = ""
				typ = 1
				If currentString[..2] = "/="	'VARIABLE CHANGE
					cmd = currentString[2..]
					I:Int = cmd.Find(" ")	',arg$
					
					Local tVar:sVar
					If i<>-1
						arg=cmd[i+1..]
						cmd=cmd[..i]
						setvariable(cmd, arg)
						tVar = GetVariable(cmd)
						If tVar
						'	Add("Set: $"+tvar.ToString(),6)
							Select cmd
							'	Case "port"
							'		GAMEPORT = Int(arg)
								Case "vlevel"
									verboseLevel = Int(arg)
							End Select
						Else
							Add("No such variable as '"+cmd+"'!",1)
						End If
					Else
						tVar = GetVariable(cmd)
						If tVar
							Add("$"+tvar.ToString(),6)
						Else
							add("No such variable as '" + cmd + "'!", 1)
						End If						
					EndIf
					
					typ = 0
					arg = ""
					cmd = ""
					currentString = ""
				ElseIf currentString[..2] = "/+"	'VARIABLE CREATION
					cmd = currentString[2..]
					I:Int = cmd.Find(" ")	',arg$
					
					If i<>-1
						arg=cmd[i+1..]
						cmd = cmd[..I]
						NewVariable(cmd, arg)
						add("$ " + cmd + "=" + arg, 2)
					Else
						add("When creating a variable you must provide non-zero data", 1)
					EndIf
					
					typ = 0
					arg = ""
					cmd = ""
					currentString = ""
				ElseIf currentString[..1] = "/"	'COMMAND
					'Local 
					cmd=currentString[1..]
					I:Int = cmd.Find(" ")',arg$
					
					If i<>-1
						arg=cmd[i+1..]
						cmd=cmd[..i]
					EndIf
					
					typ = 2
					currentString=""
					Return cmd.ToLower()
				Else
					cmd = currentString
					currentString = ""
					Return cmd
				EndIf
				
				currentString=""
			Endrem
			Default ' If an actual character...
				If c>31 And c<127 Then currentString:+Chr(c)
		End Select
		EndIf
		
		If tb.PointIn.MouseInRect(x, y, TextWidth(Prompttxt + currentString), TextHeight("asdf")) And msh[1] Then msh[1] = 0; Return True
		Return False
	End Method
End Type
