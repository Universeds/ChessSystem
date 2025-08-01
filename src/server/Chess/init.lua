local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChessUtil = require(ReplicatedStorage.Shared.ChessUtil)
local Piece = require(ReplicatedStorage.Shared.Piece)

local Shared = ReplicatedStorage:FindFirstChild("Shared")
local Remotes = Shared:FindFirstChild("Remotes")

local Board = require(script.Board)

local StartGameRemote = Remotes:FindFirstChild("StartChessGame")
local EndGameRemote = Remotes:FindFirstChild("EndChessGame")
local GetDataRemote = Remotes:FindFirstChild("GetChessData")
local MakeMoveRemote = Remotes:FindFirstChild("MakeMove")
local UpdateBoardRemote = Remotes:FindFirstChild("UpdateBoard")

local Chess = {}
Chess.ActiveGames = {}

function Chess.init()
	MakeMoveRemote.OnServerEvent:Connect(Chess.HandleMoveRequest)
end

function Chess.Start(player1, player2)
	local board = Board.new()
	
	Chess.ActiveGames[player1.UserId] = { opponent = player2, board = board, Colour = Piece.White }
	Chess.ActiveGames[player2.UserId] = { opponent = player1, board = board, Colour = Piece.Black }
	print("Started")
	

	StartGameRemote:FireClient(player1, player2, Piece.White)
	StartGameRemote:FireClient(player2, player1, Piece.Black)
end

function Chess.End(player)
	local activeGame = Chess.ActiveGames[player.UserId]
	if activeGame then
		local opponent = activeGame.opponent
		Chess.ActiveGames[player.UserId] = nil
		EndGameRemote:FireClient(player)
		if opponent then
			EndGameRemote:FireClient(opponent)
			Chess.ActiveGames[opponent.UserId] = nil
		end
	end
end

function Chess.GetFEN(player)
	local activeGame = Chess.ActiveGames[player.UserId]
	if activeGame and activeGame.board then
		return activeGame.board:GetFEN()
	end
	return nil
end

function Chess.HandleMoveRequest(player, fromIndex, toIndex)
	local activeGame = Chess.ActiveGames[player.UserId]
	if not activeGame then
		print("Player", player.Name, "is not in an active game")
		return
	end
	
	local board = activeGame.board
	local opponent = activeGame.opponent
	
	-- Validate and make the move on the server
	local success = board:MakeMove(fromIndex, toIndex)
	
	if success then
		-- Move was valid, send updated FEN to both players
		local newFEN = board:GetFEN()
		print("Move successful! New FEN:", newFEN)
		
		if UpdateBoardRemote then
			UpdateBoardRemote:FireClient(player, newFEN)
			if opponent then
				UpdateBoardRemote:FireClient(opponent, newFEN)
			end
		end
	else
		print("Invalid move attempted by", player.Name, "from", fromIndex, "to", toIndex)
	end
end

return Chess
