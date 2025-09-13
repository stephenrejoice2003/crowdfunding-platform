(define-map milestone-escrow
  { project-id: uint, milestone-id: uint }
  {
    allocated-amount: uint,
    required-approvals: uint,
    current-approvals: uint,
    is-released: bool,
    release-threshold: uint
  }
)

(define-map stakes
  { project-id: uint, staker: principal }
  { amount: uint }
)

(define-map milestone-approvals
  { project-id: uint, milestone-id: uint, approver: principal }
  { approved: bool, approval-weight: uint }
)

(define-map project-escrow-settings
  { project-id: uint }
  {
    total-escrowed: uint,
    approval-threshold-percentage: uint,
    minimum-stake-for-voting: uint
  }
)

(define-map escrow-releases
  { project-id: uint, milestone-id: uint }
  {
    released-amount: uint,
    release-date: uint,
    released-to: principal
  }
)

(define-map milestones
  { project-id: uint, milestone-id: uint }
  {
    description: (string-ascii 256),
    amount: uint,
    is-completed: bool
  }
)

(define-constant ERR-NOT-FOUND u404)
(define-constant ERR-UNAUTHORIZED u403)
(define-constant ERR-INVALID-AMOUNT u400)
(define-constant ERR-ALREADY-RELEASED u405)
(define-constant ERR-INSUFFICIENT-APPROVALS u406)
(define-constant ERR-MILESTONE-NOT-COMPLETED u407)
(define-constant ERR-INSUFFICIENT-STAKE u408)

(define-public (setup-milestone-escrow 
    (project-id uint) 
    (milestone-id uint) 
    (allocated-amount uint)
    (approval-threshold uint)
  )
  (let (
    (project (unwrap! (contract-call? .crowdfunding get-project project-id) (err ERR-NOT-FOUND)))
    (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) (err ERR-NOT-FOUND)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err ERR-UNAUTHORIZED))
    (asserts! (> allocated-amount u0) (err ERR-INVALID-AMOUNT))
    (asserts! (<= approval-threshold u100) (err ERR-INVALID-AMOUNT))
    (map-set milestone-escrow
      { project-id: project-id, milestone-id: milestone-id }
      {
        allocated-amount: allocated-amount,
        required-approvals: u0,
        current-approvals: u0,
        is-released: false,
        release-threshold: approval-threshold
      }
    )
    (ok true)
  )
)

(define-public (approve-milestone-release (project-id uint) (milestone-id uint))
  (let (
    (stake-info (unwrap! (map-get? stakes { project-id: project-id, staker: tx-sender }) (err ERR-NOT-FOUND)))
    (escrow-settings (default-to 
      { total-escrowed: u0, approval-threshold-percentage: u51, minimum-stake-for-voting: u100 }
      (map-get? project-escrow-settings { project-id: project-id })))
    (milestone-escrow-info (unwrap! (map-get? milestone-escrow { project-id: project-id, milestone-id: milestone-id }) (err ERR-NOT-FOUND)))
    (stake-amount (get amount stake-info))
    (approval-weight (/ (* stake-amount u100) (get minimum-stake-for-voting escrow-settings)))
  )
    (asserts! (>= stake-amount (get minimum-stake-for-voting escrow-settings)) (err ERR-INSUFFICIENT-STAKE))
    (asserts! (not (get is-released milestone-escrow-info)) (err ERR-ALREADY-RELEASED))
    (map-set milestone-approvals
      { project-id: project-id, milestone-id: milestone-id, approver: tx-sender }
      { approved: true, approval-weight: approval-weight }
    )
    (map-set milestone-escrow
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone-escrow-info 
        { current-approvals: (+ (get current-approvals milestone-escrow-info) approval-weight) })
    )
    (ok true)
  )
)

(define-public (trigger-milestone-release (project-id uint) (milestone-id uint) (token uint))
  (let (
    (project (unwrap! (contract-call? .crowdfunding get-project project-id) (err ERR-NOT-FOUND)))
    (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) (err ERR-NOT-FOUND)))
    (escrow-info (unwrap! (map-get? milestone-escrow { project-id: project-id, milestone-id: milestone-id }) (err ERR-NOT-FOUND)))
    (project-owner (get owner project))
    (release-amount (get allocated-amount escrow-info))
  )
    (asserts! (get is-completed milestone) (err ERR-MILESTONE-NOT-COMPLETED))
    (asserts! (not (get is-released escrow-info)) (err ERR-ALREADY-RELEASED))
    (asserts! (>= (get current-approvals escrow-info) (get release-threshold escrow-info)) (err ERR-INSUFFICIENT-APPROVALS))
    ;; (try! (as-contract (contract-call? token transfer tx-sender project-owner release-amount)))
    (map-set milestone-escrow
      { project-id: project-id, milestone-id: milestone-id }
      (merge escrow-info { is-released: true })
    )
    (map-set escrow-releases
      { project-id: project-id, milestone-id: milestone-id }
      {
        released-amount: release-amount,
        release-date: stacks-block-height,
        released-to: project-owner
      }
    )
    (ok release-amount)
  )
)

(define-public (configure-project-escrow-settings 
    (project-id uint) 
    (approval-threshold uint) 
    (minimum-stake uint)
  )
  (let (
    (project (unwrap! (contract-call? .crowdfunding get-project project-id) (err ERR-NOT-FOUND)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err ERR-UNAUTHORIZED))
    (asserts! (<= approval-threshold u100) (err ERR-INVALID-AMOUNT))
    (asserts! (> minimum-stake u0) (err ERR-INVALID-AMOUNT))
    (map-set project-escrow-settings
      { project-id: project-id }
      {
        total-escrowed: u0,
        approval-threshold-percentage: approval-threshold,
        minimum-stake-for-voting: minimum-stake
      }
    )
    (ok true)
  )
)

(define-public (emergency-release-funds (project-id uint) (milestone-id uint) (token uint))
  (let (
    (project (unwrap! (contract-call? .crowdfunding get-project project-id) (err ERR-NOT-FOUND)))
    (escrow-info (unwrap! (map-get? milestone-escrow { project-id: project-id, milestone-id: milestone-id }) (err ERR-NOT-FOUND)))
    (release-amount (get allocated-amount escrow-info))
  )
    ;; (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-UNAUTHORIZED))
    (asserts! (not (get is-released escrow-info)) (err ERR-ALREADY-RELEASED))
    ;; (try! (as-contract (contract-call? token transfer tx-sender (get owner project) release-amount)))
    (map-set milestone-escrow
      { project-id: project-id, milestone-id: milestone-id }
      (merge escrow-info { is-released: true })
    )
    (ok release-amount)
  )
)

(define-read-only (get-milestone-escrow-info (project-id uint) (milestone-id uint))
  (map-get? milestone-escrow { project-id: project-id, milestone-id: milestone-id })
)

(define-read-only (get-approval-status (project-id uint) (milestone-id uint) (approver principal))
  (map-get? milestone-approvals { project-id: project-id, milestone-id: milestone-id, approver: approver })
)

(define-read-only (get-release-info (project-id uint) (milestone-id uint))
  (map-get? escrow-releases { project-id: project-id, milestone-id: milestone-id })
)

(define-read-only (calculate-approval-percentage (project-id uint) (milestone-id uint))
  (let (
    (escrow-info (unwrap! (map-get? milestone-escrow { project-id: project-id, milestone-id: milestone-id }) (err ERR-NOT-FOUND)))
    (current-approvals (get current-approvals escrow-info))
    (threshold (get release-threshold escrow-info))
  )
    (ok (if (> threshold u0) (/ (* current-approvals u100) threshold) u0))
  )
)

(define-read-only (is-milestone-ready-for-release (project-id uint) (milestone-id uint))
  (let (
    (milestone (map-get? milestones { project-id: project-id, milestone-id: milestone-id }))
    (escrow-info (map-get? milestone-escrow { project-id: project-id, milestone-id: milestone-id }))
  )
    (and 
      (is-some milestone)
      (is-some escrow-info)
      (get is-completed (unwrap-panic milestone))
      (not (get is-released (unwrap-panic escrow-info)))
      (>= (get current-approvals (unwrap-panic escrow-info)) (get release-threshold (unwrap-panic escrow-info)))
    )
  )
)