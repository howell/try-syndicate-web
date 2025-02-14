#lang syndicate
;; A toy spreadsheet model.

(require racket/set)

(define-namespace-anchor ns)

(struct cell (name value) #:transparent) ;; assertion
(struct set-cell (name expr) #:transparent) ;; message

(define (binding-symbol? s)
  (and (symbol? s)
       (let ((chars (string->list (symbol->string s))))
         (and (andmap char-alphabetic? chars)
              (pair? chars)
              (char-upper-case? (car chars))))))

(define (extract-bindings expr)
  (let walk ((expr expr))
    (match expr
      [(? binding-symbol? b) (set b)]
      [(cons a d) (set-union (walk a) (walk d))]
      [_ (set)])))

(define (non-void? v) (not (void? v)))
(define (binding-pairs h)
  (for/list ([(k v) (in-hash h)])
    (list k v)))

(define (spawn-cell name expr)
  (define bindings (set->list (extract-bindings expr)))
  (spawn #:name (format "cell ~a" name)
         (stop-when (message (set-cell name _)))
         (field [inputs (for/hash [(b bindings)] (values b (void)))])

          (assert #:when (andmap non-void? (hash-values (inputs)))
                    (cell name
                          (eval `(let ,(binding-pairs (inputs))
                                    ,expr)
                                (namespace-anchor->namespace ns))))
            (for ([b (in-list bindings)])
              (on (asserted (cell b $value))
                  (inputs (hash-set (inputs) b value))))))

(spawn #:name 'cell-factory
       (on (message (set-cell $name $expr))
           (spawn-cell name expr)))

(spawn #:name 'observer
       (on (asserted (cell $name $value))
           (printf ">>> ~a ~v\n" name value)
           (flush-output)))

(spawn* #:name 'test-script
        (sleep 1)
        (send! (set-cell 'Name "World"))
        (sleep 1)
        (send! (set-cell 'Greeting (format "Hello, ~a!" 'Name)))
        (sleep 1)
        (send! (set-cell 'A 1))
        (sleep 1)
        (send! (set-cell 'B 2))
        (sleep 1)
        (send! (set-cell 'C 3))
        (sleep 1)
        (send! (set-cell 'Sum '(+ A B C)))
        (sleep 1)

        (send! (set-cell 'Name "Syndicate"))
        (sleep 1)
        (send! (set-cell 'A 10)))
