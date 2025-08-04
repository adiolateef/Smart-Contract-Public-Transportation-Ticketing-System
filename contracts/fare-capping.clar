;; Fare Capping Contract
;; Automatically caps fares at daily or monthly limits

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-AMOUNT (err u201))
(define-constant ERR-INVALID-PERIOD (err u202))
(define-constant ERR-CAP-EXCEEDED (err u203))

;; Data Variables
(define-data-var daily-cap uint u500)
(define-data-var monthly-cap uint u12000)
(define-data-var contract-active bool true)

;; Data Maps
(define-map daily-usage
  { user: principal, day: uint }
  { amount-spent: uint, trips: uint }
)

(define-map monthly-usage
  { user: principal, month: uint }
  { amount-spent: uint, trips: uint }
)

(define-map user-caps
  { user: principal }
  { daily-cap: uint, monthly-cap: uint, custom: bool }
)

(define-map cap-refunds
  { user: principal, period: uint, period-type: (string-ascii 10) }
  { refund-amount: uint, processed: bool }
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (get-current-day)
  (/ block-height u144)
)

(define-private (get-current-month)
  (/ block-height u4320)
)

(define-private (get-user-daily-cap (user principal))
  (let
    ((user-cap-info (map-get? user-caps { user: user })))
    (if (is-some user-cap-info)
      (get daily-cap (unwrap-panic user-cap-info))
      (var-get daily-cap)
    )
  )
)

(define-private (get-user-monthly-cap (user principal))
  (let
    ((user-cap-info (map-get? user-caps { user: user })))
    (if (is-some user-cap-info)
      (get monthly-cap (unwrap-panic user-cap-info))
      (var-get monthly-cap)
    )
  )
)

;; Public Functions

;; Record fare payment and check caps
(define-public (record-fare-payment (user principal) (amount uint))
  (let
    (
      (current-day (get-current-day))
      (current-month (get-current-month))
      (daily-usage-info (default-to { amount-spent: u0, trips: u0 }
                                   (map-get? daily-usage { user: user, day: current-day })))
      (monthly-usage-info (default-to { amount-spent: u0, trips: u0 }
                                     (map-get? monthly-usage { user: user, month: current-month })))
      (user-daily-cap (get-user-daily-cap user))
      (user-monthly-cap (get-user-monthly-cap user))
      (new-daily-spent (+ (get amount-spent daily-usage-info) amount))
      (new-monthly-spent (+ (get amount-spent monthly-usage-info) amount))
    )
    (begin
      (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
      (asserts! (> amount u0) ERR-INVALID-AMOUNT)

      ;; Update daily usage
      (map-set daily-usage
        { user: user, day: current-day }
        {
          amount-spent: new-daily-spent,
          trips: (+ (get trips daily-usage-info) u1)
        }
      )

      ;; Update monthly usage
      (map-set monthly-usage
        { user: user, month: current-month }
        {
          amount-spent: new-monthly-spent,
          trips: (+ (get trips monthly-usage-info) u1)
        }
      )

      ;; Check if refund is needed
      (let
        (
          (daily-refund (if (> new-daily-spent user-daily-cap)
                           (- new-daily-spent user-daily-cap) u0))
          (monthly-refund (if (> new-monthly-spent user-monthly-cap)
                             (- new-monthly-spent user-monthly-cap) u0))
          (total-refund (if (> daily-refund monthly-refund) daily-refund monthly-refund))
        )
        (if (> total-refund u0)
          (begin
            (map-set cap-refunds
              { user: user, period: current-day, period-type: "daily" }
              { refund-amount: total-refund, processed: false }
            )
            (ok { charged: (- amount total-refund), refund: total-refund })
          )
          (ok { charged: amount, refund: u0 })
        )
      )
    )
  )
)

;; Set custom caps for user
(define-public (set-user-caps (user principal) (daily uint) (monthly uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (and (> daily u0) (> monthly u0)) ERR-INVALID-AMOUNT)
    (asserts! (< daily monthly) ERR-INVALID-AMOUNT)
    (ok (map-set user-caps
          { user: user }
          { daily-cap: daily, monthly-cap: monthly, custom: true }))
  )
)

;; Process refund
(define-public (process-refund (user principal) (period uint) (period-type (string-ascii 10)))
  (let
    (
      (refund-info (unwrap! (map-get? cap-refunds { user: user, period: period, period-type: period-type })
                           ERR-INVALID-PERIOD))
    )
    (begin
      (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
      (asserts! (not (get processed refund-info)) ERR-INVALID-PERIOD)

      ;; Mark as processed
      (map-set cap-refunds
        { user: user, period: period, period-type: period-type }
        { refund-amount: (get refund-amount refund-info), processed: true }
      )

      ;; Transfer refund (in real implementation, this would transfer STX)
      (ok (get refund-amount refund-info))
    )
  )
)

;; Read-only Functions

;; Get daily usage for user
(define-read-only (get-daily-usage (user principal))
  (let
    ((current-day (get-current-day)))
    (map-get? daily-usage { user: user, day: current-day })
  )
)

;; Get monthly usage for user
(define-read-only (get-monthly-usage (user principal))
  (let
    ((current-month (get-current-month)))
    (map-get? monthly-usage { user: user, month: current-month })
  )
)

;; Get user caps
(define-read-only (get-user-cap-info (user principal))
  (map-get? user-caps { user: user })
)

;; Check if user has reached daily cap
(define-read-only (has-reached-daily-cap (user principal))
  (let
    (
      (current-day (get-current-day))
      (usage-info (map-get? daily-usage { user: user, day: current-day }))
      (user-daily-cap (get-user-daily-cap user))
    )
    (match usage-info
      usage (>= (get amount-spent usage) user-daily-cap)
      false
    )
  )
)

;; Get pending refunds
(define-read-only (get-pending-refund (user principal) (period uint) (period-type (string-ascii 10)))
  (map-get? cap-refunds { user: user, period: period, period-type: period-type })
)

;; Admin Functions

;; Update default caps
(define-public (update-default-caps (daily uint) (monthly uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (and (> daily u0) (> monthly u0)) ERR-INVALID-AMOUNT)
    (asserts! (< daily monthly) ERR-INVALID-AMOUNT)
    (var-set daily-cap daily)
    (var-set monthly-cap monthly)
    (ok true)
  )
)

;; Toggle contract status
(define-public (toggle-contract-status)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-active (not (var-get contract-active))))
  )
)
