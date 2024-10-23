;; Define the project struct
(define-map projects 
  { id: uint }
  {
    owner: principal,
    goal: uint,
    current-amount: uint,
    deadline: uint,
    is-active: bool
  }
)

(define-data-var next-project-id uint u1)

;; Define the milestone struct
(define-map milestones
  { project-id: uint, milestone-id: uint }
  {
    description: (string-ascii 256),
    amount: uint,
    is-completed: bool
  }
)

;; Define the staking struct
(define-map stakes
  { project-id: uint, staker: principal }
  { amount: uint }
)

;; Define last milestone ID map
(define-map last-milestone-id-map uint uint)

;; Token trait definition
(define-trait token-trait
  (
    (transfer (principal principal uint) (response bool uint))
    (get-balance (principal) (response uint uint))
  )
)

;; Project Management Functions
(define-public (create-project (goal uint) (deadline uint))
  (let (
    (project-id (var-get next-project-id))
  )
    (asserts! (> goal u0) (err u400))
    (asserts! (> deadline block-height) (err u401))
    (map-set projects
      { id: project-id }
      {
        owner: tx-sender,
        goal: goal,
        current-amount: u0,
        deadline: deadline,
        is-active: true
      }
    )
    (var-set next-project-id (+ project-id u1))
    (ok project-id)
  )
)

(define-read-only (get-project (project-id uint))
  (map-get? projects { id: project-id })
)

(define-public (update-project-amount (project-id uint) (amount uint))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (new-amount (+ (get current-amount project) amount))
  )
    (asserts! (<= new-amount (get goal project)) (err u400))
    (map-set projects
      { id: project-id }
      (merge project { current-amount: new-amount })
    )
    (ok true)
  )
)

;; Token Management Functions
(define-public (stake (amount uint) (project-id uint) (token <token-trait>))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (sender tx-sender)
    (current-stake (default-to u0 (get amount (map-get? stakes { project-id: project-id, staker: sender }))))
  )
    (asserts! (get is-active project) (err u403))
    (asserts! (<= (+ amount (get current-amount project)) (get goal project)) (err u400))
    (asserts! (< block-height (get deadline project)) (err u401))
    (try! (contract-call? token transfer sender (as-contract tx-sender) amount))
    (try! (update-project-amount project-id amount))
    (map-set stakes
      { project-id: project-id, staker: sender }
      { amount: (+ amount current-stake) }
    )
    (ok true)
  )
)

;; Milestone Tracking Functions
(define-public (add-milestone (project-id uint) (description (string-ascii 256)) (amount uint))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (new-milestone-id (increment-last-milestone-id project-id))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (asserts! (< u0 amount) (err u400))
    (asserts! (<= (len description) u256) (err u400))
    (map-set milestones
      { project-id: project-id, milestone-id: new-milestone-id }
      { description: description, amount: amount, is-completed: false }
    )
    (ok new-milestone-id)
  )
)

(define-public (complete-milestone (project-id uint) (milestone-id uint))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) (err u404)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (asserts! (not (get is-completed milestone)) (err u400))
    (asserts! (>= (get current-amount project) (get amount milestone)) (err u405))
    (map-set milestones
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone { is-completed: true })
    )
    (ok true)
  )
)

;; Refund Mechanism Functions
(define-public (claim-refund (project-id uint) (token <token-trait>))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (c-stake (unwrap! (map-get? stakes { project-id: project-id, staker: tx-sender }) (err u404)))
    (refund-amount (get amount c-stake))
  )
    (asserts! (> (get deadline project) block-height) (err u403))
    (asserts! (< (get current-amount project) (get goal project)) (err u403))
    (try! (as-contract (contract-call? token transfer tx-sender tx-sender refund-amount)))
    (map-delete stakes { project-id: project-id, staker: tx-sender })
    (ok refund-amount)
  )
)

;; Helper functions
(define-private (get-last-milestone-id (project-id uint))
  (default-to u0 (map-get? last-milestone-id-map project-id))
)

(define-private (increment-last-milestone-id (project-id uint))
  (let (
    (current-id (get-last-milestone-id project-id))
    (new-id (+ current-id u1))
  )
    (map-set last-milestone-id-map project-id new-id)
    new-id
  )
)