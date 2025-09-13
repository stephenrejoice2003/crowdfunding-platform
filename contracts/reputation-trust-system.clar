;; Project Reputation & Trust System Contract
;; Tracks creator performance, transparency metrics, and community validation

(define-map creator-profiles
  { creator: principal }
  {
    total-projects-launched: uint,
    successful-projects: uint,
    total-funds-raised: uint,
    total-funds-delivered: uint,
    avg-delivery-time: uint,
    transparency-score: uint,
    community-rating: uint,
    verification-level: uint,
    last-activity: uint
  }
)

(define-map project-reputation-scores
  { project-id: uint }
  {
    transparency-score: uint,
    delivery-confidence: uint,
    community-trust: uint,
    milestone-performance: uint,
    communication-rating: uint,
    overall-score: uint,
    risk-level: uint,
    last-score-update: uint
  }
)

(define-map trust-indicators
  { project-id: uint }
  {
    has-verified-identity: bool,
    has-business-registration: bool,
    has-prototype-evidence: bool,
    has-team-credentials: bool,
    social-media-verified: bool,
    has-financial-audit: bool,
    patent-portfolio-verified: bool,
    regulatory-compliance: bool
  }
)

(define-map performance-metrics
  { project-id: uint }
  {
    promised-delivery-date: uint,
    actual-delivery-date: uint,
    milestone-completion-rate: uint,
    communication-frequency: uint,
    update-quality-score: uint,
    budget-adherence: uint,
    scope-change-count: uint,
    backer-satisfaction: uint
  }
)

(define-map community-endorsements
  { project-id: uint, endorser: principal }
  {
    endorsement-type: uint,
    endorsement-weight: uint,
    endorsement-date: uint,
    endorser-reputation: uint,
    endorsement-rationale: (string-ascii 200)
  }
)

(define-map reputation-history
  { creator: principal, entry-id: uint }
  {
    action-type: uint,
    score-change: int,
    project-id: uint,
    timestamp: uint,
    description: (string-ascii 150)
  }
)

(define-map trust-validators
  { validator: principal }
  {
    is-active: bool,
    validation-count: uint,
    accuracy-rate: uint,
    specialization-area: uint,
    certification-level: uint
  }
)

(define-map project-risk-assessments
  { project-id: uint }
  {
    technical-risk: uint,
    market-risk: uint,
    financial-risk: uint,
    execution-risk: uint,
    regulatory-risk: uint,
    overall-risk-score: uint,
    assessment-date: uint,
    assessed-by: principal
  }
)

(define-map creator-history-counters
  { creator: principal }
  { next-entry-id: uint }
)

(define-map stakes
  { project-id: uint, staker: principal }
  { amount: uint }
)

(define-data-var contract-owner principal tx-sender)

(define-constant ERR-NOT-FOUND u404)
(define-constant ERR-UNAUTHORIZED u403)
(define-constant ERR-INVALID-INPUT u400)
(define-constant ERR-ALREADY-EXISTS u409)
(define-constant ERR-INSUFFICIENT-REPUTATION u410)

(define-constant TRANSPARENCY-WEIGHT u25)
(define-constant DELIVERY-WEIGHT u30)
(define-constant COMMUNITY-WEIGHT u20)
(define-constant MILESTONE-WEIGHT u15)
(define-constant COMMUNICATION-WEIGHT u10)

(define-public (initialize-creator-profile (creator principal))
  (let (
    (existing-profile (map-get? creator-profiles { creator: creator }))
  )
    (asserts! (is-none existing-profile) (err ERR-ALREADY-EXISTS))
    (map-set creator-profiles
      { creator: creator }
      {
        total-projects-launched: u0,
        successful-projects: u0,
        total-funds-raised: u0,
        total-funds-delivered: u0,
        avg-delivery-time: u0,
        transparency-score: u50,
        community-rating: u50,
        verification-level: u0,
        last-activity: stacks-block-height
      }
    )
    (map-set creator-history-counters
      { creator: creator }
      { next-entry-id: u1 }
    )
    (ok true)
  )
)

(define-private (update-creator-project-count (creator principal) (project-id uint))
  (let (
    (profile (default-to 
      { total-projects-launched: u0, successful-projects: u0, total-funds-raised: u0, 
        total-funds-delivered: u0, avg-delivery-time: u0, transparency-score: u50, 
        community-rating: u50, verification-level: u0, last-activity: stacks-block-height }
      (map-get? creator-profiles { creator: creator })))
  )
    (map-set creator-profiles
      { creator: creator }
      (merge profile { 
        total-projects-launched: (+ (get total-projects-launched profile) u1),
        last-activity: stacks-block-height
      })
    )
    (ok true)
  )
)

(define-public (setup-project-reputation (project-id uint))
  (let (
    (project (unwrap! (contract-call? .crowdfunding get-project project-id) (err ERR-NOT-FOUND)))
    (creator (get owner project))
  )
    (map-set project-reputation-scores
      { project-id: project-id }
      {
        transparency-score: u50,
        delivery-confidence: u50,
        community-trust: u50,
        milestone-performance: u50,
        communication-rating: u50,
        overall-score: u50,
        risk-level: u3,
        last-score-update: stacks-block-height
      }
    )
    (map-set trust-indicators
      { project-id: project-id }
      {
        has-verified-identity: false,
        has-business-registration: false,
        has-prototype-evidence: false,
        has-team-credentials: false,
        social-media-verified: false,
        has-financial-audit: false,
        patent-portfolio-verified: false,
        regulatory-compliance: false
      }
    )
    (map-set performance-metrics
      { project-id: project-id }
      {
        promised-delivery-date: u0,
        actual-delivery-date: u0,
        milestone-completion-rate: u0,
        communication-frequency: u0,
        update-quality-score: u50,
        budget-adherence: u100,
        scope-change-count: u0,
        backer-satisfaction: u50
      }
    )
    (unwrap-panic (update-creator-project-count creator project-id))
    (ok true)
  )
)

(define-public (submit-trust-verification (project-id uint) (verification-type uint) (evidence-hash (string-ascii 64)))
  (let (
    (project (unwrap! (contract-call? .crowdfunding get-project project-id) (err ERR-NOT-FOUND)))
    (trust-data (unwrap! (map-get? trust-indicators { project-id: project-id }) (err ERR-NOT-FOUND)))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err ERR-UNAUTHORIZED))
    (asserts! (<= verification-type u7) (err ERR-INVALID-INPUT))
    (let (
      (updated-trust-data 
        (if (is-eq verification-type u0)
          (merge trust-data { has-verified-identity: true })
          (if (is-eq verification-type u1)
            (merge trust-data { has-business-registration: true })
            (if (is-eq verification-type u2)
              (merge trust-data { has-prototype-evidence: true })
              (if (is-eq verification-type u3)
                (merge trust-data { has-team-credentials: true })
                (if (is-eq verification-type u4)
                  (merge trust-data { social-media-verified: true })
                  (if (is-eq verification-type u5)
                    (merge trust-data { has-financial-audit: true })
                    (if (is-eq verification-type u6)
                      (merge trust-data { patent-portfolio-verified: true })
                      (merge trust-data { regulatory-compliance: true })))))))))
    )
      (map-set trust-indicators { project-id: project-id } updated-trust-data)
      (try! (recalculate-transparency-score project-id))
      (ok true)
    )
  )
)

(define-public (endorse-project (project-id uint) (endorsement-type uint) (rationale (string-ascii 200)))
  (let (
    (project (unwrap! (contract-call? .crowdfunding get-project project-id) (err ERR-NOT-FOUND)))
    (endorser-profile (map-get? creator-profiles { creator: tx-sender }))
    (endorser-reputation (if (is-some endorser-profile)
                           (get community-rating (unwrap-panic endorser-profile))
                           u30))
    (endorsement-weight (/ endorser-reputation u10))
  )
    (asserts! (<= endorsement-type u4) (err ERR-INVALID-INPUT))
    (asserts! (>= endorser-reputation u60) (err ERR-INSUFFICIENT-REPUTATION))
    (map-set community-endorsements
      { project-id: project-id, endorser: tx-sender }
      {
        endorsement-type: endorsement-type,
        endorsement-weight: endorsement-weight,
        endorsement-date: stacks-block-height,
        endorser-reputation: endorser-reputation,
        endorsement-rationale: rationale
      }
    )
    (try! (update-community-trust-score project-id))
    (ok true)
  )
)

(define-public (assess-project-risk (project-id uint) (technical uint) (market uint) (financial uint) (execution uint) (regulatory uint))
  (let (
    (validator-info (map-get? trust-validators { validator: tx-sender }))
    (overall-risk (/ (+ technical market financial execution regulatory) u5))
  )
    (asserts! (is-some validator-info) (err ERR-UNAUTHORIZED))
    (asserts! (get is-active (unwrap-panic validator-info)) (err ERR-UNAUTHORIZED))
    (asserts! (<= technical u10) (err ERR-INVALID-INPUT))
    (asserts! (<= market u10) (err ERR-INVALID-INPUT))
    (asserts! (<= financial u10) (err ERR-INVALID-INPUT))
    (asserts! (<= execution u10) (err ERR-INVALID-INPUT))
    (asserts! (<= regulatory u10) (err ERR-INVALID-INPUT))
    (map-set project-risk-assessments
      { project-id: project-id }
      {
        technical-risk: technical,
        market-risk: market,
        financial-risk: financial,
        execution-risk: execution,
        regulatory-risk: regulatory,
        overall-risk-score: overall-risk,
        assessment-date: stacks-block-height,
        assessed-by: tx-sender
      }
    )
    (try! (update-project-reputation-score project-id))
    (ok true)
  )
)

(define-public (update-milestone-performance (project-id uint) (completion-rate uint) (on-time bool))
  (let (
    (project (unwrap! (contract-call? .crowdfunding get-project project-id) (err ERR-NOT-FOUND)))
    (performance-data (unwrap! (map-get? performance-metrics { project-id: project-id }) (err ERR-NOT-FOUND)))
    (bonus-score (if on-time u10 u0))
    (new-performance-score (+ completion-rate bonus-score))
  )
    (asserts! (is-eq tx-sender (get owner project)) (err ERR-UNAUTHORIZED))
    (asserts! (<= completion-rate u100) (err ERR-INVALID-INPUT))
    (map-set performance-metrics
      { project-id: project-id }
      (merge performance-data { milestone-completion-rate: new-performance-score })
    )
    (try! (update-project-reputation-score project-id))
    (ok true)
  )
)

(define-public (rate-communication-quality (project-id uint) (rating uint))
  (let (
    (stake-info (unwrap! (map-get? stakes { project-id: project-id, staker: tx-sender }) (err ERR-NOT-FOUND)))
    (performance-data (unwrap! (map-get? performance-metrics { project-id: project-id }) (err ERR-NOT-FOUND)))
  )
    (asserts! (<= rating u100) (err ERR-INVALID-INPUT))
    (asserts! (> (get amount stake-info) u0) (err ERR-UNAUTHORIZED))
    (map-set performance-metrics
      { project-id: project-id }
      (merge performance-data { communication-frequency: rating })
    )
    (try! (update-project-reputation-score project-id))
    (ok true)
  )
)

(define-public (register-trust-validator (validator principal) (specialization uint) (certification uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-UNAUTHORIZED))
    (asserts! (<= specialization u5) (err ERR-INVALID-INPUT))
    (asserts! (<= certification u3) (err ERR-INVALID-INPUT))
    (map-set trust-validators
      { validator: validator }
      {
        is-active: true,
        validation-count: u0,
        accuracy-rate: u100,
        specialization-area: specialization,
        certification-level: certification
      }
    )
    (ok true)
  )
)

(define-private (recalculate-transparency-score (project-id uint))
  (let (
    (trust-data (unwrap! (map-get? trust-indicators { project-id: project-id }) (err ERR-NOT-FOUND)))
    (reputation-data (unwrap! (map-get? project-reputation-scores { project-id: project-id }) (err ERR-NOT-FOUND)))
    (verification-count (+ 
      (if (get has-verified-identity trust-data) u1 u0)
      (if (get has-business-registration trust-data) u1 u0)
      (if (get has-prototype-evidence trust-data) u1 u0)
      (if (get has-team-credentials trust-data) u1 u0)
      (if (get social-media-verified trust-data) u1 u0)
      (if (get has-financial-audit trust-data) u1 u0)
      (if (get patent-portfolio-verified trust-data) u1 u0)
      (if (get regulatory-compliance trust-data) u1 u0)))
    (transparency-score (/ (* verification-count u100) u8))
  )
    (map-set project-reputation-scores
      { project-id: project-id }
      (merge reputation-data { transparency-score: transparency-score })
    )
    (ok transparency-score)
  )
)

(define-private (update-community-trust-score (project-id uint))
  (let (
    (reputation-data (unwrap! (map-get? project-reputation-scores { project-id: project-id }) (err ERR-NOT-FOUND)))
    (trust-score u70)
  )
    (map-set project-reputation-scores
      { project-id: project-id }
      (merge reputation-data { community-trust: trust-score })
    )
    (ok trust-score)
  )
)

(define-private (update-project-reputation-score (project-id uint))
  (let (
    (reputation-data (unwrap! (map-get? project-reputation-scores { project-id: project-id }) (err ERR-NOT-FOUND)))
    (transparency (get transparency-score reputation-data))
    (delivery (get delivery-confidence reputation-data))
    (community (get community-trust reputation-data))
    (milestone (get milestone-performance reputation-data))
    (communication (get communication-rating reputation-data))
    (overall-score (/ (+
      (* transparency TRANSPARENCY-WEIGHT)
      (* delivery DELIVERY-WEIGHT)
      (* community COMMUNITY-WEIGHT)
      (* milestone MILESTONE-WEIGHT)
      (* communication COMMUNICATION-WEIGHT)
    ) u100))
    (risk-level (if (> overall-score u80) u1
                  (if (> overall-score u60) u2
                    (if (> overall-score u40) u3
                      (if (> overall-score u20) u4 u5)))))
  )
    (map-set project-reputation-scores
      { project-id: project-id }
      (merge reputation-data { 
        overall-score: overall-score,
        risk-level: risk-level,
        last-score-update: stacks-block-height
      })
    )
    (ok overall-score)
  )
)

(define-read-only (get-project-reputation (project-id uint))
  (map-get? project-reputation-scores { project-id: project-id })
)

(define-read-only (get-creator-profile (creator principal))
  (map-get? creator-profiles { creator: creator })
)

(define-read-only (get-trust-indicators (project-id uint))
  (map-get? trust-indicators { project-id: project-id })
)

(define-read-only (get-risk-assessment (project-id uint))
  (map-get? project-risk-assessments { project-id: project-id })
)

(define-read-only (is-project-trustworthy (project-id uint))
  (let (
    (reputation-data (map-get? project-reputation-scores { project-id: project-id }))
  )
    (if (is-some reputation-data)
      (>= (get overall-score (unwrap-panic reputation-data)) u70)
      false)
  )
)

(define-read-only (get-endorsement (project-id uint) (endorser principal))
  (map-get? community-endorsements { project-id: project-id, endorser: endorser })
)

