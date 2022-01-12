(in-package #:org.shirakumo.fraf.vpetjam)

(define-shader-entity creature (part-parent object genetical)
  ((name :initform (generate-name 'creature))
   (texture :initform (// 'vpetjam 'creature))
   (move-time :initform 1.0 :accessor move-time)
   (random-direction :initform -1 :accessor random-direction)
   (spd :initarg :spd :initform 5.0 :accessor spd))
  (:default-initargs :children '((:face  :uv (0 1) :pivot (0 0) :location (0 -10 0)))))

(defmethod shared-initialize :after ((creature creature) slots &key)
  (setf (vx (uv-offset creature)) (random 5))
  (setf (vx (uv-offset (part :face creature))) (random 5))
  (setf (hue creature) (alexandria:random-elt '(0.0 1.5 3.0 4.5 6.0)))
  (setf (spd creature) (alexandria:random-elt '(0.2 0.5 1.0 3.0 5.0 10.0))))

(defmethod apply-transforms progn ((creature creature))
  (scale-by 1.5 1.5 1))

(defmethod (setf direction) (dir (creature creature)))

(defmethod handle ((ev tick) (creature creature))
  (when (<= (height creature) 0)
    (let ((vel (velocity creature)))
      (case (hit-border creature)
        (:x (setf (vx vel) (* -1 (vx vel))))
        (:y (setf (vy vel) (* -1 (vy vel)))))
      (when (<= (decf (move-time creature) (dt ev)) 0.0)
        (let ((pol (cartesian->polar vel)))
          (v<- vel (polar->cartesian (vec (spd creature) (+ (vy pol) (* (random-direction creature) (dt ev) 3))))))
        (when (<= (move-time creature) -0.5)
          (setf (random-direction creature) (float-sign (random* 0.0 1.0)))
          (setf (move-time creature) (random* 2.0 1.0))))
      (nv+ (frame-velocity creature) vel))))
