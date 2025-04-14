;; Battle Game Smart Contract
;; A turn-based PvP battle game on Stacks using Clarity
;; Author: Oluwabunmi Ogunlana
;; Version: 1.0

;; ---------- Constants ----------
(define-constant STARTING_HP u100)
(define-constant ATTACK_DAMAGE u10)
(define-constant TIMEOUT_BLOCKS u20)
(define-constant ERR_NO_GAME (err u1))
(define-constant ERR_GAME_EXISTS (err u2))
(define-constant ERR_SELF_PLAY (err u3))
(define-constant ERR_NOT_YOUR_TURN (err u4))
(define-constant ERR_GAME_OVER (err u5))
(define-constant ERR_TIMEOUT_NOT_REACHED (err u6))
(define-constant ERR_WRONG_PLAYER (err u7))

;; ---------- Data Structures ----------
;; Game state map
(define-map battles
  { player1: principal, player2: principal }
  {
    hp1: uint,
    hp2: uint,
    turn: principal,
    winner: (optional principal),
    last-move: uint
  }
)

;; Current block height data var (useful for testing and validation)
(define-data-var current-block uint u0)

;; ---------- Helper Functions ----------
;; Update the current block height
(define-private (set-current-block)
  (var-set current-block block-height)
)

;; Check if a game exists between two players
(define-read-only (game-exists (player1 principal) (player2 principal))
  (or 
    (is-some (map-get? battles { player1: player1, player2: player2 }))
    (is-some (map-get? battles { player1: player2, player2: player1 }))
  )
)

;; Get canonical game key (ensures consistent lookup regardless of player order)
(define-private (get-game-key (player1 principal) (player2 principal))
  ;; Compare player principals as strings and order them alphabetically
  ;; This ensures consistent key generation regardless of which player is passed first
  (if (string-compare (to-ascii (serialize-principal player1)) (to-ascii (serialize-principal player2)))
      { player1: player1, player2: player2 }
      { player1: player2, player2: player1 }
  )
)

;; String comparison helper (returns true if a < b alphabetically)
(define-private (string-compare (a (buff 40)) (b (buff 40)))
  ;; Compare strings byte by byte
  ;; Return true if a comes before b alphabetically
  ;; This is a simplified comparison that works for principal strings
  (< (unwrap-panic (index-of a u0)) (unwrap-panic (index-of b u0)))
)

;; Check if it's the player's turn
(define-private (is-players-turn (game-data (optional {
    hp1: uint,
    hp2: uint,
    turn: principal,
    winner: (optional principal),
    last-move: uint
  })) (player principal))
  (match game-data
    game (is-eq (get turn game) player)
    false
  )
)

;; Check if the game is over
(define-private (is-game-over (game-data (optional {
    hp1: uint,
    hp2: uint,
    turn: principal,
    winner: (optional principal),
    last-move: uint
  })))
  (match game-data
    game (is-some (get winner game))
    true
  )
)

;; Get player position (1 or 2) in the game
(define-private (get-player-position (player1 principal) (player2 principal) (player principal))
  (cond
    ((is-eq player player1) u1)
    ((is-eq player player2) u2)
    (true u0)
  )
)

;; Check if timeout has been reached
(define-private (is-timeout-reached (last-move uint))
  (>= (- (var-get current-block) last-move) TIMEOUT_BLOCKS)
)

;; Determine winner based on HP values
(define-private (check-winner (hp1 uint) (hp2 uint) (player1 principal) (player2 principal))
  (cond
    ((<= hp1 u0) (some player2))
    ((<= hp2 u0) (some player1))
    (true none)
  )
)

;; ---------- Core Game Functions ----------
;; Start a new game between tx-sender and opponent
(define-public (start-game (opponent principal))
  (begin
    (set-current-block)
    
    ;; Validate inputs
    (asserts! (not (is-eq tx-sender opponent)) ERR_SELF_PLAY)
    
    ;; Check if game already exists
    (asserts! (not (game-exists tx-sender opponent)) ERR_GAME_EXISTS)
    
    ;; Create canonical game key
    (let ((game-key (get-game-key tx-sender opponent)))
      ;; Initialize the game
      (ok (map-set battles game-key {
        hp1: STARTING_HP,
        hp2: STARTING_HP,
        turn: tx-sender,  ;; Player who started the game goes first
        winner: none,
        last-move: (var-get current-block)
      }))
    )
  )
)

;; Find game between players (checks both orientations)
(define-private (find-game (player1 principal) (player2 principal))
  (match (map-get? battles { player1: player1, player2: player2 })
    found-game (some found-game)
    (map-get? battles { player1: player2, player2: player1 })
  )
)

;; Attack function for player1
(define-public (attack (opponent principal))
  (begin
    (set-current-block)
    
    ;; Find game data between players
    (let ((game-data (find-game tx-sender opponent)))
      
      ;; Validate game exists
      (asserts! (is-some game-data) ERR_NO_GAME)
      
      ;; Verify game details from the actual game data
      (match game-data
        game (let (
          (player1 (match (map-get? battles { player1: tx-sender, player2: opponent })
                     found (tx-sender)
                     opponent))
          (player2 (match (map-get? battles { player1: tx-sender, player2: opponent })
                     found (opponent)
                     tx-sender))
        )
          ;; Validate sender is player1
          (asserts! (is-eq tx-sender player1) ERR_WRONG_PLAYER)
          
          ;; Validate it's sender's turn and game is not over
          (asserts! (is-players-turn game-data tx-sender) ERR_NOT_YOUR_TURN)
          (asserts! (not (is-game-over game-data)) ERR_GAME_OVER)
          
          ;; Update game state
          (let (
            (current-hp2 (get hp2 game))
            (new-hp2 (if (> current-hp2 ATTACK_DAMAGE) (- current-hp2 ATTACK_DAMAGE) u0))
            (new-winner (check-winner (get hp1 game) new-hp2 player1 player2))
            (game-key (get-game-key player1 player2))
          )
            (ok (map-set battles game-key {
              hp1: (get hp1 game),
              hp2: new-hp2,
              turn: player2,  ;; Switch turns
              winner: new-winner,
              last-move: (var-get current-block)
            }))
          )
        )
        ERR_NO_GAME
      )
    )
  )
)

;; Counter-attack function for player2
(define-public (counter-attack (opponent principal))
  (begin
    (set-current-block)
    
    ;; Find game data between players
    (let ((game-data (find-game tx-sender opponent)))
      
      ;; Validate game exists
      (asserts! (is-some game-data) ERR_NO_GAME)
      
      ;; Verify game details from the actual game data
      (match game-data
        game (let (
          (player1 (match (map-get? battles { player1: opponent, player2: tx-sender })
                     found (opponent)
                     tx-sender))
          (player2 (match (map-get? battles { player1: opponent, player2: tx-sender })
                     found (tx-sender)
                     opponent))
        )
          ;; Validate sender is player2
          (asserts! (is-eq tx-sender player2) ERR_WRONG_PLAYER)
          
          ;; Validate it's sender's turn and game is not over
          (asserts! (is-players-turn game-data tx-sender) ERR_NOT_YOUR_TURN)
          (asserts! (not (is-game-over game-data)) ERR_GAME_OVER)
          
          ;; Update game state
          (let (
            (current-hp1 (get hp1 game))
            (new-hp1 (if (> current-hp1 ATTACK_DAMAGE) (- current-hp1 ATTACK_DAMAGE) u0))
            (new-winner (check-winner new-hp1 (get hp2 game) player1 player2))
            (game-key (get-game-key player1 player2))
          )
            (ok (map-set battles game-key {
              hp1: new-hp1,
              hp2: (get hp2 game),
              turn: player1,  ;; Switch turns
              winner: new-winner,
              last-move: (var-get current-block)
            }))
          )
        )
        ERR_NO_GAME
      )
    )
  )
)

;; Forfeit game due to timeout
(define-public (forfeit-game (opponent principal))
  (begin
    (set-current-block)
    
    ;; Find game data between players
    (let ((game-data (find-game tx-sender opponent)))
      
      ;; Validate game exists and is not over
      (asserts! (is-some game-data) ERR_NO_GAME)
      (asserts! (not (is-game-over game-data)) ERR_GAME_OVER)
      
      ;; Get the players from the game data
      (match game-data
        game (let (
          (player1 (match (map-get? battles { player1: tx-sender, player2: opponent })
                     found (tx-sender)
                     opponent))
          (player2 (match (map-get? battles { player1: tx-sender, player2: opponent })
                     found (opponent)
                     tx-sender))
        )
          ;; Validate the player is part of the game
          (asserts! (or (is-eq tx-sender player1) (is-eq tx-sender player2)) ERR_WRONG_PLAYER)
          
          ;; Validate it's NOT the sender's turn (they're claiming opponent's timeout)
          (asserts! (not (is-eq (get turn game) tx-sender)) ERR_NOT_YOUR_TURN)
          (asserts! (is-timeout-reached (get last-move game)) ERR_TIMEOUT_NOT_REACHED)
          
          ;; Set the game winner to the sender (the player who called forfeit)
          (let ((game-key (get-game-key player1 player2)))
            (ok (map-set battles game-key {
              hp1: (get hp1 game),
              hp2: (get hp2 game),
              turn: (get turn game),
              winner: (some tx-sender),
              last-move: (var-get current-block)
            }))
          )
        )
        ERR_NO_GAME
      )
    )
  )
)

;; ---------- Read-Only Functions ----------
;; Get game state between two players
(define-read-only (get-game (player1 principal) (player2 principal))
  (find-game player1 player2)
)

;; Get game status as a string
(define-read-only (get-game-status (player1 principal) (player2 principal))
  (let ((game-data (get-game player1 player2)))
    (match game-data
      game (if (is-some (get winner game))
               (concat (concat "Game over. Winner: " (unwrap-panic (get winner game))) "")
               (concat (concat "Ongoing game. Current turn: " (get turn game)) ""))
      "No game exists between these players"
    )
  )
)

;; ---------- Extensible Functions (For future versions) ----------
;; These functions can be added in future versions:
;; - Variable attack damage
;; - Special abilities
;; - Power-ups
;; - NFT integration
;; - Game statistics