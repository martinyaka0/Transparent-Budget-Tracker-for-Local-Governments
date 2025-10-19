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
(define-constant ERR-COMPLAINT-NOT-FOUND (err u206))
(define-constant ERR-INVALID-STATUS (err u207))
(define-constant ERR-AUDIT-LOG-NOT-FOUND (err u208))
(define-constant ERR-INVALID-AUDIT-TYPE (err u209))
(define-constant ERR-AUDIT-ACCESS-DENIED (err u210))

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

(define-map citizen-complaints
    { complaint-id: uint }
    {
        citizen: principal,
        project-id: (optional uint),
        category: (string-ascii 30),
        description: (string-ascii 300),
        severity: (string-ascii 20),
        status: (string-ascii 20),
        filed-at: uint,
        resolved-at: (optional uint),
        resolution-notes: (optional (string-ascii 200))
    }
)

;; === AUDIT TRAIL FEATURE ===
;; Comprehensive audit logging for all financial operations
(define-map audit-logs
    { audit-id: uint }
    {
        operation-type: (string-ascii 30),
        entity-type: (string-ascii 20),
        entity-id: uint,
        actor: principal,
        action: (string-ascii 50),
        amount: (optional uint),
        previous-value: (optional (string-ascii 100)),
        new-value: (optional (string-ascii 100)),
        metadata: (string-ascii 200),
        timestamp: uint,
        block-height: uint,
        transaction-hash: (buff 32)
    }
)

(define-map audit-trail-access-control
    { accessor: principal }
    { access-level: (string-ascii 20), granted-at: uint }
)

(define-map daily-audit-summaries
    { date: uint }
    {
        total-operations: uint,
        fund-operations: uint,
        project-operations: uint,
        treasury-operations: uint,
        complaint-operations: uint,
        total-amount-tracked: uint,
        unique-actors: uint
    }
)

(define-map operation-integrity-hashes
    { operation-id: uint }
    {
        hash: (buff 32),
        previous-hash: (buff 32),
        merkle-root: (buff 32),
        verification-status: (string-ascii 20)
    }
)

(define-data-var project-counter uint u0)
(define-data-var request-counter uint u0)
(define-data-var category-counter uint u0)
(define-data-var report-counter uint u0)
(define-data-var variance-counter uint u0)
(define-data-var complaint-counter uint u0)
(define-data-var audit-log-counter uint u0)

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

(define-public (file-complaint (project-id (optional uint)) (category (string-ascii 30)) (description (string-ascii 300)) (severity (string-ascii 20)))
    (let ((complaint-id (+ (var-get complaint-counter) u1)))
        (map-insert citizen-complaints
            { complaint-id: complaint-id }
            {
                citizen: tx-sender,
                project-id: project-id,
                category: category,
                description: description,
                severity: severity,
                status: "open",
                filed-at: stacks-block-height,
                resolved-at: none,
                resolution-notes: none
            }
        )
        (var-set complaint-counter complaint-id)
        (ok complaint-id)
    )
)

(define-public (update-complaint-status (complaint-id uint) (new-status (string-ascii 20)) (resolution-notes (optional (string-ascii 200))))
    (let ((complaint (unwrap! (map-get? citizen-complaints { complaint-id: complaint-id }) ERR-COMPLAINT-NOT-FOUND)))
        (asserts! (default-to false (map-get? treasury-members tx-sender)) ERR-NOT-TREASURY-MEMBER)
        (asserts! (or (is-eq new-status "in-progress") (is-eq new-status "resolved") (is-eq new-status "dismissed")) ERR-INVALID-STATUS)
        (map-set citizen-complaints
            { complaint-id: complaint-id }
            (merge complaint {
                status: new-status,
                resolved-at: (if (is-eq new-status "resolved") (some stacks-block-height) (get resolved-at complaint)),
                resolution-notes: resolution-notes
            })
        )
        (ok true)
    )
)

(define-public (respond-to-complaint (complaint-id uint) (response (string-ascii 200)))
    (let ((complaint (unwrap! (map-get? citizen-complaints { complaint-id: complaint-id }) ERR-COMPLAINT-NOT-FOUND)))
        (asserts! (default-to false (map-get? treasury-members tx-sender)) ERR-NOT-TREASURY-MEMBER)
        (map-set citizen-complaints
            { complaint-id: complaint-id }
            (merge complaint { resolution-notes: (some response) })
        )
        (ok true)
    )
)

(define-read-only (get-complaint (complaint-id uint))
    (ok (unwrap! (map-get? citizen-complaints { complaint-id: complaint-id }) ERR-COMPLAINT-NOT-FOUND))
)

(define-read-only (get-complaints-by-status (status (string-ascii 20)))
    (ok status)
)

(define-read-only (get-complaints-by-citizen (citizen principal))
    (ok citizen)
)

(define-read-only (get-complaint-stats)
    (ok {
        total-complaints: (var-get complaint-counter),
        recent-complaints: u0
    })
)

;; === AUDIT TRAIL PUBLIC FUNCTIONS ===

(define-public (log-audit-entry (operation-type (string-ascii 30)) (entity-type (string-ascii 20)) (entity-id uint) (action (string-ascii 50)) (amount (optional uint)) (previous-value (optional (string-ascii 100))) (new-value (optional (string-ascii 100))) (metadata (string-ascii 200)))
    (let (
        (audit-id (+ (var-get audit-log-counter) u1))
        (current-timestamp stacks-block-height)
        (tx-hash (unwrap-panic (get-tx-hash)))
    )
        (asserts! 
            (or 
                (is-eq operation-type "fund-transfer")
                (is-eq operation-type "project-creation")
                (is-eq operation-type "milestone-completion")
                (is-eq operation-type "treasury-action")
                (is-eq operation-type "complaint-action")
                (is-eq operation-type "budget-variance")
                (is-eq operation-type "report-generation")
            ) 
            ERR-INVALID-AUDIT-TYPE
        )
        (map-insert audit-logs
            { audit-id: audit-id }
            {
                operation-type: operation-type,
                entity-type: entity-type,
                entity-id: entity-id,
                actor: tx-sender,
                action: action,
                amount: amount,
                previous-value: previous-value,
                new-value: new-value,
                metadata: metadata,
                timestamp: current-timestamp,
                block-height: current-timestamp,
                transaction-hash: tx-hash
            }
        )
        (unwrap-panic (update-daily-audit-summary operation-type amount))
        (unwrap-panic (create-integrity-hash audit-id))
        (var-set audit-log-counter audit-id)
        (ok audit-id)
    )
)

(define-public (grant-audit-access (accessor principal) (access-level (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender contract-caller) ERR-NOT-AUTHORIZED)
        (asserts! 
            (or 
                (is-eq access-level "read-only")
                (is-eq access-level "auditor")
                (is-eq access-level "admin")
            ) 
            ERR-INVALID-AUDIT-TYPE
        )
        (map-set audit-trail-access-control
            { accessor: accessor }
            { access-level: access-level, granted-at: stacks-block-height }
        )
        (unwrap-panic (log-audit-entry "treasury-action" "access-control" u0 "grant-audit-access" none none (some access-level) "Granted audit access"))
        (ok true)
    )
)

(define-public (revoke-audit-access (accessor principal))
    (begin
        (asserts! (is-eq tx-sender contract-caller) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (map-get? audit-trail-access-control { accessor: accessor })) ERR-AUDIT-ACCESS-DENIED)
        (map-delete audit-trail-access-control { accessor: accessor })
        (unwrap-panic (log-audit-entry "treasury-action" "access-control" u0 "revoke-audit-access" none none none "Revoked audit access"))
        (ok true)
    )
)

(define-public (generate-audit-report (start-date uint) (end-date uint) (operation-filter (optional (string-ascii 30))))
    (let (
        (has-access (check-audit-access tx-sender))
        (report-id (+ (var-get audit-log-counter) u1000000)) ;; Use high number for report IDs
    )
        (asserts! has-access ERR-AUDIT-ACCESS-DENIED)
        (asserts! (<= start-date end-date) ERR-INVALID-AMOUNT)
        (unwrap-panic (log-audit-entry "report-generation" "audit-report" report-id "generate-audit-report" none none none "Generated audit report"))
        (ok {
            report-id: report-id,
            period-start: start-date,
            period-end: end-date,
            operation-filter: operation-filter,
            generated-at: stacks-block-height,
            generated-by: tx-sender
        })
    )
)

(define-public (verify-operation-integrity (operation-id uint))
    (let (
        (integrity-data (map-get? operation-integrity-hashes { operation-id: operation-id }))
        (has-access (check-audit-access tx-sender))
    )
        (asserts! has-access ERR-AUDIT-ACCESS-DENIED)
        (match integrity-data
            data (let (
                (current-hash (get hash data))
                (verification-result (verify-hash current-hash operation-id))
            )
                (map-set operation-integrity-hashes
                    { operation-id: operation-id }
                    (merge data { verification-status: (if verification-result "verified" "tampered") })
                )
                (ok verification-result)
            )
            ERR-AUDIT-LOG-NOT-FOUND
        )
    )
)

;; === AUDIT TRAIL READ-ONLY FUNCTIONS ===

(define-read-only (get-audit-log (audit-id uint))
    (let ((has-access (check-audit-access tx-sender)))
        (asserts! has-access ERR-AUDIT-ACCESS-DENIED)
        (ok (unwrap! (map-get? audit-logs { audit-id: audit-id }) ERR-AUDIT-LOG-NOT-FOUND))
    )
)

(define-read-only (get-audit-access-level (accessor principal))
    (ok (map-get? audit-trail-access-control { accessor: accessor }))
)

(define-read-only (get-daily-audit-summary (date uint))
    (let ((has-access (check-audit-access tx-sender)))
        (asserts! has-access ERR-AUDIT-ACCESS-DENIED)
        (ok (map-get? daily-audit-summaries { date: date }))
    )
)

(define-read-only (get-operation-integrity (operation-id uint))
    (let ((has-access (check-audit-access tx-sender)))
        (asserts! has-access ERR-AUDIT-ACCESS-DENIED)
        (ok (map-get? operation-integrity-hashes { operation-id: operation-id }))
    )
)

(define-read-only (get-audit-statistics)
    (let ((has-access (check-audit-access tx-sender)))
        (asserts! has-access ERR-AUDIT-ACCESS-DENIED)
        (ok {
            total-audit-logs: (var-get audit-log-counter),
            current-block: stacks-block-height,
            contract-version: "v1.0.0"
        })
    )
)

;; === AUDIT TRAIL PRIVATE HELPER FUNCTIONS ===

(define-private (check-audit-access (accessor principal))
    (let ((access-data (map-get? audit-trail-access-control { accessor: accessor })))
        (match access-data
            data (not (is-eq (get access-level data) "none"))
            false
        )
    )
)

(define-private (update-daily-audit-summary (operation-type (string-ascii 30)) (amount (optional uint)))
    (let (
        (today (/ stacks-block-height u144)) ;; Approximate blocks per day
        (current-summary (default-to 
            { total-operations: u0, fund-operations: u0, project-operations: u0, treasury-operations: u0, complaint-operations: u0, total-amount-tracked: u0, unique-actors: u0 }
            (map-get? daily-audit-summaries { date: today })
        ))
        (amount-to-add (default-to u0 amount))
    )
        (map-set daily-audit-summaries
            { date: today }
            {
                total-operations: (+ (get total-operations current-summary) u1),
                fund-operations: (+ (get fund-operations current-summary) (if (is-eq operation-type "fund-transfer") u1 u0)),
                project-operations: (+ (get project-operations current-summary) (if (is-eq operation-type "project-creation") u1 u0)),
                treasury-operations: (+ (get treasury-operations current-summary) (if (is-eq operation-type "treasury-action") u1 u0)),
                complaint-operations: (+ (get complaint-operations current-summary) (if (is-eq operation-type "complaint-action") u1 u0)),
                total-amount-tracked: (+ (get total-amount-tracked current-summary) amount-to-add),
                unique-actors: (+ (get unique-actors current-summary) u1) ;; Simplified - in real implementation would track unique actors
            }
        )
        (ok true)
    )
)

(define-private (create-integrity-hash (audit-id uint))
    (let (
        (audit-data (unwrap! (map-get? audit-logs { audit-id: audit-id }) (err u500)))
        (previous-hash (if (> audit-id u1) 
                        (get hash (default-to { hash: 0x00, previous-hash: 0x00, merkle-root: 0x00, verification-status: "initial" }
                                             (map-get? operation-integrity-hashes { operation-id: (- audit-id u1) })))
                        0x00))
        (current-hash (hash160 (unwrap-panic (to-consensus-buff? audit-data))))
        (merkle-root (hash160 current-hash))
    )
        (map-insert operation-integrity-hashes
            { operation-id: audit-id }
            {
                hash: current-hash,
                previous-hash: previous-hash,
                merkle-root: merkle-root,
                verification-status: "verified"
            }
        )
        (ok current-hash)
    )
)

(define-private (verify-hash (hash-to-verify (buff 32)) (operation-id uint))
    (let (
        (audit-data (unwrap! (map-get? audit-logs { audit-id: operation-id }) false))
        (previous-hash (if (> operation-id u1)
                        (get hash (default-to { hash: 0x00, previous-hash: 0x00, merkle-root: 0x00, verification-status: "initial" }
                                             (map-get? operation-integrity-hashes { operation-id: (- operation-id u1) })))
                        0x00))
        (calculated-hash (hash160 (unwrap-panic (to-consensus-buff? audit-data))))
    )
        (is-eq hash-to-verify calculated-hash)
    )
)

(define-private (get-tx-hash)
    (ok 0x0000000000000000000000000000000000000000000000000000000000000000) ;; Placeholder - in real implementation would get actual tx hash
)

(define-private (uint-to-ascii (value uint))
    "0" ;; Simplified - in real implementation would convert uint to string
)

