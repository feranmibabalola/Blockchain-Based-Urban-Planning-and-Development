;; Impact Assessment Contract
;; Evaluates community effects

(define-data-var contract-version uint u1)

;; Impact categories: 0=environmental, 1=social, 2=economic, 3=infrastructure, 4=cultural
(define-map impact-assessments
  { assessment-id: (string-ascii 36) }
  {
    project-id: (string-ascii 36),
    categories: (list 5 uint),
    scores: (list 5 int),
    description: (string-utf8 1000),
    mitigations: (string-utf8 1000),
    assessor: principal,
    created-at: uint,
    status: uint, ;; 0=draft, 1=submitted, 2=approved, 3=rejected
    reviewer: (optional principal),
    reviewed-at: (optional uint)
  }
)

;; Initialize contract owner
(define-data-var contract-owner principal tx-sender)

;; List of authorized assessors
(define-map authorized-assessors
  { assessor: principal }
  { active: bool }
)

;; List of authorized reviewers
(define-map authorized-reviewers
  { reviewer: principal }
  { active: bool }
)

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Check if caller is authorized assessor
(define-private (is-authorized-assessor)
  (default-to false (get active (map-get? authorized-assessors { assessor: tx-sender })))
)

;; Check if caller is authorized reviewer
(define-private (is-authorized-reviewer)
  (default-to false (get active (map-get? authorized-reviewers { reviewer: tx-sender })))
)

;; Create a draft impact assessment (only authorized assessors)
(define-public (create-assessment
  (assessment-id (string-ascii 36))
  (project-id (string-ascii 36))
  (categories (list 5 uint))
  (scores (list 5 int))
  (description (string-utf8 1000))
  (mitigations (string-utf8 1000))
)
  (begin
    (asserts! (is-authorized-assessor) (err u1)) ;; Must be authorized assessor
    (asserts! (not (is-some (map-get? impact-assessments { assessment-id: assessment-id }))) (err u2)) ;; Assessment ID must be unique
    (ok (map-set impact-assessments
      { assessment-id: assessment-id }
      {
        project-id: project-id,
        categories: categories,
        scores: scores,
        description: description,
        mitigations: mitigations,
        assessor: tx-sender,
        created-at: block-height,
        status: u0, ;; Draft
        reviewer: none,
        reviewed-at: none
      }
    ))
  )
)

;; Submit an assessment for review (only the assessor who created it)
(define-public (submit-assessment (assessment-id (string-ascii 36)))
  (let ((assessment (map-get? impact-assessments { assessment-id: assessment-id })))
    (begin
      (asserts! (is-some assessment) (err u3)) ;; Assessment must exist
      (asserts! (is-eq (get assessor (unwrap-panic assessment)) tx-sender) (err u4)) ;; Must be the original assessor
      (asserts! (is-eq (get status (unwrap-panic assessment)) u0) (err u5)) ;; Must be in draft status
      (ok (map-set impact-assessments
        { assessment-id: assessment-id }
        (merge (unwrap-panic assessment)
          { status: u1 } ;; Submitted
        )
      ))
    )
  )
)

;; Approve an assessment (only authorized reviewers)
(define-public (approve-assessment (assessment-id (string-ascii 36)))
  (let ((assessment (map-get? impact-assessments { assessment-id: assessment-id })))
    (begin
      (asserts! (is-authorized-reviewer) (err u6)) ;; Must be authorized reviewer
      (asserts! (is-some assessment) (err u3)) ;; Assessment must exist
      (asserts! (is-eq (get status (unwrap-panic assessment)) u1) (err u7)) ;; Must be in submitted status
      (ok (map-set impact-assessments
        { assessment-id: assessment-id }
        (merge (unwrap-panic assessment)
          {
            status: u2, ;; Approved
            reviewer: (some tx-sender),
            reviewed-at: (some block-height)
          }
        )
      ))
    )
  )
)

;; Reject an assessment (only authorized reviewers)
(define-public (reject-assessment (assessment-id (string-ascii 36)))
  (let ((assessment (map-get? impact-assessments { assessment-id: assessment-id })))
    (begin
      (asserts! (is-authorized-reviewer) (err u6)) ;; Must be authorized reviewer
      (asserts! (is-some assessment) (err u3)) ;; Assessment must exist
      (asserts! (is-eq (get status (unwrap-panic assessment)) u1) (err u7)) ;; Must be in submitted status
      (ok (map-set impact-assessments
        { assessment-id: assessment-id }
        (merge (unwrap-panic assessment)
          {
            status: u3, ;; Rejected
            reviewer: (some tx-sender),
            reviewed-at: (some block-height)
          }
        )
      ))
    )
  )
)

;; Add an authorized assessor (only contract owner)
(define-public (add-assessor (assessor principal))
  (begin
    (asserts! (is-contract-owner) (err u8)) ;; Must be contract owner
    (ok (map-set authorized-assessors { assessor: assessor } { active: true }))
  )
)

;; Remove an authorized assessor (only contract owner)
(define-public (remove-assessor (assessor principal))
  (begin
    (asserts! (is-contract-owner) (err u8)) ;; Must be contract owner
    (ok (map-set authorized-assessors { assessor: assessor } { active: false }))
  )
)

;; Add an authorized reviewer (only contract owner)
(define-public (add-reviewer (reviewer principal))
  (begin
    (asserts! (is-contract-owner) (err u8)) ;; Must be contract owner
    (ok (map-set authorized-reviewers { reviewer: reviewer } { active: true }))
  )
)

;; Remove an authorized reviewer (only contract owner)
(define-public (remove-reviewer (reviewer principal))
  (begin
    (asserts! (is-contract-owner) (err u8)) ;; Must be contract owner
    (ok (map-set authorized-reviewers { reviewer: reviewer } { active: false }))
  )
)

;; Read-only function to get assessment details
(define-read-only (get-assessment (assessment-id (string-ascii 36)))
  (map-get? impact-assessments { assessment-id: assessment-id })
)

;; Read-only function to check if a principal is an authorized assessor
(define-read-only (is-assessor (assessor principal))
  (default-to false (get active (map-get? authorized-assessors { assessor: assessor })))
)

;; Read-only function to check if a principal is an authorized reviewer
(define-read-only (is-reviewer (reviewer principal))
  (default-to false (get active (map-get? authorized-reviewers { reviewer: reviewer })))
)

;; Transfer contract ownership (only current owner)
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) (err u8)) ;; Must be contract owner
    (ok (var-set contract-owner new-owner))
  )
)
