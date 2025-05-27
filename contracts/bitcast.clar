;; BitCast Protocol - Decentralized Bitcoin Price Prediction Markets
;;
;; Title: BitCast - The Bitcoin Oracle Protocol
;;
;; Summary: A decentralized prediction market specifically designed for Bitcoin price 
;;          movements, built on Stacks Layer 2 for enhanced scalability and reduced fees
;;
;; Description: BitCast enables users to stake STX tokens on Bitcoin price predictions
;;              within defined time windows. Winners receive proportional rewards from
;;              the losing pool, minus protocol fees. Features oracle-based settlement,
;;              automatic reward distribution, and comprehensive market analytics.
;;              Designed for Bitcoin maximalists and DeFi traders seeking exposure
;;              to BTC price action with Stacks-native liquidity.
;;

;; CONSTANTS & ERROR CODES

(define-constant contract-owner tx-sender) ;; Admin multisig address
(define-constant err-owner-only (err u100)) ;; Authorization error
(define-constant err-not-found (err u101)) ;; Data lookup error
(define-constant err-invalid-prediction (err u102)) ;; Invalid market position
(define-constant err-market-closed (err u103)) ;; Market lifecycle error
(define-constant err-already-claimed (err u104)) ;; Reward claim error
(define-constant err-insufficient-balance (err u105)) ;; STX balance check
(define-constant err-invalid-parameter (err u106)) ;; Input validation
(define-constant err-market-not-started (err u107)) ;; Early participation attempt
(define-constant err-market-ended (err u108)) ;; Late participation attempt
(define-constant err-market-already-resolved (err u109)) ;; Duplicate resolution

;; ECONOMIC PARAMETERS

(define-data-var oracle-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) ;; Trusted price feed
(define-data-var minimum-stake uint u1000000) ;; 1 STX minimum position
(define-data-var fee-percentage uint u2) ;; 2% protocol fee (bps)
(define-data-var market-counter uint u0) ;; Sequential market IDs

;; DATA STRUCTURES

;; Bitcoin price prediction market specification
(define-map markets
  uint ;; market-id
  {
    start-price: uint, ;; BTC/USD opening price (sats)
    end-price: uint, ;; BTC/USD closing price (sats)
    total-up-stake: uint, ;; Aggregate long positions
    total-down-stake: uint, ;; Aggregate short positions
    start-block: uint, ;; Stacks block height - market open
    end-block: uint, ;; Stacks block height - market close
    resolved: bool, ;; Settlement status
  }
)

;; Individual position tracking
(define-map user-predictions
  {
    market-id: uint,
    user: principal,
  }
  {
    prediction: (string-ascii 4), ;; "up" or "down"
    stake: uint, ;; STX committed
    claimed: bool, ;; Reward status
  }
)

;; CORE MARKET OPERATIONS

;; Initialize new BTC price prediction market
;; Creates a new prediction market with specified parameters
(define-public (create-market
    (start-price uint)
    (start-block uint)
    (end-block uint)
  )
  (let ((market-id (var-get market-counter)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> end-block start-block) err-invalid-parameter)
    (asserts! (> start-price u0) err-invalid-parameter)
    (map-set markets market-id {
      start-price: start-price,
      end-price: u0,
      total-up-stake: u0,
      total-down-stake: u0,
      start-block: start-block,
      end-block: end-block,
      resolved: false,
    })
    (var-set market-counter (+ market-id u1))
    (ok market-id)
  )
)

;; Execute BTC price prediction with STX stake
;; Allows users to place predictions on Bitcoin price direction
(define-public (make-prediction
    (market-id uint)
    (prediction (string-ascii 4))
    (stake uint)
  )
  (let (
      (market (unwrap! (map-get? markets market-id) err-not-found))
      (current-block-height stacks-block-height)
    )
    ;; Validate market timing
    (asserts!
      (and
        (>= current-block-height (get start-block market))
        (< current-block-height (get end-block market))
      )
      err-market-ended
    )
    ;; Validate prediction parameters
    (asserts! (or (is-eq prediction "up") (is-eq prediction "down"))
      err-invalid-prediction
    )
    (asserts! (>= stake (var-get minimum-stake)) err-invalid-parameter)
    (asserts! (<= stake (stx-get-balance tx-sender)) err-insufficient-balance)
    ;; Transfer stake to contract
    (try! (stx-transfer? stake tx-sender (as-contract tx-sender)))
    ;; Record user prediction
    (map-set user-predictions {
      market-id: market-id,
      user: tx-sender,
    } {
      prediction: prediction,
      stake: stake,
      claimed: false,
    })
    ;; Update market liquidity pools
    (map-set markets market-id
      (merge market {
        total-up-stake: (if (is-eq prediction "up")
          (+ (get total-up-stake market) stake)
          (get total-up-stake market)
        ),
        total-down-stake: (if (is-eq prediction "down")
          (+ (get total-down-stake market) stake)
          (get total-down-stake market)
        ),
      })
    )
    (ok true)
  )
)

;; Finalize market with oracle-provided end price
;; Resolves market using trusted price feed data
(define-public (resolve-market
    (market-id uint)
    (end-price uint)
  )
  (let ((market (unwrap! (map-get? markets market-id) err-not-found)))
    ;; Validate oracle authorization
    (asserts! (is-eq tx-sender (var-get oracle-address)) err-owner-only)
    (asserts! (>= stacks-block-height (get end-block market)) err-market-ended)
    (asserts! (not (get resolved market)) err-market-already-resolved)
    (asserts! (> end-price u0) err-invalid-parameter)
    ;; Set final settlement parameters
    (map-set markets market-id
      (merge market {
        end-price: end-price,
        resolved: true,
      })
    )
    (ok true)
  )
)

;; Claim prediction rewards for winning positions
;; Distributes proportional rewards to winning predictors
(define-public (claim-winnings (market-id uint))
  (let (
      (market (unwrap! (map-get? markets market-id) err-not-found))
      (prediction (unwrap!
        (map-get? user-predictions {
          market-id: market-id,
          user: tx-sender,
        })
        err-not-found
      ))
    )
    ;; Validate claim eligibility
    (asserts! (get resolved market) err-market-closed)
    (asserts! (not (get claimed prediction)) err-already-claimed)
    (let (
        (winning-prediction (if (> (get end-price market) (get start-price market))
          "up"
          "down"
        ))
        (total-stake (+ (get total-up-stake market) (get total-down-stake market)))
        (winning-stake (if (is-eq winning-prediction "up")
          (get total-up-stake market)
          (get total-down-stake market)
        ))
      )
      ;; Verify winning prediction
      (asserts! (is-eq (get prediction prediction) winning-prediction)
        err-invalid-prediction
      )
      ;; Calculate proportional rewards
      (let (
          (winnings (/ (* (get stake prediction) total-stake) winning-stake))
          (fee (/ (* winnings (var-get fee-percentage)) u100))
          (payout (- winnings fee))
        )
        ;; Transfer rewards and fees
        (try! (as-contract (stx-transfer? payout (as-contract tx-sender) tx-sender)))
        (try! (as-contract (stx-transfer? fee (as-contract tx-sender) contract-owner)))
        ;; Mark as claimed
        (map-set user-predictions {
          market-id: market-id,
          user: tx-sender,
        }
          (merge prediction { claimed: true })
        )
        (ok payout)
      )
    )
  )
)

;; READ-ONLY FUNCTIONS

;; Retrieve market parameters and current state
(define-read-only (get-market (market-id uint))
  (map-get? markets market-id)
)

;; Get user position details for specific market
(define-read-only (get-user-prediction
    (market-id uint)
    (user principal)
  )
  (map-get? user-predictions {
    market-id: market-id,
    user: user,
  })
)

;; Check total contract STX balance
(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

;; Get current protocol parameters
(define-read-only (get-protocol-info)
  {
    oracle-address: (var-get oracle-address),
    minimum-stake: (var-get minimum-stake),
    fee-percentage: (var-get fee-percentage),
    market-counter: (var-get market-counter),
  }
)

;; ADMINISTRATIVE FUNCTIONS

;; Update trusted price oracle address
;; Changes the authorized oracle for market resolution
(define-public (set-oracle-address (new-address principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (is-eq new-address (var-get oracle-address)))
      err-invalid-parameter
    )
    (ok (var-set oracle-address new-address))
  )
)

;; Configure minimum position size requirement
;; Sets minimum STX amount required for predictions
(define-public (set-minimum-stake (new-minimum uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-minimum u0) err-invalid-parameter)
    (ok (var-set minimum-stake new-minimum))
  )
)

;; Adjust protocol fee percentage
;; Updates the fee taken from winning pools
(define-public (set-fee-percentage (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u100) err-invalid-parameter)
    (ok (var-set fee-percentage new-fee))
  )
)

;; Withdraw accumulated protocol revenue
;; Allows contract owner to claim collected fees
(define-public (withdraw-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= amount (stx-get-balance (as-contract tx-sender)))
      err-insufficient-balance
    )
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) contract-owner)))
    (ok amount)
  )
)
