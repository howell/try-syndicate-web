#lang syndicate

(assertion-struct active ())
(message-struct toggle ())
(message-struct stdout-message (body))

(spawn #:name 'printer
       (on (message (stdout-message $body))
           (displayln body)))

(spawn* #:name 'flip-flop
        (define (active-state)
          (react (assert (active))
                 (stop-when (message (toggle))
                    (inactive-state))))
        (define (inactive-state)
          (react (stop-when (message (toggle))
                    (active-state))))
        (inactive-state))

(spawn #:name 'monitor-flip-flop
       (on (asserted (active)) (send! (stdout-message "Flip-flop is active")))
       (on (retracted (active)) (send! (stdout-message "Flip-flop is inactive"))))

(spawn #:name 'periodic-toggle
       (field [next-toggle-time (current-inexact-milliseconds)])
       (define deadline (+ (current-inexact-milliseconds) 10000))
       (stop-when (later-than deadline))
       (on (asserted (later-than (next-toggle-time)))
           (send! (toggle))
           (next-toggle-time (+ (next-toggle-time) 1000))))