(in-package "OBJC-CFFI")

;;; Method calls

(defcfun ("objc_msgSend" objc-msg-send) :pointer
  (id objc-id)
  (sel objc-sel)
  &rest)

(cffi:defcfun ("objc_msgSend_fpret" objc-msg-send-fpret) :double
  (id objc-id)
  (sel objc-sel)
  &rest)

(cffi:defcfun ("objc_msgSend_fpret" objc-msg-send-sfpret) :float
  (id objc-id)
  (sel objc-sel)
  &rest)

(defcfun ("objc_msgSend_stret" objc-msg-send-stret) :pointer
  (stret :pointer)
  (id objc-id)
  (sel objc-sel)
  &rest)

(defcstruct objc-super 
  (id objc-id)
  (class objc-class-pointer))

(defcfun ("objc_msgSendSuper" objc-msg-send-super) :pointer
  (id objc-super)
  (sel objc-sel)
  &rest)

(defcfun ("objc_msgSendSuper_stret" objc-msg-send-super-stret) :pointer
  (stret :pointer)
  (id objc-super)
  (sel objc-sel)
  &rest)

;; Building foreign function declarations for each objc primitive type
;; e.g. char-objc-msg-send, unsigned-int-objc-msg-send, etc.

(defmacro ensure-fun (name args &body body)
  `(unless (fboundp ',name)
     (defun ,name ,args ,@body)))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (ensure-fun allowed-simple-return-types ()
    (remove 'objc-types:objc-unknown-type (mapcar #'cadr objc-types:typemap)))

  (ensure-fun make-objc-msg-send-symbol (type superp)
    (intern 
     (format nil "~a-OBJC-MSG-SEND~:[~;-SUPER~]" (string-upcase (symbol-name type)) superp) 
     (find-package "OBJC-CFFI")))

  (ensure-fun odd-positioned-elements (list)
    (when (> (length list) 1)
      (cons (cadr list) (odd-positioned-elements (cddr list)))))

  (ensure-fun even-positioned-elements (list)
    (when (> (length list) 1)
      (cons (car list) (even-positioned-elements (cddr list))))))

(defmacro %objc-msg-send (return-type id sel args &optional superp)
  (let ((gensyms (gensym-list (+ 2 (/ (length args) 2)))))
    (cffi::translate-objects gensyms 
			     (append (list id sel) (odd-positioned-elements args))
			     (append (list (if superp 'objc-super 'objc-id) 'objc-sel) (even-positioned-elements args))
			     return-type
			     `(cffi-sys:%foreign-funcall 
			       ,(cond
				 ((member return-type '(:float :double)) "objc_msgSend_fpret")
				 (superp "objc_msgSendSuper")
				 (t "objc_msgSend")) 
			       ,(append (list :pointer (first gensyms)
					      :pointer (second gensyms))
					(interpose (mapcar #'cffi::canonicalize-foreign-type 
							   (even-positioned-elements args))
						   (cddr gensyms))
					(list (cffi::canonicalize-foreign-type return-type)))
			       :library :default :calling-convention :cdecl))))

(defmacro build-objc-msg-send ()
  `(progn
     ,@(mapcar (lambda (type)
		 `(defmacro ,(make-objc-msg-send-symbol type nil) (id sel args)
		    `(%objc-msg-send ,',type ,id ,sel ,args)))
	       (allowed-simple-return-types))
     ,@(mapcar (lambda (type)
		 `(defmacro ,(make-objc-msg-send-symbol type t) (id sel args)
		    `(%objc-msg-send ,',type ,id ,sel ,args t)))
	       (allowed-simple-return-types))))

(build-objc-msg-send)

(defmethod translate-from-foreign (protocol-ptr (type objc-protocol-type))
  (unless (null-pointer-p protocol-ptr)
    (let* ((name (%objc-msg-send :string protocol-ptr "name" nil))
	   (new-protocol
	    (make-instance 'objc-protocol
			   :id protocol-ptr
			   :name name))
	   (instance-methods (get-ivar new-protocol "instance_methods"))
	   (class-methods (get-ivar new-protocol "class_methods")))
      (setf (slot-value new-protocol 'included-protocols) 
	    (convert-from-foreign (get-ivar new-protocol "protocol_list") 'objc-protocol-list-pointer)

	    (slot-value new-protocol 'instance-methods)
	    (unless (null-pointer-p instance-methods)
	      (loop 
		 for idx below (foreign-slot-value instance-methods 'objc-method-description-list 'count)
		 for method-desc-ptr = (foreign-slot-pointer instance-methods 'objc-method-description-list 'list) then (inc-pointer method-desc-ptr (foreign-type-size 'objc-method-description))
		 collecting (foreign-slot-value method-desc-ptr 'objc-method-description 'name)))

	    (slot-value new-protocol 'class-methods)
	    (unless (null-pointer-p class-methods)
	      (loop 
		 for idx below (foreign-slot-value class-methods 'objc-method-description-list 'count)
		 for method-desc-ptr = (foreign-slot-pointer class-methods 'objc-method-description-list 'list) then (inc-pointer method-desc-ptr (foreign-type-size 'objc-method-description))
		 collecting (foreign-slot-value method-desc-ptr 'objc-method-description 'name))))
      new-protocol)))

(defun method-return-type (method)
  (caddar (objc-types:parse-objc-typestr (method-type-signature method))))

(defun method-argument-types (method)
  (mapcar #'caddr (cdddr (objc-types:parse-objc-typestr (method-type-signature method)))))

(defun objc-foreign-type-size (type)
  (cond 
    ((and (listp type) (eq (car type) :struct))
     (reduce #'+ (mapcar #'objc-foreign-type-size (caddr type))))
    (t (foreign-type-size type))))

(defparameter *methods-cache* (make-hash-table :test #'equal))

(defun cache-compile (sel return-type super-call-p types)
  (let* ((sel-name (etypecase sel
		     (objc-selector (sel-name sel))
		     (string sel))))
    (macrolet ((cache (sel-name super-call-p types)
		 `(gethash (append (list ,sel-name ,super-call-p) ,types) *methods-cache*)))
      (or (cache sel-name super-call-p types)
	  (setf (cache sel-name super-call-p types)
		(compile nil
			 (let ((varargs (gensym-list (length types))))
			   `(lambda ,varargs
			      (,(make-objc-msg-send-symbol return-type super-call-p) 
				,(first varargs) 
				,sel
				,(interpose types (cdr varargs)))))))))))

(defparameter *super-call* nil
  "If this variable is set to t, the objc_msgSend will be translated to ")

(defmacro with-super (&body body)
  `(let ((objc-cffi::*super-call* t))
     ,@body))

(defmacro typed-objc-msg-send ((id sel &optional stret) &rest args-and-types)
  "Send the message binded to selector SEL to the object ID
returning the value of the ObjectiveC call.

ARGS-AND-TYPES is a list of pairs. The first element of a pair
is the CFFI type and the second is the value of the argument
passed to the method.

If the method return type is an ObjectiveC struct you can pass a
pointer to a an allocated struct that will retain the value
returned, otherwise a new struct will be allocated.

If ID is an ObjectiveC class object it will call the class method
binded to SEL.
"
  (with-gensyms (gsel gid gmethod greturn-type super)
    `(let* ((,gsel ,sel)
	    (,gid ,id)
	    (,gmethod (etypecase ,gid
			(objc-class (class-get-class-method ,gid ,gsel))
			(objc-object (class-get-instance-method (obj-class ,gid) ,gsel))))
	    (,gid (if *super-call*
		      (let ((,super (foreign-alloc 'objc-super)))
			(setf (foreign-slot-value ,super 'objc-super 'id) ,gid
			      (foreign-slot-value ,super 'objc-super 'class) (second (super-classes ,gid)))
			,super)
		      ,gid)))
       (if ,gmethod
	   (prog1
	       (let ((,greturn-type (method-return-type ,gmethod)))
		 (cond
		   ;; big struct passed by value as argument
		   ((and (some #'big-struct-type-p (method-argument-types ,gmethod)) 
			 (equal (mapcar #'extract-struct-name (method-argument-types ,gmethod))
				',(even-positioned-elements args-and-types)))
		    (untyped-objc-msg-send ,gid ,gsel ,@(odd-positioned-elements args-and-types)))

		   ;; big struct as return value passed by value
		   ((big-struct-type-p ,greturn-type) 
		    (if *super-call*
			(objc-msg-send-super-stret (or ,stret 
						       (foreign-alloc (extract-struct-name ,greturn-type))) 
						   ,gid ,gsel ,@args-and-types)
			(objc-msg-send-stret (or ,stret 
						 (foreign-alloc (extract-struct-name ,greturn-type))) 
					     ,gid ,gsel ,@args-and-types)))
		   ;; small struct as return value passed by value
		   ((small-struct-type-p ,greturn-type)
		    (if *super-call*
			(objc-msg-send-super ,gid ,gsel ,@args-and-types)
			(objc-msg-send ,gid ,gsel ,@args-and-types))) 

		   ;; general case
		   ((member ,greturn-type ',(allowed-simple-return-types)) 
		    (funcall 
		     (cache-compile ,gsel ,greturn-type *super-call* ',(even-positioned-elements args-and-types))
		     ,gid ,@(odd-positioned-elements args-and-types)))
		   (t (error "Unknown return type ~s" ,greturn-type))))
	     (when *super-call*
	       (foreign-free ,gid)))
	   (error "ObjC method ~a not found" ,gsel)))))

(defparameter *untyped-methods-cache* (make-hash-table :test #'equal))

(defun cache-compile-for-untyped (sel method)
  (let ((sel-name (etypecase sel
		    (objc-selector (sel-name sel))
		    (string sel))))
    (or (gethash sel-name *untyped-methods-cache*)
	(setf (gethash sel-name *untyped-methods-cache*)
	      (compile nil
		       (let ((varargs (gensym-list (- (method-get-number-of-arguments method) 2))))
			 `(lambda ,varargs
			    (typed-objc-msg-send (,(first varargs) ,sel) 
						 ,@(interpose 
						    (pack-struct-arguments-type (method-argument-types method)) 
						    (pack-struct-arguments-val (cdr varargs) method))))))))))

(defun clear-method-caches ()
  (setf *methods-cache* (make-hash-table)
	*untyped-methods-cache* (make-hash-table)))

(defun untyped-objc-msg-send (receiver selector &rest args)
  "Send the message binded to SELECTOR to RECEIVER returning the
value of the ObjectiveC call with ARGS.

This method invokes typed-objc-msg-send calculating the types of
ARGS at runtime.
"
  (let* ((method (etypecase receiver
		   (objc-class (class-get-class-method receiver selector))
		   (objc-object (class-get-instance-method (obj-class receiver) selector)))))
    (if method
	(apply (cache-compile-for-untyped selector method)	receiver args)
	(error "ObjC method ~a not found for class ~a" selector (class-name (etypecase receiver
									      (objc-class receiver)
									      (objc-object (obj-class receiver))))))))