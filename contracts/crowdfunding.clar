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


(define-map project-categories 
  { project-id: uint }
  { category: (string-ascii 64) }
)

(define-public (set-project-category (project-id uint) (category (string-ascii 64)))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (map-set project-categories 
      { project-id: project-id }
      { category: category }
    )
    (ok true)
  )
)


(define-map staker-rewards
  { project-id: uint, staker: principal }
  { reward-tier: uint }
)

(define-public (set-staker-reward-tier (project-id uint) (staker principal) (tier uint))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (stake-info (unwrap! (map-get? stakes { project-id: project-id, staker: staker }) (err u404)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (map-set staker-rewards
      { project-id: project-id, staker: staker }
      { reward-tier: tier }
    )
    (ok true)
  )
)


(define-map project-ratings
  { project-id: uint, rater: principal }
  { rating: uint }
)

(define-public (rate-project (project-id uint) (rating uint))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (stake-info (unwrap! (map-get? stakes { project-id: project-id, staker: tx-sender }) (err u404)))
  )
    (asserts! (<= rating u5) (err u400))
    (asserts! (> rating u0) (err u400))
    (map-set project-ratings
      { project-id: project-id, rater: tx-sender }
      { rating: rating }
    )
    (ok true)
  )
)



(define-map project-tags
  { project-id: uint }
  { tags: (list 10 (string-ascii 20)) }
)

(define-public (set-project-tags (project-id uint) (tags (list 10 (string-ascii 20))))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (map-set project-tags { project-id: project-id } { tags: tags })
    (ok true)
  )
)



(define-map project-progress
  { project-id: uint }
  {
    percentage-complete: uint,
    last-update: uint
  }
)

(define-public (update-project-progress (project-id uint) (percentage uint))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (asserts! (<= percentage u100) (err u400))
    (map-set project-progress
      { project-id: project-id }
      { percentage-complete: percentage, last-update: block-height }
    )
    (ok true)
  )
)



;; Add this map to track project updates
(define-map project-updates
  { project-id: uint, update-id: uint }
  {
    title: (string-ascii 100),
    content: (string-ascii 500),
    timestamp: uint
  }
)

(define-public (post-project-update (project-id uint) (title (string-ascii 100)) (content (string-ascii 500)))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (update-id (increment-last-update-id project-id))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (map-set project-updates
      { project-id: project-id, update-id: update-id }
      { title: title, content: content, timestamp: block-height }
    )
    (ok update-id)
  )
)

;; Map to store the last update ID for each project
(define-map last-update-id-map uint uint)

;; Helper function to get the last update ID
(define-private (get-last-update-id (project-id uint))
  (default-to u0 (map-get? last-update-id-map project-id))
)

;; Helper function to increment the last update ID
(define-private (increment-last-update-id (project-id uint))
  (let (
    (current-id (get-last-update-id project-id))
    (new-id (+ current-id u1))
  )
    (map-set last-update-id-map project-id new-id)
    new-id
  )
)



(define-map project-comments
  { project-id: uint, comment-id: uint }
  {
    author: principal,
    content: (string-ascii 280),
    timestamp: uint
  }
)

(define-public (add-comment (project-id uint) (content (string-ascii 280)))
  (let (
    (comment-id (increment-last-comment-id project-id))
  )
    (map-set project-comments
      { project-id: project-id, comment-id: comment-id }
      { author: tx-sender, content: content, timestamp: block-height }
    )
    (ok comment-id)
  )
)


;; Map to store the last comment ID for each project
(define-map last-comment-id-map uint uint)

;; Helper function to get the last comment ID
(define-private (get-last-comment-id (project-id uint))
  (default-to u0 (map-get? last-comment-id-map project-id))
)

;; Helper function to increment the last comment ID
(define-private (increment-last-comment-id (project-id uint))
  (let (
    (current-id (get-last-comment-id project-id))
    (new-id (+ current-id u1))
  )
    (map-set last-comment-id-map project-id new-id)
    new-id
  )
)



(define-map funding-tiers
  { project-id: uint, tier-id: uint }
  {
    name: (string-ascii 50),
    amount: uint,
    rewards: (string-ascii 200)
  }
)

(define-public (create-funding-tier (project-id uint) (name (string-ascii 50)) (amount uint) (rewards (string-ascii 200)))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (tier-id (increment-last-tier-id project-id))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (map-set funding-tiers
      { project-id: project-id, tier-id: tier-id }
      { name: name, amount: amount, rewards: rewards }
    )
    (ok tier-id)
  )
)


;; Map to store the last tier ID for each project
(define-map last-tier-id-map uint uint)

;; Helper function to get the last tier ID
(define-private (get-last-tier-id (project-id uint))
  (default-to u0 (map-get? last-tier-id-map project-id))
)

;; Helper function to increment the last tier ID
(define-private (increment-last-tier-id (project-id uint))
  (let (
    (current-id (get-last-tier-id project-id))
    (new-id (+ current-id u1))
  )
    (map-set last-tier-id-map project-id new-id)
    new-id
  )
)


(define-map project-media
  { project-id: uint, update-id: uint }
  {
    media-url: (string-ascii 256),
    media-type: (string-ascii 20),
    timestamp: uint
  }
)

(define-public (add-project-media (project-id uint) (media-url (string-ascii 256)) (media-type (string-ascii 20)))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (update-id (increment-last-update-id project-id))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (map-set project-media
      { project-id: project-id, update-id: update-id }
      { 
        media-url: media-url,
        media-type: media-type,
        timestamp: block-height 
      }
    )
    (ok update-id)
  )
)



(define-map project-team
  { project-id: uint, member-id: principal }
  {
    role: (string-ascii 50),
    join-date: uint,
    is-active: bool
  }
)

(define-public (add-team-member (project-id uint) (member principal) (role (string-ascii 50)))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (map-set project-team
      { project-id: project-id, member-id: member }
      { 
        role: role,
        join-date: block-height,
        is-active: true 
      }
    )
    (ok true)
  )
)
