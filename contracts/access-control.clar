;; Access Control Contract
;; Controls data access permissions

(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_ACCESS_DENIED (err u301))
(define-constant ERR_INVALID_ROLE (err u302))

;; Data maps
(define-map user-roles principal (string-ascii 20))
(define-map role-permissions (string-ascii 20) (list 10 (string-ascii 30)))
(define-map access-logs {user: principal, resource: (string-ascii 50)} {
    timestamp: uint,
    action: (string-ascii 20),
    granted: bool
})

;; Initialize roles and permissions
(map-set role-permissions "admin" (list "read" "write" "delete" "manage"))
(map-set role-permissions "officer" (list "read" "write" "audit"))
(map-set role-permissions "user" (list "read"))

;; Public functions
(define-public (assign-role (user principal) (role (string-ascii 20)))
    (begin
        ;; Only admin can assign roles
        (asserts! (is-eq (default-to "" (map-get? user-roles tx-sender)) "admin") ERR_UNAUTHORIZED)
        (asserts! (is-some (map-get? role-permissions role)) ERR_INVALID_ROLE)
        (map-set user-roles user role)
        (ok true)
    )
)

(define-public (request-access (resource (string-ascii 50)) (action (string-ascii 20)))
    (let (
        (user-role (default-to "user" (map-get? user-roles tx-sender)))
        (permissions (default-to (list) (map-get? role-permissions user-role)))
        (access-granted (is-some (index-of permissions action)))
    )
        (map-set access-logs {user: tx-sender, resource: resource} {
            timestamp: block-height,
            action: action,
            granted: access-granted
        })
        (if access-granted
            (ok true)
            ERR_ACCESS_DENIED
        )
    )
)

;; Read-only functions
(define-read-only (get-user-role (user principal))
    (map-get? user-roles user)
)

(define-read-only (has-permission (user principal) (action (string-ascii 20)))
    (let (
        (user-role (default-to "user" (map-get? user-roles user)))
        (permissions (default-to (list) (map-get? role-permissions user-role)))
    )
        (is-some (index-of permissions action))
    )
)

(define-read-only (get-access-log (user principal) (resource (string-ascii 50)))
    (map-get? access-logs {user: user, resource: resource})
)
