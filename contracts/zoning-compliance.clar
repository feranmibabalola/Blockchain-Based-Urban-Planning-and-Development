;; Zoning Compliance Contract
;; Records land use requirements

(define-data-var contract-version uint u1)

;; Zone types: 0=residential, 1=commercial, 2=industrial, 3=mixed, 4=agricultural, 5=public
(define-map zoning-regulations
  { zone-id: (string-ascii 36) }
  {
    zone-type: uint,
    name: (string-ascii 100),
    description: (string-utf8 500),
    max-height: uint,
    max-density: uint,
    allowed-uses: (list 10 uint),
    created-at: uint,
    created-by: principal
  }
)

;; Land parcels with assigned zoning
(define-map land-parcels
  { parcel-id: (string-ascii 36) }
  {
    zone-id: (string-ascii 36),
    owner: principal,
    area: uint,
    location: (string-ascii 100),
    registered-at: uint
  }
)

;; Compliance records for projects
(define-map compliance-records
  { project-id: (string-ascii 36) }
  {
    parcel-id: (string-ascii 36),
    compliant: bool,
    height: uint,
    density: uint,
    proposed-use: uint,
    verified-by: (optional principal),
    verified-at: (optional uint)
  }
)

;; Initialize contract owner
(define-data-var contract-owner principal tx-sender)

;; List of authorized zoning officials
(define-map zoning-officials
  { official: principal }
  { active: bool }
)

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Check if caller is zoning official
(define-private (is-zoning-official)
  (default-to false (get active (map-get? zoning-officials { official: tx-sender })))
)

;; Add a new zoning regulation (only zoning officials)
(define-public (add-zoning-regulation
  (zone-id (string-ascii 36))
  (zone-type uint)
  (name (string-ascii 100))
  (description (string-utf8 500))
  (max-height uint)
  (max-density uint)
  (allowed-uses (list 10 uint))
)
  (begin
    (asserts! (is-zoning-official) (err u1)) ;; Must be zoning official
    (asserts! (not (is-some (map-get? zoning-regulations { zone-id: zone-id }))) (err u2)) ;; Zone ID must be unique
    (ok (map-set zoning-regulations
      { zone-id: zone-id }
      {
        zone-type: zone-type,
        name: name,
        description: description,
        max-height: max-height,
        max-density: max-density,
        allowed-uses: allowed-uses,
        created-at: block-height,
        created-by: tx-sender
      }
    ))
  )
)

;; Register a land parcel with zoning (only zoning officials)
(define-public (register-land-parcel
  (parcel-id (string-ascii 36))
  (zone-id (string-ascii 36))
  (owner principal)
  (area uint)
  (location (string-ascii 100))
)
  (begin
    (asserts! (is-zoning-official) (err u1)) ;; Must be zoning official
    (asserts! (is-some (map-get? zoning-regulations { zone-id: zone-id })) (err u3)) ;; Zone must exist
    (asserts! (not (is-some (map-get? land-parcels { parcel-id: parcel-id }))) (err u4)) ;; Parcel ID must be unique
    (ok (map-set land-parcels
      { parcel-id: parcel-id }
      {
        zone-id: zone-id,
        owner: owner,
        area: area,
        location: location,
        registered-at: block-height
      }
    ))
  )
)

;; Check compliance of a project (only zoning officials)
(define-public (check-compliance
  (project-id (string-ascii 36))
  (parcel-id (string-ascii 36))
  (height uint)
  (density uint)
  (proposed-use uint)
)
  (let (
    (parcel (map-get? land-parcels { parcel-id: parcel-id }))
    (zone-info (unwrap! (map-get? zoning-regulations { zone-id: (get zone-id (unwrap! parcel (err u5))) }) (err u6)))
    (is-compliant (and
      (<= height (get max-height zone-info))
      (<= density (get max-density zone-info))
      (is-some (index-of (get allowed-uses zone-info) proposed-use))
    ))
  )
    (begin
      (asserts! (is-zoning-official) (err u1)) ;; Must be zoning official
      (ok (map-set compliance-records
        { project-id: project-id }
        {
          parcel-id: parcel-id,
          compliant: is-compliant,
          height: height,
          density: density,
          proposed-use: proposed-use,
          verified-by: (some tx-sender),
          verified-at: (some block-height)
        }
      ))
    )
  )
)

;; Add a zoning official (only contract owner)
(define-public (add-zoning-official (official principal))
  (begin
    (asserts! (is-contract-owner) (err u7)) ;; Must be contract owner
    (ok (map-set zoning-officials { official: official } { active: true }))
  )
)

;; Remove a zoning official (only contract owner)
(define-public (remove-zoning-official (official principal))
  (begin
    (asserts! (is-contract-owner) (err u7)) ;; Must be contract owner
    (ok (map-set zoning-officials { official: official } { active: false }))
  )
)

;; Read-only function to get zoning regulation
(define-read-only (get-zoning-regulation (zone-id (string-ascii 36)))
  (map-get? zoning-regulations { zone-id: zone-id })
)

;; Read-only function to get land parcel
(define-read-only (get-land-parcel (parcel-id (string-ascii 36)))
  (map-get? land-parcels { parcel-id: parcel-id })
)

;; Read-only function to get compliance record
(define-read-only (get-compliance-record (project-id (string-ascii 36)))
  (map-get? compliance-records { project-id: project-id })
)

;; Transfer contract ownership (only current owner)
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) (err u7)) ;; Must be contract owner
    (ok (var-set contract-owner new-owner))
  )
)
