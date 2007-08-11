(defpackage "OBJC-CFFI"
  (:use "COMMON-LISP" "CFFI")
  (:export 

   "DEFINE-OBJC-FRAMEWORK"
   "DEFINE-OBJC-STRUCT"

   "OBJC-ID"
   "OBJC-CLASS-POINTER"
   "OBJC-SEL"
   "OBJC-OBJECT"

   "GET-CLASS-LIST" 
   "GET-CLASS-METHODS" 
   "OBJC-GET-CLASS"
   "CLASS-IVARS" 
   "PRIVATE-IVAR" 
   "CLASS-HAS-PUBLIC-IVARS"
   "SUPER-CLASSES"
   "CLASS-GET-INSTANCE-METHOD" 
   "CLASS-GET-CLASS-METHOD" 
   "OBJC-NIL-CLASS"
   "OBJC-NIL-OBJECT"

   "SEL-NAME"
   "SEL-GET-UID"
   "IVAR-NAME"
   "IVAR-TYPE"

   "METHOD-TYPE-SIGNATURE"
   "METHOD-SELECTOR"

   "TYPED-OBJC-MSG-SEND" 
   "UNTYPED-OBJC-MSG-SEND" 

   "ADD-OBJC-METHOD" 
   "ADD-OBJC-CLASS"
   "ENSURE-OBJC-CLASS"
   "MAKE-IVAR"

   "CFFI-TYPE-P"
   "OBJC-STRUCT-SLOT-VALUE"
   "SIMPLE-REPLACE-STRING"
   "SYMBOLS-TO-OBJC-SELECTOR"
   "OBJC-SELECTOR-TO-SYMBOLS"
   "SYMBOL-TO-OBJC-CLASS-NAME"
   "OBJC-CLASS-NAME-TO-SYMBOL"
   "*ACRONYMS*"))

(defpackage "CL-OBJC"
  (:use "COMMON-LISP" "OBJC-CFFI")
  (:export "INVOKE"
	   "SLET"
	   "DEFINE-OBJC-METHOD"
	   "DEFINE-OBJC-CLASS"
	   "WITH-IVAR-ACCESSORS"

	   "SELECTOR"))

(defpackage "OBJC-TYPES"
  (:use "COMMON-LISP" "YACC")
  (:export "PARSE-OBJC-TYPESTR" 
           "OBJC-UNKNOWN-TYPE" 
	   "TYPEMAP" 
	   "ENCODE-TYPES" 
	   "ENCODE-TYPE"))

(defpackage "OBJC-READER"
  (:use "COMMON-LISP" "OBJC-CFFI")
  (:export "ACTIVATE-OBJC-READER-MACRO" 
	   "RESTORE-READTABLE"
	   "*ACCEPT-UNTYPED-CALL*"))

(defpackage "CL-OBJC-EXAMPLES"
  (:use "COMMON-LISP" "CL-OBJC" "OBJC-CFFI" "OBJC-READER"))