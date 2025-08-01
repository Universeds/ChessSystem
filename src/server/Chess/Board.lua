local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:FindFirstChild("Shared")

local Util = require(Shared.ChessUtil)
local Piece = require(Shared.Piece)

local StandardPosition = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
local Board = {}
Board.__index = Board

function Board.new()
	local self = setmetatable({}, Board)

	self.Square = table.create(64, 0)
	self.ColourToMove = Piece.White
	self.FEN = StandardPosition
	self.CastlingRights = {
		WhiteKingside = true,
		WhiteQueenside = true,
		BlackKingside = true,
		BlackQueenside = true
	}
	self.EnPassantSquare = 0
	self.HalfmoveClock = 0
	self.FullmoveNumber = 1
	self.GameState = "Playing"

	Util.LoadPositionFromFen(self, self.FEN)
	return self
end

function Board:GetFEN()
	return self.FEN
end

function Board:MakeMove(fromIndex, toIndex)
	if not Util.IsValidMove(self, fromIndex, toIndex) then
		return false
	end
	
	-- Check if it's the correct player's turn
	local piece = self.Square[fromIndex]
	local pieceColor = Util.IsColour(piece, Piece.White) and Piece.White or Piece.Black
	
	if pieceColor ~= self.ColourToMove then
		return false
	end
	
	-- Make the move
	local success = Util.MakeMove(self, fromIndex, toIndex)
	if success then
		-- Update FEN
		self.FEN = Util.GenerateFENFromPosition(self)
	end
	
	return success
end

function Board:IsValidMove(fromIndex, toIndex)
	local piece = self.Square[fromIndex]
	if piece == Piece.None then
		return false
	end
	
	local pieceColor = Util.IsColour(piece, Piece.White) and Piece.White or Piece.Black
	if pieceColor ~= self.ColourToMove then
		return false
	end
	
	return Util.IsValidMove(self, fromIndex, toIndex)
end

function Board:GetLegalMoves(fromIndex)
	return Util.GetLegalMoves(self, fromIndex)
end

function Board:IsInCheck(color)
	return Util.IsInCheck(self, color or self.ColourToMove)
end

function Board:GetGameState()
	return self.GameState
end

function Board:IsGameOver()
	return self.GameState ~= "Playing"
end

function Board:GetWinner()
	if self.GameState == "WhiteWins" then
		return Piece.White
	elseif self.GameState == "BlackWins" then
		return Piece.Black
	else
		return nil
	end
end

function Board:IsDraw()
	return self.GameState == "Draw"
end

function Board:CanCastle(color, side)
	if color == Piece.White then
		if side == "kingside" then
			return self.CastlingRights.WhiteKingside and Util.CanCastleKingside(self, color)
		else
			return self.CastlingRights.WhiteQueenside and Util.CanCastleQueenside(self, color)
		end
	else
		if side == "kingside" then
			return self.CastlingRights.BlackKingside and Util.CanCastleKingside(self, color)
		else
			return self.CastlingRights.BlackQueenside and Util.CanCastleQueenside(self, color)
		end
	end
end

return Board
