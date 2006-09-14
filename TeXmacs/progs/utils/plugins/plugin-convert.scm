
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : plugin-convert.scm
;; DESCRIPTION : Convert mathematical formulas to plugin input
;; COPYRIGHT   : (C) 1999  Joris van der Hoeven
;;
;; This software falls under the GNU general public license and comes WITHOUT
;; ANY WARRANTY WHATSOEVER. See the file $TEXMACS_PATH/LICENSE for details.
;; If you don't have this file, write to the Free Software Foundation, Inc.,
;; 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(texmacs-module (utils plugins plugin-convert))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Main conversion routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define current-plugin-input-stree "")

(define (convert-test)
  (set! current-plugin-input-stree (tree->stree (selection-tree)))
  (write (with-output-to-string plugin-input-caller))
  (display "\n"))

(tm-define (plugin-math-input l)
  (:synopsis "Convert mathematical input to a string")
  (:argument l "A list of the form @(tuple plugin expr)")
  (set! current-plugin-input-stree (caddr l))
  (set! plugin-input-current-plugin (cadr l))
  (with-output-to-string plugin-input-caller))

(define (plugin-input-caller)
  (plugin-input current-plugin-input-stree))

(tm-define (plugin-input t)
  (if (string? t)
      (plugin-input-tmtokens (string->tmtokens t 0 (string-length t)))
      (let* ((f (car t)) (args (cdr t)) (im (plugin-input-ref f)))
	(cond ((!= im #f) (im args))
	      (else (noop))))))

(define (plugin-input-arg t)
  (if (and (string? t)
	   (= (length (string->tmtokens t 0 (string-length t))) 1))
      (plugin-input t)
      (begin
	(display "(")
	(plugin-input t)
	(display ")"))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; conversion of strings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (string-find-char s i n c)
  (cond ((>= i n) n)
	((== (string-ref s i) c) i)
	(else (string-find-char s (+ i 1) n c))))

(define (string-find-end s i n pred)
  (cond ((>= i n) n)
	((not (pred (string-ref s i))) i)
	(else (string-find-end s (+ i 1) n pred))))

(define (string->tmtokens s i n)
  (cond ((>= i n) '())
	((== (string-ref s i) #\<)
	 (let ((j (min n (+ (string-find-char s i n #\>) 1))))
	   (cons (substring s i j) (string->tmtokens s j n))))
	((char-alphabetic? (string-ref s i))
	 (let ((j (string-find-end s i n char-alphabetic?)))
	   (cons (substring s i j) (string->tmtokens s j n))))
	((char-numeric? (string-ref s i))
	 (let ((j (string-find-end s i n char-numeric?)))
	   (cons (substring s i j) (string->tmtokens s j n))))
	(else (cons (substring s i (+ 1 i))
		    (string->tmtokens s (+ 1 i) n)))))

(define (plugin-input-tmtoken s)
  (let ((im (plugin-input-ref s)))
    (if (== im #f)
        (if (and (!= s "") (== (string-ref s 0) #\<))
            (display (substring s 1 (- (string-length s) 1)))
            (display s))
        (if (procedure? im)
            (im s)
            (display im)))))

(define (plugin-input-tmtokens l)
  (if (nnull? l)
      (begin
	(plugin-input-tmtoken (car l))
	(plugin-input-tmtokens (cdr l)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; conversion of other nodes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (plugin-input-with args)
  (if (null? (cdr args))
      (plugin-input (car args))
      (plugin-input-with (cdr args))))

(define (plugin-input-concat-big args)
  (cond ((== (caar args) ".")
	 (plugin-input (car args))
	 (plugin-input-concat (cdr args)))
        ((and (nnull? (cddr args))
	      (func? (cadr args) 'rsub)
	      (func? (caddr args) 'rsup))
	 (plugin-input `(big ,(cadr (car args))
			     ,(cadr (cadr args))
			     ,(cadr (caddr args))))
	 (plugin-input-concat (cdddr args)))
	((and (nnull? (cddr args))
	      (func? (cadr args) 'rsup)
	      (func? (caddr args) 'rsub))
	 (plugin-input `(big ,(cadr (car args))
			     ,(cadr (caddr args))
			     ,(cadr (cadr args))))
	 (plugin-input-concat (cdddr args)))
	((func? (cadr args) 'rsub)
	 (plugin-input `(big ,(cadr (car args)) ,(cadr (cadr args))))
	 (plugin-input-concat (cddr args)))
	(else
	 (plugin-input (car args))
	 (plugin-input-concat (cdr args)))))

(define (plugin-input-concat args)
  (cond ((null? args) (noop))
	((and (func? (car args) 'big) (nnull? (cdr args)))
	 (plugin-input-concat-big args))
	(else
	 (plugin-input (car args))
	 (plugin-input-concat (cdr args)))))

(define (plugin-input-frac args)
  (display "(")
  (plugin-input-arg (car args))
  (display "/")
  (plugin-input-arg (cadr args))
  (display ")"))

(define (plugin-input-sqrt args)
  (if (= (length args) 1)
      (begin
	(display "sqrt(")
	(plugin-input (car args))
	(display ")"))
      (begin
	(plugin-input-arg (car args))
	(display "^(1/")
	(plugin-input-arg (cadr args))
	(display ")"))))

(define (plugin-input-rsub args)
  (display "[")
  (plugin-input (car args))
  (display "]"))

(define (plugin-input-rsup args)
  (display "^")
  (plugin-input-arg (car args)))

(define (plugin-input-large args)
  (display (car args)))

(define (plugin-input-big args)
  (if (== (car args) ".")
      (display ")")
      (begin
	(display (car args))
	(display "(")
	(if (nnull? (cdr args))
	    (begin
	      (plugin-input (cadr args))
	      (display ",")
	      (if (nnull? (cddr args))
		  (begin
		    (plugin-input (caddr args))
		    (display ","))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Conversion of matrices
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (plugin-input-descend-last args)
  (if (null? (cdr args))
      (plugin-input (car args))
      (plugin-input-descend-last (cdr args))))

(define (plugin-input-det args)
  (display "matdet(")
  (plugin-input-descend-last args)
  (display ")"))

(define (rewrite-cell c)
  (if (and (list? c) (== (car c) 'cell)) (cadr c) c))

(define (rewrite-row r)
  (if (null? r) r (cons (rewrite-cell (car r)) (rewrite-row (cdr r)))))

(define (rewrite-table t)
  (if (null? t) t (cons (rewrite-row (cdar t)) (rewrite-table (cdr t)))))

(define (plugin-input-row r)
  (if (null? (cdr r))
      (plugin-input (car r))
      (begin
	(plugin-input (car r))
	(display ", ")
	(plugin-input-row (cdr r)))))

(define (plugin-input-var-rows t)
  (if (nnull? t)
      (begin
	(display "; ")
	(plugin-input-row (car t))
	(plugin-input-var-rows (cdr t)))))

(define (plugin-input-rows t)
  (display "[")
  (plugin-input-row (car t))
  (plugin-input-var-rows (cdr t))
  (display "]"))

(define (plugin-input-table args)
  (let ((t (rewrite-table args)))
    (plugin-input (cons 'rows t))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Lazy input converters
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define lazy-input-converter-table (make-ahash-table))

(tm-define-macro (lazy-input-converter module plugin)
  (lazy-input-converter-force plugin)
  (ahash-set! lazy-input-converter-table plugin module)
  '(noop))

(define (lazy-input-converter-force plugin2)
  (with plugin (if (string? plugin2) (string->symbol plugin2) plugin2)
    (with module (ahash-ref lazy-input-converter-table plugin)
      (if module
	  (begin
	    (ahash-remove! lazy-input-converter-table plugin)
	    (module-load module))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialization subroutines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define plugin-input-current-plugin "generic")

(define (plugin-input-converters-rules name l)
  (if (null? l) '()
      (cons (let* ((rule (car l))
		   (key (car rule))
		   (im (list 'unquote (cadr rule))))
	      (list (list 'plugin-input-converter% (list name key) im)))
	    (plugin-input-converters-rules name (cdr l)))))

(tm-define-macro (plugin-input-converters name2 . l)
  (let ((name (if (string? name2) name2 (symbol->string name2))))
    (lazy-input-converter-force name)
    (drd-group plugin-input-converters% ,name)
    `(drd-rules ,@(plugin-input-converters-rules name l))))

(define (plugin-input-ref key)
  (lazy-input-converter-force plugin-input-current-plugin)
  (let ((im (drd-ref plugin-input-converter%
		     (list plugin-input-current-plugin key))))
    (if im im (drd-ref plugin-input-converter% (list "generic" key)))))

(tm-define (plugin-supports-math-input-ref key)
  (lazy-input-converter-force key)
  (drd-in? key plugin-input-converters%))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(plugin-input-converters generic
  (with plugin-input-with)
  (concat plugin-input-concat)
  (document plugin-input-concat)
  (frac plugin-input-frac)
  (sqrt plugin-input-sqrt)
  (rsub plugin-input-rsub)
  (rsup plugin-input-rsup)
  (left plugin-input-large)
  (middle plugin-input-large)
  (right plugin-input-large)
  (big plugin-input-big)
  (tabular plugin-input-descend-last)
  (tabular* plugin-input-descend-last)
  (block plugin-input-descend-last)
  (block* plugin-input-descend-last)
  (matrix plugin-input-descend-last)
  (det plugin-input-det)
  (tformat plugin-input-descend-last)
  (table plugin-input-table)
  (rows plugin-input-rows)

  ("<less>" "<less>")
  ("<gtr>" "<gtr>")
  ("<leq>" "<less>=")
  ("<geq>" "<gtr>=")
  ("<leqslant>" "<less>=")
  ("<geqslant>" "<gtr>=")
  ("<neq>" "!=")
  ("<longequal>" "==")
  ("<neg>" "not ")
  ("<wedge>" " and ")
  ("<vee>" " or ")
  ("<ll>" "<less><less>")
  ("<gg>" "<gtr><gtr>")
  ("<assign>" ":=")
  ("<ldots>" "..")
  ("<um>" "-")
  ("<upl>" "+")
  ("<times>" "*")
  ("<ast>" "*")
  ("<cdot>" "*")
  ("<bbb-C>" "CC")
  ("<bbb-F>" "FF")
  ("<bbb-N>" "NN")
  ("<bbb-K>" "KK")
  ("<bbb-R>" "RR")
  ("<bbb-Q>" "QQ")
  ("<bbb-Z>" "ZZ")
  ("<mathe>" "(exp(1))")
  ("<mathpi>" "(4*atan(1))")
  ("<mathi>" "(sqrt(-1))")

  ("<alpha>"      "alpha")
  ("<beta>"       "beta")
  ("<gamma>"      "gamma")
  ("<delta>"      "delta")
  ("<epsilon>"    "epsilon")
  ("<varepsilon>" "varepsilon")
  ("<zeta>"       "zeta")
  ("<eta>"        "eta")
  ("<theta>"      "theta")
  ("<vartheta>"   "vartheta")
  ("<iota>"       "iota")
  ("<kappa>"      "kappa")
  ("<lambda>"     "lambda")
  ("<mu>"         "mu")
  ("<nu>"         "nu")
  ("<xi>"         "xi")
  ("<pi>"         "pi")
  ("<rho>"        "rho")
  ("<varrho>"     "varrho")
  ("<sigma>"      "sigma")
  ("<varsigma>"   "varsigma")
  ("<tau>"        "tau")
  ("<upsilon>"    "upsilon")
  ("<phi>"        "phi")
  ("<varphi>"     "varphi")
  ("<chi>"        "chi")
  ("<psi>"        "psi")
  ("<omega>"      "omega")
  ("<Gamma>"      "gamma")
  ("<Delta>"      "Delta")
  ("<Theta>"      "Theta")
  ("<Lambda>"     "Lambda")
  ("<Xi>"         "Xi")
  ("<Pi>"         "Pi")
  ("<Sigma>"      "Sigma")
  ("<Upsilon>"    "Upsilon")
  ("<Phi>"        "Phi")
  ("<Psi>"        "Psi")
  ("<Omega>"      "Omega"))
