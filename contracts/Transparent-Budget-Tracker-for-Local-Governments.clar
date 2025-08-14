(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-PROJECT-EXISTS (err u102))
(define-constant ERR-PROJECT-NOT-FOUND (err u103))
(define-constant ERR-MILESTONE-NOT-FOUND (err u104))
(define-constant ERR-INSUFFICIENT-VOTES (err u105))
(define-constant ERR-NOT-TREASURY-MEMBER (err u200))
(define-constant ERR-ALREADY-APPROVED (err u201))
(define-constant ERR-INSUFFICIENT-APPROVALS (err u202))
(define-constant ERR-TRANSFER-FAILED (err u203))
(define-constant ERR-VARIANCE-EXISTS (err u204))
(define-constant ERR-VARIANCE-NOT-FOUND (err u205))

(define-data-var governance-token-address principal 'SP000000000000000000002Q6VF78.governance-token)
(define-data-var min-votes uint u100)
(define-data-var treasury-address principal 'SP000000000000000000002Q6VF78.treasury)
(define-data-var required-approvals uint u3)

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

(define-map treasury-members principal bool)

(define-map fund-requests
    { request-id: uint }
    {
        project-id: uint,
        milestone-id: uint,
        amount: uint,
        recipient: principal,
        approvals: uint,
        executed: bool,
        created-at: uint
    }
)

(define-map request-approvals
    { request-id: uint, approver: principal }
    { approved: bool }
)

(define-map project-categories
    { category-id: uint }
    {
        name: (string-ascii 30),
        total-allocated: uint,
        total-spent: uint,
        project-count: uint
    }
)

(define-map project-category-mapping
    { project-id: uint }
    { category-id: uint }
)

(define-map spending-reports
    { report-id: uint }
    {
        period-start: uint,
        period-end: uint,
        total-budget: uint,
        total-spent: uint,
        active-projects: uint,
        completed-projects: uint,
        created-at: uint
    }
)

(define-map monthly-spending
    { year: uint, month: uint }
    {
        total-spent: uint,
        transaction-count: uint,
        average-transaction: uint
    }
)

(define-map budget-variances
    { variance-id: uint }
    {
        project-id: uint,
        budgeted-amount: uint,
        actual-amount: uint,
        variance-percentage: int,
        variance-status: (string-ascii 20),
        created-at: uint,
        analysis-period: uint
    }
)

(define-map project-variance-tracking
    { project-id: uint }
    {
        current-variance-id: uint,
        total-budget-allocated: uint,
        total-amount-spent: uint,
        last-updated: uint
    }
)

(define-data-var project-counter uint u0)
(define-data-var request-counter uint u0)
(define-data-var category-counter uint u0)
(define-data-var report-counter uint u0)
(define-data-var variance-counter uint u0)

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

(define-public (add-treasury-member (member principal))
    (begin
        (asserts! (is-eq tx-sender contract-caller) ERR-NOT-AUTHORIZED)
        (map-set treasury-members member true)
        (ok true)
    )
)

(define-public (remove-treasury-member (member principal))
    (begin
        (asserts! (is-eq tx-sender contract-caller) ERR-NOT-AUTHORIZED)
        (map-delete treasury-members member)
        (ok true)
    )
)

(define-public (create-fund-request (project-id uint) (milestone-id uint) (amount uint) (recipient principal))
    (let ((request-id (+ (var-get request-counter) u1)))
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (map-insert fund-requests
            { request-id: request-id }
            {
                project-id: project-id,
                milestone-id: milestone-id,
                amount: amount,
                recipient: recipient,
                approvals: u0,
                executed: false,
                created-at: stacks-block-height
            }
        )
        (var-set request-counter request-id)
        (ok request-id)
    )
)

(define-public (approve-fund-request (request-id uint))
    (let (
        (request (unwrap! (map-get? fund-requests { request-id: request-id }) ERR-PROJECT-NOT-FOUND))
        (approval-key { request-id: request-id, approver: tx-sender })
    )
        (asserts! (default-to false (map-get? treasury-members tx-sender)) ERR-NOT-TREASURY-MEMBER)
        (asserts! (not (default-to false (get approved (map-get? request-approvals approval-key)))) ERR-ALREADY-APPROVED)
        (map-set request-approvals approval-key { approved: true })
        (map-set fund-requests
            { request-id: request-id }
            (merge request { approvals: (+ (get approvals request) u1) })
        )
        (ok true)
    )
)

(define-public (execute-fund-request (request-id uint))
    (let ((request (unwrap! (map-get? fund-requests { request-id: request-id }) ERR-PROJECT-NOT-FOUND)))
        (asserts! (>= (get approvals request) (var-get required-approvals)) ERR-INSUFFICIENT-APPROVALS)
        (asserts! (not (get executed request)) ERR-NOT-AUTHORIZED)
        (try! (stx-transfer? (get amount request) (as-contract tx-sender) (get recipient request)))
        (map-set fund-requests
            { request-id: request-id }
            (merge request { executed: true })
        )
        (ok true)
    )
)

(define-public (create-category (name (string-ascii 30)))
    (let ((category-id (+ (var-get category-counter) u1)))
        (asserts! (is-eq tx-sender contract-caller) ERR-NOT-AUTHORIZED)
        (map-insert project-categories
            { category-id: category-id }
            {
                name: name,
                total-allocated: u0,
                total-spent: u0,
                project-count: u0
            }
        )
        (var-set category-counter category-id)
        (ok category-id)
    )
)

(define-public (assign-project-category (project-id uint) (category-id uint))
    (let (
        (project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
        (category (unwrap! (map-get? project-categories { category-id: category-id }) ERR-PROJECT-NOT-FOUND))
    )
        (asserts! (is-eq (get owner project) tx-sender) ERR-NOT-AUTHORIZED)
        (map-set project-category-mapping
            { project-id: project-id }
            { category-id: category-id }
        )
        (map-set project-categories
            { category-id: category-id }
            (merge category {
                total-allocated: (+ (get total-allocated category) (get total-budget project)),
                project-count: (+ (get project-count category) u1)
            })
        )
        (ok true)
    )
)

(define-public (update-spending-record (project-id uint) (amount uint))
    (let (
        (category-mapping (map-get? project-category-mapping { project-id: project-id }))
        (current-month (mod stacks-block-height u4320))
        (current-year (/ stacks-block-height u52560))
    )
        (match category-mapping
            mapping (let ((category (unwrap! (map-get? project-categories { category-id: (get category-id mapping) }) ERR-PROJECT-NOT-FOUND)))
                (map-set project-categories
                    { category-id: (get category-id mapping) }
                    (merge category { total-spent: (+ (get total-spent category) amount) })
                )
            )
            true
        )
        (let ((monthly-data (default-to { total-spent: u0, transaction-count: u0, average-transaction: u0 }
                                       (map-get? monthly-spending { year: current-year, month: current-month }))))
            (map-set monthly-spending
                { year: current-year, month: current-month }
                {
                    total-spent: (+ (get total-spent monthly-data) amount),
                    transaction-count: (+ (get transaction-count monthly-data) u1),
                    average-transaction: (/ (+ (get total-spent monthly-data) amount) (+ (get transaction-count monthly-data) u1))
                }
            )
        )
        (ok true)
    )
)

(define-public (generate-spending-report (period-start uint) (period-end uint))
    (let (
        (report-id (+ (var-get report-counter) u1))
        (total-budget (calculate-total-budget))
        (total-spent (calculate-total-spent))
        (active-count (count-active-projects))
        (completed-count (count-completed-projects))
    )
        (map-insert spending-reports
            { report-id: report-id }
            {
                period-start: period-start,
                period-end: period-end,
                total-budget: total-budget,
                total-spent: total-spent,
                active-projects: active-count,
                completed-projects: completed-count,
                created-at: stacks-block-height
            }
        )
        (var-set report-counter report-id)
        (ok report-id)
    )
)

(define-read-only (get-project (project-id uint))
    (ok (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
)

(define-read-only (get-milestone (project-id uint) (milestone-id uint))
    (ok (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) ERR-MILESTONE-NOT-FOUND))
)

(define-read-only (get-fund-request (request-id uint))
    (ok (unwrap! (map-get? fund-requests { request-id: request-id }) ERR-PROJECT-NOT-FOUND))
)

(define-read-only (is-treasury-member (member principal))
    (ok (default-to false (map-get? treasury-members member)))
)

(define-read-only (get-category (category-id uint))
    (ok (unwrap! (map-get? project-categories { category-id: category-id }) ERR-PROJECT-NOT-FOUND))
)

(define-read-only (get-project-category (project-id uint))
    (ok (map-get? project-category-mapping { project-id: project-id }))
)

(define-read-only (get-spending-report (report-id uint))
    (ok (unwrap! (map-get? spending-reports { report-id: report-id }) ERR-PROJECT-NOT-FOUND))
)

(define-read-only (get-monthly-spending (year uint) (month uint))
    (ok (map-get? monthly-spending { year: year, month: month }))
)

(define-private (calculate-total-budget)
    u1000000
)

(define-private (calculate-total-spent)
    u500000
)

(define-private (count-active-projects)
    u10
)

(define-private (count-completed-projects)
    u5
)

(define-public (create-budget-variance (project-id uint) (budgeted-amount uint) (actual-amount uint))
    (let (
        (variance-id (+ (var-get variance-counter) u1))
        (variance-percentage (calculate-variance-percentage budgeted-amount actual-amount))
        (variance-status (determine-variance-status variance-percentage))
    )
        (asserts! (is-some (map-get? projects { project-id: project-id })) ERR-PROJECT-NOT-FOUND)
        (asserts! (> budgeted-amount u0) ERR-INVALID-AMOUNT)
        (map-insert budget-variances
            { variance-id: variance-id }
            {
                project-id: project-id,
                budgeted-amount: budgeted-amount,
                actual-amount: actual-amount,
                variance-percentage: variance-percentage,
                variance-status: variance-status,
                created-at: stacks-block-height,
                analysis-period: u30
            }
        )
        (map-set project-variance-tracking
            { project-id: project-id }
            {
                current-variance-id: variance-id,
                total-budget-allocated: budgeted-amount,
                total-amount-spent: actual-amount,
                last-updated: stacks-block-height
            }
        )
        (var-set variance-counter variance-id)
        (ok variance-id)
    )
)

(define-public (update-project-spending (project-id uint) (new-spending uint))
    (let (
        (project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
        (current-tracking (unwrap! (map-get? project-variance-tracking { project-id: project-id }) ERR-VARIANCE-NOT-FOUND))
    )
        (asserts! (> new-spending u0) ERR-INVALID-AMOUNT)
        (let (
            (updated-total (+ (get total-amount-spent current-tracking) new-spending))
            (variance-percentage (calculate-variance-percentage (get total-budget-allocated current-tracking) updated-total))
            (variance-status (determine-variance-status variance-percentage))
            (variance-id (+ (var-get variance-counter) u1))
        )
            (map-insert budget-variances
                { variance-id: variance-id }
                {
                    project-id: project-id,
                    budgeted-amount: (get total-budget-allocated current-tracking),
                    actual-amount: updated-total,
                    variance-percentage: variance-percentage,
                    variance-status: variance-status,
                    created-at: stacks-block-height,
                    analysis-period: u30
                }
            )
            (map-set project-variance-tracking
                { project-id: project-id }
                {
                    current-variance-id: variance-id,
                    total-budget-allocated: (get total-budget-allocated current-tracking),
                    total-amount-spent: updated-total,
                    last-updated: stacks-block-height
                }
            )
            (var-set variance-counter variance-id)
            (ok variance-id)
        )
    )
)

(define-read-only (get-budget-variance (variance-id uint))
    (ok (unwrap! (map-get? budget-variances { variance-id: variance-id }) ERR-VARIANCE-NOT-FOUND))
)

(define-read-only (get-project-variance-status (project-id uint))
    (ok (map-get? project-variance-tracking { project-id: project-id }))
)

(define-read-only (check-budget-alerts (project-id uint))
    (match (map-get? project-variance-tracking { project-id: project-id })
        tracking (let (
            (variance-percentage (calculate-variance-percentage 
                (get total-budget-allocated tracking) 
                (get total-amount-spent tracking)
            ))
        )
            (ok {
                over-budget: (> variance-percentage 0),
                critical-alert: (> variance-percentage 25),
                variance-percentage: variance-percentage
            })
        )
        (ok { over-budget: false, critical-alert: false, variance-percentage: 0 })
    )
)

(define-private (calculate-variance-percentage (budgeted uint) (actual uint))
    (if (is-eq budgeted u0)
        0
        (/ (* (- (to-int actual) (to-int budgeted)) 100) (to-int budgeted))
    )
)

(define-private (determine-variance-status (variance-percentage int))
    (if (> variance-percentage 25)
        "critical-overspend"
        (if (> variance-percentage 0)
            "over-budget"
            (if (< variance-percentage -10)
                "under-budget"
                "on-track"
            )
        )
    )
)
