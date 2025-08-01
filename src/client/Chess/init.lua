local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Assets = ReplicatedStorage:FindFirstChild("Assets")
local Shared = ReplicatedStorage:FindFirstChild("Shared")
local Remotes = Shared:FindFirstChild("Remotes")

local ChessBoardGUI = Assets:FindFirstChild("ChessBoardGui")
local Pieces = Assets:FindFirstChild("Pieces")
local Sounds = Assets:FindFirstChild("Sounds")

local Piece = require(ReplicatedStorage.Shared.Piece)
local Util = require(ReplicatedStorage.Shared.ChessUtil)

local StartGameRemote = Remotes:FindFirstChild("StartChessGame")
local EndGameRemote = Remotes:FindFirstChild("EndChessGame")
local GetDataRemote = Remotes:FindFirstChild("GetChessData")
local MakeMoveRemote = Remotes:FindFirstChild("MakeMove")
local UpdateBoardRemote = Remotes:FindFirstChild("UpdateBoard")

local Chess = {}

-- Game state variables
Chess.CurrentBoard = nil
Chess.CurrentBoardGUI = nil
Chess.PlayerColor = nil
Chess.SelectedSquare = nil
Chess.HighlightedMoves = {}
Chess.CurrentFEN = nil
Chess.LastMove = nil

local StandardPosition = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

local PieceNames = {
	[Piece.King] = "king",
	[Piece.Queen] = "queen",
	[Piece.Rook] = "rook",
	[Piece.Bishop] = "bishop",
	[Piece.Knight] = "knight",
	[Piece.Pawn] = "pawn"
}

-- Store connections to prevent duplicates
Chess.Connections = {}

function Chess.init()
	Chess.Connections.Start = StartGameRemote.OnClientEvent:Connect(Chess.Start)
	Chess.Connections.Stop = EndGameRemote.OnClientEvent:Connect(Chess.Stop)
	Chess.Connections.Update = UpdateBoardRemote.OnClientEvent:Connect(Chess.UpdateBoard)
end

function Chess.Start(Opponent, PieceColor)
	-- Remove any existing chess board
	if Chess.CurrentBoardGUI and Chess.CurrentBoardGUI.Parent and Chess.CurrentBoardGUI.Parent.Parent then
		Chess.CurrentBoardGUI.Parent:Destroy()
	end
	
	local ScreenBoardGui = ChessBoardGUI:Clone()
	local BoardGUI = ScreenBoardGui.Board
	local UIGridLayout = BoardGUI.UIGridLayout
	ScreenBoardGui.Parent = player.PlayerGui
	
	-- Store game state
	Chess.CurrentBoardGUI = BoardGUI
	Chess.PlayerColor = PieceColor
	Chess.CurrentFEN = StandardPosition
	Chess.CurrentBoard = {
		Square = table.create(64, 0),
		ColourToMove = Piece.White,
		CastlingRights = {
			WhiteKingside = true,
			WhiteQueenside = true,
			BlackKingside = true,
			BlackQueenside = true
		},
		EnPassantSquare = 0,
		HalfmoveClock = 0,
		FullmoveNumber = 1,
		GameState = "Playing"
	}
	
	if PieceColor == Piece.White then
		UIGridLayout.StartCorner = Enum.StartCorner.BottomLeft
	end
	
	Chess.RenderFENToGUI(BoardGUI, StandardPosition)
	Chess.SetupSquareConnections(BoardGUI)
end

function Chess.RenderFENToGUI(BoardFrame, fen)
	local board = {
		Square = table.create(64, 0),
		ColourToMove = Piece.White,
		CastlingRights = {
			WhiteKingside = true,
			WhiteQueenside = true,
			BlackKingside = true,
			BlackQueenside = true
		},
		EnPassantSquare = 0,
		HalfmoveClock = 0,
		FullmoveNumber = 1,
		GameState = "Playing"
	}
	
	Util.LoadPositionFromFen(board, fen)

	for index = 1, 64 do
		local squareFrame = BoardFrame:FindFirstChild(index)
		local value = board.Square[index]
		local pieceType = Util.GetPieceType(value)
		local pieceColor = Util.IsColour(value, Piece.White) and "White" or (Util.IsColour(value, Piece.Black) and "Black" or nil)
		
		if squareFrame:FindFirstChild("Piece") then
			squareFrame.Piece:Destroy()
		end
		
		if squareFrame:FindFirstChild("LastMoveHighlight") then
			squareFrame.LastMoveHighlight:Destroy()
		end
		
		if pieceType ~= Piece.None and pieceColor then
			local colorName = pieceColor == "White" and "white" or "black"
			local pieceName = PieceNames[pieceType]
			local decalName = colorName .. "-" .. pieceName
			local decal = Pieces:FindFirstChild(decalName)
			
			if decal then
				local pieceImage = Instance.new("ImageLabel")
				pieceImage.Size = UDim2.fromScale(1, 1)
				pieceImage.BackgroundTransparency = 1
				pieceImage.Image = decal.Texture
				pieceImage.Name = "Piece"
				pieceImage.Parent = squareFrame
			end
		end
	end
	
	Chess.HighlightLastMove()
end

function Chess.HighlightLastMove()
	if not Chess.LastMove or not Chess.CurrentBoardGUI then
		return
	end
	
	local fromSquare = Chess.CurrentBoardGUI:FindFirstChild(Chess.LastMove.from)
	local toSquare = Chess.CurrentBoardGUI:FindFirstChild(Chess.LastMove.to)
	
	if fromSquare then
		local highlight = Instance.new("Frame")
		highlight.Size = UDim2.fromScale(1, 1)
		highlight.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
		highlight.BackgroundTransparency = 0.8
		highlight.Name = "LastMoveHighlight"
		highlight.ZIndex = 3
		highlight.Parent = fromSquare
	end
end


function Chess.SetupSquareConnections(BoardFrame)
	for index = 1, 64 do
		local squareFrame = BoardFrame:FindFirstChild(index)
		if squareFrame then
			local button = Instance.new("TextButton")
			button.Size = UDim2.fromScale(1, 1)
			button.BackgroundTransparency = 1
			button.Text = ""
			button.Name = "ClickDetector"
			button.ZIndex = 10
			button.Parent = squareFrame
			
			button.MouseButton1Click:Connect(function()
				Chess.OnSquareClicked(index)
			end)
		else
			print("Could not find square frame for index:", index)
		end
	end
end

function Chess.OnSquareClicked(squareIndex)
	print("Square clicked:", squareIndex)
	
	if not Chess.CurrentBoard or not Chess.CurrentBoardGUI then
		print("No current board or GUI")
		return
	end
	
	-- Update current board state from FEN
	Util.LoadPositionFromFen(Chess.CurrentBoard, Chess.CurrentFEN)
	
	local piece = Chess.CurrentBoard.Square[squareIndex]
	local isPlayerPiece = piece ~= Piece.None and Util.IsColour(piece, Chess.PlayerColor)
	
	print("Piece at square:", piece, "Player piece:", isPlayerPiece, "Player color:", Chess.PlayerColor, "Current turn:", Chess.CurrentBoard.ColourToMove)
	
	-- If no piece is selected and clicked on player's piece, select it
	if not Chess.SelectedSquare and isPlayerPiece then
		-- Check if it's the player's turn
		if Chess.CurrentBoard.ColourToMove == Chess.PlayerColor then
			print("Selecting piece at square:", squareIndex)
			Chess.SelectedSquare = squareIndex
			Chess.HighlightPossibleMoves(squareIndex)
		else
			print("Not your turn!")
		end
	-- If piece is selected and clicked on different square, try to move
	elseif Chess.SelectedSquare then
		if Chess.SelectedSquare == squareIndex then
			-- Clicked same square, deselect
			print("Deselecting piece")
			Chess.ClearSelection()
		else
			-- Try to make a move
			print("Attempting move from", Chess.SelectedSquare, "to", squareIndex)
			Chess.AttemptMove(Chess.SelectedSquare, squareIndex)
		end
	else
		print("No piece selected and clicked square is not a player piece")
	end
end

function Chess.HighlightPossibleMoves(fromIndex)
	Chess.ClearHighlights()
	
	local possibleMoves = Util.GetLegalMoves(Chess.CurrentBoard, fromIndex)
	print("Highlighting moves for square", fromIndex, "- Found", #possibleMoves, "possible moves")
	
	for _, moveIndex in ipairs(possibleMoves) do
		local squareFrame = Chess.CurrentBoardGUI:FindFirstChild(moveIndex)
		if squareFrame then
			local highlight = Instance.new("Frame")
			highlight.Size = UDim2.fromScale(1, 1)
			highlight.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
			highlight.BackgroundTransparency = 0.7
			highlight.Name = "MoveHighlight"
			highlight.ZIndex = 5
			highlight.Parent = squareFrame
			
			table.insert(Chess.HighlightedMoves, highlight)
		else
			print("Could not find square frame for move index:", moveIndex)
		end
	end
	
	-- Highlight selected square
	local selectedFrame = Chess.CurrentBoardGUI:FindFirstChild(fromIndex)
	if selectedFrame then
		local selectedHighlight = Instance.new("Frame")
		selectedHighlight.Size = UDim2.fromScale(1, 1)
		selectedHighlight.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
		selectedHighlight.BackgroundTransparency = 0.7
		selectedHighlight.Name = "SelectedHighlight"
		selectedHighlight.ZIndex = 5
		selectedHighlight.Parent = selectedFrame
		
		table.insert(Chess.HighlightedMoves, selectedHighlight)
	else
		print("Could not find selected square frame for index:", fromIndex)
	end
end

function Chess.ClearHighlights()
	for _, highlight in ipairs(Chess.HighlightedMoves) do
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end
	Chess.HighlightedMoves = {}
end

function Chess.ClearSelection()
	Chess.SelectedSquare = nil
	Chess.ClearHighlights()
end

function Chess.PlaySound(soundName)
	if not Sounds then
		return
	end
	
	local sound = Sounds:FindFirstChild(soundName)
	if sound then
		sound:Play()
	end
end

function Chess.AttemptMove(fromIndex, toIndex)
	-- Validate move locally first
	if not Util.IsValidMove(Chess.CurrentBoard, fromIndex, toIndex) then
		print("Invalid move attempted locally")
		Chess.ClearSelection()
		return
	end
	
	-- Store the last move for highlighting
	Chess.LastMove = {
		from = fromIndex,
		to = toIndex
	}
	
	-- Send move to server for verification
	MakeMoveRemote:FireServer(fromIndex, toIndex)
	Chess.ClearSelection()
end

function Chess.UpdateBoard(newFEN)
	if Chess.CurrentBoardGUI then
		local oldFEN = Chess.CurrentFEN
		Chess.CurrentFEN = newFEN
		
		if Chess.LastMove and oldFEN then
			Chess.PlayMoveSound(oldFEN, newFEN)
		end
		
		Chess.RenderFENToGUI(Chess.CurrentBoardGUI, newFEN)
		Chess.ClearSelection()
		print("Board updated with FEN:", newFEN)
	end
end

function Chess.PlayMoveSound(oldFEN, newFEN)
	if not Chess.LastMove then
		return
	end
	
	local oldBoard = {
		Square = table.create(64, 0),
		ColourToMove = Piece.White,
		CastlingRights = {WhiteKingside = true, WhiteQueenside = true, BlackKingside = true, BlackQueenside = true},
		EnPassantSquare = 0, HalfmoveClock = 0, FullmoveNumber = 1, GameState = "Playing"
	}
	local newBoard = {
		Square = table.create(64, 0),
		ColourToMove = Piece.White,
		CastlingRights = {WhiteKingside = true, WhiteQueenside = true, BlackKingside = true, BlackQueenside = true},
		EnPassantSquare = 0, HalfmoveClock = 0, FullmoveNumber = 1, GameState = "Playing"
	}
	
	Util.LoadPositionFromFen(oldBoard, oldFEN)
	Util.LoadPositionFromFen(newBoard, newFEN)
	
	local fromIndex = Chess.LastMove.from
	local toIndex = Chess.LastMove.to
	local movingPiece = oldBoard.Square[fromIndex]
	local capturedPiece = oldBoard.Square[toIndex]
	local pieceType = Util.GetPieceType(movingPiece)
	local pieceColor = Util.IsColour(movingPiece, Piece.White) and Piece.White or Piece.Black
	local fromFile, fromRank = Util.IndexToCoords(fromIndex)
	local toFile, toRank = Util.IndexToCoords(toIndex)
	
	local soundToPlay = "move"
	
	if pieceType == Piece.King and math.abs(toFile - fromFile) == 2 then
		soundToPlay = "castle"
	elseif pieceType == Piece.Pawn and (toRank == 0 or toRank == 7) then
		soundToPlay = "promote"
	elseif capturedPiece ~= Piece.None then
		soundToPlay = "capture"
	end
	
	if Util.IsInCheck(newBoard, newBoard.ColourToMove) then
		soundToPlay = "move-check"
	end
	
	Chess.PlaySound(soundToPlay)
end

function Chess.GetData()

end

function Chess.Stop()
	if Chess.CurrentBoardGUI and Chess.CurrentBoardGUI.Parent then
		Chess.CurrentBoardGUI.Parent:Destroy()
	end
	Chess.ClearSelection()
	Chess.CurrentBoard = nil
	Chess.CurrentBoardGUI = nil
	Chess.PlayerColor = nil
	Chess.CurrentFEN = nil
end

return Chess
