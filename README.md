# with-cached-reader-conditionals

Exposes `#'call-with-cached-reader-conditionals` and the macro `with-cached-reader-conditionals`

### #'call-with-cached-reader-conditionals

Calls the given function with the given args. Returns the first result of the given function as the first result and the returns a list of the 'feature-expression pairs' as the second result.

A 'feature-expression pair' is defined as: A list of length 2 where the first element is a valid lisp feature-expression and the second element is `t` or `nil` depending on whether the feature expression succeeded for the current system.

To get the list of features the function rebinds the `#+` and `#-` conditional reader macros so that they will work as normal but also record the feature expressions they are given. This accumulated list of feature expressions is then flattened and deduplicated so only a set of features remain.


### with-cached-reader-conditionals

This macro takes it's body, wraps in in a lambda and passes it to #'call-with-cached-reader-conditionals.


### Example Usage

```
    ;; With this function
	(defun test (string)
	  (with-cached-reader-conditionals
		(with-input-from-string (stream string)
		  (loop for l = (read stream nil) while l collect l))))

	;; this call
	CL-USER> (test "(+ 1 2 3)
	#+windows(print 1)
	#+(or sbcl bsd)(print 2)
	#+(or bsd sbcl)(print 3)")

	;; returns these two values
	((+ 1 2 3) (PRINT 2) (PRINT 3))
	(((:OR :BSD :SBCL) T) (:WINDOWS NIL))
```
