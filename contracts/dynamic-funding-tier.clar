(define-map dynamic-tier-rules
  { project-id: uint }
  {
    base-tier-amount: uint,
    velocity-multiplier: uint,
    urgency-bonus-percentage: uint,
    tier-adjustment-frequency: uint,
    max-tier-amount: uint,
    min-tier-amount: uint
  }
)

(define-map funding-velocity
  { project-id: uint }
  {
    last-calculation-height: uint,
    recent-funding-amount: uint,
    velocity-score: uint,
    trend-direction: bool
  }
)

(define-map dynamic-tiers
  { project-id: uint, tier-level: uint }
  {
    current-amount: uint,
    reward-multiplier: uint,
    urgency-expires-at: uint,
    auto-generated: bool,
    participants-count: uint
  }
)

(define-map tier-participations
  { project-id: uint, tier-level: uint, participant: principal }
  {
    amount-contributed: uint,
    joined-at: uint,
    bonus-applied: uint
  }
)

(define-map project-tier-settings
  { project-id: uint }
  {
    next-tier-level: uint,
    last-tier-update: uint,
    auto-scaling-enabled: bool,
    performance-threshold: uint
  }
)

(define-constant ERR-NOT-FOUND u404)
(define-constant ERR-UNAUTHORIZED u403)
(define-constant ERR-INVALID-AMOUNT u400)
(define-constant ERR-TIER-EXPIRED u405)
(define-constant ERR-INSUFFICIENT-FUNDING u406)
(define-constant ERR-TIER-FULL u407)

(define-public (setup-dynamic-tier-rules
    (project-id uint)
    (base-amount uint)
    (velocity-multiplier uint)
    (urgency-bonus uint)
    (adjustment-frequency uint)
    (max-amount uint)
    (min-amount uint)
  )
  (let (
    (project (unwrap! (contract-call? .crowdfunding get-project project-id) (err ERR-NOT-FOUND)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err ERR-UNAUTHORIZED))
    (asserts! (> base-amount u0) (err ERR-INVALID-AMOUNT))
    (asserts! (<= min-amount base-amount) (err ERR-INVALID-AMOUNT))
    (asserts! (>= max-amount base-amount) (err ERR-INVALID-AMOUNT))
    (map-set dynamic-tier-rules
      { project-id: project-id }
      {
        base-tier-amount: base-amount,
        velocity-multiplier: velocity-multiplier,
        urgency-bonus-percentage: urgency-bonus,
        tier-adjustment-frequency: adjustment-frequency,
        max-tier-amount: max-amount,
        min-tier-amount: min-amount
      }
    )
    (map-set project-tier-settings
      { project-id: project-id }
      {
        next-tier-level: u1,
        last-tier-update: stacks-block-height,
        auto-scaling-enabled: true,
        performance-threshold: u75
      }
    )
    (ok true)
  )
)

(define-public (calculate-funding-velocity (project-id uint))
  (let (
    (project (unwrap! (contract-call? .crowdfunding get-project project-id) (err ERR-NOT-FOUND)))
    (current-velocity (default-to
      { last-calculation-height: u0, recent-funding-amount: u0, velocity-score: u0, trend-direction: true }
      (map-get? funding-velocity { project-id: project-id })))
    (current-amount (get current-amount project))
    (blocks-passed (- stacks-block-height (get last-calculation-height current-velocity)))
    (funding-increase (- current-amount (get recent-funding-amount current-velocity)))
    (new-velocity-score (if (> blocks-passed u0) (/ funding-increase blocks-passed) u0))
    (trend-up (> new-velocity-score (get velocity-score current-velocity)))
  )
    (map-set funding-velocity
      { project-id: project-id }
      {
        last-calculation-height: stacks-block-height,
        recent-funding-amount: current-amount,
        velocity-score: new-velocity-score,
        trend-direction: trend-up
      }
    )
    (ok new-velocity-score)
  )
)

(define-public (generate-dynamic-tier (project-id uint))
  (let (
    (tier-rules (unwrap! (map-get? dynamic-tier-rules { project-id: project-id }) (err ERR-NOT-FOUND)))
    (tier-settings (unwrap! (map-get? project-tier-settings { project-id: project-id }) (err ERR-NOT-FOUND)))
    (velocity-data (unwrap! (map-get? funding-velocity { project-id: project-id }) (err ERR-NOT-FOUND)))
    (base-amount (get base-tier-amount tier-rules))
    (velocity-score (get velocity-score velocity-data))
    (velocity-adjustment (/ (* base-amount velocity-score (get velocity-multiplier tier-rules)) u10000))
    (adjusted-amount (+ base-amount velocity-adjustment))
    (final-amount (if (> adjusted-amount (get max-tier-amount tier-rules))
                     (get max-tier-amount tier-rules)
                     (if (< adjusted-amount (get min-tier-amount tier-rules))
                         (get min-tier-amount tier-rules)
                         adjusted-amount)))
    (tier-level (get next-tier-level tier-settings))
    (urgency-duration (get tier-adjustment-frequency tier-rules))
    (reward-multiplier (if (get trend-direction velocity-data) u120 u100))
  )
    (asserts! (get auto-scaling-enabled tier-settings) (err ERR-UNAUTHORIZED))
    (map-set dynamic-tiers
      { project-id: project-id, tier-level: tier-level }
      {
        current-amount: final-amount,
        reward-multiplier: reward-multiplier,
        urgency-expires-at: (+ stacks-block-height urgency-duration),
        auto-generated: true,
        participants-count: u0
      }
    )
    (map-set project-tier-settings
      { project-id: project-id }
      (merge tier-settings {
        next-tier-level: (+ tier-level u1),
        last-tier-update: stacks-block-height
      })
    )
    (ok tier-level)
  )
)

(define-public (participate-in-dynamic-tier
    (project-id uint)
    (tier-level uint)
    (contribution-amount uint)
    (token <token-trait>)
  )
  (let (
    (project (unwrap! (contract-call? .crowdfunding get-project project-id) (err ERR-NOT-FOUND)))
    (tier-info (unwrap! (map-get? dynamic-tiers { project-id: project-id, tier-level: tier-level }) (err ERR-NOT-FOUND)))
    (tier-rules (unwrap! (map-get? dynamic-tier-rules { project-id: project-id }) (err ERR-NOT-FOUND)))
    (required-amount (get current-amount tier-info))
    (is-tier-active (< stacks-block-height (get urgency-expires-at tier-info)))
    (urgency-bonus (if is-tier-active 
                      (/ (* contribution-amount (get urgency-bonus-percentage tier-rules)) u100)
                      u0))
    (total-contribution (+ contribution-amount urgency-bonus))
  )
    (asserts! (>= contribution-amount required-amount) (err ERR-INSUFFICIENT-FUNDING))
    (asserts! is-tier-active (err ERR-TIER-EXPIRED))
    (try! (contract-call? token transfer tx-sender (as-contract tx-sender) contribution-amount))
    (try! (contract-call? .crowdfunding update-project-amount project-id total-contribution))
    (map-set tier-participations
      { project-id: project-id, tier-level: tier-level, participant: tx-sender }
      {
        amount-contributed: contribution-amount,
        joined-at: stacks-block-height,
        bonus-applied: urgency-bonus
      }
    )
    (map-set dynamic-tiers
      { project-id: project-id, tier-level: tier-level }
      (merge tier-info {
        participants-count: (+ (get participants-count tier-info) u1)
      })
    )
    (ok total-contribution)
  )
)

(define-public (trigger-tier-auto-scaling (project-id uint))
  (let (
    (tier-settings (unwrap! (map-get? project-tier-settings { project-id: project-id }) (err ERR-NOT-FOUND)))
    (tier-rules (unwrap! (map-get? dynamic-tier-rules { project-id: project-id }) (err ERR-NOT-FOUND)))
    (blocks-since-update (- stacks-block-height (get last-tier-update tier-settings)))
    (adjustment-frequency (get tier-adjustment-frequency tier-rules))
  )
    (asserts! (>= blocks-since-update adjustment-frequency) (err ERR-UNAUTHORIZED))
    (try! (calculate-funding-velocity project-id))
    (try! (generate-dynamic-tier project-id))
    (ok true)
  )
)

(define-public (toggle-auto-scaling (project-id uint) (enabled bool))
  (let (
    (project (unwrap! (contract-call? .crowdfunding get-project project-id) (err ERR-NOT-FOUND)))
    (tier-settings (unwrap! (map-get? project-tier-settings { project-id: project-id }) (err ERR-NOT-FOUND)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err ERR-UNAUTHORIZED))
    (map-set project-tier-settings
      { project-id: project-id }
      (merge tier-settings { auto-scaling-enabled: enabled })
    )
    (ok true)
  )
)

(define-read-only (get-tier-info (project-id uint) (tier-level uint))
  (map-get? dynamic-tiers { project-id: project-id, tier-level: tier-level })
)

(define-read-only (get-funding-velocity-info (project-id uint))
  (map-get? funding-velocity { project-id: project-id })
)

(define-read-only (get-tier-participation (project-id uint) (tier-level uint) (participant principal))
  (map-get? tier-participations { project-id: project-id, tier-level: tier-level, participant: participant })
)

(define-read-only (calculate-tier-urgency-remaining (project-id uint) (tier-level uint))
  (let (
    (tier-info (map-get? dynamic-tiers { project-id: project-id, tier-level: tier-level }))
  )
    (if (is-some tier-info)
      (let (
        (expires-at (get urgency-expires-at (unwrap-panic tier-info)))
      )
        (if (> expires-at stacks-block-height)
          (some (- expires-at stacks-block-height))
          (some u0)))
      none)
  )
)

(define-read-only (get-recommended-tier-amount (project-id uint))
  (let (
    (tier-rules (map-get? dynamic-tier-rules { project-id: project-id }))
    (velocity-data (map-get? funding-velocity { project-id: project-id }))
  )
    (if (and (is-some tier-rules) (is-some velocity-data))
      (let (
        (base-amount (get base-tier-amount (unwrap-panic tier-rules)))
        (velocity-score (get velocity-score (unwrap-panic velocity-data)))
        (multiplier (get velocity-multiplier (unwrap-panic tier-rules)))
        (adjustment (/ (* base-amount velocity-score multiplier) u10000))
      )
        (some (+ base-amount adjustment)))
      none)
  )
)

(define-read-only (is-tier-trending-up (project-id uint))
  (let (
    (velocity-data (map-get? funding-velocity { project-id: project-id }))
  )
    (if (is-some velocity-data)
      (get trend-direction (unwrap-panic velocity-data))
      false)
  )
)

(define-trait token-trait
  (
    (transfer (principal principal uint) (response bool uint))
    (get-balance (principal) (response uint uint))
  )
)
