(in-package #:with-cached-reader-conditionals)

;;; If X is a symbol, see whether it is present in *FEATURES*. Also
;;; handle arbitrary combinations of atoms using NOT, AND, OR.
(defun featurep (x)
  (typecase x
    (cons
     (case (car x)
       ((:not not)
        (cond
          ((cddr x)
           (error "too many subexpressions in feature expression: ~S" x))
          ((null (cdr x))
           (error "too few subexpressions in feature expression: ~S" x))
          (t (not (featurep (cadr x))))))
       ((:and and) (every #'featurep (cdr x)))
       ((:or or) (some #'featurep (cdr x)))
       (t (error "unknown operator in feature expression: ~S." x))))
    (symbol (not (null (member x *features* :test #'eq))))
    (t (error "invalid feature expression: ~S" x))))

(defun dirty-featurep (x)
  "Ugly in implementation but will always match the implementations logic :|"
  (with-input-from-string (s (format nil "#+~s t" x))
    (read s nil nil)))

(defclass feature-cache () ((cache :initform nil)))

(defvar *keyword-package* (find-package :keyword))

(defun make-reader-conditional-caching-sharp-plus-minus ()
  (let ((cache (make-instance 'feature-cache)))
    (list (lambda (stream sub-char numarg)
            (declare (ignore numarg))
            (let* ((feature-expr (let ((*package* *keyword-package*)
                                       ;; sbcl also set *reader-package* to nil
                                       ;; that was internal to sbcl
                                       (*read-suppress* nil))
                                   (read stream t nil t)))
                   (present (featurep feature-expr))
                   (match (char= sub-char (if present #\+ #\-))))
              (push (list feature-expr present) (slot-value cache 'cache))
              (if match
                  (read stream t nil t)
                  (let ((*read-suppress* t))
                    (read stream t nil t)
                    (values)))))
          cache)))

(defun feature-expr-key (expr)
  (etypecase expr
    (atom expr)
    (list (second expr))))

(defun sort-feature-expr (feature-expr)
  (etypecase feature-expr
    (atom feature-expr)
    (list (cons (first feature-expr)
                (sort (mapcar #'sort-feature-expr (rest feature-expr))
                      #'string< :key #'feature-expr-key)))))

(defun normalize-feature-list (pairs)
  (labels ((sort-inner (pair)
             (destructuring-bind (feature-expr applies?) pair
               (list (sort-feature-expr feature-expr) applies?)))
           (pair-key (pair)
             (feature-expr-key (first pair))))
    (let* ((inner-sorted (mapcar #'sort-inner pairs))
           (dedupd (remove-duplicates inner-sorted :test #'equal)))
      (sort dedupd #'string< :key #'pair-key))))

(defun cached-feature-list (cache)
  (normalize-feature-list (slot-value cache 'cache)))

(defun call-with-cached-reader-conditionals (func &rest args)
  (destructuring-bind (rfunc cache)
      (make-reader-conditional-caching-sharp-plus-minus)
    (let ((*readtable* (copy-readtable)))
      (set-dispatch-macro-character #\# #\+ rfunc *readtable*)
      (set-dispatch-macro-character #\# #\- rfunc *readtable*)
      (values (apply func args) (cached-feature-list cache)))))

(defmacro with-cached-reader-conditionals (&body body)
  `(call-with-cached-reader-conditionals (lambda () ,@body)))

(defun flatten-features (feature-expressions)
  (labels ((flatten (x)
             (labels ((rec (x acc)
                        (cond ((null x) acc)
                              ((atom x) (cons x acc))
                              (t (rec (car x)
                                      (rec (cdr x) acc))))))
               (rec x nil))))
    (let* ((ignored '(:or :and or and nil t))
           (features (remove-if (lambda (x) (member x ignored))
                                (sort
                                 (remove-duplicates
                                  (remove-if-not
                                   #'keywordp
                                   (flatten feature-expressions)))
                                 #'string<))))
      (mapcar (lambda (x) (list x (featurep x))) features))))
