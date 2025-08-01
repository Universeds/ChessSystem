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
	local castlingRights = fenParts[3] or "KQkq"
	local enPassant = fenParts[4] or "-"
	local halfmove = tonumber(fenParts[5]) or 0
	local fullmove = tonumber(fenParts[6]) or 1
	
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
	
	Board.ColourToMove = sideToMove == "w" and Piece.White or Piece.Black
	
	if not Board.CastlingRights then
		Board.CastlingRights = {}
	end
	Board.CastlingRights.WhiteKingside = string.find(castlingRights, "K") ~= nil
	Board.CastlingRights.WhiteQueenside = string.find(castlingRights, "Q") ~= nil
	Board.CastlingRights.BlackKingside = string.find(castlingRights, "k") ~= nil
	Board.CastlingRights.BlackQueenside = string.find(castlingRights, "q") ~= nil
	
	if enPassant == "-" then
		Board.EnPassantSquare = 0
	else
		local file = string.byte(enPassant:sub(1, 1)) - string.byte("a")
		local rank = tonumber(enPassant:sub(2, 2)) - 1
		Board.EnPassantSquare = Util.CoordsToIndex(file, rank)
	end
	
	Board.HalfmoveClock = halfmove
	Board.FullmoveNumber = fullmove
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
	
	local sideToMove = board.ColourToMove == Piece.White and "w" or "b"
	fen ..= " " .. sideToMove
	
	local castling = ""
	if board.CastlingRights.WhiteKingside then castling ..= "K" end
	if board.CastlingRights.WhiteQueenside then castling ..= "Q" end
	if board.CastlingRights.BlackKingside then castling ..= "k" end
	if board.CastlingRights.BlackQueenside then castling ..= "q" end
	if castling == "" then castling = "-" end
	fen ..= " " .. castling
	
	if board.EnPassantSquare == 0 then
		fen ..= " -"
	else
		local file, rank = Util.IndexToCoords(board.EnPassantSquare)
		local fileChar = string.char(string.byte("a") + file)
		fen ..= " " .. fileChar .. tostring(rank + 1)
	end
	
	fen ..= " " .. tostring(board.HalfmoveClock)
	fen ..= " " .. tostring(board.FullmoveNumber)
	
	return fen
end

function Util.IsColour(sqaureValue, colour)
	return bit32.band(sqaureValue, colour) ~= 0
end

function Util.GetPieceType(squareValue)
	return bit32.band(squareValue, 7)
end

function Util.IndexToCoords(index)
	local file = (index - 1) % 8
	local rank = math.floor((index - 1) / 8)
	return file, rank
end

function Util.CoordsToIndex(file, rank)
	return rank * 8 + file + 1
end

function Util.IsValidSquare(file, rank)
	return file >= 0 and file <= 7 and rank >= 0 and rank <= 7
end

function Util.FindKing(board, color)
	for i = 1, 64 do
		local piece = board.Square[i]
		if Util.GetPieceType(piece) == Piece.King and Util.IsColour(piece, color) then
			return i
		end
	end
	return 0
end

function Util.IsSquareAttacked(board, squareIndex, byColor)
	local file, rank = Util.IndexToCoords(squareIndex)
	
	local directions = {{0, 1}, {0, -1}, {1, 0}, {-1, 0}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
	for _, dir in ipairs(directions) do
		local f, r = file + dir[1], rank + dir[2]
		while Util.IsValidSquare(f, r) do
			local idx = Util.CoordsToIndex(f, r)
			local piece = board.Square[idx]
			if piece ~= Piece.None then
				if Util.IsColour(piece, byColor) then
					local pieceType = Util.GetPieceType(piece)
					if pieceType == Piece.Queen then
						return true
					elseif pieceType == Piece.Rook and (dir[1] == 0 or dir[2] == 0) then
						return true
					elseif pieceType == Piece.Bishop and (dir[1] ~= 0 and dir[2] ~= 0) then
						return true
					elseif pieceType == Piece.King and math.abs(f - file) <= 1 and math.abs(r - rank) <= 1 then
						return true
					end
				end
				break
			end
			f, r = f + dir[1], r + dir[2]
		end
	end
	
	local knightMoves = {{2, 1}, {2, -1}, {-2, 1}, {-2, -1}, {1, 2}, {1, -2}, {-1, 2}, {-1, -2}}
	for _, move in ipairs(knightMoves) do
		local f, r = file + move[1], rank + move[2]
		if Util.IsValidSquare(f, r) then
			local idx = Util.CoordsToIndex(f, r)
			local piece = board.Square[idx]
			if piece ~= Piece.None and Util.IsColour(piece, byColor) and Util.GetPieceType(piece) == Piece.Knight then
				return true
			end
		end
	end
	
	local pawnDir = byColor == Piece.White and 1 or -1
	for _, fileOffset in ipairs({-1, 1}) do
		local f, r = file + fileOffset, rank - pawnDir
		if Util.IsValidSquare(f, r) then
			local idx = Util.CoordsToIndex(f, r)
			local piece = board.Square[idx]
			if piece ~= Piece.None and Util.IsColour(piece, byColor) and Util.GetPieceType(piece) == Piece.Pawn then
				return true
			end
		end
	end
	
	return false
end

function Util.IsInCheck(board, color)
	local kingSquare = Util.FindKing(board, color)
	if kingSquare == 0 then
		return false
	end
	return Util.IsSquareAttacked(board, kingSquare, color == Piece.White and Piece.Black or Piece.White)
end

function Util.GetLegalMoves(board, fromIndex)
	local moves = {}
	local piece = board.Square[fromIndex]
	if piece == Piece.None then
		return moves
	end
	
	local pieceType = Util.GetPieceType(piece)
	local pieceColor = Util.IsColour(piece, Piece.White) and Piece.White or Piece.Black
	local fromFile, fromRank = Util.IndexToCoords(fromIndex)
	
	local pseudoMoves = {}
	
	if pieceType == Piece.Pawn then
		Util.GetPawnMoves(board, fromFile, fromRank, pieceColor, pseudoMoves)
	elseif pieceType == Piece.Rook then
		Util.GetRookMoves(board, fromFile, fromRank, pieceColor, pseudoMoves)
	elseif pieceType == Piece.Bishop then
		Util.GetBishopMoves(board, fromFile, fromRank, pieceColor, pseudoMoves)
	elseif pieceType == Piece.Queen then
		Util.GetQueenMoves(board, fromFile, fromRank, pieceColor, pseudoMoves)
	elseif pieceType == Piece.Knight then
		Util.GetKnightMoves(board, fromFile, fromRank, pieceColor, pseudoMoves)
	elseif pieceType == Piece.King then
		Util.GetKingMoves(board, fromFile, fromRank, pieceColor, pseudoMoves)
	end
	
	for _, move in ipairs(pseudoMoves) do
		if Util.IsLegalMove(board, fromIndex, move) then
			table.insert(moves, move)
		end
	end
	
	return moves
end

function Util.IsLegalMove(board, fromIndex, toIndex)
	local originalPiece = board.Square[toIndex]
	local movingPiece = board.Square[fromIndex]
	local pieceColor = Util.IsColour(movingPiece, Piece.White) and Piece.White or Piece.Black
	
	board.Square[toIndex] = movingPiece
	board.Square[fromIndex] = Piece.None
	
	local isLegal = not Util.IsInCheck(board, pieceColor)
	
	board.Square[fromIndex] = movingPiece
	board.Square[toIndex] = originalPiece
	
	return isLegal
end

function Util.GetPawnMoves(board, file, rank, color, moves)
	local direction = color == Piece.White and 1 or -1
	local startRank = color == Piece.White and 1 or 6
	
	local newRank = rank + direction
	if Util.IsValidSquare(file, newRank) then
		local targetIndex = Util.CoordsToIndex(file, newRank)
		if board.Square[targetIndex] == Piece.None then
			table.insert(moves, targetIndex)
			
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
	
	for _, fileOffset in ipairs({-1, 1}) do
		local newFile = file + fileOffset
		newRank = rank + direction
		if Util.IsValidSquare(newFile, newRank) then
			local targetIndex = Util.CoordsToIndex(newFile, newRank)
			local targetPiece = board.Square[targetIndex]
			if targetPiece ~= Piece.None and not Util.IsColour(targetPiece, color) then
				table.insert(moves, targetIndex)
			elseif targetIndex == board.EnPassantSquare then
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
				break
			else
				break
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
	
	if color == Piece.White then
		if board.CastlingRights.WhiteKingside and Util.CanCastleKingside(board, color) then
			table.insert(moves, Util.CoordsToIndex(6, 0))
		end
		if board.CastlingRights.WhiteQueenside and Util.CanCastleQueenside(board, color) then
			table.insert(moves, Util.CoordsToIndex(2, 0))
		end
	else
		if board.CastlingRights.BlackKingside and Util.CanCastleKingside(board, color) then
			table.insert(moves, Util.CoordsToIndex(6, 7))
		end
		if board.CastlingRights.BlackQueenside and Util.CanCastleQueenside(board, color) then
			table.insert(moves, Util.CoordsToIndex(2, 7))
		end
	end
end

function Util.CanCastleKingside(board, color)
	local rank = color == Piece.White and 0 or 7
	local kingSquare = Util.CoordsToIndex(4, rank)
	local rookSquare = Util.CoordsToIndex(7, rank)
	
	if board.Square[rookSquare] == Piece.None or Util.GetPieceType(board.Square[rookSquare]) ~= Piece.Rook then
		return false
	end
	
	if board.Square[Util.CoordsToIndex(5, rank)] ~= Piece.None or board.Square[Util.CoordsToIndex(6, rank)] ~= Piece.None then
		return false
	end
	
	local enemyColor = color == Piece.White and Piece.Black or Piece.White
	if Util.IsSquareAttacked(board, kingSquare, enemyColor) or
	   Util.IsSquareAttacked(board, Util.CoordsToIndex(5, rank), enemyColor) or
	   Util.IsSquareAttacked(board, Util.CoordsToIndex(6, rank), enemyColor) then
		return false
	end
	
	return true
end

function Util.CanCastleQueenside(board, color)
	local rank = color == Piece.White and 0 or 7
	local kingSquare = Util.CoordsToIndex(4, rank)
	local rookSquare = Util.CoordsToIndex(0, rank)
	
	if board.Square[rookSquare] == Piece.None or Util.GetPieceType(board.Square[rookSquare]) ~= Piece.Rook then
		return false
	end
	
	if board.Square[Util.CoordsToIndex(1, rank)] ~= Piece.None or 
	   board.Square[Util.CoordsToIndex(2, rank)] ~= Piece.None or 
	   board.Square[Util.CoordsToIndex(3, rank)] ~= Piece.None then
		return false
	end
	
	local enemyColor = color == Piece.White and Piece.Black or Piece.White
	if Util.IsSquareAttacked(board, kingSquare, enemyColor) or
	   Util.IsSquareAttacked(board, Util.CoordsToIndex(2, rank), enemyColor) or
	   Util.IsSquareAttacked(board, Util.CoordsToIndex(3, rank), enemyColor) then
		return false
	end
	
	return true
end

function Util.IsValidMove(board, fromIndex, toIndex)
	local legalMoves = Util.GetLegalMoves(board, fromIndex)
	for _, move in ipairs(legalMoves) do
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
	
	local movingPiece = board.Square[fromIndex]
	local capturedPiece = board.Square[toIndex]
	local pieceType = Util.GetPieceType(movingPiece)
	local pieceColor = Util.IsColour(movingPiece, Piece.White) and Piece.White or Piece.Black
	local fromFile, fromRank = Util.IndexToCoords(fromIndex)
	local toFile, toRank = Util.IndexToCoords(toIndex)
	
	board.EnPassantSquare = 0
	
	if pieceType == Piece.Pawn then
		if math.abs(toRank - fromRank) == 2 then
			board.EnPassantSquare = Util.CoordsToIndex(fromFile, fromRank + (pieceColor == Piece.White and 1 or -1))
		elseif toIndex == board.EnPassantSquare then
			local capturedPawnSquare = Util.CoordsToIndex(toFile, fromRank)
			board.Square[capturedPawnSquare] = Piece.None
		end
		
		if toRank == 0 or toRank == 7 then
			board.Square[toIndex] = bit32.bor(pieceColor, Piece.Queen)
		else
			board.Square[toIndex] = movingPiece
		end
		board.HalfmoveClock = 0
	elseif pieceType == Piece.King then
		if math.abs(toFile - fromFile) == 2 then
			if toFile == 6 then
				board.Square[Util.CoordsToIndex(5, toRank)] = board.Square[Util.CoordsToIndex(7, toRank)]
				board.Square[Util.CoordsToIndex(7, toRank)] = Piece.None
			else
				board.Square[Util.CoordsToIndex(3, toRank)] = board.Square[Util.CoordsToIndex(0, toRank)]
				board.Square[Util.CoordsToIndex(0, toRank)] = Piece.None
			end
		end
		
		if pieceColor == Piece.White then
			board.CastlingRights.WhiteKingside = false
			board.CastlingRights.WhiteQueenside = false
		else
			board.CastlingRights.BlackKingside = false
			board.CastlingRights.BlackQueenside = false
		end
		
		board.Square[toIndex] = movingPiece
		board.HalfmoveClock += 1
	else
		board.Square[toIndex] = movingPiece
		board.HalfmoveClock += 1
	end
	
	if pieceType == Piece.Rook then
		if pieceColor == Piece.White then
			if fromIndex == Util.CoordsToIndex(0, 0) then
				board.CastlingRights.WhiteQueenside = false
			elseif fromIndex == Util.CoordsToIndex(7, 0) then
				board.CastlingRights.WhiteKingside = false
			end
		else
			if fromIndex == Util.CoordsToIndex(0, 7) then
				board.CastlingRights.BlackQueenside = false
			elseif fromIndex == Util.CoordsToIndex(7, 7) then
				board.CastlingRights.BlackKingside = false
			end
		end
	end
	
	if capturedPiece ~= Piece.None then
		board.HalfmoveClock = 0
		
		if Util.GetPieceType(capturedPiece) == Piece.Rook then
			if toIndex == Util.CoordsToIndex(0, 0) then
				board.CastlingRights.WhiteQueenside = false
			elseif toIndex == Util.CoordsToIndex(7, 0) then
				board.CastlingRights.WhiteKingside = false
			elseif toIndex == Util.CoordsToIndex(0, 7) then
				board.CastlingRights.BlackQueenside = false
			elseif toIndex == Util.CoordsToIndex(7, 7) then
				board.CastlingRights.BlackKingside = false
			end
		end
	end
	
	board.Square[fromIndex] = Piece.None
	
	board.ColourToMove = board.ColourToMove == Piece.White and Piece.Black or Piece.White
	
	if board.ColourToMove == Piece.White then
		board.FullmoveNumber += 1
	end
	
	local enemyColor = board.ColourToMove
	local hasLegalMoves = false
	for i = 1, 64 do
		if board.Square[i] ~= Piece.None and Util.IsColour(board.Square[i], enemyColor) then
			local moves = Util.GetLegalMoves(board, i)
			if #moves > 0 then
				hasLegalMoves = true
				break
			end
		end
	end
	
	if not hasLegalMoves then
		if Util.IsInCheck(board, enemyColor) then
			board.GameState = pieceColor == Piece.White and "WhiteWins" or "BlackWins"
		else
			board.GameState = "Draw"
		end
	end
	
	return true
end

return Util
