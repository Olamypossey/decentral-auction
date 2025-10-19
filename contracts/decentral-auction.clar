;; Use built-in block height

(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_AUCTION_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_ENDED (err u102))
(define-constant ERR_AUCTION_NOT_ENDED (err u103))
(define-constant ERR_LOW_BID (err u104))
(define-constant ERR_SELF_BID (err u105))

(define-constant contract-owner tx-sender)
(define-constant initial-block-height u0)
(define-data-var auction-counter uint u0)

(define-map auctions
  { id: uint }
  {
    creator: principal,
    item-name: (string-ascii 100),
    description: (string-ascii 200),
    min-bid: uint,
    highest-bid: uint,
    highest-bidder: (optional principal),
    end-block: uint,
    active: bool,
    closed: bool
  }
)

(define-map bids
  { id: uint, bidder: principal }
  { amount: uint })

;; ===============================================================
;; CREATE AUCTION
;; ===============================================================

(define-public (create-auction
  (item-name (string-ascii 100))
  (description (string-ascii 200))
  (min-bid uint)
  (duration uint))
  (let ((id (+ (var-get auction-counter) u1)))
    (begin
      (map-set auctions { id: id }
        {
          creator: tx-sender,
          item-name: item-name,
          description: description,
          end-block: (+ burn-block-height duration),
          highest-bid: u0,
          highest-bidder: none,
          min-bid: min-bid,
          active: true,
          closed: false
        })
      (var-set auction-counter id)
      (ok id)
    )
  )
)

;; ===============================================================
;; PLACE BID
;; ===============================================================

(define-public (place-bid (id uint))
  (let ((auction (map-get? auctions { id: id })))
    (if (is-some auction)
        (let (
          (data (unwrap-panic auction))
          (end (get end-block data))
          (min-bid (get min-bid data))
          (high-bid (get highest-bid data))
          (new-bid (stx-get-balance tx-sender)) ;; Get sender's STX balance
        )
          (if (and (< burn-block-height end) (get active data))
              (if (and (> new-bid min-bid) (> new-bid high-bid))
                  (begin
                    ;; refund previous highest bidder
                    (if (is-some (get highest-bidder data))
                        (let ((prev (unwrap-panic (get highest-bidder data))))
                          (unwrap-panic (stx-transfer? (get highest-bid data) tx-sender prev))
                        )
                        true
                    )
                    ;; record new bid
                    (map-set auctions { id: id }
                      (merge data {
                        highest-bid: new-bid,
                        highest-bidder: (some tx-sender)
                      })
                    )
                    (map-set bids { id: id, bidder: tx-sender } { amount: new-bid })
                    (ok "Bid placed successfully")
                  )
                  ERR_LOW_BID
              )
              ERR_ALREADY_ENDED
          )
        )
        ERR_AUCTION_NOT_FOUND
    )
  )
)
    
(define-public (close-auction (id uint))
  (let ((auction (map-get? auctions { id: id })))
    (if (is-some auction)
        (let ((data (unwrap-panic auction)))
          (if (>= burn-block-height (get end-block data))
              (if (not (get closed data))
                  (if (or (is-eq tx-sender contract-owner) (is-eq tx-sender (get creator data)))
                      (begin
                        (map-set auctions { id: id } (merge data { active: false, closed: true }))

                        (if (is-some (get highest-bidder data))
                            (let (
                              (winner (unwrap-panic (get highest-bidder data)))
                              (amount (get highest-bid data))
                            )
                              ;; send highest bid amount to auction creator
                              (match (stx-transfer? amount tx-sender (get creator data))
                                success (ok { winner: winner, amount: amount })
                                error (err error))
                            )
                            (ok { winner: tx-sender, amount: u0 })
                        )
                      )
                      ERR_UNAUTHORIZED
                  )
                  ERR_ALREADY_ENDED
              )
              ERR_AUCTION_NOT_ENDED
          )
        )
        ERR_AUCTION_NOT_FOUND
    )
  )
)

(define-read-only (get-auction (id uint))
  (map-get? auctions { id: id })
)

(define-read-only (get-highest-bid (id uint))
  (let ((auction (map-get? auctions { id: id })))
    (if (is-some auction)
        (ok {
          bidder: (get highest-bidder (unwrap-panic auction)),
          amount: (get highest-bid (unwrap-panic auction))
        })
        ERR_AUCTION_NOT_FOUND
    )
  )
)

(define-read-only (get-total-auctions)
  (var-get auction-counter)
)
