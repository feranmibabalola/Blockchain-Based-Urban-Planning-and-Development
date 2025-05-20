;; Project Verification Contract
;; Validates development initiatives

(define-data-var contract-version uint u1)

;; Project status enum: 0=pending, 1=verified, 2=rejected
(define-map projects
  { project-id: (string-ascii 36) }
  {
    name: (string-ascii 100),
    description: (string-utf8 500),
    owner: principal,
    status: uint,
    verification-date: uint,
    verified-by: (optional principal)
  }
)

;; List of authorized verifiers
(define-map authorized-verifiers
  { verifier: principal }
  { active: bool }
)

;; Initialize contract owner
(define-data-var contract-owner principal tx-sender)

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Check if caller is authorized verifier
(define-private (is-authorized-verifier)
  (default-to false (get active (map-get? authorized-verifiers { verifier: tx-sender })))
)

;; Add a new project (can be done by anyone)
(define-public (submit-project (project-id (string-ascii 36)) (name (string-ascii 100)) (description (string-utf8 500)))
  (begin
    (asserts! (not (is-some (map-get? projects { project-id: project-id }))) (err u1)) ;; Project ID must be unique
    (ok (map-set projects
      { project-id: project-id }
      {
        name: name,
        description: description,
        owner: tx-sender,
        status: u0, ;; Pending
        verification-date: u0,
        verified-by: none
      }
    ))
  )
)

;; Verify a project (only authorized verifiers)
(define-public (verify-project (project-id (string-ascii 36)))
  (let ((project (map-get? projects { project-id: project-id })))
    (begin
      (asserts! (is-authorized-verifier) (err u2)) ;; Must be authorized verifier
      (asserts! (is-some project) (err u3)) ;; Project must exist
      (asserts! (is-eq (get status (unwrap-panic project)) u0) (err u4)) ;; Project must be pending
      (ok (map-set projects
        { project-id: project-id }
        (merge (unwrap-panic project)
          {
            status: u1, ;; Verified
            verification-date: block-height,
            verified-by: (some tx-sender)
          }
        )
      ))
    )
  )
)

;; Reject a project (only authorized verifiers)
(define-public (reject-project (project-id (string-ascii 36)))
  (let ((project (map-get? projects { project-id: project-id })))
    (begin
      (asserts! (is-authorized-verifier) (err u2)) ;; Must be authorized verifier
      (asserts! (is-some project) (err u3)) ;; Project must exist
      (asserts! (is-eq (get status (unwrap-panic project)) u0) (err u4)) ;; Project must be pending
      (ok (map-set projects
        { project-id: project-id }
        (merge (unwrap-panic project)
          {
            status: u2, ;; Rejected
            verification-date: block-height,
            verified-by: (some tx-sender)
          }
        )
      ))
    )
  )
)

;; Add an authorized verifier (only contract owner)
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-contract-owner) (err u5)) ;; Must be contract owner
    (ok (map-set authorized-verifiers { verifier: verifier } { active: true }))
  )
)

;; Remove an authorized verifier (only contract owner)
(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-contract-owner) (err u5)) ;; Must be contract owner
    (ok (map-set authorized-verifiers { verifier: verifier } { active: false }))
  )
)

;; Read-only function to get project details
(define-read-only (get-project (project-id (string-ascii 36)))
  (map-get? projects { project-id: project-id })
)

;; Read-only function to check if a principal is an authorized verifier
(define-read-only (is-verifier (verifier principal))
  (default-to false (get active (map-get? authorized-verifiers { verifier: verifier })))
)

;; Transfer contract ownership (only current owner)
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) (err u5)) ;; Must be contract owner
    (ok (var-set contract-owner new-owner))
  )
)
