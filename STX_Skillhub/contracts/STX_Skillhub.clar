;; SkillHub - Decentralized Talent Marketplace
;; Smart contract for managing talent engagements, payments, and resolution

(define-constant contract-admin tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-ENGAGEMENT (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-ALREADY-FINALIZED (err u103))
(define-constant ERR-INVALID-RATING (err u104))
(define-constant ERR-NO-MEDIATOR (err u105))
(define-constant ERR-INVALID-INPUT (err u106))
(define-constant ERR-SELF-ENGAGEMENT (err u107))

;; Core data structures
(define-map Engagements
    { engagement-id: uint }
    {
        client: principal,
        talent: principal,
        payment-amount: uint,
        project-description: (string-ascii 512),
        engagement-status: (string-ascii 32),
        created-block: uint,
        finalized-block: uint,
        mediator: (optional principal)
    }
)

(define-map TalentProfiles
    { user-address: principal }
    {
        total-reviews: uint,
        review-score-sum: uint,
        projects-completed: uint,
        reputation-score: uint
    }
)

(define-data-var engagement-counter uint u0)
(define-data-var platform-fee-rate uint u250) ;; 2.5% = 250 basis points

;; Input validation helpers
(define-private (is-valid-principal (addr principal))
    (not (is-eq addr tx-sender)))

(define-private (is-valid-engagement-id (engagement-id uint))
    (and (> engagement-id u0) (<= engagement-id (var-get engagement-counter))))

(define-private (is-valid-description (desc (string-ascii 512)))
    (> (len desc) u0))

(define-private (is-valid-amount (amount uint))
    (> amount u0))

;; Create new talent engagement
(define-public (create-engagement (talent-address principal) (payment-amount uint) (project-description (string-ascii 512)))
    (let
        ((new-engagement-id (+ (var-get engagement-counter) u1))
         (platform-fee (/ (* payment-amount (var-get platform-fee-rate)) u10000)))
        
        ;; Input validation
        (asserts! (is-valid-principal talent-address) ERR-INVALID-INPUT)
        (asserts! (not (is-eq tx-sender talent-address)) ERR-SELF-ENGAGEMENT)
        (asserts! (is-valid-amount payment-amount) ERR-INVALID-INPUT)
        (asserts! (is-valid-description project-description) ERR-INVALID-INPUT)
        (asserts! (>= (stx-get-balance tx-sender) (+ payment-amount platform-fee)) ERR-INSUFFICIENT-BALANCE)
        
        (try! (stx-transfer? (+ payment-amount platform-fee) tx-sender (as-contract tx-sender)))
        (map-set Engagements
            { engagement-id: new-engagement-id }
            {
                client: tx-sender,
                talent: talent-address,
                payment-amount: payment-amount,
                project-description: project-description,
                engagement-status: "active",
                created-block: stacks-block-height,
                finalized-block: u0,
                mediator: none
            }
        )
        (var-set engagement-counter new-engagement-id)
        (ok new-engagement-id)))

;; Finalize engagement and release payment
(define-public (finalize-engagement (engagement-id uint))
    (let ((engagement (unwrap! (map-get? Engagements { engagement-id: engagement-id }) ERR-INVALID-ENGAGEMENT)))
        
        ;; Input validation
        (asserts! (is-valid-engagement-id engagement-id) ERR-INVALID-INPUT)
        (asserts! (is-eq (get engagement-status engagement) "active") ERR-ALREADY-FINALIZED)
        (asserts! (or (is-eq tx-sender (get client engagement)) 
                     (is-eq tx-sender (get talent engagement)))
                 ERR-UNAUTHORIZED)
        
        (try! (as-contract (stx-transfer? (get payment-amount engagement) tx-sender (get talent engagement))))
        (map-set Engagements
            { engagement-id: engagement-id }
            (merge engagement { 
                engagement-status: "completed",
                finalized-block: stacks-block-height
            })
        )
        (update-talent-stats (get talent engagement))
        (ok true)))

;; Submit review for talent
(define-public (submit-review (talent-address principal) (review-score uint))
    (let ((current-profile (default-to 
            { total-reviews: u0, review-score-sum: u0, projects-completed: u0, reputation-score: u0 }
            (map-get? TalentProfiles { user-address: talent-address }))))
        
        ;; Input validation
        (asserts! (is-valid-principal talent-address) ERR-INVALID-INPUT)
        (asserts! (and (>= review-score u1) (<= review-score u5)) ERR-INVALID-RATING)
        
        (let ((new-total-reviews (+ (get total-reviews current-profile) u1))
              (new-score-sum (+ (get review-score-sum current-profile) review-score)))
            (map-set TalentProfiles
                { user-address: talent-address }
                {
                    total-reviews: new-total-reviews,
                    review-score-sum: new-score-sum,
                    projects-completed: (get projects-completed current-profile),
                    reputation-score: (calculate-reputation new-total-reviews new-score-sum (get projects-completed current-profile))
                }
            ))
        (ok true)))

;; Request mediation
(define-public (request-mediation (engagement-id uint) (mediator-address principal))
    (let ((engagement (unwrap! (map-get? Engagements { engagement-id: engagement-id }) ERR-INVALID-ENGAGEMENT)))
        
        ;; Input validation
        (asserts! (is-valid-engagement-id engagement-id) ERR-INVALID-INPUT)
        (asserts! (is-valid-principal mediator-address) ERR-INVALID-INPUT)
        (asserts! (is-eq (get engagement-status engagement) "active") ERR-ALREADY-FINALIZED)
        (asserts! (or (is-eq tx-sender (get client engagement)) 
                     (is-eq tx-sender (get talent engagement)))
                 ERR-UNAUTHORIZED)
        
        (map-set Engagements
            { engagement-id: engagement-id }
            (merge engagement { 
                engagement-status: "mediation",
                mediator: (some mediator-address)
            })
        )
        (ok true)))

;; Resolve mediation
(define-public (resolve-mediation (engagement-id uint) (payment-recipient principal))
    (let ((engagement (unwrap! (map-get? Engagements { engagement-id: engagement-id }) ERR-INVALID-ENGAGEMENT)))
        
        ;; Input validation
        (asserts! (is-valid-engagement-id engagement-id) ERR-INVALID-INPUT)
        (asserts! (is-valid-principal payment-recipient) ERR-INVALID-INPUT)
        (asserts! (is-eq (get engagement-status engagement) "mediation") ERR-INVALID-ENGAGEMENT)
        (asserts! (is-eq tx-sender (unwrap! (get mediator engagement) ERR-NO-MEDIATOR))
                 ERR-UNAUTHORIZED)
        
        (try! (as-contract (stx-transfer? (get payment-amount engagement) tx-sender payment-recipient)))
        (map-set Engagements
            { engagement-id: engagement-id }
            (merge engagement { 
                engagement-status: "resolved",
                finalized-block: stacks-block-height
            })
        )
        (ok true)))

;; Update platform fee (admin only)
(define-public (update-platform-fee (new-fee-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-admin) ERR-UNAUTHORIZED)
        (asserts! (<= new-fee-rate u1000) ERR-INVALID-RATING) ;; Max 10%
        (var-set platform-fee-rate new-fee-rate)
        (ok true)))

;; Internal helper functions
(define-private (update-talent-stats (talent-address principal))
    (let ((current-profile (default-to 
            { total-reviews: u0, review-score-sum: u0, projects-completed: u0, reputation-score: u0 }
            (map-get? TalentProfiles { user-address: talent-address }))))
        (map-set TalentProfiles
            { user-address: talent-address }
            (merge current-profile { 
                projects-completed: (+ (get projects-completed current-profile) u1)
            })
        )))

(define-private (calculate-reputation (total-reviews uint) (score-sum uint) (projects-completed uint))
    (if (> total-reviews u0)
        (+ (/ (* score-sum u20) total-reviews) projects-completed)
        projects-completed))

;; Read-only functions
(define-read-only (get-engagement (engagement-id uint))
    (if (is-valid-engagement-id engagement-id)
        (map-get? Engagements { engagement-id: engagement-id })
        none))

(define-read-only (get-talent-profile (talent-address principal))
    (let ((profile (map-get? TalentProfiles { user-address: talent-address })))
        (match profile
            some-profile (ok {
                average-rating: (if (> (get total-reviews some-profile) u0)
                                  (/ (get review-score-sum some-profile) (get total-reviews some-profile))
                                  u0),
                total-reviews: (get total-reviews some-profile),
                projects-completed: (get projects-completed some-profile),
                reputation-score: (get reputation-score some-profile)
            })
            (err ERR-INVALID-INPUT))))

(define-read-only (get-platform-fee-rate)
    (var-get platform-fee-rate))

(define-read-only (get-engagement-count)
    (var-get engagement-counter))

;; Additional validation functions
(define-read-only (is-engagement-active (engagement-id uint))
    (match (get-engagement engagement-id)
        some-engagement (is-eq (get engagement-status some-engagement) "active")
        false))

(define-read-only (get-engagement-status (engagement-id uint))
    (match (get-engagement engagement-id)
        some-engagement (some (get engagement-status some-engagement))
        none))