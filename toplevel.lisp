(cl:in-package :prepl)

(defvar *noprint* nil
  "boolean: T if don't print prompt and output")
(defvar *break-level* 0
  "current break level")
(defvar *inspect-break* nil
  "boolean: T if break caused by inspect")
(defvar *continuable-break* nil
  "boolean: T if break caused by continuable error")

(defvar *unwind-hooks*
  (list #+sbcl #'sb-impl::disable-stepping))

(defun run-hooks (hooks &rest args)
  (mapc (lambda (hookfun)
	  (apply hookfun args))
	hooks))

(defvar *outmost-repl* t)

(defun %repl (&key
             (break-level (1+ *break-level*))
             (noprint *noprint*)
             (inspect nil)
             (continuable nil))
  (let ((*noprint* noprint)
        (*break-level* break-level)
        (*inspect-break* inspect)
        (*continuable-break* continuable))
    (iter
     (if *outmost-repl*
	 (with-simple-restart (abort-to-outmost-repl "Abort to outmost REPL")
	   (let ((*outmost-repl* nil))
	     (rep-one)))
	 (until (rep-one))))))

(defun interactive-eval (form)
  "Evaluate FORM, returning whatever it returns and adjusting ***, **, *,
+++, ++, +, ///, //, /, and -."
  (setf - form)
  (unwind-protect
       (let ((results (multiple-value-list (eval form))))
         (setf /// //
               // /
               / results
               *** **
               ** *
               * (car results)))
    (setf +++ ++
          ++ +
          + -))
  (unless (boundp '*)
    ;; The bogon returned an unbound marker.
    ;; FIXME: It would be safer to check every one of the values in RESULTS,
    ;; instead of just the first one.
    (setf * nil)
    (cerror "Go on with * set to NIL."
            "EVAL returned an unbound marker."))
  (values-list /))

(defvar *after-prompt-hooks*
  (list #+sbcl #'scrub-control-stack))

(defun rep-one ()
  (multiple-value-bind (reason reason-param)
      (catch 'repl-catcher
	(unwind-protect
	     (%rep-one)
	  (run-hooks *unwind-hooks*)))
    (declare (ignore reason-param))
    (or (and (eq reason :inspect)
	     (plusp *break-level*))
	(and (eq reason :pop)
	     (plusp *break-level*)))))

(defun %rep-one ()
  "Read-Eval-Print one form"
  ;; (See comment preceding the definition of SCRUB-CONTROL-STACK.)
  (run-hooks *after-prompt-hooks*)
  (unless *noprint*
    (prompt *standard-output*)
    (force-output *standard-output*))
  (let* ((*input* *standard-input*)
	 (*output* *standard-output*)
	 (user-cmd (read-cmd *input*)))
    (unless (process-cmd user-cmd)
      (let ((results
	     (multiple-value-list
	      (interactive-eval
	       (user-cmd-input user-cmd)))))
	(unless *noprint*
	  (dolist (result results)
	    (prin1 result *standard-output*)
	    (fresh-line *standard-output*)))))))