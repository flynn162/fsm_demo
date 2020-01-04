;; Copyright 2020 Flynn Liu
;; SPDX-License-Identifier: Apache-2.0

(import (scheme base)
        (scheme write)
        (scheme file)
        (scheme read)
        (scheme process-context)
        (scheme char)
        (srfi 27)  ; random source
        (srfi 69)  ; dictionary
        )

;; define (zip list1 ...)
(cond-expand
  (racket
   (begin
     (define zip
       (lambda ls (apply map (cons list ls)))
       )))
  (else
   (import (only (srfi 1) zip)))
  )

;; define (sort! vec lt key)
(cond-expand
  (racket
   ;; chibi won't recognize #:keyword
   (begin
     (import (only (racket vector) vector-sort!)
             (only (racket base) string->keyword keyword-apply)
             (rename (only (racket base) list) (list ilist)))
     (define (sort! vec lt key)
       (keyword-apply vector-sort!
                      (ilist (string->keyword "key")) (ilist key)
                      (ilist vec lt)))
     ))
  (else
   (import (only (srfi 95) sort!)))
  )

;; define (rename-file old new)
(cond-expand
  (gauche
   (import (rename (only (gauche base) sys-rename) (sys-rename rename-file))))
  (chibi
   (import (only (chibi filesystem) rename-file)))
  (racket
   (begin
     (import (only (racket base) rename-file-or-directory))
     (define (rename-file old new) (rename-file-or-directory old new #t))))
  )

;; patch Gauche's janky hash-table-ref
(cond-expand
  (gauche
   (begin
     (define %hash-table-ref/original hash-table-ref)
     (set! hash-table-ref
       (lambda args
         (let ((self (car args))
               (key (cadr args))
               (default (cddr args)))
           (if (and (null? default) (not (hash-table-exists? self key)))
               (error "Key Error:" key)
               (apply %hash-table-ref/original args)))))
     )))

(define (name/scheme->c symb)
  ;; convert a scheme symbol to a C-style name, returning a string
  (let ((replace-dash (lambda (c) (if (char=? #\- c) #\_ c)))
        (the-string (symbol->string symb)))
    (list->string (map replace-dash (string->list the-string)))))

(define (name/scheme->C-CAP symb)
  (string-upcase (name/scheme->c symb)))

(define (compile/declare-node state-name-in-enum n-edges)
  ;; The order of initialization parameter is important!!
  ;; Sinks will be generated with n-edges = 0
  ;; Unused nodes will also be generated, with n-edges = 0
  (list
   "static Node<SClass, TClass> node_" state-name-in-enum " = {\n"
   "  .name = " state-name-in-enum
   ", .n_edges = " n-edges
   ", .out_edges = nullptr"
   "\n};\n"
   ))

(define (compile/init-node state-name n-edges)
  (list
   "  "
   (if (> n-edges 0)
       `("node_" ,state-name ".out_edges = &(out_" , state-name "[0]);")
       `("/* The node " ,state-name " does not have any out-arrows */"))
   "\n"))

(define (compile/declare-edge-array state-name-in-enum input-next-array)
  (if (not (null? input-next-array))
      (%compile/declare-edge-array state-name-in-enum input-next-array)
      '()))

(define (%compile/declare-edge-array state-name-in-enum input-next-array)
  ;; the fields must in the exact order of the declaration
  (list
   "static Edge<SClass, TClass> out_" state-name-in-enum "[] = {\n"
   (map (lambda (input-next)
          (list
           "  {.input = " (car input-next)
           ", .next = &node_" (cadr input-next) "},\n"))
        input-next-array)
   "};\n"))

(define (compile/declare-graph graph-name node-names)
  (list
   "Node* " graph-name "[] = {\n"
   (map (lambda (gn) `("&" ,gn ", ")) node-names) "};\n"
   "size_t " graph-name "_length = " (length node-names) ";\n"
   ))

(define (compile/declare-enum enum-name node-names)
  (list
   "enum " enum-name " {\n"
   (map (lambda (name) (string-append "  " name ",\n")) node-names)
   "  NR_" enum-name "\n"
   "};\n"))

(define-record-type <enum>
  (%make-enum)
  enum?
  (name enum-name %set-enum-name!)
  (dict %enum-dict %set-enum-dict!)
  (lex enum-lex %set-enum-lex!)
  (lex-c enum-lex-c %set-enum-lex-c!))

(define (make-enum name-symb list-of-options)
  (let ((result (%make-enum))
        (table (make-translation-table list-of-options name/scheme->C-CAP)))
    ;; first we set up a map between symbols and translations, and numbers
    (%set-enum-dict! result table)
    ;; then we store the list of options as is (lexical order)
    (%set-enum-lex! result list-of-options)
    (%set-enum-lex-c! result (map (lambda (s) (%enum-translate table s))
                                  list-of-options))
    ;; set the name
    (%set-enum-name! result (name/scheme->c name-symb))
    result))

(define (%enum-translate ht symb)
  (car (hash-table-ref ht symb)))

(define (enum-translate enum symb)
  (%enum-translate (%enum-dict enum) symb))

(define (enum-order enum symb)
  (cdr (hash-table-ref enum symb)))

(define (enum->c enum)
  (compile/declare-enum
   (enum-name enum)
   (enum-lex-c enum)))

(define (make-translation-table names transform)
  (let ((result (make-hash-table)))
    (let loop ((curr names))
      (cond ((null? curr) result)
            (#t (hash-table-set!
                 result
                 (car curr)
                 (cons (transform (car curr)) (hash-table-size result)))
                (loop (cdr curr))))
      )))

(define-record-type <acc>
  (%make-acc)
  acc?
  (first %acc-first %set-acc-first!)
  (last %acc-last %set-acc-last!))

(define (make-acc)
  (let* ((result (%make-acc))
         (sentinel (cons #t '())))
    (%set-acc-first! result sentinel)
    (%set-acc-last! result sentinel)
  result))

(define (acc-append! self value)
  (let ((node (cons value '())))
    (set-cdr! (%acc-last self) node)
    (%set-acc-last! self node)))

(define (acc->list self)
  (cdr (%acc-first self)))

(define-record-type <fsm>
  (%make-fsm)
  fsm?
  (name fsm-name %set-fsm-name!)
  (initial fsm-initial %set-fsm-initial!)
  (symbols fsm-symbols %set-fsm-symbols!)
  (states fsm-states %set-fsm-states!)
  (adj-list %fsm-adj-list %set-fsm-adj-list!)
  (n-edges-table fsm-n-edges-table %set-fsm-n-edges-table!)
  )

(define (%fsm-translate-edge one-edge)
  (map name/scheme->C-CAP one-edge))

(define (%fsm-translate-edges edges-for-one-node)
  (map %fsm-translate-edge edges-for-one-node))

(define (sort-edges! edges symbol-enum)
  (cond ((null? edges) edges)
        (#t (%sort-edges! edges (%enum-dict symbol-enum)))))

(define (%label-with-number! edges symbol-dict)
  ;; label each edge with the number from the translation table
  ;; (e1 e2 e3) -> ((3 . e1) (1 . e2) (2 . e3))
  (let loop ((curr edges))
    (cond ((null? curr) edges)
          (#t
           (let* ((edge (car curr))
                  (symbol (car edge))
                  ;; --- check if symbol exists first
                  (%exists (hash-table-exists? symbol-dict symbol))
                  (%error (if %exists #t (error 'what-symbol?! symbol)))
                  ;; ---
                  (value (hash-table-ref symbol-dict symbol))
                  (number (cdr value)))
             (set-car! curr (cons number edge))
             (loop (cdr curr))
             )))
    ))

(define (%sort-edges-and-delete-numbers edges)
  ;; convert list to vector for bug-free sorting :(
  (let* ((vec (list->vector edges))
         (%undef (sort! vec < car))
         (sorted (vector->list vec)))
    ;; for each pair, delete the number
    (let loop ((curr sorted))
      (cond ((null? curr) sorted)
            (#t
             (set-car! curr (cdar curr))
                (loop (cdr curr))))
      )))

(define (%sort-edges! edges symbol-dict)
  (%label-with-number! edges symbol-dict)
  (let ((sorted (%sort-edges-and-delete-numbers edges)))
    ;; overwrite the `edges` variable
    ;; first use set-car! on the first element
    (set-car! edges (car sorted))
    ;; then rewire the tail
    (set-cdr! edges (cdr sorted))
    )
  edges)



(define (make-fsm symbol-name symbol-initial symbol-enum state-enum fsm-exp)
  (define result (%make-fsm))
  (define adj-list (make-hash-table))
  (%set-fsm-name! result (name/scheme->c symbol-name))
  (%set-fsm-initial! result (name/scheme->C-CAP symbol-initial))
  (%set-fsm-symbols! result symbol-enum)
  (%set-fsm-states! result state-enum)

  ;; store translations
  (let loop ((curr fsm-exp))
    (cond ((null? curr) (%set-fsm-adj-list! result adj-list))
          (#t
           (let* ((key (car (car curr)))  ; node name (symbol)
                  (edges (sort-edges! (cadr (car curr)) symbol-enum))
                  (translated-edges (%fsm-translate-edges edges)))
             (hash-table-set! adj-list key (cons edges translated-edges))
             (loop (cdr curr)))
           )))

  ;; make the "n-edges" table, so that when the table is zipped with lexical
  ;; order state enum, it lines up perfectly
  (let* ((default (cons '() '()))
         (default-f (lambda () default))
         (length-f (lambda (dict-value) (length (car dict-value)))))
    (%set-fsm-n-edges-table!
     result
     (map (lambda (sym) (length-f (hash-table-ref adj-list sym default-f)))
          (enum-lex state-enum))))
  result)

(define (fsm-translate-edges self node-symb)
  (cdr (hash-table-ref (%fsm-adj-list self) node-symb)))

(define (fsm-header->c self)
  (list
   "typedef " (enum-name (fsm-symbols self)) " SClass;\n"
   "typedef " (enum-name (fsm-states self)) " TClass;\n"))

(define (make-zip-applier func)
  (lambda (args) (apply func args)))

(define (fsm-nodes->c self)
  (list
   (map (make-zip-applier compile/declare-node)
        (zip (enum-lex-c (fsm-states self))
             (fsm-n-edges-table self)))))

(define (fsm-init->c self)
  (list
   "static bool initialized = false;\n"
   "void init() {\n"
   "  if (initialized) return;\n"
   (map (make-zip-applier compile/init-node)
        (zip (enum-lex-c (fsm-states self))
             (fsm-n-edges-table self)))
   "  initialized = true;\n"
   "};\n"))

(define (%fsm-edge->c self node-symb)
  (let* ((default (cons '() '()))
         (default-f (lambda () default)))
    (compile/declare-edge-array
     (enum-translate (fsm-states self) node-symb)
     (cdr (hash-table-ref (%fsm-adj-list self) node-symb default-f)))
    ))

(define (fsm-edges->c self)
  (map (lambda (symb) (%fsm-edge->c self symb))
       (enum-lex (fsm-states self))))

(define (fsm-decl->c self)
  (list
   "Node<SClass, TClass>* array_" (fsm-name self) "[] = {"
   (map (lambda (node-name) (string-append "\n  &node_" node-name ","))
        (enum-lex-c (fsm-states self)))
   "\n  nullptr"
   "\n};\n"
   ;;
   "FsmInfo<SClass, TClass> " (fsm-name self) " = {"
   "\n  .length = " (length (enum-lex (fsm-states self))) ","
   "\n  .nodes = &(array_" (fsm-name self) "[0]),"
   "\n  .initial = &node_" (fsm-initial self)
   "\n};"
   ))

(define-record-type <environment>
  (make-env)
  env?
  (symbol-enum env-symbols set-env-symbols!)
  (state-enum env-states set-env-states!)
  (fsm env-fsm set-env-fsm!))

(define (eval. exp env)
  (let ((op (car exp))
        (args (cdr exp)))
    (cond ((equal? op 'define-symbols) (eval-enum-symbol args env))
          ((equal? op 'define-states) (eval-enum-state args env))
          ((equal? op 'define-fsm) (eval-fsm args env))
          (#t (error 'unknown-command op 'in exp)))
    ))

(define (eval-enum-symbol exp env)
  (set-env-symbols! env (make-enum (car exp) (cadr exp))))

(define (eval-enum-state exp env)
  (set-env-states! env (make-enum (car exp) (cadr exp))))

(define (eval-fsm exp env)
  (let* ((options (car exp))
         (name (car options))
         (initial (cadr options))
         (args (cdr exp)))
    (set-env-fsm! env (make-fsm name initial
                                (env-symbols env) (env-states env) args))
    ))

(define (main/parse-file filepath)
  (let ((input-file (open-input-file filepath))
        (env (make-env)))
    (let loop ((symb (read input-file)))
      (cond ((eof-object? symb) (close-port input-file) env)
            (#t (eval. symb env)
                (loop (read input-file))))
      )))

(define (main/sanity-check env)
  #f)

(define (main/write-a-file cpp-path handler env)
  (let* ((tmp (number->string (+ (random-integer 89999999) 1000000)))
         (cpp-temp (string-append cpp-path "." tmp ".tmp"))
         (cpp (open-output-file cpp-temp)))
    (dynamic-wind
      (lambda () #f)
      (lambda ()
        (handler cpp env)
        (close-port cpp)
        (rename-file cpp-temp cpp-path))
      (lambda ()
        (close-port cpp)
        (if (file-exists? cpp-temp) (delete-file cpp-temp))))
    ))

(define (main/write-hpp port env)
  (write-out
   (list
    "#pragma once\n"
    (enum->c (env-symbols env))
    (enum->c (env-states env))
    ;; declarations
    "extern FsmInfo<"
    (enum-name (env-symbols env)) ", " (enum-name (env-states env)) "> "
    (fsm-name (env-fsm env)) ";\n"
    "void init();\n"
    )
   port))

(define (main/write-cpp port env)
  (write-out
   (list
    (fsm-header->c (env-fsm env))
    (fsm-nodes->c (env-fsm env))
    "/* Each out_* array's content is sorted by the input field's\n"
    "   numeric value */\n"
    (fsm-edges->c (env-fsm env))
    (fsm-init->c (env-fsm env))
    (fsm-decl->c (env-fsm env)))
   port))

(define (main/output-files hpp-path cpp-path env)
  (main/write-a-file hpp-path main/write-hpp env)
  (main/write-a-file cpp-path main/write-cpp env))

(define (write-out nested-list port)
  (display "/* This file is automatically generated */\n" port)
  (let loop ((curr nested-list))
    (cond ((null? curr) #f)
          (#t
           (if (list? (car curr)) (loop (car curr))
               (display (car curr) port))
           (loop (cdr curr))))
    )
  (newline port))

(define (main in-file out-hpp out-cpp)
  (let* ((env (main/parse-file in-file))
         (error-report (main/sanity-check env)))
    (cond (error-report (write-out error-report (current-error-port))
                        (exit 11))
          (#t (main/output-files out-hpp out-cpp env)))
    ))

(apply main (cdr (command-line)))
