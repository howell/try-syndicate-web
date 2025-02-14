#lang syndicate
;; Simple mutable box and box client.

(message-struct set-box (new-value))
(assertion-struct box-state (value))

(spawn #:name 'box
       (field [current-value 0])
       (assert (box-state (current-value)))
       (stop-when-true (= (current-value) 10)
                       (printf "box: terminating\n"))
       (on (message (set-box $new-value))
           (printf "box: taking on new-value ~v\n" new-value)
           (current-value new-value)))

(spawn #:name 'client
       (stop-when (retracted (observe (set-box _)))
                  (printf "client: box has gone"))
       (on (asserted (box-state $v))
           (printf "client: learned that box's value is now ~v\n" v)
           (send! (set-box (+ v 1)))))