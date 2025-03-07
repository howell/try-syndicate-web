#lang syndicate

;; Market example from "Conversational Concurrency with Dataspaces and Facets" @ <Programming> 2025
;; https://programming-journal.org/2025/10/2/

(require (for-syntax racket/syntax)
         racket/set)

(assertion-struct client (id))
(assertion-struct balance (account amt))
(assertion-struct order (id account amt price))
;; answer is one of
;;  - 'fulfilled
;;  - 'no-price-match
;;  - 'insufficient-funds
;;  - 'canceled
(assertion-struct order-result (order answer))
(assertion-struct price (v))

(assertion-struct trading-open ())
(assertion-struct trading-closed ())


(assertion-struct client-finished (id))

(assertion-struct create-account (who bal))
(assertion-struct account-for (who num))
(assertion-struct withdraw-funds (id account amount))
(assertion-struct deposit-funds (id account amount))
(assertion-struct bank-response (id ok?))
(assertion-struct purchase (id amount price ok?))

(assertion-struct funds-needed (id account amt))
(assertion-struct funds-held (id account amt ok?))
(assertion-struct purchase-request (id amt p))
(assertion-struct purchase-response (id ok?))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; State Machine

(require syntax/parse/define)

(define-syntax-parse-rule (state-machine name
                            [(~or* label0:id (label0)) body0 ...]
                            [(~or* (~and labelN:id (~parse (argN ...) '()))
                                   (labelN argN ...))
                             bodyN ...] ...)
  #:with goto (format-id #'name "goto")
  (let ([label0 'label0]
        [labelN 'labelN]
        ...)
    (define (run-state state args)
      (react
        (define f (current-facet-id))
        (define (name #:transition-to new-state . new-args)
          (stop-facet f (run-state new-state new-args)))
        (define (goto lbl . args)
          (apply name #:transition-to lbl args))
        (match state
          ['label0 body0 ...]
          ['labelN (match-define (list argN ...) args) bodyN ...] ...)))
    (run-state label0 '())))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Broker

(define (spawn-broker)
  (spawn #:name 'broker

    (spawn-wallet)
    (spawn-order-cacher)

    (during (trading-open)
      (on (asserted (order $id $account $amt $desired-price))
          (react
            (define the-order (order id account amt desired-price))
            (define order-facet (current-facet-id))
            (define stop-with! (make-order-finisher! the-order order-facet))
            (work-on-one-order the-order stop-with!))))))

(define (make-order-finisher! the-order order-context)
  (field [termination-reason #false])
  (lambda (answer)
    (unless (termination-reason)
      (termination-reason answer)
      (stop-facet order-context
       (spawn #:name (format "order result ~a" (order-id the-order))
         (order-result-caching the-order answer))))))

(define (order-result-caching the-order answer)
  (define result (order-result the-order answer))
  (assert result)
  (stop-when (retracted (observe result))))

(define (work-on-one-order the-order stop-with!)
  (define potential-cost (max-order-cost the-order))
  (state-machine acquire-funds
    [request
     (define (on-funded) (goto funded))
     (request-funds the-order potential-cost on-funded stop-with!)]
    [funded
     (finish-funded the-order potential-cost stop-with!)]))

(define (max-order-cost the-order)
  (* (order-amt the-order)
     (order-price the-order)))

(define (request-funds the-order potential-cost on-funded stop-with!)
  (define account (order-account the-order))
  (assert (funds-needed the-order account potential-cost))
  (on (retracted the-order)
      (stop-with! 'canceled))
  (on (asserted (funds-held the-order account potential-cost #false))
      (stop-with! 'insufficient-funds))
  (on (asserted (funds-held the-order account potential-cost #true))
      (on-funded)))

(define (finish-funded the-order held-funds stop-with!)
  (state-machine purchase-progress
    [request
     (define (on-match actual) (goto purchase actual))
     (request-price the-order held-funds on-match stop-with!)]
    [(purchase actual)
     (complete-purchase the-order held-funds actual stop-with!)]))

(define (request-price the-order held-funds on-match stop-with!)
  (match-define (order _ account _ desired-price) the-order)
  (on (asserted (price $actual-price))
      (if (<= actual-price desired-price)
          (on-match actual-price)
          (stop-with! 'no-price-match)))
  (on (retracted the-order)
      (return->stop account held-funds 'canceled stop-with!)))

(define (return->stop account held-funds reason stop-with!)
  (deposit! account held-funds)
  (stop-with! reason))

(define (complete-purchase the-order held-funds actual stop-with!)
  (match-define (order _ account desired-no-shares _) the-order)
  (assert (purchase-request the-order desired-no-shares actual))
  (on (asserted (purchase-response the-order #true))
      (define left-over (- held-funds (* desired-no-shares actual)))
      (return->stop account left-over 'fulfilled stop-with!)))

(define (spawn-wallet)
  (spawn #:name 'wallet
    (field [processed (set)])
    (on (asserted (funds-needed $the-order $account $amt))
        (unless (set-member? (processed) the-order)
          (processed (set-add (processed) the-order))
          (react
            (define parent (current-facet-id))
            (assert (withdraw-funds the-order account amt))
            (during (bank-response the-order $ok?)
              (assert (funds-held the-order account amt ok?))
              (on (asserted (order-result the-order $ans))
                  (stop-facet parent
                              (when (and ok?
                                         (not (equal? 'fulfilled ans)))
                                (deposit! account amt))))))))))

(define (deposit! account amt)
  (unless (zero? amt)
    (spawn #:name (format "deposit ~a $~a" account amt)
      (define deposit-txn-id (gensym))
      (assert (deposit-funds deposit-txn-id account amt))
      (stop-when (asserted (bank-response deposit-txn-id _))))))

(define (spawn-order-cacher)
  (spawn #:name 'order-cacher
    (define/query-value trading? #f (trading-open) #t)
    (on (asserted (order $id $account $amt $desired-price))
        (define the-order (order id account amt desired-price))
        (react
          (stop-when (asserted (order-result the-order _)))
          (on (retracted the-order)
              (cond
                [(trading?)
                 (stop-current-facet)]
                [else
                 (stop-current-facet
                  (react
                    (assert the-order)
                    (on (asserted (trading-open))
                        (stop-current-facet))))]))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Seller


(define (spawn-seller share-price)
  (spawn #:name 'seller

    (during (trading-open)
      (assert (price share-price))

      (during (purchase-request $id $amt $p)
        (assert (purchase-response id (>= p share-price)))))))


(define (spawn-clock period days)
  (spawn #:name 'clock
    (field [days-elapsed 0])
    (define (open)
      (react
        (assert (trading-open))
        (stop-when-timeout period
         (days-elapsed (add1 (days-elapsed)))
         (when (< (days-elapsed) days)
           (closed)))))

    (define (closed)
      (react
        (assert (trading-closed))
        (stop-when-timeout period (open))))

    (closed)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Bank

(define (spawn-bank)
  (spawn #:name 'bank
    (field [next-number 0])
    (define (next-account-number!)
      (define num (next-number))
      (next-number (add1 (next-number)))
      num)
    (on (asserted (create-account $client $initial-balance))
        (define account-number (next-account-number!))
        (manage-account client account-number initial-balance))))

(define (manage-account client account-number initial-balance)
  (react
    (assert (account-for client account-number))
    (field [current-balance initial-balance])
    (assert (balance account-number (current-balance)))

    (during (withdraw-funds $id account-number $amt)
      (define accepted? (<= amt (current-balance)))
      (when accepted?
        (current-balance (- (current-balance) amt)))
      (assert (bank-response id accepted?)))

    (during (deposit-funds $id account-number $amt)
      (current-balance (+ (current-balance) amt))
      (assert (bank-response id #true)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Buyer

(define (spawn-buyer name initial-balance orders)
  (spawn #:name (format "buyer ~a" name)
    (assert (create-account name initial-balance))

    (field [remaining orders])
    (assert #:when (null? (remaining)) (client-finished name))

    (on (asserted (account-for name $account-number))
        (for ([spec orders])
          (match-define (list amt p cancel?) spec)
          (react
            (define id (gensym name))
            (define the-order (order id account-number amt p))
            (assert the-order)
            (on (asserted (order-result the-order $answer))
                (remaining (remove spec (remaining))))
            (when cancel?
              (define parent (current-facet-id))
              (on (asserted (trading-open))
                  (react
                    (on (asserted the-order)
                        (stop-facet parent
                                    (react
                                      (stop-when (asserted (order-result the-order 'canceled))
                                                 (remaining (remove spec (remaining)))))))))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Termination

(define (wait-to-finish ids)
  (spawn #:name 'wait-to-finish
    (define/query-set finished-clients (client-finished $id) id)
    (begin/dataflow
      (when (subset? (list->set ids) (finished-clients))
        (printf "all clients finished\n")))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Logging

(define (spawn-logger)
  (spawn #:name 'logger
    (on (asserted (order $id $account $amt $price))
        (define the-order (order id account amt price))
        (printf "buyer ~a issues an order to buy ~a shares at price $~a\n" account amt price)
        (react
          (on (retracted the-order)
              (printf "buyer ~a requests to cancel their order of ~a @ $~a\n" account amt price))
          (stop-when (asserted (order-result the-order $answer))
              (printf "broker informs buyer ~a of the result of their order of ~a @ $~a: ~a\n" account amt price answer))))

    (on (asserted (withdraw-funds $id $account $amt))
        (react
          (stop-when (asserted (bank-response id $ok?))
                     (printf "a transaction to withdraw $~a from client account ~a ~a\n" amt account (if ok? "succeeds" "fails")))))

    (on (asserted (deposit-funds $id $account $amt))
        (react
          (stop-when (asserted (bank-response id $ok?))
                     (printf "a transaction to deposit $~a in client account ~a ~a\n" amt account (if ok? "succeeds" "fails")))))

    (on (asserted (observe (purchase $id $amt $p _)))
        (react
          (stop-when (asserted (purchase id amt p $ok?))
                     (printf "a request to purchase ~a shares @ $~a each ~a\n" amt p (if ok? "succeeds" "fails")))))

    (on (asserted (trading-open))
        (printf "trading opens\n"))

    (on (asserted (trading-closed))
        (printf "trading closes\n"))

    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Main

(define (main)
  (spawn-bank)
  (spawn-buyer 'a 100 '((1 2 #f) (1 3 #t)))
  (spawn-buyer 'b 100 '((2 1 #f) (100 2 #f) (3 4 #t)))
  (spawn-buyer 'c 100 '((2 2 #f)))
  (spawn-seller 1)
  (spawn-clock 1000 3)

  (spawn-broker)
  (spawn-logger)
  (wait-to-finish '(a b c)))

(main)
