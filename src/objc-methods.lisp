(in-package "OBJC-CFFI")

(defcfun ("class_addMethods" class-add-methods) :void 
  (class objc-class-pointer) 
  (method-list objc-method-list-pointer))

(defcfun ("class_removeMethods" class-remove-methods) :void 
  (class objc-class-pointer) 
  (method-list objc-method-list-pointer))

(defparameter *method-list-added* (make-hash-table :test #'equal))

(defun unregister-method (class-name selector-name)
  (awhen (gethash (cons selector-name class-name) *method-list-added*)
      (class-remove-methods (objc-get-class class-name) it)))

(defun register-method (class-name selector-name types callback)
  (let* ((selector (sel-register-name selector-name))
	 (method-list (foreign-alloc 'objc-method-list))
	 (method (foreign-slot-pointer method-list 'objc-method-list 'method_list)))

    (setf (mem-aref method 'objc-method 1) (null-pointer))

    (setf (foreign-slot-value method 'objc-method 'method_name) selector
	  (foreign-slot-value method 'objc-method 'method_types) (cffi:foreign-string-alloc types)
	  (foreign-slot-value method 'objc-method 'method_imp) callback)
    (setf 
     (foreign-slot-value method-list 'objc-method-list 'method_count) 1)
    
    (when (gethash (cons class-name selector-name) *method-list-added*)
	(unregister-method class-name selector-name))
    (class-add-methods (objc-get-class class-name) method-list)
    (setf (gethash (cons selector-name class-name) *method-list-added*) method-list)
    (values (class-get-instance-method (objc-get-class class-name)  selector) method-list)))

(defmacro add-objc-method ((selector-name class-name &key (return-type 'objc-id) (class-method nil))
			   argument-list &body body)
  (declare (ignore class-method))
  (let* ((callback (gensym (format nil "~A-CALLBACK-" (remove #\: selector-name))))
	 (type-list (append (list 'objc-id 'objc-sel) 
			    (mapcar (lambda (type) 
				      (if (listp type) 
					  (second type) 
					  'objc-id)) 
				     argument-list)))
	 (var-list (append (list (intern "SELF") (intern "SEL")) 
			   (mapcar (lambda (arg) 
				     (if (listp arg) 
					 (first arg) 
					 arg)) 
				    argument-list))))
    `(progn 
       (cffi:defcallback ,callback ,return-type ,(mapcar #'list var-list type-list)
	 ,@body)
       (register-method ,class-name 
			,selector-name
			(objc-types:encode-types (append (list ,return-type) ',type-list))
			(callback ,callback)))))