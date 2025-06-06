(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-PROJECT-EXISTS (err u102))
(define-constant ERR-PROJECT-NOT-FOUND (err u103))
(define-constant ERR-MILESTONE-NOT-FOUND (err u104))
(define-constant ERR-INSUFFICIENT-VOTES (err u105))

(define-data-var governance-token-address principal 'SP000000000000000000002Q6VF78.governance-token)
(define-data-var min-votes uint u100)
(define-data-var treasury-address principal 'SP000000000000000000002Q6VF78.treasury)

(define-map projects 
    { project-id: uint }
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        total-budget: uint,
        released-amount: uint,
        status: (string-ascii 20),
        owner: principal
    }
)

(define-map milestones
    { project-id: uint, milestone-id: uint }
    {
        description: (string-ascii 100),
        amount: uint,
        due-date: uint,
        status: (string-ascii 20),
        votes: uint
    }
)

(define-map votes
    { project-id: uint, milestone-id: uint, voter: principal }
    { voted: bool }
)

(define-data-var project-counter uint u0)

(define-public (create-project (name (string-ascii 50)) (description (string-ascii 200)) (total-budget uint))
    (let ((project-id (+ (var-get project-counter) u1)))
        (asserts! (is-eq tx-sender contract-caller) ERR-NOT-AUTHORIZED)
        (asserts! (> total-budget u0) ERR-INVALID-AMOUNT)
        (asserts! (map-insert projects
            { project-id: project-id }
            {
                name: name,
                description: description,
                total-budget: total-budget,
                released-amount: u0,
                status: "active",
                owner: tx-sender
            }
        ) ERR-PROJECT-EXISTS)
        (var-set project-counter project-id)
        (ok project-id)
    )
)

(define-public (add-milestone (project-id uint) (description (string-ascii 100)) (amount uint) (due-date uint))
    (let ((project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND)))
        (asserts! (is-eq (get owner project) tx-sender) ERR-NOT-AUTHORIZED)
        (map-insert milestones
            { project-id: project-id, milestone-id: u1 }
            {
                description: description,
                amount: amount,
                due-date: due-date,
                status: "pending",
                votes: u0
            }
        )
        (ok true)
    )
)

(define-public (vote-milestone (project-id uint) (milestone-id uint))
    (let (
        (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) ERR-MILESTONE-NOT-FOUND))
        (vote-key { project-id: project-id, milestone-id: milestone-id, voter: tx-sender })
    )
        (asserts! (not (default-to false (get voted (map-get? votes vote-key)))) ERR-NOT-AUTHORIZED)
        (map-set votes vote-key { voted: true })
        (map-set milestones 
            { project-id: project-id, milestone-id: milestone-id }
            (merge milestone { votes: (+ (get votes milestone) u1) })
        )
        (ok true)
    )
)

(define-public (release-funds (project-id uint) (milestone-id uint))
    (let (
        (project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
        (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) ERR-MILESTONE-NOT-FOUND))
    )
        (asserts! (>= (get votes milestone) (var-get min-votes)) ERR-INSUFFICIENT-VOTES)
        (asserts! (is-eq (get owner project) tx-sender) ERR-NOT-AUTHORIZED)
        (map-set projects
            { project-id: project-id }
            (merge project { released-amount: (+ (get released-amount project) (get amount milestone)) })
        )
        (map-set milestones
            { project-id: project-id, milestone-id: milestone-id }
            (merge milestone { status: "completed" })
        )
        (ok true)
    )
)

(define-read-only (get-project (project-id uint))
    (ok (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
)

(define-read-only (get-milestone (project-id uint) (milestone-id uint))
    (ok (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) ERR-MILESTONE-NOT-FOUND))
)
