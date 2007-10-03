;; Test suite for untyped-objc-msg-send
(in-package "CL-OBJC-TEST")

(in-suite :untyped-objc-msg-send)

(test untyped-instantiation "Test instantiation of ObjC object"
      (is (eq (class-of  (untyped-objc-msg-send (objc-get-class "NSObject") "alloc"))
	      (find-class 'objc-object)))
      (is 
       (string-equal (objc-cffi::class-name 
		      (objc-cffi::obj-class 
		       (objc-cffi:untyped-objc-msg-send (objc-cffi:objc-get-class "NSPlaceholderNumber") "alloc")))
		     (objc-cffi::class-name (objc-get-class "NSPlaceholderNumber")))))

(test untyped-length "Test getting an unsigned integer return value of a method using NSString#length"
      (is (= 3 (untyped-objc-msg-send (create-new-string "foo") "length"))))

(test untyped-characterAtIndex "Test getting a char return value and
passing a param to of a method using NSString#characterAtIndex:"
      (is (= (char-code #\b) (untyped-objc-msg-send (create-new-string "bar") "characterAtIndex:" 0)))
      (is (= (char-code #\z) (untyped-objc-msg-send (create-new-string "baz") "characterAtIndex:" 2))))

(test untyped-string-return "Test getting a string return value usign
NSString#UTF8String"
      (let ((string "foo"))
	(is (string-equal string
			  (untyped-objc-msg-send 
			   (untyped-objc-msg-send 
			    (untyped-objc-msg-send (objc-get-class "NSString") "alloc")
			    "initWithUTF8String:" 
			    string)
			   "UTF8String")))))

(test untyped-float-return "Test getting a float return value usign
NSNumber#floatValue"
      (let ((num (float 1.3)))
	(is (= num
	       (untyped-objc-msg-send 
		(untyped-objc-msg-send (objc-get-class "NSNumber") "numberWithDouble:" (float num 1.0d0))
		"floatValue")))))

(test untyped-double-return "Test getting a double float return value
usign NSNumber#doubleValue"
      (let ((num (float 1.3d0)))
	(is (= num
	       (untyped-objc-msg-send 
		(untyped-objc-msg-send (objc-get-class "NSNumber") "numberWithDouble:" num)
		"doubleValue")))))

(test untyped-signed-int-return "Test getting a signed integer return
value usign NSNumber#intValue"
      (let ((num -1))
	(is (= num
	       (untyped-objc-msg-send (untyped-objc-msg-send (objc-get-class "NSNumber") "numberWithInt:" num)
				      "intValue")))))

(test untyped-float-arguments "Test passing a single float argument with NSNumber#numberWithFloat:"
      (let ((num (float (random 1.3))))
	(is (= num
	       (untyped-objc-msg-send (untyped-objc-msg-send (objc-get-class "NSNumber") "numberWithFloat:" num)
				      "floatValue")))))

(test untyped-light-struct-returning-values "Test with method returning and passing a light struct value"
      (let ((range (cffi:foreign-alloc 'ns-range))
	    (intval (mod (random (get-universal-time)) 1000)))
	(setf (cffi:foreign-slot-value range 'ns-range 'length) intval)
	(let ((value-with-range (untyped-objc-msg-send (objc-get-class "NSValue") "valueWithRange:" range)))
	  (is (= intval (cffi:foreign-slot-value (untyped-objc-msg-send value-with-range "rangeValue") 'ns-range 'length))))))

(test untyped-big-struct-returning-values "Test with method returning and passing as input a big struct value"
      (cffi:with-foreign-object (rect 'ns-rect)
	(let ((floatval (random 4.0)))
	  (setf (cffi:foreign-slot-value (cffi:foreign-slot-value rect 'ns-rect 'size) 'ns-size 'width) floatval)
	  (let ((value-with-rect (untyped-objc-msg-send (objc-get-class "NSValue") "valueWithRect:" rect)))
	    (is (= floatval (cffi:foreign-slot-value (objc-struct-slot-value (untyped-objc-msg-send value-with-rect "rectValue") 'ns-rect 'size) 'ns-size 'width)))))))

(test untyped-passing-buffers-to-write "Test passing a buffer as argument
who should gets the result"
  (cffi:with-foreign-pointer (buffer (* (cffi:foreign-type-size :unsigned-short) 3))
    (untyped-objc-msg-send (create-new-string "foo") "getCharacters:" buffer)
    (is (= (char-code #\f) (cffi:mem-aref buffer :unsigned-short 0)))))