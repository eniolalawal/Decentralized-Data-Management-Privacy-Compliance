;; Breach Notification Contract
;; Manages data breach notifications and reporting

(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INVALID_SEVERITY (err u501))
(define-constant ERR_BREACH_NOT_FOUND (err u502))

;; Data maps
(define-map breach-reports uint {
    reporter: principal,
    severity: (string-ascii 10),
    description: (string-ascii 200),
    affected-users: uint,
    reported-at: uint,
    resolved: bool,
    resolution-notes: (string-ascii 200)
})

(define-map user-notifications {user: principal, breach-id: uint} {
    notified-at: uint,
    acknowledged: bool
})

(define-data-var breach-counter uint u0)

;; Valid severity levels
(define-map valid-severities (string-ascii 10) bool)
(map-set valid-severities "low" true)
(map-set valid-severities "medium" true)
(map-set valid-severities "high" true)
(map-set valid-severities "critical" true)

;; Public functions
(define-public (report-breach (severity (string-ascii 10)) (description (string-ascii 200)) (affected-users uint))
    (let ((breach-id (+ (var-get breach-counter) u1)))
        (asserts! (default-to false (map-get? valid-severities severity)) ERR_INVALID_SEVERITY)
        (map-set breach-reports breach-id {
            reporter: tx-sender,
            severity: severity,
            description: description,
            affected-users: affected-users,
            reported-at: block-height,
            resolved: false,
            resolution-notes: ""
        })
        (var-set breach-counter breach-id)
        (ok breach-id)
    )
)

(define-public (resolve-breach (breach-id uint) (resolution-notes (string-ascii 200)))
    (match (map-get? breach-reports breach-id)
        breach (begin
            (map-set breach-reports breach-id
                (merge breach {
                    resolved: true,
                    resolution-notes: resolution-notes
                })
            )
            (ok true)
        )
        ERR_BREACH_NOT_FOUND
    )
)

(define-public (notify-user (user principal) (breach-id uint))
    (begin
        (asserts! (is-some (map-get? breach-reports breach-id)) ERR_BREACH_NOT_FOUND)
        (map-set user-notifications {user: user, breach-id: breach-id} {
            notified-at: block-height,
            acknowledged: false
        })
        (ok true)
    )
)

(define-public (acknowledge-notification (breach-id uint))
    (let ((notification-key {user: tx-sender, breach-id: breach-id}))
        (match (map-get? user-notifications notification-key)
            notification (begin
                (map-set user-notifications notification-key
                    (merge notification {acknowledged: true})
                )
                (ok true)
            )
            (err u404)
        )
    )
)

;; Read-only functions
(define-read-only (get-breach-report (breach-id uint))
    (map-get? breach-reports breach-id)
)

(define-read-only (get-user-notification (user principal) (breach-id uint))
    (map-get? user-notifications {user: user, breach-id: breach-id})
)

(define-read-only (get-breach-count)
    (var-get breach-counter)
)
