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