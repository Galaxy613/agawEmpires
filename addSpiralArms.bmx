
'Framework brl.blitz
Import brl.standardio
Import brl.stream
Import brl.socket
Import brl.linkedlist
Import brl.glmax2d
Import "sfTCP.bmx"

curGame.gID = 613
If curGame.LoadFromFile()
	TPrint "[INFO] Found map! Adding arms.."
	
	curGame.CreateSpiralArm(0, 5, 15, 1, 37)
	curGame.CreateSpiralArm(90, 5, 15, 1, 37)
	curGame.CreateSpiralArm(180, 5, 15, 1, 37)
	curGame.CreateSpiralArm(-90, 5, 15, 1, 37)
	
	curGame.CreateSpiralArm(0 + 45, 14, 15, 1.5, 47)
	curGame.CreateSpiralArm(90 + 45, 11, 15, 1.5, 47)
	curGame.CreateSpiralArm(180 + 45, 14, 15, 1.5, 47)
	curGame.CreateSpiralArm((-90) + 45, 11, 15, 1.5, 47)
	
	curGame.SaveToFile()

EndIf