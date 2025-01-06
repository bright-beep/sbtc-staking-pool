;; Title: sBTC Staking Pool Contract
;; Version: 1.0
;;
;; Summary:
;; A staking pool contract that allows users to deposit sBTC tokens and earn rewards.
;; The contract implements a fair reward distribution system based on deposit amount
;; and time staked.
;;
;; Description:
;; This contract manages a staking pool where users can:
;; - Deposit sBTC tokens to earn staking rewards
;; - Withdraw their staked tokens
;; - Claim accumulated rewards
;;
;; The reward rate is configurable and rewards are distributed proportionally
;; to each user's stake in the pool. The contract includes safety features
;; like pause functionality and minimum deposit requirements.


;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant POOL_ADMIN 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_POOL_PAUSED (err u103))
(define-constant ERR_ALREADY_INITIALIZED (err u104))
(define-constant ERR_NOT_INITIALIZED (err u105))
(define-constant ERR_SLASHING_CONDITION (err u106))
(define-constant ERR_POOL_FULL (err u107))
(define-constant ERR_INVALID_DELEGATION (err u108))
(define-constant ERR_COOLDOWN_ACTIVE (err u109))

;; Pool Configuration
(define-constant REWARD_RATE u100000) 
(define-constant MINIMUM_DEPOSIT u1000000)
(define-constant MAXIMUM_POOL_SIZE u1000000000000)
(define-constant COOLDOWN_PERIOD u144) ;; ~24 hours in blocks
(define-constant TIER1_THRESHOLD u4320) ;; 30 days in blocks
(define-constant TIER2_THRESHOLD u8640) ;; 60 days in blocks
(define-constant TIER1_BONUS u10) ;; 10% bonus
(define-constant TIER2_BONUS u25) ;; 25% bonus
(define-constant SLASH_RATE u50) ;; 50% slash rate

;; Data Variables
(define-data-var contract-initialized bool false)
(define-data-var pool-paused bool false)
(define-data-var total-liquidity uint u0)
(define-data-var total-rewards uint u0)
(define-data-var last-update-time uint u0)
(define-data-var reward-per-token uint u0)
(define-data-var emergency-mode bool false)

;; Data Maps
(define-map user-deposits principal uint)
(define-map user-rewards principal uint)
(define-map user-reward-paid principal uint)
(define-map staking-time principal uint)
(define-map delegation-info { delegator: principal } { delegate: principal })
(define-map cooldown-period principal uint)
(define-map slashed-addresses principal bool)

;; Access Control
(define-private (is-authorized)
    (or (is-eq tx-sender CONTRACT_OWNER)
        (is-eq tx-sender POOL_ADMIN)
		)
)

(define-private (check-initialized)
    (ok (asserts! (var-get contract-initialized) ERR_NOT_INITIALIZED)
	)
)

(define-private (check-not-paused)
    (ok (asserts! (not (var-get pool-paused)) ERR_POOL_PAUSED)
	)
)

;; Reward Calculation
(define-private (calculate-tier-multiplier (staking-duration uint))
    (cond
        ((>= staking-duration TIER2_THRESHOLD) (+ u100 TIER2_BONUS))
        ((>= staking-duration TIER1_THRESHOLD) (+ u100 TIER1_BONUS))
        true u100)
)

(define-private (update-reward (user principal))
    (let (
        (current-time (unwrap-panic (get-block-info? time u0)))
        (time-delta (- current-time (var-get last-update-time)))
        (user-balance (default-to u0 (map-get? user-deposits user)))
        (staking-duration (- current-time (default-to u0 (map-get? staking-time user))))
        (tier-multiplier (calculate-tier-multiplier staking-duration))
    )
    (if (> (var-get total-liquidity) u0)
        (let (
            (new-reward-per-token (+ (var-get reward-per-token) 
                (* (* (* REWARD_RATE time-delta) tier-multiplier) u1000000)))
        )
        (var-set reward-per-token new-reward-per-token)
        (var-set last-update-time current-time)
        (map-set user-reward-paid user new-reward-per-token)
        (ok true))
        (ok false)))
)