local Players = game:GetService("Players")

local Chess = require(script.Chess)

-- Initialize the chess system
Chess.init()

-- Wait until exactly 2 players have joined
while #Players:GetPlayers() < 2 do
	task.wait(2)
	print("waiting")
end

Chess.Start(Players:GetPlayers()[1], Players:GetPlayers()[2])
