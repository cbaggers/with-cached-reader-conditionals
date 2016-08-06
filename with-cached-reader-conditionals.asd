;;;; with-cached-reader-conditionals.asd

(asdf:defsystem #:with-cached-reader-conditionals
  :description "Read whilst collection reader conditionals"
  :author "Chris Bagley <chris.bagley@gmail.com>"
  :license "BSD 2 Clause"
  :serial t
  :components ((:file "package")
               (:file "with-cached-reader-conditionals")))
