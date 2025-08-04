;; Fare Payment Integration Contract
;; Enables passengers to pay for transit using various methods

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-FUNDS (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-PAYMENT-FAILED (err u103))
(define-constant ERR-ROUTE-NOT-FOUND (err u104))

;; Data Variables
(define-data-var contract-active bool true)
(define-data-var base-fare uint u50)

;; Data Maps
(define-map payments
  { payment-id: uint }
  {
    payer: principal,
    amount: uint,
    route: (string-ascii 50),
    timestamp: uint,
    payment-method: (string-ascii 20)
  }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

(define-map route-fares
  { route: (string-ascii 50) }
  { fare: uint, active: bool }
)

(define-map payment-methods
  { method: (string-ascii 20) }
  { active: bool, fee-percentage: uint }
)

;; Private Variables
(define-data-var next-payment-id uint u1)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-valid-amount (amount uint))
  (and (> amount u0) (< amount u10000))
)

(define-private (calculate-fee (amount uint) (fee-percentage uint))
  (/ (* amount fee-percentage) u10000)
)

;; Public Functions

;; Initialize route fares
(define-public (set-route-fare (route (string-ascii 50)) (fare uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-amount fare) ERR-INVALID-AMOUNT)
    (ok (map-set route-fares { route: route } { fare: fare, active: true }))
  )
)

;; Add payment method
(define-public (add-payment-method (method (string-ascii 20)) (fee-percentage uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (< fee-percentage u1000) ERR-INVALID-AMOUNT)
    (ok (map-set payment-methods { method: method } { active: true, fee-percentage: fee-percentage }))
  )
)

;; Top up user balance
(define-public (top-up-balance (amount uint))
  (let
    (
      (current-balance (default-to u0 (get balance (map-get? user-balances { user: tx-sender }))))
    )
    (begin
      (asserts! (is-valid-amount amount) ERR-INVALID-AMOUNT)
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (ok (map-set user-balances { user: tx-sender } { balance: (+ current-balance amount) }))
    )
  )
)

;; Pay fare
(define-public (pay-fare (route (string-ascii 50)) (payment-method (string-ascii 20)))
  (let
    (
      (route-info (unwrap! (map-get? route-fares { route: route }) ERR-ROUTE-NOT-FOUND))
      (method-info (unwrap! (map-get? payment-methods { method: payment-method }) ERR-PAYMENT-FAILED))
      (fare-amount (get fare route-info))
      (fee (calculate-fee fare-amount (get fee-percentage method-info)))
      (total-amount (+ fare-amount fee))
      (current-balance (default-to u0 (get balance (map-get? user-balances { user: tx-sender }))))
      (payment-id (var-get next-payment-id))
    )
    (begin
      (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
      (asserts! (get active route-info) ERR-ROUTE-NOT-FOUND)
      (asserts! (get active method-info) ERR-PAYMENT-FAILED)
      (asserts! (>= current-balance total-amount) ERR-INSUFFICIENT-FUNDS)

      ;; Deduct from balance
      (map-set user-balances { user: tx-sender } { balance: (- current-balance total-amount) })

      ;; Record payment
      (map-set payments
        { payment-id: payment-id }
        {
          payer: tx-sender,
          amount: fare-amount,
          route: route,
          timestamp: block-height,
          payment-method: payment-method
        }
      )

      ;; Increment payment ID
      (var-set next-payment-id (+ payment-id u1))

      (ok payment-id)
    )
  )
)

;; Read-only Functions

;; Get user balance
(define-read-only (get-user-balance (user principal))
  (default-to u0 (get balance (map-get? user-balances { user: user })))
)

;; Get route fare
(define-read-only (get-route-fare (route (string-ascii 50)))
  (map-get? route-fares { route: route })
)

;; Get payment details
(define-read-only (get-payment (payment-id uint))
  (map-get? payments { payment-id: payment-id })
)

;; Get payment method info
(define-read-only (get-payment-method (method (string-ascii 20)))
  (map-get? payment-methods { method: method })
)

;; Admin Functions

;; Toggle contract active status
(define-public (toggle-contract-status)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-active (not (var-get contract-active))))
  )
)

;; Emergency withdraw
(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER))
  )
)
