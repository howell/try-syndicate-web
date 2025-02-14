#lang syndicate
;; Hello-worldish "bank account" example.

(struct account (balance) #:prefab)
(struct deposit (amount) #:prefab)

(spawn #:name 'banker
       (field [balance 0])
       (assert (account (balance)))
       (on (message (deposit $amount))
           (balance (+ (balance) amount))))

(spawn #:name 'observer
       (on (asserted (account $balance))
           (printf "Balance changed to ~a\n" balance)))

(spawn* #:name 'client
        (until (asserted (observe (deposit _))))
        (send! (deposit +100))
        (send! (deposit -30)))