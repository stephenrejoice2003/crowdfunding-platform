;; Campaign Update Scheduler Contract
;; Automates project communications and scheduled backer notifications
;; Integrates with existing crowdfunding system for enhanced engagement

(define-constant ERR-NOT-AUTHORIZED u5001)
(define-constant ERR-PROJECT-NOT-FOUND u5002) 
(define-constant ERR-UPDATE-NOT-FOUND u5003)
(define-constant ERR-INVALID-SCHEDULE u5004)
(define-constant ERR-UPDATE-ALREADY-EXECUTED u5005)
(define-constant ERR-MILESTONE-NOT-FOUND u5006)
(define-constant ERR-INVALID-TEMPLATE u5007)

;; Update types
(define-constant UPDATE-TYPE-TIME-BASED u1)
(define-constant UPDATE-TYPE-MILESTONE-TRIGGERED u2)
(define-constant UPDATE-TYPE-FUNDING-MILESTONE u3)

;; Scheduled updates mapping
(define-map scheduled-updates
  { update-id: uint }
  {
    project-id: uint,
    creator: principal,
    update-type: uint,
    title: (string-ascii 100),
    content: (string-ascii 500),
    trigger-block-height: uint,
    milestone-id: (optional uint),
    funding-threshold: (optional uint),
    is-executed: bool,
    created-at: uint,
    template-id: uint
  })

;; Update templates for common communications
(define-map update-templates
  { template-id: uint }
  {
    template-name: (string-ascii 50),
    title-template: (string-ascii 100),
    content-template: (string-ascii 500),
    category: (string-ascii 30),
    is-active: bool
  })

;; Project update schedules
(define-map project-schedules
  { project-id: uint }
  {
    auto-updates-enabled: bool,
    update-interval: uint,
    last-auto-update: uint,
    next-scheduled-update: uint,
    total-scheduled: uint
  })

;; Executed updates log
(define-map executed-updates
  { update-id: uint }
  {
    executed-at: uint,
    actual-delivery-block: uint,
    notification-count: uint,
    execution-status: (string-ascii 20)
  })

;; Update counters
(define-map update-counters
  { counter-type: (string-ascii 10) }
  { value: uint })

;; Initialize default templates
(define-private (init-default-templates)
  (begin
    (map-set update-templates { template-id: u1 }
      { template-name: "Weekly Progress", title-template: "Weekly Update", 
        content-template: "Weekly progress update for project", category: "progress", is-active: true })
    (map-set update-templates { template-id: u2 }
      { template-name: "Milestone Achieved", title-template: "Milestone Completed", 
        content-template: "Milestone successfully completed", category: "milestone", is-active: true })
    (map-set update-templates { template-id: u3 }
      { template-name: "Funding Goal", title-template: "Funding Milestone Reached", 
        content-template: "Project has reached funding milestone", category: "funding", is-active: true })
    (map-set update-counters { counter-type: "updates" } { value: u0 })
    (map-set update-counters { counter-type: "templates" } { value: u3 })))

;; Get next update ID
(define-read-only (get-next-update-id)
  (+ u1 (default-to u0 (get value (map-get? update-counters { counter-type: "updates" })))))

;; Get project details from main crowdfunding contract
(define-private (get-project-info (project-id uint))
  (contract-call? .crowdfunding get-project project-id))

;; Schedule time-based update
(define-public (schedule-time-based-update 
    (project-id uint) 
    (title (string-ascii 100)) 
    (content (string-ascii 500))
    (blocks-delay uint)
    (template-id uint))
  (let ((project (unwrap! (get-project-info project-id) (err ERR-PROJECT-NOT-FOUND)))
        (update-id (get-next-update-id))
        (trigger-block (+ stacks-block-height blocks-delay)))
    
    (asserts! (is-eq tx-sender (get owner project)) (err ERR-NOT-AUTHORIZED))
    (asserts! (> blocks-delay u0) (err ERR-INVALID-SCHEDULE))
    
    (map-set scheduled-updates
      { update-id: update-id }
      {
        project-id: project-id,
        creator: tx-sender,
        update-type: UPDATE-TYPE-TIME-BASED,
        title: title,
        content: content,
        trigger-block-height: trigger-block,
        milestone-id: none,
        funding-threshold: none,
        is-executed: false,
        created-at: stacks-block-height,
        template-id: template-id
      })
    
    (map-set update-counters { counter-type: "updates" } { value: update-id })
    (unwrap-panic (update-project-schedule project-id))
    (ok update-id)))

;; Schedule milestone-triggered update
(define-public (schedule-milestone-update 
    (project-id uint) 
    (milestone-id uint)
    (title (string-ascii 100)) 
    (content (string-ascii 500))
    (template-id uint))
  (let ((project (unwrap! (get-project-info project-id) (err ERR-PROJECT-NOT-FOUND)))
        (update-id (get-next-update-id)))
    
    (asserts! (is-eq tx-sender (get owner project)) (err ERR-NOT-AUTHORIZED))
    
    (map-set scheduled-updates
      { update-id: update-id }
      {
        project-id: project-id,
        creator: tx-sender,
        update-type: UPDATE-TYPE-MILESTONE-TRIGGERED,
        title: title,
        content: content,
        trigger-block-height: u0,
        milestone-id: (some milestone-id),
        funding-threshold: none,
        is-executed: false,
        created-at: stacks-block-height,
        template-id: template-id
      })
    
    (map-set update-counters { counter-type: "updates" } { value: update-id })
    (unwrap-panic (update-project-schedule project-id))
    (ok update-id)))

;; Schedule funding milestone update
(define-public (schedule-funding-milestone-update 
    (project-id uint) 
    (funding-amount uint)
    (title (string-ascii 100)) 
    (content (string-ascii 500))
    (template-id uint))
  (let ((project (unwrap! (get-project-info project-id) (err ERR-PROJECT-NOT-FOUND)))
        (update-id (get-next-update-id)))
    
    (asserts! (is-eq tx-sender (get owner project)) (err ERR-NOT-AUTHORIZED))
    (asserts! (> funding-amount u0) (err ERR-INVALID-SCHEDULE))
    
    (map-set scheduled-updates
      { update-id: update-id }
      {
        project-id: project-id,
        creator: tx-sender,
        update-type: UPDATE-TYPE-FUNDING-MILESTONE,
        title: title,
        content: content,
        trigger-block-height: u0,
        milestone-id: none,
        funding-threshold: (some funding-amount),
        is-executed: false,
        created-at: stacks-block-height,
        template-id: template-id
      })
    
    (map-set update-counters { counter-type: "updates" } { value: update-id })
    (unwrap-panic (update-project-schedule project-id))
    (ok update-id)))

;; Execute scheduled update when conditions are met
(define-public (execute-scheduled-update (update-id uint))
  (let ((update-info (unwrap! (map-get? scheduled-updates { update-id: update-id }) (err ERR-UPDATE-NOT-FOUND)))
        (project (unwrap! (get-project-info (get project-id update-info)) (err ERR-PROJECT-NOT-FOUND))))
    
    (asserts! (not (get is-executed update-info)) (err ERR-UPDATE-ALREADY-EXECUTED))
    (asserts! (is-ready-for-execution update-info project) (err ERR-INVALID-SCHEDULE))
    
    ;; Mark update as executed
    (map-set scheduled-updates
      { update-id: update-id }
      (merge update-info { is-executed: true }))
    
    ;; Log execution
    (map-set executed-updates
      { update-id: update-id }
      {
        executed-at: stacks-block-height,
        actual-delivery-block: stacks-block-height,
        notification-count: u1,
        execution-status: "completed"
      })
    
    ;; Create the actual project update
    (try! (contract-call? .crowdfunding post-project-update 
           (get project-id update-info) 
           (get title update-info) 
           (get content update-info)))
    
    (ok true)))

;; Check if update is ready for execution
(define-private (is-ready-for-execution (update-info { project-id: uint, creator: principal, update-type: uint, title: (string-ascii 100), content: (string-ascii 500), trigger-block-height: uint, milestone-id: (optional uint), funding-threshold: (optional uint), is-executed: bool, created-at: uint, template-id: uint }) (project { owner: principal, goal: uint, current-amount: uint, deadline: uint, is-active: bool }))
  (let ((update-type (get update-type update-info)))
    (if (is-eq update-type UPDATE-TYPE-TIME-BASED)
        (>= stacks-block-height (get trigger-block-height update-info))
        (if (is-eq update-type UPDATE-TYPE-FUNDING-MILESTONE)
            (>= (get current-amount project) (unwrap-panic (get funding-threshold update-info)))
            true))))

;; Update project schedule tracking
(define-private (update-project-schedule (project-id uint))
  (let ((schedule (default-to 
                    { auto-updates-enabled: true, update-interval: u1000, last-auto-update: u0, 
                      next-scheduled-update: u0, total-scheduled: u0 }
                    (map-get? project-schedules { project-id: project-id }))))
    (map-set project-schedules
      { project-id: project-id }
      (merge schedule { total-scheduled: (+ (get total-scheduled schedule) u1) }))
    (ok true)))

;; Cancel scheduled update
(define-public (cancel-scheduled-update (update-id uint))
  (let ((update-info (unwrap! (map-get? scheduled-updates { update-id: update-id }) (err ERR-UPDATE-NOT-FOUND))))
    (asserts! (is-eq tx-sender (get creator update-info)) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (get is-executed update-info)) (err ERR-UPDATE-ALREADY-EXECUTED))
    
    (map-delete scheduled-updates { update-id: update-id })
    (ok true)))

;; Get scheduled updates for a project
(define-read-only (get-project-scheduled-updates (project-id uint))
  (ok { project-id: project-id, message: "Use get-scheduled-update for individual updates" }))

;; Get scheduled update details
(define-read-only (get-scheduled-update (update-id uint))
  (ok (map-get? scheduled-updates { update-id: update-id })))

;; Get project schedule settings
(define-read-only (get-project-schedule (project-id uint))
  (ok (map-get? project-schedules { project-id: project-id })))

;; Get update template
(define-read-only (get-update-template (template-id uint))
  (ok (map-get? update-templates { template-id: template-id })))

;; Get pending updates (ready for execution)
(define-read-only (get-pending-updates-count)
  (ok (default-to u0 (get value (map-get? update-counters { counter-type: "updates" })))))

;; Initialize contract with default templates
(init-default-templates)
