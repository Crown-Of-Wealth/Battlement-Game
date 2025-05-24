;; Battle Game Smart Contract
;; A turn-based PvP battle game on Stacks using Clarity
;; Author: Oluwabunmi Ogunlana
;; Version: 1.1 (Turn Timer Added)

;; ---------- Constants ----------
(define-constant STARTING_HP u100)
(define-constant ATTACK_DAMAGE u10)
(define-constant TIMEOUT_BLOCKS u20)
(define-constant TURN_TIMEOUT_BLOCKS u10) ;; NEW: Turn timer constant

(define-constant ERR_NO_GAME (err u1))
(define-constant ERR_GAME_EXISTS (err u2))
(define-constant ERR_SELF_PLAY (err u3))
(define-constant ERR_NOT_YOUR_TURN (err u4))
(define-constant ERR_GAME_OVER (err u5))
(define-constant ERR_TIMEOUT_NOT_REACHED (err u6))
(define-constant ERR_WRONG_PLAYER (err u7))
(define-constant ERR_INVALID_OPPONENT (err u8))
(define-constant ERR_TURN_TIMEOUT (err u9)) ;; NEW: Error for turn timer timeout

;; ---------- Data Structures ----------
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

(define-data-var current-block uint u0)

;; ---------- Helper Functions ----------
(define-private (set-current-block)
  (var-set current-block (+ (var-get current-block) u1))
)

(define-read-only (game-exists (player1 principal) (player2 principal))
  (or 
    (is-some (map-get? battles { player1: player1, player2: player2 }))
    (is-some (map-get? battles { player1: player2, player2: player1 }))
  )
)

(define-private (validate-opponent (opponent principal))
  (game-exists tx-sender opponent)
)

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

(define-private (is-timeout-reached (last-move uint))
  (>= (- (var-get current-block) last-move) TIMEOUT_BLOCKS)
)

;; NEW: Check if turn-specific timeout is reached
(define-private (is-turn-timeout-reached (last-move uint))
  (>= (- (var-get current-block) last-move) TURN_TIMEOUT_BLOCKS)
)

(define-private (check-winner (hp1 uint) (hp2 uint) (player1 principal) (player2 principal))
  (if (game-exists player1 player2)
    (if (<= hp1 u0)
        (some player2)
        (if (<= hp2 u0)
            (some player1)
            none
        )
    )
    none
  )
)

(define-private (find-game (player1 principal) (player2 principal))
  (match (map-get? battles { player1: player1, player2: player2 })
    found-game (some found-game)
    (map-get? battles { player1: player2, player2: player1 })
  )
)

(define-private (update-game-state (player1 principal) (player2 principal) 
                                   (hp1 uint) (hp2 uint) 
                                   (turn principal) (winner (optional principal)))
  (if (game-exists player1 player2)
    (begin
      (map-set battles { player1: player1, player2: player2 }
        {
          hp1: hp1,
          hp2: hp2,
          turn: turn,
          winner: winner,
          last-move: (var-get current-block)
        })
      (map-set battles { player1: player2, player2: player1 }
        {
          hp1: hp2,
          hp2: hp1,
          turn: turn,
          winner: winner,
          last-move: (var-get current-block)
        })
      true
    )
    false
  )
)

;; ---------- Core Game Functions with Turn Timer Enforcement ----------

(define-public (attack (opponent principal))
  (begin
    (set-current-block)
    (asserts! (validate-opponent opponent) ERR_INVALID_OPPONENT)
    (match (map-get? battles { player1: tx-sender, player2: opponent })
      game (begin
        (asserts! (is-eq (get turn game) tx-sender) ERR_NOT_YOUR_TURN)
        (asserts! (is-none (get winner game)) ERR_GAME_OVER)
        (asserts! (not (is-turn-timeout-reached (get last-move game))) ERR_TURN_TIMEOUT)
        (let (
          (current-hp2 (get hp2 game))
          (new-hp2 (if (> current-hp2 ATTACK_DAMAGE) (- current-hp2 ATTACK_DAMAGE) u0))
          (new-winner (check-winner (get hp1 game) new-hp2 tx-sender opponent))
        )
          (asserts! (update-game-state tx-sender opponent (get hp1 game) new-hp2 opponent new-winner) ERR_INVALID_OPPONENT)
          (ok true)
        )
      )
      (match (map-get? battles { player1: opponent, player2: tx-sender })
        reverse-game ERR_WRONG_PLAYER
        ERR_NO_GAME
      )
    )
  )
)

(define-public (counter-attack (opponent principal))
  (begin
    (set-current-block)
    (asserts! (validate-opponent opponent) ERR_INVALID_OPPONENT)
    (match (map-get? battles { player1: opponent, player2: tx-sender })
      game (begin
        (asserts! (is-eq (get turn game) tx-sender) ERR_NOT_YOUR_TURN)
        (asserts! (is-none (get winner game)) ERR_GAME_OVER)
        (asserts! (not (is-turn-timeout-reached (get last-move game))) ERR_TURN_TIMEOUT)
        (let (
          (current-hp1 (get hp1 game))
          (new-hp1 (if (> current-hp1 ATTACK_DAMAGE) (- current-hp1 ATTACK_DAMAGE) u0))
          (new-winner (check-winner new-hp1 (get hp2 game) opponent tx-sender))
        )
          (asserts! (update-game-state opponent tx-sender new-hp1 (get hp2 game) opponent new-winner) ERR_INVALID_OPPONENT)
          (ok true)
        )
      )
      (match (map-get? battles { player1: tx-sender, player2: opponent })
        reverse-game ERR_WRONG_PLAYER
        ERR_NO_GAME
      )
    )
  )
)

;; The rest of the contract remains unchanged and fully compatible with the turn timer enforcement.
