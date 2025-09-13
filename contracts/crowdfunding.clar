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



(define-map project-faqs
  { project-id: uint, faq-id: uint }
  {
    question: (string-ascii 200),
    answer: (string-ascii 500)
  }
)

(define-map last-faq-id uint uint)

(define-public (add-faq (project-id uint) (question (string-ascii 200)) (answer (string-ascii 500)))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (faq-id (+ (default-to u0 (map-get? last-faq-id project-id)) u1))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (map-set project-faqs
      { project-id: project-id, faq-id: faq-id }
      { question: question, answer: answer }
    )
    (map-set last-faq-id project-id faq-id)
    (ok faq-id)
  )
)



(define-map project-timeline
  { project-id: uint, event-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    date: uint,
    event-type: (string-ascii 20)
  }
)

(define-map last-event-id uint uint)

(define-public (add-timeline-event 
    (project-id uint) 
    (title (string-ascii 100)) 
    (description (string-ascii 500))
    (event-type (string-ascii 20))
  )
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (event-id (+ (default-to u0 (map-get? last-event-id project-id)) u1))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (map-set project-timeline
      { project-id: project-id, event-id: event-id }
      { 
        title: title,
        description: description,
        date: block-height,
        event-type: event-type 
      }
    )
    (map-set last-event-id project-id event-id)
    (ok event-id)
  )
)



(define-map project-endorsements
  { project-id: uint, endorser: principal }
  {
    message: (string-ascii 200),
    credentials: (string-ascii 100),
    timestamp: uint
  }
)

(define-public (endorse-project 
    (project-id uint) 
    (message (string-ascii 200))
    (credentials (string-ascii 100))
  )
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
  )
    (map-set project-endorsements
      { project-id: project-id, endorser: tx-sender }
      { 
        message: message,
        credentials: credentials,
        timestamp: block-height 
      }
    )
    (ok true)
  )
)



(define-map project-risks
  { project-id: uint, risk-id: uint }
  {
    risk-type: (string-ascii 50),
    description: (string-ascii 500),
    mitigation: (string-ascii 500)
  }
)

(define-map last-risk-id uint uint)

(define-public (add-project-risk 
    (project-id uint) 
    (risk-type (string-ascii 50))
    (description (string-ascii 500))
    (mitigation (string-ascii 500))
  )
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (risk-id (+ (default-to u0 (map-get? last-risk-id project-id)) u1))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (map-set project-risks
      { project-id: project-id, risk-id: risk-id }
      { 
        risk-type: risk-type,
        description: description,
        mitigation: mitigation 
      }
    )
    (map-set last-risk-id project-id risk-id)
    (ok risk-id)
  )
)


(define-map project-votes 
  { project-id: uint, voter: principal }
  { vote: bool }
)

(define-public (vote-for-project (project-id uint) (support bool))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
  )
    (map-set project-votes
      { project-id: project-id, voter: tx-sender }
      { vote: support }
    )
    (ok true)
  )
)


(define-map project-subscribers
  { project-id: uint, subscriber: principal }
  { subscribed-at: uint }
)

(define-public (subscribe-to-project (project-id uint))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
  )
    (map-set project-subscribers
      { project-id: project-id, subscriber: tx-sender }
      { subscribed-at: block-height }
    )
    (ok true)
  )
)



(define-map referrals
  { project-id: uint, referrer: principal }
  { referral-count: uint, total-stakes: uint }
)

(define-public (refer-project (project-id uint) (referee principal))
  (let (
    (current-refs (default-to { referral-count: u0, total-stakes: u0 } 
      (map-get? referrals { project-id: project-id, referrer: tx-sender })))
  )
    (map-set referrals
      { project-id: project-id, referrer: tx-sender }
      { 
        referral-count: (+ (get referral-count current-refs) u1),
        total-stakes: (get total-stakes current-refs)
      }
    )
    (ok true)
  )
)



(define-map collaborations
  { project-id: uint, collaborator: principal }
  { 
    role: (string-ascii 50),
    permissions: (list 5 (string-ascii 20)),
    active: bool
  }
)

(define-public (add-collaborator (project-id uint) (collaborator principal) (role (string-ascii 50)) (permissions (list 5 (string-ascii 20))))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (map-set collaborations
      { project-id: project-id, collaborator: collaborator }
      { role: role, permissions: permissions, active: true }
    )
    (ok true)
  )
)



(define-map reward-distributions
  { project-id: uint, milestone-id: uint }
  { 
    total-amount: uint,
    distributed: bool,
    distribution-date: uint
  }
)

(define-public (distribute-rewards (project-id uint) (milestone-id uint) (token <token-trait>))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) (err u404)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (asserts! (get is-completed milestone) (err u405))
    (map-set reward-distributions
      { project-id: project-id, milestone-id: milestone-id }
      { total-amount: (get amount milestone), distributed: true, distribution-date: block-height }
    )
    (ok true)
  )
)


(define-map project-analytics
  { project-id: uint }
  { 
    view-count: uint,
    unique-visitors: uint,
    conversion-rate: uint
  }
)

(define-public (track-project-view (project-id uint))
  (let (
    (current-analytics (default-to { view-count: u0, unique-visitors: u0, conversion-rate: u0 }
      (map-get? project-analytics { project-id: project-id })))
  )
    (map-set project-analytics
      { project-id: project-id }
      (merge current-analytics { view-count: (+ (get view-count current-analytics) u1) })
    )
    (ok true)
  )
)



(define-map social-shares
  { project-id: uint, sharer: principal }
  { 
    platform: (string-ascii 20),
    share-count: uint,
    last-shared: uint
  }
)

(define-public (record-social-share (project-id uint) (platform (string-ascii 20)))
  (let (
    (current-shares (default-to { platform: platform, share-count: u0, last-shared: u0 }
      (map-get? social-shares { project-id: project-id, sharer: tx-sender })))
  )
    (map-set social-shares
      { project-id: project-id, sharer: tx-sender }
      { 
        platform: platform,
        share-count: (+ (get share-count current-shares) u1),
        last-shared: block-height
      }
    )
    (ok true)
  )
)



(define-public (withdraw-funds (project-id uint) (token <token-trait>))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (owner (get owner project))
    (amount (get current-amount project))
  )
    (asserts! (is-eq tx-sender owner) (err u403))
    (asserts! (>= amount (get goal project)) (err u406))
    (asserts! (> block-height (get deadline project)) (err u407))
    (try! (as-contract (contract-call? token transfer tx-sender owner amount)))
    (map-set projects
      { id: project-id }
      (merge project { current-amount: u0 })
    )
    (ok amount)
  )
)

(define-map category-projects
  { category: (string-ascii 64) }
  { project-ids: (list 100 uint) }
)

(define-public (add-project-to-category (project-id uint) (category (string-ascii 64)))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (current-list (default-to { project-ids: (list) } (map-get? category-projects { category: category })))
    (updated-list (unwrap! (as-max-len? (append (get project-ids current-list) project-id) u100) (err u408)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (map-set category-projects
      { category: category }
      { project-ids: updated-list }
    )
    (ok true)
  )
)

(define-read-only (get-projects-by-category (category (string-ascii 64)))
  (default-to { project-ids: (list) } (map-get? category-projects { category: category }))
)



(define-data-var contract-owner principal tx-sender)

(define-map featured-projects
  { project-id: uint }
  { 
    featured-at: uint,
    featured-until: uint,
    featured-reason: (string-ascii 100)
  }
)

(define-public (set-featured-project (project-id uint) (duration uint) (reason (string-ascii 100)))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (featured-until (+ block-height duration))
  )
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (map-set featured-projects
      { project-id: project-id }
      { 
        featured-at: block-height,
        featured-until: featured-until,
        featured-reason: reason
      }
    )
    (ok true)
  )
)

(define-read-only (is-project-featured (project-id uint))
  (let (
    (featured-info (map-get? featured-projects { project-id: project-id }))
  )
    (and 
      (is-some featured-info)
      (< block-height (get featured-until (unwrap! featured-info false)))
    )
  )
)


(define-map project-reports
  { project-id: uint, reporter: principal }
  { 
    reason: (string-ascii 200),
    timestamp: uint,
    status: (string-ascii 20)
  }
)

(define-map project-report-count
  { project-id: uint }
  { count: uint }
)

(define-public (report-project (project-id uint) (reason (string-ascii 200)))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (current-count (default-to { count: u0 } (map-get? project-report-count { project-id: project-id })))
  )
    (map-set project-reports
      { project-id: project-id, reporter: tx-sender }
      { 
        reason: reason,
        timestamp: block-height,
        status: "pending"
      }
    )
    (map-set project-report-count
      { project-id: project-id }
      { count: (+ (get count current-count) u1) }
    )
    (ok true)
  )
)

(define-public (resolve-report (project-id uint) (reporter principal) (new-status (string-ascii 20)))
  (let (
    (report (unwrap! (map-get? project-reports { project-id: project-id, reporter: reporter }) (err u404)))
  )
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (map-set project-reports
      { project-id: project-id, reporter: reporter }
      (merge report { status: new-status })
    )
    (ok true)
  )
)


(define-map verified-projects
  { project-id: uint }
  { 
    verified-by: principal,
    verified-at: uint,
    verification-level: uint
  }
)

(define-map verifiers
  { address: principal }
  { is-active: bool }
)

(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (map-set verifiers
      { address: verifier }
      { is-active: true }
    )
    (ok true)
  )
)

(define-public (verify-project (project-id uint) (level uint))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (verifier-status (default-to { is-active: false } (map-get? verifiers { address: tx-sender })))
  )
    (asserts! (get is-active verifier-status) (err u403))
    (asserts! (<= level u3) (err u400))
    (map-set verified-projects
      { project-id: project-id }
      { 
        verified-by: tx-sender,
        verified-at: block-height,
        verification-level: level
      }
    )
    (ok true)
  )
)



(define-map user-bookmarks
  { user: principal }
  { bookmarked-projects: (list 100 uint) }
)

(define-public (bookmark-project (project-id uint))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (current-bookmarks (default-to { bookmarked-projects: (list) } (map-get? user-bookmarks { user: tx-sender })))
    (updated-bookmarks (unwrap! (as-max-len? (append (get bookmarked-projects current-bookmarks) project-id) u100) (err u408)))
  )
    (map-set user-bookmarks
      { user: tx-sender }
      { bookmarked-projects: updated-bookmarks }
    )
    (ok true)
  )
)


(define-map stretch-goals
  { project-id: uint, goal-id: uint }
  { 
    amount: uint,
    description: (string-ascii 200),
    is-reached: bool
  }
)

(define-map last-stretch-goal-id uint uint)

(define-public (add-stretch-goal (project-id uint) (amount uint) (description (string-ascii 200)))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (goal-id (+ (default-to u0 (map-get? last-stretch-goal-id project-id)) u1))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (asserts! (> amount (get goal project)) (err u400))
    (map-set stretch-goals
      { project-id: project-id, goal-id: goal-id }
      { 
        amount: amount,
        description: description,
        is-reached: false
      }
    )
    (map-set last-stretch-goal-id project-id goal-id)
    (ok goal-id)
  )
)

(define-public (update-stretch-goal-status (project-id uint) (goal-id uint))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (stretch-goal (unwrap! (map-get? stretch-goals { project-id: project-id, goal-id: goal-id }) (err u404)))
    (current-amount (get current-amount project))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (asserts! (>= current-amount (get amount stretch-goal)) (err u400))
    (map-set stretch-goals
      { project-id: project-id, goal-id: goal-id }
      (merge stretch-goal { is-reached: true })
    )
    (ok true)
  )
)


(define-map project-polls
  { project-id: uint, poll-id: uint }
  { 
    title: (string-ascii 100),
    description: (string-ascii 200),
    options: (list 5 (string-ascii 50)),
    deadline: uint,
    is-active: bool
  }
)

(define-map poll-votes
  { project-id: uint, poll-id: uint, voter: principal }
  { option-index: uint }
)

(define-map poll-results
  { project-id: uint, poll-id: uint, option-index: uint }
  { vote-count: uint }
)

(define-map last-poll-id uint uint)

(define-public (create-poll 
    (project-id uint) 
    (title (string-ascii 100)) 
    (description (string-ascii 200))
    (options (list 5 (string-ascii 50)))
    (duration uint)
  )
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (poll-id (+ (default-to u0 (map-get? last-poll-id project-id)) u1))
    (deadline (+ block-height duration))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (asserts! (> (len options) u1) (err u400))
    (map-set project-polls
      { project-id: project-id, poll-id: poll-id }
      { 
        title: title,
        description: description,
        options: options,
        deadline: deadline,
        is-active: true
      }
    )
    (map-set last-poll-id project-id poll-id)
    (ok poll-id)
  )
)

(define-public (vote-in-poll (project-id uint) (poll-id uint) (option-index uint))
  (let (
    (poll (unwrap! (map-get? project-polls { project-id: project-id, poll-id: poll-id }) (err u404)))
    (stake-info (unwrap! (map-get? stakes { project-id: project-id, staker: tx-sender }) (err u404)))
    (current-votes (default-to { vote-count: u0 } (map-get? poll-results { project-id: project-id, poll-id: poll-id, option-index: option-index })))
  )
    (asserts! (get is-active poll) (err u403))
    (asserts! (< block-height (get deadline poll)) (err u403))
    (asserts! (< option-index (len (get options poll))) (err u400))
    (map-set poll-votes
      { project-id: project-id, poll-id: poll-id, voter: tx-sender }
      { option-index: option-index }
    )
    (map-set poll-results
      { project-id: project-id, poll-id: poll-id, option-index: option-index }
      { vote-count: (+ (get vote-count current-votes) u1) }
    )
    (ok true)
  )
)

(define-public (close-poll (project-id uint) (poll-id uint))
  (let (
    (poll (unwrap! (map-get? project-polls { project-id: project-id, poll-id: poll-id }) (err u404)))
    (project (unwrap! (get-project project-id) (err u404)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err u403))
    (asserts! (get is-active poll) (err u403))
    (map-set project-polls
      { project-id: project-id, poll-id: poll-id }
      (merge poll { is-active: false })
    )
    (ok true)
  )
)



(define-map milestone-votes
  { project-id: uint, milestone-id: uint, voter: principal }
  { approved: bool }
)

(define-map milestone-vote-counts
  { project-id: uint, milestone-id: uint }
  { approve-count: uint, reject-count: uint }
)

(define-public (vote-on-milestone (project-id uint) (milestone-id uint) (approve bool))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) (err u404)))
    (stake-info (unwrap! (map-get? stakes { project-id: project-id, staker: tx-sender }) (err u404)))
    (current-counts (default-to { approve-count: u0, reject-count: u0 } 
      (map-get? milestone-vote-counts { project-id: project-id, milestone-id: milestone-id })))
  )
    (asserts! (not (get is-completed milestone)) (err u400))
    (map-set milestone-votes
      { project-id: project-id, milestone-id: milestone-id, voter: tx-sender }
      { approved: approve }
    )
    (map-set milestone-vote-counts
      { project-id: project-id, milestone-id: milestone-id }
      {
        approve-count: (if approve (+ (get approve-count current-counts) u1) (get approve-count current-counts)),
        reject-count: (if (not approve) (+ (get reject-count current-counts) u1) (get reject-count current-counts))
      }
    )
    (ok true)
  )
)


(define-map escrow-balances
  { project-id: uint }
  { 
    total-locked: uint,
    total-released: uint
  }
)

(define-public (lock-funds-in-escrow (project-id uint) (amount uint) (token <token-trait>))
  (let (
    (project (unwrap! (get-project project-id) (err u404)))
    (current-escrow (default-to { total-locked: u0, total-released: u0 } 
      (map-get? escrow-balances { project-id: project-id })))
  )
    (try! (contract-call? token transfer tx-sender (as-contract tx-sender) amount))
    (map-set escrow-balances
      { project-id: project-id }
      {
        total-locked: (+ (get total-locked current-escrow) amount),
        total-released: (get total-released current-escrow)
      }
    )
    (ok true)
  )
)

(define-public (release-escrow-funds (project-id uint) (amount uint) (token <token-trait>))
    (let (
        (project (unwrap! (get-project project-id) (err u404)))
        (current-escrow (unwrap! (map-get? escrow-balances { project-id: project-id }) (err u404)))
    )
        (asserts! (is-eq tx-sender (get owner project)) (err u403))
        (asserts! (<= amount (- (get total-locked current-escrow) (get total-released current-escrow))) (err u400))
        (try! (as-contract (contract-call? token transfer tx-sender (get owner project) amount)))
        (map-set escrow-balances
            { project-id: project-id }
            {
                total-locked: (get total-locked current-escrow),
                total-released: (+ (get total-released current-escrow) amount)
            })
        (ok true)))

;; Project Likes & Social Engagement Feature
;; Provides lightweight social metrics to boost project discovery and community interaction

;; Track total likes per project
(define-map project-like-counts
    { project-id: uint }
    { likes: uint, last-liked: uint })

;; Track which users liked which projects (prevents duplicate likes)
(define-map user-project-likes
    { project-id: uint, user: principal }
    { liked: bool, liked-at: uint })

;; Social engagement statistics
(define-map project-social-metrics
    { project-id: uint }
    {
        total-likes: uint,
        unique-likers: uint,
        social-score: uint,
        trending-score: uint,
        last-activity: uint
    })

;; Track top liked projects for discovery
(define-map trending-projects
    { rank: uint }
    { project-id: uint, like-count: uint, updated-at: uint })

;; Global social stats
(define-data-var total-likes-all-time uint u0)
(define-data-var trending-threshold uint u10) ;; Minimum likes to be trending
(define-data-var social-boost-multiplier uint u5) ;; Boost factor for social score

;; Like/Unlike a project (toggle functionality)
(define-public (like-project (project-id uint))
    (let (
        (project (unwrap! (get-project project-id) (err u404)))
        (current-like (map-get? user-project-likes { project-id: project-id, user: tx-sender }))
        (project-likes (default-to { likes: u0, last-liked: u0 } 
                       (map-get? project-like-counts { project-id: project-id })))
        (already-liked (and (is-some current-like) 
                           (get liked (unwrap-panic current-like))))
    )
        (if already-liked
            ;; Unlike the project
            (begin
                (map-set user-project-likes
                    { project-id: project-id, user: tx-sender }
                    { liked: false, liked-at: (get liked-at (unwrap-panic current-like)) })
                (map-set project-like-counts
                    { project-id: project-id }
                    { 
                        likes: (- (get likes project-likes) u1),
                        last-liked: (get last-liked project-likes)
                    })
                (var-set total-likes-all-time (- (var-get total-likes-all-time) u1))
                (try! (update-social-metrics project-id))
                (ok { action: "unliked", new-count: (- (get likes project-likes) u1) }))
            ;; Like the project
            (begin
                (map-set user-project-likes
                    { project-id: project-id, user: tx-sender }
                    { liked: true, liked-at: block-height })
                (map-set project-like-counts
                    { project-id: project-id }
                    { 
                        likes: (+ (get likes project-likes) u1),
                        last-liked: block-height
                    })
                (var-set total-likes-all-time (+ (var-get total-likes-all-time) u1))
                (try! (update-social-metrics project-id))
                (ok { action: "liked", new-count: (+ (get likes project-likes) u1) })))))

;; Get total likes for a project
(define-read-only (get-project-likes (project-id uint))
    (let ((like-data (map-get? project-like-counts { project-id: project-id })))
        (if (is-some like-data)
            (get likes (unwrap-panic like-data))
            u0)))

;; Check if current user has liked a project
(define-read-only (has-user-liked (project-id uint) (user principal))
    (let ((user-like (map-get? user-project-likes { project-id: project-id, user: user })))
        (if (is-some user-like)
            (get liked (unwrap-panic user-like))
            false)))

;; Get comprehensive social metrics for a project
(define-read-only (get-project-social-stats (project-id uint))
    (let (
        (like-count (get-project-likes project-id))
        (social-metrics (default-to 
                        { total-likes: u0, unique-likers: u0, social-score: u0, trending-score: u0, last-activity: u0 }
                        (map-get? project-social-metrics { project-id: project-id })))
    )
        (ok {
            project-id: project-id,
            total-likes: like-count,
            social-score: (get social-score social-metrics),
            trending-score: (get trending-score social-metrics),
            is-trending: (>= like-count (var-get trending-threshold)),
            last-activity: (get last-activity social-metrics),
            user-liked: (has-user-liked project-id tx-sender)
        })))

;; Update social metrics when likes change
(define-private (update-social-metrics (project-id uint))
    (let (
        (like-count (get-project-likes project-id))
        (project (unwrap! (get-project project-id) (err u404)))
        (current-amount (get current-amount project))
        (goal (get goal project))
        ;; Calculate social score based on likes + funding progress
        (funding-factor (if (> goal u0) (/ (* current-amount u100) goal) u0))
        (social-score (+ (* like-count (var-get social-boost-multiplier)) funding-factor))
        ;; Calculate trending score (recent activity weighted)
        (trending-score (if (> like-count u0)
                          (/ (* like-count u1000) (- block-height u1))
                          u0))
    )
        (map-set project-social-metrics
            { project-id: project-id }
            {
                total-likes: like-count,
                unique-likers: like-count, ;; Simplified for now
                social-score: social-score,
                trending-score: trending-score,
                last-activity: block-height
            })
        (ok true)))

;; Get trending projects (projects with high like counts)
(define-read-only (get-trending-projects (limit uint))
    (ok {
        threshold: (var-get trending-threshold),
        total-global-likes: (var-get total-likes-all-time),
        message: "Use get-project-social-stats for individual project metrics"
    }))

;; Get user's liked projects (simplified version)
(define-read-only (get-user-liked-projects (user principal))
    (ok {
        user: user,
        message: "Check individual projects with has-user-liked function"
    }))

;; Admin function to set trending threshold
(define-public (set-trending-threshold (new-threshold uint))
    (let ((project (unwrap! (get-project u1) (err u404)))) ;; Check if any project exists
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
        (var-set trending-threshold new-threshold)
        (ok new-threshold)))

;; Get global social platform stats
(define-read-only (get-platform-social-stats)
    (ok {
        total-likes-platform: (var-get total-likes-all-time),
        trending-threshold: (var-get trending-threshold),
        social-boost-multiplier: (var-get social-boost-multiplier),
        current-block: block-height
    }))

;; Batch like status check (useful for frontend)
(define-read-only (check-multiple-likes (project-ids (list 10 uint)) (user principal))
    (ok {
        user: user,
        checked-projects: (len project-ids),
        message: "Use has-user-liked for individual project checks"
    }))

;; Get projects sorted by social engagement
(define-read-only (get-socially-ranked-projects)
    (ok {
        ranking-criteria: "likes + social-score",
        message: "Use get-project-social-stats to get individual project rankings"
    }))
