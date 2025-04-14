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
;; Game state map - Note: We'll store games twice (once for each player order combination)
;; This simplifies lookups but requires careful updates
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
;; Update the current block height (simplified for testing)
(define-private (set-current-block)
  (var-set current-block (+ (var-get current-block) u1))
)

;; Check if a game exists between two players
(define-read-only (game-exists (player1 principal) (player2 principal))
  (or 
    (is-some (map-get? battles { player1: player1, player2: player2 }))
    (is-some (map-get? battles { player1: player2, player2: player1 }))
  )
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

;; Check if timeout has been reached
(define-private (is-timeout-reached (last-move uint))
  (>= (- (var-get current-block) last-move) TIMEOUT_BLOCKS)
)

;; Determine winner based on HP values
(define-private (check-winner (hp1 uint) (hp2 uint) (player1 principal) (player2 principal))
  (if (<= hp1 u0)
      (some player2)
      (if (<= hp2 u0)
          (some player1)
          none
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

;; Update game state in both orientations (p1-p2 and p2-p1)
(define-private (update-game-state (player1 principal) (player2 principal) 
                                   (hp1 uint) (hp2 uint) 
                                   (turn principal) (winner (optional principal)))
  (begin
    ;; Update the game in both orientations to ensure consistency
    (map-set battles { player1: player1, player2: player2 }
      {
        hp1: hp1,
        hp2: hp2,
        turn: turn,
        winner: winner,
        last-move: (var-get current-block)
      })
      
    ;; Also update with reversed player order for easy lookup
    (map-set battles { player1: player2, player2: player1 }
      {
        hp1: hp2, ;; Note the swap of hp1/hp2 when players are reversed
        hp2: hp1,
        turn: turn,
        winner: winner,
        last-move: (var-get current-block)
      })
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
    
    ;; Initialize the game with both orientations
    (update-game-state tx-sender opponent 
                      STARTING_HP STARTING_HP
                      tx-sender none)
    
    (ok true)
  )
)

;; Attack function for player1
(define-public (attack (opponent principal))
  (begin
    (set-current-block)
    
    ;; Check for direct match first (where tx-sender is player1)
    (match (map-get? battles { player1: tx-sender, player2: opponent })
      game (begin
        ;; Validate it's sender's turn and game is not over
        (asserts! (is-eq (get turn game) tx-sender) ERR_NOT_YOUR_TURN)
        (asserts! (is-none (get winner game)) ERR_GAME_OVER)
        
        ;; Calculate new HP and check for winner
        (let (
          (current-hp2 (get hp2 game))
          (new-hp2 (if (> current-hp2 ATTACK_DAMAGE) (- current-hp2 ATTACK_DAMAGE) u0))
          (new-winner (check-winner (get hp1 game) new-hp2 tx-sender opponent))
        )
          ;; Update game state in both orientations
          (update-game-state tx-sender opponent
                            (get hp1 game) new-hp2
                            opponent new-winner)
          
          (ok true)
        )
      )
      
      ;; Check if the game exists with reversed roles (attacker is stored as player2)
      (match (map-get? battles { player1: opponent, player2: tx-sender })
        reverse-game (begin
          ;; For reversed game, player is attacking as player2, should use counter-attack
          ERR_WRONG_PLAYER
        )
        ;; No game exists
        ERR_NO_GAME
      )
    )
  )
)

;; Counter-attack function for player2
(define-public (counter-attack (opponent principal))
  (begin
    (set-current-block)
    
    ;; Check for game where tx-sender is player2
    (match (map-get? battles { player1: opponent, player2: tx-sender })
      game (begin
        ;; Validate it's sender's turn and game is not over
        (asserts! (is-eq (get turn game) tx-sender) ERR_NOT_YOUR_TURN)
        (asserts! (is-none (get winner game)) ERR_GAME_OVER)
        
        ;; Calculate new HP and check for winner
        (let (
          (current-hp1 (get hp1 game))
          (new-hp1 (if (> current-hp1 ATTACK_DAMAGE) (- current-hp1 ATTACK_DAMAGE) u0))
          (new-winner (check-winner new-hp1 (get hp2 game) opponent tx-sender))
        )
          ;; Update game state in both orientations
          (update-game-state opponent tx-sender
                            new-hp1 (get hp2 game)
                            opponent new-winner)
          
          (ok true)
        )
      )
      
      ;; Check if the game exists with reversed roles (counter-attacker is stored as player1)
      (match (map-get? battles { player1: tx-sender, player2: opponent })
        reverse-game (begin
          ;; For reversed game, player is counter-attacking as player1, should use attack
          ERR_WRONG_PLAYER
        )
        ;; No game exists
        ERR_NO_GAME
      )
    )
  )
)

;; Forfeit game due to timeout
(define-public (forfeit-game (opponent principal))
  (begin
    (set-current-block)
    
    ;; Find the game data - check both orientations
    (let ((game-data (find-game tx-sender opponent)))
      ;; Validate game exists and is not over
      (asserts! (is-some game-data) ERR_NO_GAME)
      
      (match game-data
        game (begin
          ;; Verify game is still active
          (asserts! (is-none (get winner game)) ERR_GAME_OVER)
          
          ;; Validate it's NOT the sender's turn (they're claiming opponent's timeout)
          (asserts! (not (is-eq (get turn game) tx-sender)) ERR_NOT_YOUR_TURN)
          
          ;; Validate timeout period has passed
          (asserts! (is-timeout-reached (get last-move game)) ERR_TIMEOUT_NOT_REACHED)
          
          ;; Determine players' positions
          (if (is-some (map-get? battles { player1: tx-sender, player2: opponent }))
            ;; tx-sender is player1
            (update-game-state tx-sender opponent
                              (get hp1 game) (get hp2 game)
                              (get turn game) (some tx-sender))
                              
            ;; tx-sender is player2
            (update-game-state opponent tx-sender
                              (get hp1 game) (get hp2 game)
                              (get turn game) (some tx-sender))
          )
          
          (ok true)
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
               "Game over. Winner announced."
               "Ongoing game. Current turn is active player.")
      "No game exists between these players"
    )
  )
)

;; Check if it's a player's turn
(define-read-only (is-my-turn (opponent principal))
  (let ((game-data (find-game tx-sender opponent)))
    (match game-data
      game (is-eq (get turn game) tx-sender)
      false
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