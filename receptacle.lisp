(in-package #:org.shirakumo.fraf.vpetjam)

(define-condition object-not-accepted (error) ())

(defclass receptacle (collider)
  ())

(defgeneric object-accepted-p (object receptacle))
(defgeneric receive (object receptacle))

(defmethod object-accepted-p (object (receptacle receptacle))
  NIL)

(defmethod receive (object (receptacle receptacle))
  (error 'object-not-accepted))

(define-shader-entity object (game-entity)
  ((height :initarg :height :initform 0.0 :accessor height)
   (hvel :initarg :hvel :initform 0.0 :accessor hvel)))

(defmethod handle :after ((ev tick) (object object))
  (when (< 0 (height object))
    (decf (hvel object) (* (dt ev) 15))
    (incf (height object) (hvel object))
    (when (<= (height object) 0.1)
      (cond ((<= (abs (hvel object)) 0.1)
             (setf (height object) 0.0)
             (setf (hvel object) 0.0)
             (vsetf (velocity object) 0 0))
            (T
             (nv* (velocity object) 0.5)
             (setf (hvel object) (* (hvel object) -0.5))
             (setf (height object) 0.1))))
    (let ((found (bvh:do-fitting (entity (bvh +world+) object)
                   (when (and (typep entity 'receptacle)
                              (object-accepted-p object entity))
                     (return entity)))))
      (when found (receive object found)))
    (nv+ (frame-velocity object) (velocity object))))

(defmethod apply-transforms progn ((object object))
  (translate-by 0 (height object) 0))

(defmethod receive :after ((object object) (receptacle receptacle))
  (when (slot-boundp object 'container)
    (leave* object T)))

(define-shader-entity basic-receptacle (basic-entity listener receptacle)
  ((bulge-time :initform 0.0 :accessor bulge-time)))

(defmethod receive :after ((object object) (receptacle basic-receptacle))
  (maybe-leave object)
  (setf (bulge-time receptacle) 0.0))

(defmethod handle :after ((ev tick) (receptacle basic-receptacle))
  (incf (bulge-time receptacle) (dt ev)))

(defmethod apply-transforms progn ((receptacle basic-receptacle))
  (let ((tt (bulge-time receptacle)))
    (flet ((ease (a b x &optional (by 'flare:sine-in-out))
             (ease x by a b)))
      (cond ((<= tt 0.2)
             (let ((x (/ tt 0.2)))
               (scale-by (ease 1.0 2.0 x)
                         (ease 1.0 0.5 x)
                         1)))
            ((<= tt 0.3)
             (let ((x (/ (- tt 0.2) 0.1)))
               (scale-by (ease 2.0 0.25 x)
                         (ease 0.5 2.2 x)
                         1)))
            ((<= tt 0.5)
             (let ((x (/ (- tt 0.3) 0.2)))
               (scale-by (ease 0.25 1.0 x)
                         (ease 2.2 1.0 x)
                         1)))))))
