local Piece = require(script.Parent.Piece)
local Util = {}

local pieceTypeFromSymbol = {
	k = Piece.King;
	p = Piece.Pawn;
	n = Piece.Knight;
	b = Piece.Bishop;
	r = Piece.Rook;
	q = Piece.Queen;
}

local symbolFromPieceType = {
	[Piece.King] = "k";
	[Piece.Pawn] = "p";
	[Piece.Knight] = "n";
	[Piece.Bishop] = "b";
	[Piece.Rook] = "r";
	[Piece.Queen] = "q";
}

function Util.LoadPositionFromFen(Board, fen : string)
	local fenParts = string.split(fen, " ")
	local fenBoard = fenParts[1]
	local sideToMove = fenParts[2] or "w"
	
	-- Clear the board first
	for i = 1, 64 do
		Board.Square[i] = Piece.None
	end
	
	local file = 0
	local rank = 7
	
	for i = 1, #fenBoard do
		local symbol = fenBoard:sub(i, i)
		
		if symbol == "/" then
			file = 0
			rank -= 1
		else
			local num = tonumber(symbol)
			if num then	
				file += num
			else
				local isUpper = symbol:upper() == symbol
				local pieceColor = isUpper and Piece.White or Piece.Black
				local pieceType = pieceTypeFromSymbol[symbol:lower()]
				local index = rank * 8 + file + 1
				Board.Square[index] = bit32.bor(pieceColor, pieceType)
				file += 1
			end
		end
	end
	
	-- Set the side to move
	Board.ColourToMove = sideToMove == "w" and Piece.White or Piece.Black
end

function Util.GenerateFENFromPosition(board)
	local fen = ""
	for rank = 7, 0, -1 do
		local empty = 0
		for file = 0, 7 do
			local index = rank * 8 + file + 1
			local piece = board.Square[index]
			if piece == Piece.None then
				empty += 1
			else
				if empty > 0 then
					fen ..= tostring(empty)
					empty = 0
				end
				local symbol = symbolFromPieceType[Util.GetPieceType(piece)]
				if Util.IsColour(piece, Piece.White) then
					symbol = string.upper(symbol)
				end
				fen ..= symbol
			end
		end
		if empty > 0 then
			fen ..= tostring(empty)
		end
		if rank > 0 then
			fen ..= "/"
		end
	end
	-- Add side to move, castling, en passant, halfmove, fullmove
	local sideToMove = board.ColourToMove == Piece.White and "w" or "b"
	fen ..= " " .. sideToMove .. " KQkq - 0 1"
	return fen
end


function Util.IsColour(sqaureValue, colour)
	return bit32.band(sqaureValue, colour) ~= 0
end

function Util.GetPieceType(squareValue)
	return bit32.band(squareValue, 7)
end

function Util.IndexToCoords(index)
	-- Convert 1-based index to file (0-7) and rank (0-7)
	local file = (index - 1) % 8
	local rank = math.floor((index - 1) / 8)
	return file, rank
end

function Util.CoordsToIndex(file, rank)
	-- Convert file (0-7) and rank (0-7) to 1-based index
	return rank * 8 + file + 1
end

function Util.IsValidSquare(file, rank)
	return file >= 0 and file <= 7 and rank >= 0 and rank <= 7
end

function Util.GetPossibleMoves(board, fromIndex)
	local moves = {}
	local piece = board.Square[fromIndex]
	if piece == Piece.None then
		return moves
	end
	
	local pieceType = Util.GetPieceType(piece)
	local pieceColor = Util.IsColour(piece, Piece.White) and Piece.White or Piece.Black
	local fromFile, fromRank = Util.IndexToCoords(fromIndex)
	
	if pieceType == Piece.Pawn then
		Util.GetPawnMoves(board, fromFile, fromRank, pieceColor, moves)
	elseif pieceType == Piece.Rook then
		Util.GetRookMoves(board, fromFile, fromRank, pieceColor, moves)
	elseif pieceType == Piece.Bishop then
		Util.GetBishopMoves(board, fromFile, fromRank, pieceColor, moves)
	elseif pieceType == Piece.Queen then
		Util.GetQueenMoves(board, fromFile, fromRank, pieceColor, moves)
	elseif pieceType == Piece.Knight then
		Util.GetKnightMoves(board, fromFile, fromRank, pieceColor, moves)
	elseif pieceType == Piece.King then
		Util.GetKingMoves(board, fromFile, fromRank, pieceColor, moves)
	end
	
	return moves
end

function Util.GetPawnMoves(board, file, rank, color, moves)
	local direction = color == Piece.White and 1 or -1
	local startRank = color == Piece.White and 1 or 6
	
	-- Move forward one square
	local newRank = rank + direction
	if Util.IsValidSquare(file, newRank) then
		local targetIndex = Util.CoordsToIndex(file, newRank)
		if board.Square[targetIndex] == Piece.None then
			table.insert(moves, targetIndex)
			
			-- Move forward two squares from starting position
			if rank == startRank then
				newRank = rank + (2 * direction)
				if Util.IsValidSquare(file, newRank) then
					targetIndex = Util.CoordsToIndex(file, newRank)
					if board.Square[targetIndex] == Piece.None then
						table.insert(moves, targetIndex)
					end
				end
			end
		end
	end
	
	-- Capture diagonally
	for _, fileOffset in ipairs({-1, 1}) do
		local newFile = file + fileOffset
		newRank = rank + direction
		if Util.IsValidSquare(newFile, newRank) then
			local targetIndex = Util.CoordsToIndex(newFile, newRank)
			local targetPiece = board.Square[targetIndex]
			if targetPiece ~= Piece.None and not Util.IsColour(targetPiece, color) then
				table.insert(moves, targetIndex)
			end
		end
	end
end

function Util.GetRookMoves(board, file, rank, color, moves)
	local directions = {{0, 1}, {0, -1}, {1, 0}, {-1, 0}}
	Util.GetSlidingMoves(board, file, rank, color, directions, moves)
end

function Util.GetBishopMoves(board, file, rank, color, moves)
	local directions = {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
	Util.GetSlidingMoves(board, file, rank, color, directions, moves)
end

function Util.GetQueenMoves(board, file, rank, color, moves)
	local directions = {{0, 1}, {0, -1}, {1, 0}, {-1, 0}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
	Util.GetSlidingMoves(board, file, rank, color, directions, moves)
end

function Util.GetSlidingMoves(board, file, rank, color, directions, moves)
	for _, direction in ipairs(directions) do
		local fileDir, rankDir = direction[1], direction[2]
		local newFile, newRank = file + fileDir, rank + rankDir
		
		while Util.IsValidSquare(newFile, newRank) do
			local targetIndex = Util.CoordsToIndex(newFile, newRank)
			local targetPiece = board.Square[targetIndex]
			
			if targetPiece == Piece.None then
				table.insert(moves, targetIndex)
			elseif not Util.IsColour(targetPiece, color) then
				table.insert(moves, targetIndex)
				break -- Can't move past a piece
			else
				break -- Can't move past own piece
			end
			
			newFile, newRank = newFile + fileDir, newRank + rankDir
		end
	end
end

function Util.GetKnightMoves(board, file, rank, color, moves)
	local knightMoves = {{2, 1}, {2, -1}, {-2, 1}, {-2, -1}, {1, 2}, {1, -2}, {-1, 2}, {-1, -2}}
	
	for _, move in ipairs(knightMoves) do
		local newFile, newRank = file + move[1], rank + move[2]
		if Util.IsValidSquare(newFile, newRank) then
			local targetIndex = Util.CoordsToIndex(newFile, newRank)
			local targetPiece = board.Square[targetIndex]
			if targetPiece == Piece.None or not Util.IsColour(targetPiece, color) then
				table.insert(moves, targetIndex)
			end
		end
	end
end

function Util.GetKingMoves(board, file, rank, color, moves)
	local kingMoves = {{0, 1}, {0, -1}, {1, 0}, {-1, 0}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
	
	for _, move in ipairs(kingMoves) do
		local newFile, newRank = file + move[1], rank + move[2]
		if Util.IsValidSquare(newFile, newRank) then
			local targetIndex = Util.CoordsToIndex(newFile, newRank)
			local targetPiece = board.Square[targetIndex]
			if targetPiece == Piece.None or not Util.IsColour(targetPiece, color) then
				table.insert(moves, targetIndex)
			end
		end
	end
end

function Util.IsValidMove(board, fromIndex, toIndex)
	local possibleMoves = Util.GetPossibleMoves(board, fromIndex)
	for _, move in ipairs(possibleMoves) do
		if move == toIndex then
			return true
		end
	end
	return false
end

function Util.MakeMove(board, fromIndex, toIndex)
	if not Util.IsValidMove(board, fromIndex, toIndex) then
		return false
	end
	
	-- Make the move
	board.Square[toIndex] = board.Square[fromIndex]
	board.Square[fromIndex] = Piece.None
	
	-- Toggle the color to move
	board.ColourToMove = board.ColourToMove == Piece.White and Piece.Black or Piece.White
	
	return true
end

return Util
