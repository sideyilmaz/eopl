(load-relative "../libs/init.scm")
(load-relative "./base/environments.scm")
;;; based on exercises 16
;;; a little similar with let,
;;; but the vals should be a list-exp-val

;;;;;;;;;;;;;;;; grammatical specification ;;;;;;;;;;;;;;;;
(define the-lexical-spec
  '((whitespace (whitespace) skip)
    (comment ("%" (arbno (not #\newline))) skip)
    (identifier
     (letter (arbno (or letter digit "_" "-" "?")))
     symbol)
    (number (digit (arbno digit)) number)
    (number ("-" digit (arbno digit)) number)
    ))

(define the-grammar
  '((program (expression) a-program)
    (expression (identifier) var-exp)
    (expression (number) const-exp)
    (expression ("-" "(" expression "," expression ")") diff-exp)
    (expression ("+" "(" expression "," expression ")") add-exp)
    (expression ("*" "(" expression "," expression ")") mult-exp)
    (expression ("/" "(" expression "," expression ")") div-exp)
    (expression ("zero?" "(" expression ")") zero?-exp)
    (expression ("equal?" "(" expression "," expression ")") equal?-exp)
    (expression ("less?" "(" expression "," expression ")") less?-exp)
    (expression ("greater?" "(" expression "," expression ")") greater?-exp)
    (expression ("minus" "(" expression ")") minus-exp)
    (expression ("if" expression "then" expression "else" expression) if-exp)
    (expression ("cons" "(" expression "," expression ")") cons-exp)
    (expression ("car" "(" expression ")") car-exp)
    (expression ("cdr" "(" expression ")") cdr-exp)
    (expression ("emptylist") emptylist-exp)
    (expression ("null?" "(" expression ")") null?-exp)
    (expression ("list" "(" (separated-list expression ",") ")" ) list-exp)
    (expression ("cond" (arbno expression "==>" expression) "end") cond-exp)
    (expression ("print" "(" expression ")") print-exp)
    (expression ("let" (arbno identifier "=" expression) "in" expression) let-exp)
    (expression ("let*" (arbno identifier "=" expression) "in" expression) let*-exp)
    ;;new stuff
    (expression ("unpack" (arbno identifier) "=" expression "in" expression) unpack-exp)
    ))

;;;;;;;;;;;;;;;; sllgen boilerplate ;;;;;;;;;;;;;;;;
(sllgen:make-define-datatypes the-lexical-spec the-grammar)

(define scan&parse
  (sllgen:make-string-parser the-lexical-spec the-grammar))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-datatype expression expression?
  (var-exp
   (id symbol?))
  (const-exp
   (num number?))
  (zero?-exp
   (expr expression?))
  (equal?-exp
   (exp1 expression?)
   (exp2 expression?))
  (less?-exp
   (exp1 expression?)
   (exp2 expression?))
  (greater?-exp
   (exp1 expression?)
   (exp2 expression?))
  (if-exp
   (predicate-exp expression?)
   (true-exp expression?)
   (false-exp expression?))
  (minus-exp
   (body-exp expression?))
  (diff-exp
   (exp1 expression?)
   (exp2 expression?))
  (add-exp
   (exp1 expression?)
   (exp2 expression?))
  (mult-exp
   (exp1 expression?)
   (exp2 expression?))
  (div-exp
   (exp1 expression?)
   (exp2 expression?))
  (let-exp
   (vars (list-of symbols?))
   (vals (list-of expression?))
   (body expression?))
  (let*-exp
   (vars (list-of symbols?))
   (vals (list-of expression?))
   (body expression?))
  (emptylist-exp)
  (cons-exp
   (exp1 expression?)
   (exp2 expression?))
  (car-exp
   (body expression?))
  (cdr-exp
   (body expression?))
  (null?-exp
   (body expression?))
  (list-exp
   (args (list-of expression?)))
  (cond-exp
   (conds (list-of expression?))
   (acts  (list-of expression?)))
  (unpack-exp
   (args (list-of identifier?))
   (vals expression?)
   (body expression?))
  (print-exp
   (arg expression?)))

;;; an expressed value is either a number, a boolean or a procval.
(define-datatype expval expval?
  (num-val
   (value number?))
  (bool-val
   (boolean boolean?))
  (pair-val
   (car expval?)
   (cdr expval?))
  (emptylist-val))

;;; extractors:

;; expval->num : ExpVal -> Int
;; Page: 70
(define expval->num
  (lambda (v)
    (cases expval v
           (num-val (num) num)
           (else (expval-extractor-error 'num v)))))

;; expval->bool : ExpVal -> Bool
;; Page: 70
(define expval->bool
  (lambda (v)
    (cases expval v
           (bool-val (bool) bool)
           (else (expval-extractor-error 'bool v)))))

(define expval->pair
  (lambda (val)
    (cases expval val
	   (emptylist-val () '())
	   (pair-val (car cdr) (cons car (expval->pair cdr)))
	   (else (error 'expval->pair "Invalid pair: ~s" val)))))

(define expval-car
  (lambda (v)
    (cases expval v
           (pair-val (car cdr) car)
           (else (expval-extractor-error 'car v)))))

(define expval-cdr
  (lambda (v)
    (cases expval v
           (pair-val (car cdr) cdr)
           (else (expval-extractor-error 'cdr v)))))

(define expval-null?
  (lambda (v)
    (cases expval v
           (emptylist-val () (bool-val #t))
           (else (bool-val #f)))))


(define list-val
  (lambda (args)
    (if (null? args)
        (emptylist-val)
        (pair-val (car args)
                  (list-val (cdr args))))))


;;new stuff
(define cond-val
  (lambda (conds acts env)
    (cond ((null? conds)
           (error 'cond-val "No conditions got into #t"))
          ((expval->bool (value-of (car conds) env))
           (value-of (car acts) env))
          (else
           (cond-val (cdr conds) (cdr acts) env)))))

(define expval-extractor-error
  (lambda (variant value)
    (error 'expval-extractors "Looking for a ~s, found ~s"
           variant value)))


(define value-of-vals
  (lambda (vals env)
    (if (null? vals)
        '()
        (cons (value-of (car vals) env)
              (value-of-vals (cdr vals) env)))))

(define extend-env-list
  (lambda (vars vals env)
    (if (null? vars)
        env
        (let ((var1 (car vars))
              (val1 (car vals)))
          (extend-env-list (cdr vars) (cdr vals) (extend-env var1 val1 env))))))

(define extend-env-list-exp
  (lambda (vars vals env)
    (if (null? vars)
	env
	(let ((var1 (car vars))
	      (val1 (expval-car vals)))
	  (extend-env-list-exp (cdr vars)
			       (expval-cdr vals)
			       (extend-env var1 val1 env))))))

(define extend-env-list-iter
  (lambda(vars vals env)
    (if (null? vars)
        env
        (let ((var1 (car vars))
              (val1 (value-of (car vals) env)))
          (extend-env-list-iter (cdr vars) (cdr vals)
                                (extend-env var1 val1 env))))))

;;;;;;;;;;;;;;;; the interpreter ;;;;;;;;;;;;;;;;

;; value-of-program : Program -> ExpVal
;; Page: 71
(define value-of-program
  (lambda (pgm)
    (cases program pgm
           (a-program (exp1)
                      (value-of exp1 (init-env))))))

;; used as map for the list
(define apply-elm
  (lambda (env)
    (lambda (elem)
      (value-of elem env))))

;; value-of : Exp * Env -> ExpVal
;; Page: 71
(define value-of
  (lambda (exp env)
    (cases expression exp
           (const-exp (num) (num-val num))
           (var-exp (var) (apply-env env var))

           (diff-exp (exp1 exp2)
                     (let ((val1 (value-of exp1 env))
                           (val2 (value-of exp2 env)))
                       (let ((num1 (expval->num val1))
                             (num2 (expval->num val2)))
                         (num-val
                          (- num1 num2)))))
           (add-exp (exp1 exp2)
                    (let ((val1 (value-of exp1 env))
                          (val2 (value-of exp2 env)))
                      (let ((num1 (expval->num val1))
                            (num2 (expval->num val2)))
                        (num-val
                         (+ num1 num2)))))
           (mult-exp (exp1 exp2)
                     (let ((val1 (value-of exp1 env))
                           (val2 (value-of exp2 env)))
                       (let ((num1 (expval->num val1))
                             (num2 (expval->num val2)))
                         (num-val
                          (* num1 num2)))))
           (div-exp (exp1 exp2)
                    (let ((val1 (value-of exp1 env))
                          (val2 (value-of exp2 env)))
                      (let ((num1 (expval->num val1))
                            (num2 (expval->num val2)))
                        (num-val
                         (/ num1 num2)))))
           (zero?-exp (exp1)
                      (let ((val1 (value-of exp1 env)))
                        (let ((num1 (expval->num val1)))
                          (if (zero? num1)
                              (bool-val #t)
                              (bool-val #f)))))

           (equal?-exp (exp1 exp2)
                       (let ((val1 (value-of exp1 env))
                             (val2 (value-of exp2 env)))
                         (let ((num1 (expval->num val1))
                               (num2 (expval->num val2)))
                           (bool-val
                            (= num1 num2)))))

           (less?-exp (exp1 exp2)
                      (let ((val1 (value-of exp1 env))
                            (val2 (value-of exp2 env)))
                        (let ((num1 (expval->num val1))
                              (num2 (expval->num val2)))
                          (bool-val
                           (< num1 num2)))))
           (greater?-exp (exp1 exp2)
                         (let ((val1 (value-of exp1 env))
                               (val2 (value-of exp2 env)))
                           (let ((num1 (expval->num val1))
                                 (num2 (expval->num val2)))
                             (bool-val
                              (> num1 num2)))))
           (if-exp (exp1 exp2 exp3)
                   (let ((val1 (value-of exp1 env)))
                     (if (expval->bool val1)
                         (value-of exp2 env)
                         (value-of exp3 env))))
           (minus-exp (body-exp)
                      (let ((val1 (value-of body-exp env)))
                        (let ((num (expval->num val1)))
                          (num-val (- 0 num)))))
           (let-exp (vars vals body)
                    (let ((_vals (value-of-vals vals env)))
                      (value-of body (extend-env-list vars _vals env))))
           (let*-exp (vars vals body)
                     (value-of body (extend-env-list-iter vars vals env)))
           (emptylist-exp ()
                          (emptylist-val))
           (cons-exp (exp1 exp2)
                     (let ((val1 (value-of exp1 env))
                           (val2 (value-of exp2 env)))
                       (pair-val val1 val2)))
           (car-exp (body)
                    (expval-car (value-of body env)))
           (cdr-exp (body)
                    (expval-cdr (value-of body env)))
           (null?-exp (exp)
                      (expval-null? (value-of exp env)))
           (list-exp (args)
                     (list-val (map (apply-elm env) args)))
           (cond-exp (conds acts)
                     (cond-val conds acts env))
           (print-exp (arg)
                      (let ((val (value-of arg env)))
                        (print val)
                        (num-val 1)))
	   (unpack-exp (vars vals body)
		       (let ((_vals (value-of vals env)))
			(value-of body (extend-env-list-exp vars _vals env))))
           )))

;;
(define run
  (lambda (string)
    (value-of-program (scan&parse string))))


(run "x")
(run "v")
(run "i")
(run "10")
(run "-(1, 2)")
(run "-(1, x)")

;; (run "foo") -> error

(run  "if zero?(-(11, 11)) then 3 else 4")

(run "minus(4)")

(run  "if zero?(-(11, 11)) then minus(3) else minus(4)")

(run "+(1, 2)")
(run "+(+(1,2), 3)")
(run "/(1, 2)")
(run "*(*(1,2), *(10, 2))")

(run "if less?(1, 2) then 1 else 2")
(run "if greater?(2, 1) then minus(1) else minus(2)")

(run "cons(1, 2)")
(run "car (cons (1, 2))")
(run "cdr (cons (1, 2))")
(run "null? (emptylist)")
(run "null? (cons (1, 2))")

(run "let x = 4
            in cons(x,
              cons(cons(-(x,1),
                        emptylist),
                       emptylist))")

(run "list(1, 2, 3)")
(run "cdr(list(1, 2, 3))")
(run "let x = 4
      in list(x, -(x,1), -(x,3))")

(run "1")

(run "less?(1, 2)")
(run "cond less?(1, 2) ==> 2 end")
(run "cond less?(2, 1) ==> 1 greater?(2, 2) ==> 2  greater?(3, 2) ==> 3 end")
;; (run "cond less?(2, 1) ==> 1 end")  ==> error)

;;(run "print( less? (1, 2))")


(run "let x = 10
       in let x = 20
       in +(x, 10)")

(run "let x = 30
      in let x = -(x,1)
             y = -(x,2)
         in -(x, y)")

(run "let x = 30
      in let* x = -(x,1)
             y = -(x,2)
         in -(x, y)")

(run "cons(1, emptylist)")
(run "cons(7,cons(3,emptylist))")

;; new testcase
(run "let u = 7
      in unpack x y = cons(u, cons(3,emptylist))
      in -(x,y)")

;; -> (num-val 4)
