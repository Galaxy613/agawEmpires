Rem
'---------------------------------------------------------------------------------------------------
Explorer HOG Engine - By Subsoap
Lead Programmer - Karl Nyborg | Company Head - Brian Kramer

Order: 08

	NOT FOR FREE USE. FOR USE BY SUBSOAP ONLY OR WITH PROPER LICENSE.
	
	File: INI_Interface.bmx
	Purpose: Saving/Loading, Phrases INI Files for use inside of games and applications

'---------------------------------------------------------------------------------------------------
End Rem

Type INI_File
	'Global 
	
	Field Filename:String
	Field Groups:TList = CreateList()
	Field Items:TList = CreateList()
	
	'--------------------------------------------------------
	'#Region Methods
	
	'#Region Retrieve Data
	
	Method ItemExists:Int(Name:String, group:String = "")
		Local iItem:INI_Item = Null
		
		Name = Lower(Name) ; Group = Lower(Group)
		
		For iItem = EachIn Items
			If iItem.Name = name And iItem.Group = group Then
				Return 1
			EndIf
		Next
		
		Return 0
	End Method
	
	Method ItEx:Int(Name:String, group:String = "") 	' Just a short-hand version to
														' keep If statements shorter
		Return ItemExists(Name, Group)
	End Method
	
	Method GetString:String(name:String, group:String = "")
		Local iItem:INI_Item = Null
		
		Name = Lower(Name) ; Group = Lower(Group)
		
		If group = "" Then Print "Warning! Possible error, group is set to default."
		
		For iItem = EachIn Items
			If iItem.Name = name And iItem.Group = group Then
				Return iItem.Data
			EndIf
		Next
		Notify "While using '"+Self.Filename+"' | Could not find '" + Name + "' in '"+group+"'!"
		Return ""
	End Method
	
	Method GetFloat:Float(name:String, group:String = "")
		Local iItem:INI_Item = Null
		
		Name = Lower(Name) ; Group = Lower(Group)
		
		If group = "" Then Print "Warning! Possible error, group is set to default."
		
		For iItem = EachIn Items
			If iItem.Name = name And iItem.Group = group Then
				Return Float(iItem.Data)
			EndIf
		Next
		
		Notify "While using '"+Self.Filename+"' | Could not find '" + Name + "' in '"+group+"'!"
		Return 0.0
	End Method
	
	Method GetInteger:Int(name:String, group:String = "")
		Local iItem:INI_Item = Null
		
		Name = Lower(Name) ; Group = Lower(Group)
		
		If group = "" Then Print "Warning! Possible error, group is set to default."
		
		For iItem = EachIn Items
			If iItem.Name = name And iItem.Group = group Then
				Return Int(iItem.Data)
			EndIf
		Next
		
		Notify "While using '"+Self.Filename+"' | Could not find '" + Name + "' in '"+group+"'!"
		Return 0
	End Method
	'#End Region
	
	'#Region Editing Data
	Method ModifyItem(name:String, data:String, group:String = "")
		Local iItem:INI_Item = Null
		
		Name = Lower(Name) ; Group = Lower(Group)
		
		For iItem = EachIn Items
			If iItem.Name = name And iItem.Group Then
				iItem.Data = Data
			EndIf
		Next
	End Method
	
	Method AddItem:INI_Item(name:String, data:String, group:String = "")
		Local tmp:INI_Item = INI_Item.Create(name, data, group)
		Local tempStr:String
		Local NewGroup = True
		
		'We need to check if this item is being added to a new group.
		For tempStr = EachIn Groups
			If tempStr = Group Then NewGroup = False;Exit
		Next
		
		'If so, make a new group
		If NewGroup Then ListAddLast Groups, group
		
		ListAddLast Items, tmp
		Return tmp
	End Method
	'#End Region
	
	'#Region Setting Data
	Method Setup:INI_File(File:TStream)
		Local CurrentGroup:String = ""
		Local CurrentLine:String
		Local TempIndex:Int
		Local TempStr1:String, TempStr2:String
		ListAddLast Groups, String("")
		
		If _debug Then Print "INI_FILE: Setup Start"
		
		While Not Eof(File)
			CurrentLine = ReadLine(file)						'Read Next Item
			
			If Left(CurrentLine, 1) = "[" And Instr(CurrentLine, "]") Then 	' Check for new group
				CurrentGroup = Lower(Mid(CurrentLine, 2, (Len CurrentLine) - 2))
				Print "NEW GROUP: " + CurrentGroup
				ListAddLast Groups, CurrentGroup
			ElseIf Left(CurrentLine, 1) = ";" Then							' Check for comment
				CurrentLine = ReadLine(file)
				Continue
			EndIf
			
			If Instr(CurrentLine, ";")							' Check for comment past the start
				CurrentLine = Left(CurrentLine, Instr(CurrentLine, ";") - 1)
			EndIf
			
			If Instr(CurrentLine, " = ")						'Check for item
				TempIndex = Instr(CurrentLine, " = ")
				TempStr1 = Lower(Left(CurrentLine, TempIndex - 1))
				TempStr2 = Right(CurrentLine, CurrentLine.Length - (TempIndex + 2))
				ListAddLast Items, INI_Item.Create(TempStr1, TempStr2, CurrentGroup)
			ElseIf Instr(CurrentLine, "=")
				TempIndex = Instr(CurrentLine, "=")
				TempStr1 = Lower(Left(CurrentLine, TempIndex - 1))
				TempStr2 = Right(CurrentLine, CurrentLine.Length - TempIndex)
				ListAddLast Items, INI_Item.Create(TempStr1, TempStr2, CurrentGroup)
			End If
			
			'If Replace(CurrentLine," ","") = "" Then CurrenGroup = ""	' Should clear the current
			'					group when a space is encountered, I don't know if I want this yet.	
		Wend
		If _debug Then Print "INI_FILE: Setup End"
		Return Self
	End Method
	
	Method Save(Filename:String)
		Local SaveFile:TStream = OpenFile(Filename, 0, 1)
		
		For Group:String = EachIn Groups
			If Group <> "" Then
				WriteLine SaveFile, "";WriteLine SaveFile, "[" + Group + "]"
			EndIf
			
			For Item:INI_Item = EachIn Items
				If Item.Group = Group Then
					WriteLine SaveFile, Item.Name + " = " + Item.Data
				End If
			Next
		Next
		
		CloseStream SaveFile
		Return 0
	End Method
	'#End Region
	
	'#End Region
	'--------------------------------------------------------
	'#Region Functions
	Function Load:INI_File(filename:String)
		If _debug Then Print "INI_FILE: Ini_File.Load ( '" + filename + "' )"
		If filename =< 0 Then RuntimeError "ERROR :: INI_File.Load :: Was not given a proper filename!!"
		Local file:TStream = OpenFile(filename, 1, 0)
		If Not file Then RuntimeError "ERROR :: INI_File.Load :: Can not open '" + filename + "'!"
		If FileSize(filename) =< 0 Then RuntimeError "ERROR :: INI_File.Load :: File does not exist '"+SceneFilename+"'!"
		
		Local iFile:INI_File = New INI_File.Setup(file)
		iFile.Filename = StripDir(filename)
		
		'Notify "Succesfully Loaded "+iFile.Filename+" in memory!"
		
		CloseStream File
		Return iFile
	End Function
	'#End Region
End Type

Function LoadINI:INI_File(filename:String)
	Return INI_File.Load(filename:String)
End Function

Function CreateINI:INI_File(filename:String)
	Local iFile:INI_File = New INI_File
	' I don't know if there will be some sort of extra stuff later... so yeah.
	Return iFile
End Function

Type INI_Item
	Field Name:String, Data:String, Group:String
	
	Function Create:INI_Item(Name:String, Data:String, Group:String)
		Local tmp:INI_Item = New INI_Item
		
		tmp.Name = Name
		tmp.Data = Data
		tmp.Group = Group
		
		Return tmp
	End Function
End Type

Rem

''''''''''''''''''''''''''''''
'
'	INI Test
'
''''''''''''''''''''''''''''''

TestINI:INI_File = INI_File.Load("setup_edit_edit.ini")

For Group:String = EachIn TestINI.Groups
	Print "Group: '" + Group + "'"
Next

For Item:INI_Item = EachIn TestINI.Items
	Print "Item: '" + Item.Name + "' Data: '" + Item.Data + "' Group: '" + Item.Group + "'"
Next

TestINI.ModifyItem("musicvolume", "20", "audio")
Print
Print "Edited"
Print

For Group:String = EachIn TestINI.Groups
	Print "Group: '" + Group + "'"
Next

For Item:INI_Item = EachIn TestINI.Items
	Print "Item: '" + Item.Name + "' Data: '" + Item.Data + "' Group: '" + Item.Group + "'"
Next

TestINI.Save("setup_edit_edit.ini")

End Rem