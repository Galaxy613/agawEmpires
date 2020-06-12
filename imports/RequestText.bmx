Import maxgui.Drivers
'Import maxgui.proxyGadgets
?Win32
Import maxgui.win32maxguiex
?MacOS
Import maxgui.CocoaMaxGui
?Linux
Import MaxGui.FLTKMaxGui
?

Function RequestText:String(titleText:String, questionText:String, defaultTxt:String = "", doesGameHideMouse = False, passwordField = False)
	Local rWindow:TGadget = CreateWindow(titleText,64,64,350,125,Null,WINDOW_TITLEBAR|WINDOW_CENTER)
	CreateLabel(questionText,8,8,325,16,rWindow)
	Local rTextfield:TGadget = CreateTextField(8, 8 + 24, 325, 24, rWindow, passwordField)
	Local rOkButton:TGadget = CreateButton("Ok",325-200-8,32+32,100,24,rWindow)
	Local rCancelButton:TGadget = CreateButton("Cancel",325-100,32+32,100,24,rWindow)
	
	rTextfield.SetText defaultTxt
	
	ActivateWindow rWindow
	If doesGameHideMouse Then ShowMouse
	
	While Not AppTerminate( ) 
	    WaitEvent()
	'	If CurrentEvent.id = EVENT_GADGETLOSTFOCUS
	'		Print CurrentEvent.ToString()
	'		If CurrentEvent.source Then Print "Source: " + (TGadget(CurrentEvent.source)).ToString()
	'		If CurrentEvent.extra Then Print "Extra Object Available"
	'	End If
			
		Select CurrentEvent.id
			Case EVENT_WINDOWCLOSE, EVENT_APPTERMINATE
				rTextfield.SetText defaultTxt
				Exit
			Case EVENT_GADGETACTION
				If CurrentEvent.source = rOkButton Then
					Exit
				ElseIf CurrentEvent.source = rCancelButton
					rTextfield.SetText defaultTxt
					Exit
				End If
	'		Case EVENT_GADGETLOSTFOCUS
	'			ActivateWindow rWindow
		End Select
	Wend
	
	Local returnText$ = rTextfield.GetText()
	
	HideGadget rWindow
	FreeGadget rWindow
	If doesGameHideMouse Then HideMouse
	
	Return returnText
End Function