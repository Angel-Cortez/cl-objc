(in-package :objc-reader)

(defparameter *old-readtable* nil)
(defparameter *objc-readtable* nil)
(defparameter *objc-argument-readtable* nil
  "The readtable used to read arguments of messages")
(defparameter *accept-untyped-call* t
  "If nil, methods have to be invoked with input type parameters.")
(defparameter *use-clos-interface* t)

(defun end-selector-char-p (char)
  (member char '(#\Space #\])))

(defun separator-char-p (char)
  (member char '(#\Space)))

(defun eat-separators (stream)
  (loop 
     for char = (read-char stream nil nil t)
     while (and char (separator-char-p char))
     finally (when char (unread-char char stream))))

(defun read-selector-part (stream)
  "Read a part of a selector. Returns 'eof if can't find any
selector."
  (eat-separators stream)
  (let ((string
	 (with-output-to-string (out)
	   (loop 
	      for char = (read-char stream t nil t)
	      when (not char) return nil
	      until (end-selector-char-p char)
	      do (princ char out)
	      finally (unread-char char stream)))))
    (if (zerop (length string))
	'eof
	string)))

(defun objc-read-right-square-bracket (stream char)
  (declare (ignore stream char))
  'eof)

(defmacro with-argument-readtable (&body body)
  `(let ((*readtable* *objc-argument-readtable*))
     ,@body))

(defmacro with-old-readtable (&body body)
  `(let ((*readtable* *old-readtable*))
     ,@body))

(defmacro with-objc-readtable (&body body)
  `(let ((*readtable* *objc-readtable*))
     (setf (readtable-case *readtable*) :preserve)
     (prog1
	 (progn
	   ,@body)
       (setf (readtable-case *readtable*) (readtable-case *old-readtable*)))))

(defun objc-read-comma (stream char)
  (declare (ignore char))
  (eval (with-old-readtable 
	  (read stream t nil t))))

(defun read-arg-and-type (stream)
  "Returns a list with a cffi type and an argument for foreign
  funcall.

If the type is unspecified, the argument is present and
*accept-untyped-call* is nil it signals an error.

If *accept-untyped-call* is t and the type is not present returns
a list with just the argument.

If both the argument and the type are not present returns a list
with the symbol 'eof."
  (eat-separators stream)
  (with-argument-readtable
    (let ((ret (let ((type-or-arg (read stream nil 'eof t)))
		 (if (cffi-type-p type-or-arg)
		     (list type-or-arg (read stream nil 'eof t))
		     (list type-or-arg)))))
      (cond 
	((eq (car ret) (intern "]")) (list 'eof))       ; using the old
					      ; readtable so we need
					      ; to convert the ] into
					      ; 'eof

	((and (not *accept-untyped-call*)
	      (= 1 (length ret)) 
	      (not (eq (car ret) 'eof))) (error "Params specified without correct CFFI type: ~s" ret)) ; the params are read
	(t ret)))))

(defun read-args-and-selector (stream)
  (do* ((selector-part (read-selector-part stream) (read-selector-part stream))
	(arg/type (read-arg-and-type stream) (append arg/type (read-arg-and-type stream)))
	(typed t)
	(selector selector-part (if (not (eq 'eof selector-part)) 
				    (concatenate 'string selector selector-part)
				    selector))) 
      ((or (eq selector-part 'eof)
	   (eq (car arg/type) 'eof)) (list (remove 'eof arg/type) selector typed))
    (when (or (and (= 2 (length arg/type))
		   (eq 'eof (second arg/type)))
	      (= 1 (length arg/type)))
      (setf typed nil))))

(defun objc-read-left-square-bracket (stream char)
  "Read an objc form: [ receiver selector args*]. 

Both receiver selector and each arg can be a lisp form or an objc
form (starting with an another #\[).

The receiver and the selector will be read using the objc
readtable (so preserving the case). You can escape using the
comma (e.g. in order to use a lisp variable containing the class
object). As a special case if a class name is found as receiver
it will be read and evalued as (objc-get-class (symbol-name
receiver-read)).

The args will be read with the lisp readtable.
"
  (declare (ignore char))
  (flet ((starts-with-a-upcase-char-p (string)
	   (let ((first-char (elt string 0)))
	     (and (alpha-char-p first-char) 
		  (char-equal (char-upcase first-char) first-char)))))
    (with-objc-readtable 
      (let ((id (read stream t nil t)))
	(let ((receiver (if (and (symbolp id) (starts-with-a-upcase-char-p (symbol-name id)))
			    (if *use-clos-interface*
				`(objc-clos:meta (objc-class-name-to-symbol (class-name (objc-get-class ,(symbol-name id)))))
				`(objc-get-class ,(symbol-name id))) 
			 id)))
	  (destructuring-bind (args selector typed) 
	      (read-args-and-selector stream)
	    (if typed
		(if *use-clos-interface*
		    `(objc-clos:convert-result-from-objc (typed-objc-msg-send ((objc:objc-id ,receiver) ,selector) ,@args))
		    `(typed-objc-msg-send (,receiver ,selector) ,@args))
		(if *use-clos-interface*
		    `(objc-clos:convert-result-from-objc (untyped-objc-msg-send (objc:objc-id ,receiver) ,selector ,@args))
		    `(untyped-objc-msg-send ,receiver ,selector ,@args)))))))))

(defun read-at-sign (stream char n)
  (declare (ignore n))
  (unread-char char stream)
  (typed-objc-msg-send 
   ((typed-objc-msg-send ((objc-get-class "NSString") "alloc")) 
    "initWithUTF8String:") 
   :string (read stream t nil t)))

(defun restore-readtable ()
  "Restore the readtable being present before the call of
ACTIVATE-OBJC-READER-MACRO."
  (setf *readtable* *old-readtable*))

(defun activate-objc-reader-macro (&optional (accept-untyped-call nil) (use-clos-interface nil))
  "Installs a the ObjectiveC readtable. If ACCEPT-UNTYPED-CALL is
NIL method has to be invoked with input type parameters. It saves
the current readtable to be later restored with
RESTORE-READTABLE"
  (setf *old-readtable* (copy-readtable)
	*accept-untyped-call* accept-untyped-call
	*use-clos-interface* use-clos-interface)
  (set-macro-character #\] #'objc-read-right-square-bracket)
  (unless (get-macro-character #\@)
    (make-dispatch-macro-character #\@))
  (set-dispatch-macro-character #\@ #\" #'read-at-sign)
  (setf *objc-argument-readtable* (copy-readtable))
  (set-macro-character #\[ #'objc-read-left-square-bracket)
  (set-macro-character #\, #'objc-read-comma)
  (setf *objc-readtable* (copy-readtable)))

;; Copyright (c) 2007, Luigi Panzeri
;; All rights reserved. 
;; 
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are
;; met:
;; 
;;  - Redistributions of source code must retain the above copyright
;;    notice, this list of conditions and the following disclaimer.
;; 
;;  - Redistributions in binary form must reproduce the above copyright
;;    notice, this list of conditions and the following disclaimer in the
;;    documentation and/or other materials provided with the distribution.
;;
;;  - The name of its contributors may not be used to endorse or
;;    promote products derived from this software without specific
;;    prior written permission.
;; 
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;; A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
;; OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
;; DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
