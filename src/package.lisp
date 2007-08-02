(defpackage "OBJC-CFFI"
  (:use "COMMON-LISP" "CFFI")
  (:export "GET-CLASS-LIST" "GET-CLASS-METHODS" "CLASS-IVARS" "PRIVATE-IVAR" "CLASS-HAS-PUBLIC-IVARS"
           "OBJC-SELECTOR" "OBJC-CLASS" "OBJC-METHOD" "OBJC-IVAR" "OBJC-OBJECT" "OBJ-CLASS" "SUPER-CLASSES"
           "CLASS-GET-INSTANCE-METHOD" "CLASS-GET-CLASS-METHOD" "METHOD-TYPE-SIGNATURE"
           "OBJC-ID" "OBJC-SEL" "OBJC-CLASS-POINTER" "OBJC-BOOL" "OBJC-MSG-SEND" "OBJC-MSG-SEND-STRET" "OBJC-GET-CLASS"
           "TYPED-OBJC-MSG-SEND" "UNTYPED-OBJC-MSG-SEND" "ADD-OBJC-METHOD" "CFFI-TYPE-P"
	   "OBJC-STRUCT-SLOT-VALUE"))

(defpackage "CL-OBJC"
  (:use "COMMON-LISP" "CFFI"))

(defpackage "OBJC-TYPES"
  (:use "COMMON-LISP" "YACC")
  (:export "PARSE-OBJC-TYPESTR" "LEX-TYPESTR" "*OBJC-TYPE-PARSER*" "TYPESTR-LEXER"
           "OBJC-UNKNOWN-TYPE" "TYPEMAP" "ENCODE-TYPES" "ENCODE-TYPE"))

(defpackage "OBJC-READER"
  (:use "COMMON-LISP" "OBJC-CFFI")
  (:export "ACTIVATE-OBJC-READER-MACRO" "RESTORE-READTABLE"
	   "*ACCEPT-UNTYPED-CALL*"))