module Crusher where
-- CPSC 312 - Project 2
-- by Khurram Ali Jaffery

-- Main Components:
-- minimax algorithm
-- a board evaluator
-- state search
-- movement generators (and by extension, tree generator, new state generator)
-- crusher
-- custom data types (already done)

-- Piece is a data representation of possible pieces on a board
-- where D is an empty spot on the board
--		 W is a piece of the White player
--		 B is a piece of the Black player
--

data Piece = D | W | B deriving (Eq, Show)

--
-- Point is a tuple of 2 elements
-- representing a point on a grid system
-- where the first element represents the x coordinate
-- the second element represents the y coordinate
--

type Point = (Int, Int)

--
-- Tile is a tuple of 2 elements
-- representing what a point is occupied by
-- where the first element represents a piece
-- the second element represents a point
--

type Tile  = (Piece, Point)

--
-- Board is a list of Pieces, thus it is an internal representation
-- of the provided string representation of the board, it maintains
-- the same order as the string representation of the board
--

type Board = [Piece]

--
-- Grid is a list of Points, thus it is an internal representation
-- of the hexagonal grid system translated into a coordinate
-- system to easily maintain and make moves on the board
--

type Grid = [Point]

--
-- State is a list of Tile, thus it is an internal representation precisely
-- for the purposes of zipping the board and the grid together in order
-- to keep easier track of the effects on the pieces of making moves on grid
--

type State = [Tile]

--
-- Next is a data representation for storing and passing around information within
-- the tree generating function, allowing it to correctly generate new children
--
-- Next consists of 4 elements
-- where usedDepth is an integer reprsenting the current depth level
--		 newBoard is the next board to add to the tree
-- 		 seenBoards is the updated history to avoid possible future trouble boards
-- 		 cplayer is the current player for whom the board was generated for
--

data Next a = Next {usedDepth :: Int, newBoard :: a, seenBoards :: [a], cplayer :: Piece}

--
-- Tree is a data representation for the search tree, it is an extention of
-- the rose tree widely used for implementing such unequally branched search trees
--
-- Tree consists of 3 elements
-- where depth is an integer representing the depth level of the node
-- 		 board is the game state at that node
-- 		 nextBoards are the child nodes of the current node
--

data Tree a = Node {depth :: Int, board :: a, nextBoards :: [Tree a]} deriving (Show)

--
-- BoardTree is the internal representation of the search tree of the given board
-- that is to be generatated for correctly implementing the minimax algorithm.
--

type BoardTree = Tree Board

--
-- Slide is a tuple of 2 elements
-- an internal representation of a slide
-- where the first element represents the point to move from
-- 		 the second element represents the adjacent point to move to
--

type Slide = (Point,Point)

--
-- Jump is a tuple of 2 elements
-- an internal representation of a leap
-- where the first element represents the point to move from
-- 		 the second element represents the adjacent point to move over
--		 the third element represents the point to move to
--

type Jump = (Point,Point,Point)

--
-- Move is a tuple of 2 elements
-- an internal representation of a move
-- where the first element represents the point to move from
-- 		 the second element represents the point to move to
--
-- Note: in essence it is the same as a slide however the idea
--		 is that a jump can be reduced to a move as in effect
--		 nothing happens the point moved over in a jump
--

type Move = (Point,Point)

--
-- Some test results to see what functions are producing
--
run = crusher ["W------------BB-BBB","----W--------BB-BBB","-W-----------BB-BBB"] 'W' 2 3
grid0 = generateGrid 3 2 4 []
slides0 = generateSlides grid0 3
jumps0 = generateLeaps grid0 3
board0 = sTrToBoard "WWW-WW-------BB-BBB"
newBoards0 = generateNewStates board0 [] grid0 slides0 jumps0 W
tree0 = generateTree board0 [] grid0 slides0 jumps0 W 4 3
heuristic0 = boardEvaluator W [] 3

-- crusher ["WWW-WW-------BB-BBB"] p d n
-- use it to record last result
run2 = crusher ["WWW-WW-------BB-BBB"] 'W' 2 3
run3 = crusher ["WWW-WW-------BB-BBB"] 'W' 4 3
run4 = crusher ["WWW-WW-------BB-BBB"] 'B' 2 3


--
-- crusher
--
-- This function consumes a list of boards, a player, the depth of
-- search tree, the size of the provide boards, and produces the
-- next best board possible for the provided player, and accordingly
-- makes the move and returns new board consed onto the list of boards
--
-- Arguments:
-- -- (current:old): current represents the most recent board, old is
--                   the history of all boards already seen in game
-- -- p: 'W' or 'B' representing the player the program is
-- -- d: an Integer indicating depth of search tree
-- -- n: an Integer representing the dimensions of the board
--
-- Returns: a list of String with the new current board consed onto the front
--

crusher :: [String] -> Char -> Int -> Int -> [String]
crusher (current:old) p d n =
    ((boardToStr nextboard):current:old)
    where
        nextboard = stateSearch (sTrToBoard current) (toHistory old) grid (generateSlides grid n) (generateLeaps grid n) (toPlayer p) d n
          where
              grid = (generateGrid n (n-1) (2*(n-1)) [])

-- history is a list of Board, old is a list of string, old -> history
toHistory :: [String] -> [Board]
toHistory lst = foldr (\x acc -> (sTrToBoard x):acc) [] lst

toPlayer :: Char -> Piece
toPlayer p = head (sTrToBoard [p])

--
-- gameOver
--
-- This function consumes a board, a list of boards, and the dimension
-- of board and determines whether the given board is in a state where
-- the game has ended by checking if the board is present in the provided
-- list of boards or either the W or B pieces are less than dimension of board
--
-- Arguments:
-- -- board: a Board representing the most recent board
-- -- history: a list of Boards of representing all boards already seen
-- -- n: an Integer representing the dimensions of the board
--
-- Returns: True if the board is in a state where the game has ended, otherwise False
--

gameOver :: Board -> [Board] -> Int -> Bool
gameOver board history n
    | count B board < n = True
    | count W board < n = True
    | board `elem` history = True
    | otherwise = False

count :: Piece -> Board -> Int
count pc b = foldl (\acc x -> if x == pc then acc+1 else acc) 0 b

--
-- sTrToBoard
--
-- This function consumes a list of characters which can be either 'W' or 'B'
-- or '-' and converts them to a list of pieces, i.e W or B or D respectively
--
-- Arguments:
-- -- s: the String to convert into piece-wise representation
--
-- Note: This function would convert "WWW-WW-------BB-BBB" to
-- 	     [W,W,W,D,W,W,D,D,D,D,D,D,D,B,B,D,B,B,B]
--
-- Returns: the Board corresponding to the string
--

sTrToBoard :: String -> Board
sTrToBoard s = map (\ x -> check x) s
    where
        check 'W' = W
        check 'B' = B
        check '-' = D

--
-- boardToStr
--
-- This function consumes a board which is a list of either W or B  or D and
-- converts them to a list of characters, i.e 'W' or 'B' or 'D' respectively
--
-- Arguments:
-- -- b: the Board to convert into char-wise representation
--
-- Note: This function would convert [W,W,W,D,W,W,D,D,D,D,D,D,D,B,B,D,B,B,B]
-- 	     to "WWW-WW-------BB-BBB"
--
-- Returns: the String corresponding to the board
--

boardToStr :: Board -> String
boardToStr b = map (\ x -> check x) b
    where
        check W = 'W'
        check B = 'B'
        check D = '-'

--
-- generateGrid
--
-- This function consumes three integers (described below) specifying how to
-- properly generate the grid and also a list as an accumulator; to generate a
-- regular hexagon of side length n, pass n (n- 1) (2 * (n - 1)) and []
--
-- Arguments:
-- -- n1: one more than max x-coordinate in the row, initialized always to n
-- -- n2: the number of rows away from the middle row of the grid
-- -- n3: the current y-coordinate i.e the current row number
-- -- acc: an accumulator that keeps track of accumulating rows of grid
--		   initialized to []
--
-- Note: This function on being passed 3 2 4 [] would produce
--		 [(0,0),(1,0),(2,0)
--		  (0,1),(1,1),(2,1),(3,1)
--		  (0,2),(1,2),(2,2),(3,2),(4,2)
--		  (0,3),(1,3),(2,3),(3,3)
--		  (0,4),(1,4),(2,4)]
--
-- Returns: the corresponding Grid i.e the acc when n3 == -1
--

generateGrid :: Int -> Int -> Int -> Grid -> Grid
generateGrid n1 n2 n3 acc
    | n3 == -1      = acc
    | otherwise     = generateGrid nn1 (n2 - 1) (n3 - 1) (row ++ acc)
        where
            row = map (\ x -> (x,n3)) [0 .. (n1 - 1)]
            nn1 = if n2 > 0 then n1 + 1 else n1 - 1

--
-- generateSlides
--
-- This function consumes a grid and the size of the grid, accordingly
-- generates a list of all possible slides from any point on the grid to
-- any adjacent point on the grid
--
-- Arguments:
-- -- b: the Grid to generate slides for
-- -- n: an Integer representing the dimensions of the grid
--
-- Note: This function is only called at the initial setup of the game,
-- 		 it is a part of the internal representation of the game, this
--		 list of all possible slides is only generated once; and when
-- 		 generating next moves, the program decides which slides out of
--		 all these possible slides could a player actually make
--
-- Returns: the list of all Slides possible on the given grid
--

generateSlides :: Grid -> Int -> [Slide]
generateSlides b n
 | n < 3 = []
 | otherwise = generateSlidesHelper b b n []

generateSlidesHelper b blist n slist
 | (length blist) == 0 = slist
 | ypt < n = (addAllSlides b (head blist) [(xpt + 1, ypt),(xpt-1, ypt), (xpt, ypt+1), (xpt, ypt-1), (xpt-1, ypt-1), (xpt+1, ypt+1)] slist) ++ generateSlidesHelper b (tail blist) n slist
 | ypt == n = (addAllSlides b (head blist) [(xpt + 1, ypt),(xpt-1, ypt), (xpt, ypt+1), (xpt, ypt-1), (xpt-1, ypt-1), (xpt-1, ypt+1)] slist) ++ generateSlidesHelper b (tail blist) n slist
 | ypt > n = (addAllSlides b (head blist) [(xpt + 1, ypt),(xpt-1, ypt), (xpt, ypt+1), (xpt, ypt-1), (xpt+1, ypt-1), (xpt-1, ypt+1)] slist) ++ generateSlidesHelper b (tail blist) n slist
    where
        xpt = (fst(head blist))
        ypt = (snd(head blist))


addAllSlides b p plist slist
 | (length plist) == 0 = slist
 | (isValidSlideLoc b (head plist)) = addAllSlides b p (tail plist) ((p,(head plist)) : slist)
 | otherwise = addAllSlides b p (tail plist) slist


isValidSlideLoc b np
 | (np `elem` b) = True
 | otherwise = False

--
-- generateLeaps
--
-- This function consumes a grid and the size of the grid, accordingly
-- generates a list of all possible leaps from any point on the grid over
-- any adjacent point on the grid to any point next to the adjacent point
-- such that it is movement in the same direction
--
-- Arguments:
-- -- b: the Grid to generate leaps for
-- -- n: an Integer representing the dimensions of the grid
--
-- Note: This function is only called at the initial setup of the game,
-- 		 it is a part of the internal representation of the game, this
--		 list of all possible leaps is only generated once; and when
-- 		 generating next moves, the program decides which leaps out of
--		 all these possible leaps could a player actually make
--
-- Returns: the list of all Jumps possible on the given grid
--

generateLeaps :: Grid -> Int -> [Jump]
generateLeaps b n =
    foldl (\acc e -> acc ++ (filter (check b) (generate e))) [] b
  where
      generate (x,y)
          | y < n-2 = [((x,y),(x-1,y-1),(x-2,y-2)),((x,y),(x,y-1),(x,y-2)),((x,y),(x-1,y),(x-2,y)),((x,y),(x+1,y),(x+2,y)),((x,y),(x,y+1),(x,y+2)),((x,y),(x+1,y+1),(x+2,y+2))]
          | y == n-2 = [((x,y),(x-1,y-1),(x-2,y-2)),((x,y),(x,y-1),(x,y-2)),((x,y),(x-1,y),(x-2,y)),((x,y),(x+1,y),(x+2,y)),((x,y),(x,y+1),(x-1,y+2)),((x,y),(x+1,y+1),(x+1,y+2))]
          | y == n-1 = [((x,y),(x-1,y-1),(x-2,y-2)),((x,y),(x,y-1),(x,y-2)),((x,y),(x-1,y),(x-2,y)),((x,y),(x+1,y),(x+2,y)),((x,y),(x-1,y+1),(x-2,y+2)),((x,y),(x,y+1),(x,y+2))]
          | y == n = [((x,y),(x,y-1),(x-1,y-2)),((x,y),(x+1,y-1),(x+1,y-2)),((x,y),(x-1,y),(x-2,y)),((x,y),(x+1,y),(x+2,y)),((x,y),(x-1,y+1),(x-2,y+2)),((x,y),(x,y+1),(x,y+2))]
          |otherwise = [((x,y),(x,y-1),(x,y-2)),((x,y),(x+1,y-1),(x+2,y-2)),((x,y),(x-1,y),(x-2,y)),((x,y),(x+1,y),(x+2,y)),((x,y),(x-1,y+1),(x-2,y+2)),((x,y),(x,y+1),(x,y+2))]
      check b (_,_,(x,y)) = (x,y) `elem` b

--
-- stateSearch
--
-- This function consumes the arguments described below, based on the internal
-- representation of the game, if there is no point in playing the game as the
-- current board is in a state where the game has ended then just return the
-- board, else generate a search tree till the specified depth and apply
-- minimax to it by using the appropriately generated heuristic
--
-- Arguments:
-- -- board: a Board representing the most recent board
-- -- history: a list of Boards of representing all boards already seen
-- -- grid: the Grid representing the coordinate-grid the game being played
-- -- slides: the list of all Slides possible for the given grid
-- -- jumps: the list of all Jumps possible for the given grid
-- -- player: W or B representing the player the program is
-- -- depth: an Integer indicating depth of search tree
-- -- num: an Integer representing the dimensions of the board
--
-- Returns: the current board if game is over,
--          otherwise produces the next best board
--

stateSearch :: Board -> [Board] -> Grid -> [Slide] -> [Jump] -> Piece -> Int -> Int -> Board
stateSearch board history grid slides jumps player depth num
    | gameOver board history num = board
    | depth == 0 = board
    -- heuristic is boardEvaluator with partial arguments, -> player history n
    | otherwise = minimax (generateTree board history grid slides jumps player depth num) (boardEvaluator player history num)

--
-- generateTree
--
-- This function consumes the arguments described below, and builds a search
-- tree till specified depth from scratch by using the current board and
-- generating all the next states recursively; however it doesn't generate
-- children of those states which are in a state where the game has ended.
--
-- Arguments:
-- -- board: a Board representing the most recent board
-- -- history: a list of Boards of representing all boards already seen
-- -- grid: the Grid representing the coordinate-grid the game being played
-- -- slides: the list of all Slides possible for the given grid
-- -- jumps: the list of all Jumps possible for the given grid
-- -- player: W or B representing the player the program is
-- -- depth: an Integer indicating depth of search tree
-- -- n: an Integer representing the dimensions of the board
--
-- Returns: the corresponding BoardTree generated till specified depth

generateTree :: Board -> [Board] -> Grid -> [Slide] -> [Jump] -> Piece -> Int -> Int -> BoardTree
generateTree board history grid slides jumps player depth n = generateTreeHelper board history grid slides jumps player depth 0 n

generateTreeHelper board history grid slides jumps player depth currDepth n
 | (currDepth == depth) = (Node currDepth board [])
 | (gameOver board history n) = (Node currDepth board [])
 | otherwise = (Node currDepth board childNodes)
    where childNodes =  [generateTreeHelper x (board:history) grid slides jumps player depth (currDepth + 1) n | x <- (generateNewStates board history grid slides jumps player)]

--
-- generateNewStates
--
-- This function consumes the arguments described below, it first generates a
-- list of valid moves, applies those moves to the current board to generate
-- a list of next boards, and then checks whether or not that move would
-- have been possible by filtering out those boards already seen before
--
-- Arguments:
-- -- board: a Board representing the most recent board
-- -- history: a list of Boards of representing all boards already seen
-- -- grid: the Grid representing the coordinate-grid the game being played
-- -- slides: the list of all Slides possible for the given grid
-- -- jumps: the list of all Jumps possible for the given grid
-- -- player: W or B representing the player the program is
--
-- Returns: the list of next boards
--

--generateNewStates :: Board -> [Board] -> Grid -> [Slide] -> [Jump] -> Piece -> [Board]
--generateNewStates board history grid []	[] player = [board]
--generateNewStates board history grid slides jumps player = (filterSlides board grid slides player []) ++ (filterJumps board jumps player [])


--filterSlides board grid slides player flist
-- | (length slides) == 0 = flist
-- | (validMove h board grid player) = filterSlides board grid (tail slides) player ((head slides) : flist)
-- | otherwise = filterSlides board grid (tail slides) player flist

--filterJumps board grid jumps player flist
-- | (length jumps) == 0 = flist
-- | (validMove h board grid player) = filterJumps board grid (tail jumps) player ((head jumps) : flist)
-- | otherwise = filterJumps board grid (tail jumps) player flist


--validSlide mv board grid player
-- | player == W =

generateNewStates :: Board -> [Board] -> Grid -> [Slide] -> [Jump] -> Piece -> [Board]
generateNewStates board history grid slides jumps player =
-- applies moves to the current board to generate a list of next boards
    checkBoard (nextBoard state move player) history
        where
            -- need to generates a list of valud move
            move = (moveGenerator state slides jumps player)
            -- we need state
            state = (getState grid board)

-- check valid
checkBoard :: [Board] -> [Board] -> [Board]
checkBoard board history = [b | b <- board, (not (b `elem` history))]

-- we need a new board after player makes the move
-- state: the point of each piece change
-- -- the changes have made:
-- --     player = Piece [W | B]
-- --     if player = W chooses it's piece for example (W,(0,0)) and moves to a new location on board/grid
-- --	  the new state of the board will change (D, (0,0)) and add (W, to a new point)
nextBoard :: State -> [Move] -> Piece -> [Board]
nextBoard state move player = map (\(from,to) -> (nextBoardState state player from to)) move

nextBoardState :: State -> Piece -> Point -> Point -> Board
nextBoardState state player from to = map (\(piece,point) -> helperNextBoard player from to piece point) state
--helperNextBoard :: Piece -> Point -> Point -> Piece -> Point -> Board
helperNextBoard player from to piece point
    -- (D,from)
    |(from == point) = D
    -- (W, to)
    |(to == point) = player
    | otherwise = piece
-- notes for getState:
-- -- list of Tile = (Piece, Point)
-- -- zipping the board and the grid together
-- -- keep easier track of the effects on the pieces of making moves on grid
-- -- Board -> [piece]
-- -- Grid -> [point]
getState :: Grid -> Board -> State
getState _ [] = []
getState [] _ = []
getState (point:gpr) (piece:bpr) = (piece, point): getState gpr bpr

--
-- moveGenerator
--
-- This function consumes a state, a list of possible jumps,
-- a list of possible slides and a player from whose perspective
-- to generate moves, to check which of these jumps and slides
-- the player could actually make, and produces a list of valid moves
--
-- Arguments:
-- -- state: a State representing the most recent state
-- -- slides: the list of all Slides possible for the given grid
-- -- jumps: the list of all Jumps possible for the given grid
-- -- player: W or B representing the player the program is
--
-- Note: This is the only instance where the program makes use of the
--		 type State, for our purposes it is zipping the board and the
--		 grid together for making it easier to make moves.
--
-- Note:
-- -- oP is opponentsPieces
-- -- pP is playersPieces
-- -- vS is validSlides
-- -- vJ is validJumps
--
-- Returns: the list of all valid moves that the player could make
--

moveGenerator :: State -> [Slide] -> [Jump] -> Piece -> [Move]
moveGenerator state slides jumps player =
    foldl (\acc x -> if fst x == player then (validMoves (snd x) slides jumps player state) ++ acc else acc) [] state

validMoves :: Point -> [Slide] -> [Jump] -> Piece -> State -> [Move]
validMoves p slides jumps player state =
    (validSlides p slides) ++ (validJumps p jumps)
     where
         validSlides _ [] = []
         validSlides p ((a,b):slds)
           | a == p && (find_in_state b state) == D = (p,b):validSlides p slds
             | otherwise = validSlides p slds

         validJumps _ [] = []
         validJumps p ((a,b,c):jmps)
           | a == p && (find_in_state b state) == player && (find_in_state c state) /= player = (p,c):validJumps p jmps
             | otherwise = validJumps p jmps

find_in_state :: Point -> State -> Piece
find_in_state pt1 ((pc,pt):tls)
    | pt1 == pt = pc
    | otherwise = find_in_state pt1 tls
--
-- boardEvaluator
--
-- This function consumes a board and performs a static board evaluation, by
-- taking into account whose perspective the program is playing from, the list
-- of boards already seen, the size of the board, and whether or not it is the
-- program's turn or not; to generate quantitative measures of the board, and
-- accordingly produce a goodness value of the given board
--
-- Arguments:
-- -- player: W or B representing the player the program is
-- -- history: a list of Boards of representing all boards already seen
-- -- n: an Integer representing the dimensions of the board
-- -- board: a Board representing the most recent board
-- -- myTurn: a Boolean indicating whether it is the program's turn or the opponents.
--
-- Returns: the goodness value of the provided board
--

boardEvaluator :: Piece -> [Board] -> Int -> Board -> Bool -> Int
boardEvaluator player history n board myTurn
    | myTurn && gameOver board history n = - 10000*n -- lose
    | not myTurn && gameOver board history n = 10000*n -- win
    | myTurn && not (gameOver board history n) = (count player board) - (count (opponent player) board)
    | otherwise = (count (opponent player) board) - (count player board)

opponent :: Piece -> Piece
opponent player
  | player == B = W
    | otherwise = B

--
-- minimax
--
-- This function implements the minimax algorithm, it consumes a search tree,
-- and an appropriate heuristic to apply to the tree, by applying minimax it
-- produces the next best board that the program should make a move to
--
-- Arguments:
-- -- (Node _ b children): a BoardTree to apply minimax algorithm on
-- -- heuristic: a paritally evaluated boardEvaluator representing the
--				 appropriate heuristic to apply based on the size of the board,
--				 who the program is playing as, and all the boards already seen
--
-- Returns: the next best board
--

minimax :: BoardTree -> (Board -> Bool -> Int) -> Board
minimax (Node _ b []) heuristic = b
minimax (Node _ b children) heuristic =
    let listofscores = (map (\bt -> minimax' bt heuristic False) children)
    in findNextBoard (findMax listofscores) (zip children listofscores)

-- Since the designed player is MaxPlayer, find the next board with max score
-- findNextBoard find the board in children with max score
findNextBoard :: Int -> [(BoardTree, Int)] -> Board
findNextBoard maxscore (((Node _ b _),s):rest)
    | s == maxscore = b
    | otherwise = findNextBoard maxscore rest

--
-- minimax'
--
-- This function is a helper to the actual minimax function, it consumes
-- a search tree, an appropriate heuristic to apply to the leaf nodes of
-- the tree, and based on whether it would have been the maximizing
-- player's turn, it accordingly propogates the values upwards until
-- it reaches the top to the base node, and produces that value.
--
-- Arguments:
-- -- (Node _ b []): a BoardTree
-- -- (Node _ b children): a BoardTree
-- -- heuristic: a paritally evaluated boardEvaluator representing the
--				 appropriate heuristic to apply based on the size of the board,
--				 who the program is playing as, and all the boards already seen
-- -- maxPlayer: a Boolean indicating whether the function should be maximizing
-- 				 or miniziming the goodness values of its children
--
-- Returns: the minimax value at the top of the tree
--

minimax' :: BoardTree -> (Board -> Bool -> Int) -> Bool -> Int
-- base case is a Leaf -> (Node _ _ []), just use heuristic to calculate its score
-- heuristic is boardEvaluator player history n
-- thus need myTurn and board -> maxPlayer and board here
minimax' (Node _ board []) heuristic maxPlayer = heuristic board maxPlayer
minimax' (Node _ board nextboards) heuristic maxPlayer
-- at each depth the player is (...Max Min Max Min...)
    | maxPlayer = findMax (map (\bt -> minimax' bt heuristic False) nextboards)
    | otherwise =  findMin (map (\bt -> minimax' bt heuristic True) nextboards)


findMax :: [Int] -> Int
findMax lst = foldl (\acc x -> if x > acc then x else acc) (head lst) lst
findMin :: [Int] -> Int
findMin lst = foldl (\acc x -> if x < acc then x else acc) (head lst) lst
